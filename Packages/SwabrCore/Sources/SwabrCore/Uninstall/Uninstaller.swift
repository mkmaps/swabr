import Darwin
import Foundation

/// One app and the leftovers chosen to go with it.
public struct UninstallPlan: Sendable, Hashable {
    public let app: InstalledApp
    public var leftovers: [Leftover]

    public init(app: InstalledApp, leftovers: [Leftover]) {
        self.app = app
        self.leftovers = leftovers
    }
}

public struct UninstallReport: Sendable {
    /// Names of the apps removed (or, with `dataOnly`, reset).
    public var removedApps: [String] = []
    public var removedBytes: Int64 = 0
    public var failures: [ProtectedPath] = []
    /// The apps stayed, only their data went.
    public var dataOnly = false
    /// System extensions of the removed apps that keep running; filled by the caller.
    public var activeExtensions: [SystemExtensions.Entry] = []

    public init() {}
}

/// Moves apps and their chosen leftovers to the Trash. Every step checks its path again, as the disk may
/// have changed since the scan.
public enum Uninstaller {
    /// Moves one item to the Trash with the user's consent (Finder or the system Trash service, both may ask for
    /// a password). Returns nil on success, otherwise the reason.
    public typealias PrivilegedTrash = @Sendable (String) -> String?
    /// Runs a shell script as root after one password prompt.
    public typealias RunPrivileged = @Sendable (String) -> String?

    /// Why the app may not be uninstalled, or nil.
    public static func refusal(forApp app: InstalledApp, home: String = UserHome.path) -> String? {
        if let why = app.protection { return why }
        if let own = Bundle.main.bundleIdentifier, app.bundleID.caseInsensitiveCompare(own) == .orderedSame {
            return String(localized: "Diese App selbst", bundle: .module)
        }
        if AppBundle.isSystemProtected(app.path) { return String(localized: "Systemkomponente von macOS", bundle: .module) }
        let notInApps = String(localized: "liegt nicht in einem Programme-Ordner", bundle: .module)
        let path = app.path
        let parts = path.split(separator: "/", omittingEmptySubsequences: false).dropFirst()
        guard path.hasPrefix("/"), path.hasSuffix(".app"), !PathSafety.hasControlCharacters(path),
              !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else { return notInApps }
        let parent = (path as NSString).deletingLastPathComponent
        let roots = AppCatalog.roots(home: home)
        if roots.contains(parent) { return nil }
        // One vendor folder deep (`/Applications/Adobe X/X.app`), but not inside another bundle.
        if roots.contains((parent as NSString).deletingLastPathComponent), !parent.hasSuffix(".app") { return nil }
        return notInApps
    }

    /// Homebrew cask tokens are lower-case letters, digits and `@._+-`; a leading dash would read as an option.
    static func isValidCaskToken(_ token: String) -> Bool {
        token.range(of: #"^[a-z0-9][a-z0-9@._+-]*$"#, options: .regularExpression) != nil
    }

    public static func quote(_ s: String) -> String { RootScript.quote(s) }

    // MARK: Run

    /// The outside world, replaceable in tests.
    struct Environment {
        /// Moves a path below home to the Trash.
        var trash: (String) throws -> Void
        var launchctl: ([String]) -> Void
        /// `brew uninstall --cask <token>`; true on success.
        var brewUninstall: (String) -> Bool
        var isSafeSystemPath: (String) -> Bool
        /// Allowed roots for the root script.
        var rootRoots: [String]
        var uid: uid_t
        var gid: gid_t

        static func live(home: String) -> Environment {
            Environment(
                trash: home == UserHome.path ? { try FileManager.default.trashItem(at: URL(fileURLWithPath: $0), resultingItemURL: nil) }
                                             : { try moveToTrashFolder($0, home: home) },
                launchctl: { _ = ToolRun.run("/bin/launchctl", $0, timeout: 15) },
                brewUninstall: Uninstaller.brewUninstall,
                isSafeSystemPath: LeftoverFinder.isSafeSystemPath,
                rootRoots: RootScript.roots(home: home),
                uid: getuid(), gid: getgid())
        }
    }

    /// For a home other than the real one (tests): a plain move into its `.Trash`.
    static func moveToTrashFolder(_ path: String, home: String) throws {
        try FileManager.default.createDirectory(atPath: home + "/.Trash", withIntermediateDirectories: true)
        var taken = Set<String>()
        try FileManager.default.moveItem(atPath: path, toPath: StartupItems.trashTarget(for: path, home: home, taken: &taken))
    }

    static func brewUninstall(_ token: String) -> Bool {
        guard let brew = AppUpdateChecker.brew else { return false }
        let folder = (brew as NSString).deletingLastPathComponent
        let env = ["PATH": "\(folder):/usr/bin:/bin:/usr/sbin:/sbin", "HOME": UserHome.path,
                   "HOMEBREW_NO_AUTO_UPDATE": "1", "HOMEBREW_NO_ENV_HINTS": "1"]
        guard case .exited(0, _) = ToolRun.run(brew, ["uninstall", "--cask", token], timeout: 600, environment: env) else { return false }
        return true
    }

    public static func run(_ plans: [UninstallPlan], home: String = UserHome.path, log: OperationLog = OperationLog(),
                           privilegedTrash: PrivilegedTrash? = nil, runPrivileged: RunPrivileged? = nil,
                           keepApps: Bool = false, progress: @escaping @Sendable (String) -> Void = { _ in }) -> UninstallReport {
        run(plans, home: home, log: log, privilegedTrash: privilegedTrash, runPrivileged: runPrivileged,
            keepApps: keepApps, progress: progress, env: .live(home: home))
    }

    /// One plan while it runs.
    private struct Work {
        let app: InstalledApp
        let label: String
        var userFiles: [Leftover] = []
        var systemFiles: [Leftover] = []
        /// The app is in the Trash (always true when the app stays).
        var appGone = false
        var needsRoot = false
        var removed = 0
        var failed = 0
    }

    /// Order: user agents stopped, movable apps removed (Homebrew or Trash), then one root step for the apps
    /// the user cannot move and for system files, then the home leftovers. Data of an app that stayed is kept.
    static func run(_ plans: [UninstallPlan], home: String, log: OperationLog, privilegedTrash: PrivilegedTrash?,
                    runPrivileged: RunPrivileged?, keepApps: Bool, progress: @escaping @Sendable (String) -> Void,
                    env: Environment) -> UninstallReport {
        var report = UninstallReport()
        report.dataOnly = keepApps
        let area = keepApps ? "Zurücksetzen" : "Deinstallieren"
        let declined = String(localized: "nicht entfernt (Passwort abgelehnt?)", bundle: .module)
        let needsAdmin = String(localized: "braucht Administratorrechte", bundle: .module)

        func fail(_ work: inout Work, _ failure: ProtectedPath) {
            report.failures.append(failure)
            work.failed += 1
        }
        func removed(_ work: inout Work, action: String = "TRASH", path: String, bytes: Int64, system: Bool = false) {
            report.removedBytes += bytes
            work.removed += 1
            log.record(action: action, path: path, bytes: bytes, label: work.label + (system ? " (System)" : ""))
        }

        func removeApp(_ work: inout Work) -> Bool {
            let app = work.app
            let bytes = app.bytes > 0 ? app.bytes : DiskSize.allocatedSize(of: app.path)
            if let token = app.caskToken, isValidCaskToken(token), env.brewUninstall(token), !exists(app.path) {
                removed(&work, action: "REMOVE", path: app.path, bytes: bytes)
                return true
            }
            do {
                try env.trash(app.path)
                removed(&work, path: app.path, bytes: bytes)
                return true
            } catch {
                let failure = ProtectedPath(path: app.path, error: error)
                guard failure.kind == .permission, let privilegedTrash else {
                    fail(&work, failure)
                    return false
                }
                return trashWithConsent(&work, app.path, bytes: bytes, system: false, privilegedTrash)
            }
        }

        func trashWithConsent(_ work: inout Work, _ path: String, bytes: Int64, system: Bool,
                              _ privilegedTrash: PrivilegedTrash) -> Bool {
            if let why = privilegedTrash(path) {
                fail(&work, .init(path: path, reason: why, kind: .permission))
                return false
            }
            if exists(path) {
                fail(&work, .init(path: path, reason: declined, kind: .permission))
                return false
            }
            removed(&work, path: path, bytes: bytes, system: system)
            return true
        }

        // 1. Check each plan and sort its leftovers into home and system files.
        var works: [Work] = []
        for plan in plans {
            if let why = refusal(forApp: plan.app, home: home) {
                report.failures.append(.init(path: plan.app.path, reason: why, kind: .protectedPath))
                continue
            }
            var work = Work(app: plan.app, label: "\(area): \(plan.app.name)")
            var seen = Set<String>()
            for l in plan.leftovers where seen.insert(l.path).inserted {
                if keepApps && isBackgroundService(l, home: home) { continue }
                if l.path.hasPrefix(home + "/") {
                    work.userFiles.append(l)
                } else if env.isSafeSystemPath(l.path) {
                    work.systemFiles.append(l)
                } else {
                    fail(&work, .init(path: l.path, reason: String(localized: "kein bekannter Systemordner", bundle: .module), kind: .protectedPath))
                }
            }
            work.appGone = keepApps
            works.append(work)
        }

        // 2.–4. User agents, then the apps the user can move.
        for i in works.indices {
            progress(works[i].app.name)
            guard !keepApps else { continue }
            for l in works[i].userFiles where isUserAgent(l.path, home: home) {
                env.launchctl(["bootout", "gui/\(env.uid)", l.path])
            }
            if AppCatalog.canMove(works[i].app.path) {
                works[i].appGone = removeApp(&works[i])
            } else {
                works[i].needsRoot = true
            }
        }

        // 5. Administrator step: locked apps and system files of apps that are gone (or stay, when resetting).
        let rootWorks = works.indices.filter { works[$0].needsRoot || (works[$0].appGone && !works[$0].systemFiles.isEmpty) }
        if !rootWorks.isEmpty {
            var sizes: [String: Int64] = [:]
            for i in rootWorks {
                for l in works[i].systemFiles { sizes[l.path] = DiskSize.allocatedSize(of: l.path) }
            }
            if let runPrivileged {
                var taken = Set<String>()
                var groups: [RootGroup] = []
                for i in rootWorks {
                    let w = works[i]
                    let app = w.needsRoot ? RootItem(source: w.app.path, target: StartupItems.trashTarget(for: w.app.path, home: home, taken: &taken)) : nil
                    let files = w.systemFiles.filter { exists($0.path) }.map {
                        RootItem(source: $0.path, target: StartupItems.trashTarget(for: $0.path, home: home, taken: &taken))
                    }
                    groups.append(RootGroup(app: app, files: files))
                }
                _ = runPrivileged(rootScript(groups, roots: env.rootRoots, uid: env.uid, gid: env.gid))
                for i in rootWorks {
                    if works[i].needsRoot {
                        if exists(works[i].app.path) {
                            fail(&works[i], .init(path: works[i].app.path, reason: declined, kind: .permission))
                            continue
                        }
                        works[i].appGone = true
                        let app = works[i].app
                        removed(&works[i], path: app.path, bytes: app.bytes)
                    }
                    for l in works[i].systemFiles {
                        if exists(l.path) {
                            fail(&works[i], .init(path: l.path, reason: declined, kind: .permission))
                        } else {
                            removed(&works[i], path: l.path, bytes: sizes[l.path] ?? l.bytes, system: true)
                        }
                    }
                }
            } else {
                // No root shell (App Store edition): one consent per item; daemons run until the next restart.
                for i in rootWorks {
                    if works[i].needsRoot {
                        guard let privilegedTrash else {
                            fail(&works[i], .init(path: works[i].app.path, reason: needsAdmin, kind: .permission))
                            continue
                        }
                        let app = works[i].app
                        works[i].appGone = trashWithConsent(&works[i], app.path, bytes: app.bytes, system: false, privilegedTrash)
                        guard works[i].appGone else { continue }
                    }
                    for l in works[i].systemFiles where exists(l.path) {
                        guard let privilegedTrash else {
                            fail(&works[i], .init(path: l.path, reason: needsAdmin, kind: .permission))
                            continue
                        }
                        _ = trashWithConsent(&works[i], l.path, bytes: sizes[l.path] ?? l.bytes, system: true, privilegedTrash)
                    }
                }
            }
        }

        // 6. Home leftovers, each checked again right before it moves.
        for i in works.indices where works[i].appGone {
            for l in works[i].userFiles where exists(l.path) {
                if case .refused(let why) = PathSafety.check(l.path, home: home) {
                    fail(&works[i], .init(path: l.path, reason: why, kind: .protectedPath))
                    continue
                }
                let bytes = DiskSize.allocatedSize(of: l.path)
                do {
                    try env.trash(l.path)
                    removed(&works[i], path: l.path, bytes: bytes)
                } catch {
                    let failure = ProtectedPath(path: l.path, error: error)
                    if failure.kind == .permission, let privilegedTrash {
                        _ = trashWithConsent(&works[i], l.path, bytes: bytes, system: false, privilegedTrash)
                    } else {
                        fail(&works[i], failure)
                    }
                }
            }
            if !keepApps || works[i].removed > 0 || works[i].failed == 0 { report.removedApps.append(works[i].app.name) }
        }
        return report
    }

    static func exists(_ path: String) -> Bool {
        var st = stat()
        return lstat(path, &st) == 0
    }

    /// A plist directly in `~/Library/LaunchAgents` that launchctl may be given.
    static func isUserAgent(_ path: String, home: String) -> Bool {
        (path as NSString).deletingLastPathComponent == home + "/Library/LaunchAgents" && path.hasSuffix(".plist")
            && !PathSafety.hasControlCharacters(path)
    }

    /// Jobs and helpers the app needs to run; they stay when only its data is reset.
    static func isBackgroundService(_ l: Leftover, home: String) -> Bool {
        l.kind == .launchAgent || l.path.hasPrefix(home + "/Library/LaunchAgents/")
            || ["/Library/LaunchAgents/", "/Library/LaunchDaemons/", "/Library/PrivilegedHelperTools/"].contains(where: l.path.hasPrefix)
    }

    // MARK: Root script

    struct RootItem {
        let source: String
        let target: String
    }

    /// A locked app (if any) and the system files that may go only once the app is gone.
    struct RootGroup {
        let app: RootItem?
        let files: [RootItem]
    }

    /// One shell run as root: each guarded move into the user's Trash is handed back to the user. A group's
    /// files move only after its app did; daemons are stopped right before their plist moves.
    static func rootScript(_ groups: [RootGroup], roots: [String], uid: uid_t, gid: gid_t) -> String {
        var lines = [RootScript.prelude(roots: roots)]
        func chown(_ path: String) -> String { "/usr/sbin/chown -R \(uid):\(gid) \(RootScript.quote(path))" }
        func fileLines(_ item: RootItem) -> [String] {
            var out: [String] = []
            if item.source.hasPrefix("/Library/LaunchDaemons/") {
                out.append("/bin/launchctl bootout system \(RootScript.quote(item.source)) >/dev/null 2>&1")
            } else if item.source.hasPrefix("/Library/LaunchAgents/") {
                out.append("/bin/launchctl bootout gui/\(uid) \(RootScript.quote(item.source)) >/dev/null 2>&1")
            }
            out.append(RootScript.move(item.source, to: item.target) + " && " + chown(item.target))
            return out
        }
        for group in groups {
            if let app = group.app {
                lines.append("if " + RootScript.move(app.source, to: app.target) + "; then")
                lines.append("  " + chown(app.target))
                lines += group.files.flatMap(fileLines).map { "  " + $0 }
                lines.append("fi")
            } else {
                lines += group.files.flatMap(fileLines)
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
