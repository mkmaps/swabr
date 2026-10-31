import Darwin
import Foundation

/// One launchd job (background service) found in a LaunchAgents or LaunchDaemons folder.
public struct StartupItem: Identifiable, Sendable, Hashable {
    public enum Kind: String, Sendable, Hashable, CaseIterable {
        case userAgent, systemAgent, daemon, loginItem

        public var title: String {
            switch self {
            case .userAgent: String(localized: "LaunchAgent (Benutzer)", bundle: .module)
            case .systemAgent: String(localized: "LaunchAgent (alle Benutzer)", bundle: .module)
            case .daemon: String(localized: "LaunchDaemon (System)", bundle: .module)
            case .loginItem: String(localized: "Anmeldeobjekt", bundle: .module)
            }
        }
    }

    /// Who changes the item: Swabr itself, or the user in System Settings.
    public enum Policy: Sendable, Hashable {
        case manageable, settings
    }

    public let label: String
    /// The plist file.
    public let path: String
    public let kind: Kind
    /// `Program`, or the first element of `ProgramArguments`.
    public let program: String?
    /// The `.app` bundle the program lives in.
    public let appPath: String?
    public let disabled: Bool
    /// Only known for user agents: the job is in `launchctl list`.
    public let loaded: Bool
    /// Set for Swabr's own, security, management and network services.
    public let protectedReason: String?

    public var id: String { path }

    public init(label: String, path: String, kind: Kind, program: String?, appPath: String?,
                disabled: Bool, loaded: Bool, protectedReason: String? = nil) {
        self.label = label
        self.path = path
        self.kind = kind
        self.program = program
        self.appPath = appPath
        self.disabled = disabled
        self.loaded = loaded
        self.protectedReason = protectedReason
    }

    /// The program is an absolute path that no longer exists.
    public var isBroken: Bool {
        guard let program, program.hasPrefix("/") else { return false }
        return !FileManager.default.fileExists(atPath: program)
    }

    public var policy: Policy { kind == .userAgent ? .manageable : .settings }

    public var isProtected: Bool { protectedReason != nil }

    /// Protected items only go once their program is gone; login items belong to System Events.
    public var canRemove: Bool {
        let orphan = isBroken && kind != .loginItem
        return isProtected ? orphan : (policy == .manageable || orphan)
    }

    public var displayName: String {
        guard let appPath else { return label }
        let name = ((appPath as NSString).lastPathComponent as NSString).deletingPathExtension
        return name.isEmpty ? label : name
    }
}

/// Lists launchd jobs and blocks, allows or removes them. Only the user's own agents are changed through
/// launchctl; system-wide items are left to System Settings unless their program is gone.
public enum StartupItems {
    /// Runs launchctl with the arguments; nil when it could not be started.
    typealias Runner = @Sendable ([String]) -> (status: Int32, output: String)?
    /// Moves a file to the Trash; nil on success, otherwise the reason.
    typealias Trash = @Sendable (String) -> String?

    static let ownMarker = "io.github.mkmaps.swabr"

    static let launchctl: Runner = { arguments in
        switch ToolRun.run("/bin/launchctl", arguments, timeout: 15) {
        case .exited(let status, let output): (status, String(decoding: output, as: UTF8.self))
        default: nil
        }
    }

    static let systemTrash: Trash = { path in
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    static var notManageable: String { String(localized: "Dieses Objekt kann Swabr nicht verwalten", bundle: .module) }

    // MARK: Listing

    public static func list(home: String = UserHome.path, protection: ProtectionData? = nil) -> [StartupItem] {
        let sources: [(String, StartupItem.Kind)] = [
            (home + "/Library/LaunchAgents", .userAgent),
            ("/Library/LaunchAgents", .systemAgent),
            ("/Library/LaunchDaemons", .daemon),
        ]
        return list(sources: sources, protection: protection ?? (try? RuleStore.protection()), run: launchctl)
    }

    static func list(sources: [(String, StartupItem.Kind)], protection: ProtectionData?, uid: uid_t = getuid(),
                     run: Runner) -> [StartupItem] {
        let domain = "gui/\(uid)"
        // Asked only once and only when user agents exist.
        var overrides: [String: Bool]?
        var loadedLabels: Set<String>?
        var out: [StartupItem] = []
        for (folder, kind) in sources {
            for path in plists(in: folder) {
                guard let job = readJob(path) else { continue }
                var disabled = job.disabled
                var loaded = false
                if kind == .userAgent {
                    if overrides == nil { overrides = run(["print-disabled", domain]).map { parseOverrides($0.output) } ?? [:] }
                    if loadedLabels == nil { loadedLabels = run(["list"]).map { parseList($0.output) } ?? [] }
                    disabled = overrides?[job.label] ?? job.disabled
                    loaded = loadedLabels?.contains(job.label) ?? false
                }
                out.append(StartupItem(
                    label: job.label, path: path, kind: kind, program: job.program,
                    appPath: job.program.flatMap(owningApp), disabled: disabled, loaded: loaded,
                    protectedReason: protectionReason(label: job.label, path: path, program: job.program, protection: protection)))
            }
        }
        return out
    }

    /// `*.plist` files of a folder, never Apple's own, sorted by name.
    static func plists(in folder: String) -> [String] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder) else { return [] }
        return names
            .filter { $0.hasSuffix(".plist") && !$0.hasPrefix(".") && !$0.lowercased().hasPrefix("com.apple.") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map { folder + "/" + $0 }
    }

    struct Job: Equatable {
        let label: String
        let program: String?
        let disabled: Bool
    }

    /// The fields of a launchd plist; nil when the file is no readable dictionary or belongs to Apple.
    static func readJob(_ path: String) -> Job? {
        guard let data = FileManager.default.contents(atPath: path),
              let dict = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
        else { return nil }
        let fileName = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        let label = (dict["Label"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fileName
        guard !label.lowercased().hasPrefix("com.apple.") else { return nil }
        let program = (dict["Program"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? (dict["ProgramArguments"] as? [Any])?.first as? String
        return Job(label: label, program: program, disabled: dict["Disabled"] as? Bool ?? false)
    }

    /// Labels that `launchctl print-disabled` reports as disabled.
    static func parseDisabled(_ text: String) -> Set<String> {
        Set(parseOverrides(text).filter(\.value).keys)
    }

    /// `"label" => disabled|enabled` (older systems: `true|false`) as label → disabled.
    static func parseOverrides(_ text: String) -> [String: Bool] {
        var out: [String: Bool] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.components(separatedBy: "=>")
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            guard key.count > 2, key.hasPrefix("\""), key.hasSuffix("\"") else { continue }
            let label = String(key.dropFirst().dropLast())
            switch parts[1].trimmingCharacters(in: .whitespaces).lowercased() {
            case "disabled", "true": out[label] = true
            case "enabled", "false": out[label] = false
            default: continue
            }
        }
        return out
    }

    /// Labels in the third column of `launchctl list` (`PID  Status  Label`).
    static func parseList(_ text: String) -> Set<String> {
        var out = Set<String>()
        for line in text.split(whereSeparator: \.isNewline).dropFirst() {
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
            if columns.count >= 3 { out.insert(String(columns[2])) }
        }
        return out
    }

    /// The outermost `.app` bundle on the program's path.
    static func owningApp(_ program: String) -> String? {
        guard program.hasPrefix("/") else { return nil }
        var path = ""
        for component in program.split(separator: "/") {
            path += "/" + component
            if component.count > 4, component.lowercased().hasSuffix(".app") { return path }
        }
        return nil
    }

    /// launchd labels Swabr passes to launchctl: letters, digits, dot, underscore, hyphen.
    static func validLabel(_ label: String) -> Bool {
        !label.isEmpty && label.unicodeScalars.allSatisfy { s in
            (s >= "a" && s <= "z") || (s >= "A" && s <= "Z") || (s >= "0" && s <= "9") || s == "." || s == "_" || s == "-"
        }
    }

    // MARK: Protection (REGELWERK S9)

    public static func protectionReason(label: String, path: String, program: String?, protection: ProtectionData?) -> String? {
        let texts = [label, path, program ?? ""].map { $0.lowercased() }
        if texts.contains(where: { $0.contains(ownMarker) }) {
            return String(localized: "Dienst von Swabr", bundle: .module)
        }
        guard let protection else { return nil }
        let lowLabel = label.lowercased()
        for rule in protection.officialUninstallerRules {
            let byPrefix = rule.bundlePrefixes.contains { !$0.isEmpty && lowLabel.hasPrefix($0.lowercased()) }
            let byName = rule.nameFragments.contains { fragment in texts.contains { containsWord(fragment.lowercased(), in: $0) } }
            if byPrefix || byName {
                return String(localized: "Sicherheits- oder Verwaltungssoftware (\(rule.vendor))", bundle: .module)
            }
        }
        if protection.sensitiveBundles.contains(where: { fnmatch($0.lowercased(), lowLabel, 0) == 0 }) {
            return String(localized: "Passwort-, Schlüssel- oder Netzwerkprogramm", bundle: .module)
        }
        return nil
    }

    /// `word` occurs with no letter or digit directly before or after it ("eset" is not in "resetdns").
    static func containsWord(_ word: String, in text: String) -> Bool {
        guard !word.isEmpty else { return false }
        func isWordChar(_ c: Character) -> Bool { c.isLetter || c.isNumber }
        var searchFrom = text.startIndex
        while let hit = text.range(of: word, range: searchFrom..<text.endIndex) {
            let before = hit.lowerBound == text.startIndex ? nil : text[text.index(before: hit.lowerBound)]
            let after = hit.upperBound == text.endIndex ? nil : text[hit.upperBound]
            if !(before.map(isWordChar) ?? false) && !(after.map(isWordChar) ?? false) { return true }
            searchFrom = text.index(after: hit.lowerBound)
        }
        return false
    }

    // MARK: App Store edition

    /// App Store edition: only the user's own agents whose program lies in an app inside a granted folder.
    public static func storeEdition(_ items: [StartupItem], grantedFolders: [String]) -> [StartupItem] {
        items.filter { item in
            guard item.kind == .userAgent, let app = item.appPath else { return false }
            return grantedFolders.contains { folder in
                let base = folder.count > 1 && folder.hasSuffix("/") ? String(folder.dropLast()) : folder
                return app == base || app.hasPrefix(base == "/" ? "/" : base + "/")
            }
        }
    }

    // MARK: Changing user agents

    /// Stops the agent and keeps launchd from starting it again. Nil on success, otherwise the reason.
    public static func block(_ item: StartupItem, confirmed: Bool = false) -> String? {
        block(item, confirmed: confirmed, uid: getuid(), run: launchctl)
    }

    static func block(_ item: StartupItem, confirmed: Bool, uid: uid_t, run: Runner) -> String? {
        if let why = item.protectedReason, !confirmed { return why }
        guard isChangeable(item) else { return notManageable }
        let domain = "gui/\(uid)"
        // Not running is fine here; the override below is what counts.
        _ = run(["bootout", domain, item.path])
        guard let done = run(["disable", "\(domain)/\(item.label)"]), done.status == 0 else {
            return String(localized: "Blockieren fehlgeschlagen", bundle: .module)
        }
        return nil
    }

    /// Removes the override and, while its program exists, loads the agent again.
    public static func allow(_ item: StartupItem) -> String? {
        allow(item, uid: getuid(), run: launchctl)
    }

    static func allow(_ item: StartupItem, uid: uid_t, run: Runner) -> String? {
        guard isChangeable(item) else { return notManageable }
        let domain = "gui/\(uid)"
        guard let done = run(["enable", "\(domain)/\(item.label)"]), done.status == 0 else {
            return String(localized: "Erlauben fehlgeschlagen", bundle: .module)
        }
        // Fails when the job is loaded already; the state shows after the next listing either way.
        if !item.isBroken { _ = run(["bootstrap", domain, item.path]) }
        return nil
    }

    /// Stops the user agent and moves its plist to the Trash.
    public static func remove(_ item: StartupItem, log: OperationLog = OperationLog()) -> String? {
        remove(item, home: UserHome.path, log: log, uid: getuid(), run: launchctl, trash: systemTrash)
    }

    static func remove(_ item: StartupItem, home: String, log: OperationLog, uid: uid_t, run: Runner, trash: Trash) -> String? {
        guard item.policy == .manageable, item.canRemove, isUserPlist(item.path, home: home) else { return notManageable }
        _ = run(["bootout", "gui/\(uid)", item.path])
        let bytes = DiskSize.allocatedSize(of: item.path)
        if let why = trash(item.path) { return why }
        log.record(action: "TRASH", path: item.path, bytes: bytes, label: "Startobjekt")
        return nil
    }

    /// A user agent with a label launchctl may be given.
    static func isChangeable(_ item: StartupItem) -> Bool {
        item.policy == .manageable && validLabel(item.label) && !PathSafety.hasControlCharacters(item.path)
    }

    /// A plain `.plist` directly inside `~/Library/LaunchAgents`.
    static func isUserPlist(_ path: String, home: String) -> Bool {
        let folder = home + "/Library/LaunchAgents"
        guard (path as NSString).deletingLastPathComponent == folder, path.hasSuffix(".plist"),
              case .ok = PathSafety.check(path, home: home) else { return false }
        return !isLink(path)
    }

    static func isLink(_ path: String) -> Bool {
        var st = stat()
        return lstat(path, &st) == 0 && (st.st_mode & S_IFMT) == S_IFLNK
    }

    // MARK: Orphaned system-wide items

    /// Moves orphaned system-wide plists to the user's Trash: with a root shell under one password prompt,
    /// otherwise one by one through `privilegedTrash`. Returns path → reason for every item still there.
    public static func removeSystem(_ items: [StartupItem], home: String = UserHome.path, log: OperationLog = OperationLog(),
                                    runPrivileged: (@Sendable (String) -> String?)?,
                                    privilegedTrash: (@Sendable (String) -> String?)? = nil) -> [String: String] {
        var failures: [String: String] = [:]
        var eligible: [StartupItem] = []
        for item in items {
            if isRemovableSystemItem(item) { eligible.append(item) } else { failures[item.path] = notManageable }
        }
        guard !eligible.isEmpty else { return failures }
        let sizes = Dictionary(eligible.map { ($0.path, DiskSize.allocatedSize(of: $0.path)) }, uniquingKeysWith: { a, _ in a })

        var reasons: [String: String] = [:]
        if let runPrivileged {
            _ = runPrivileged(systemScript(for: eligible, home: home, uid: getuid(), gid: getgid()))
        } else if let privilegedTrash {
            for item in eligible { if let why = privilegedTrash(item.path) { reasons[item.path] = why } }
        }
        let declined = String(localized: "nicht entfernt (Passwort abgelehnt?)", bundle: .module)
        for item in eligible {
            if FileManager.default.fileExists(atPath: item.path) || isLink(item.path) {
                failures[item.path] = reasons[item.path] ?? declined
            } else {
                log.record(action: "TRASH", path: item.path, bytes: sizes[item.path] ?? 0, label: "Startobjekt (System)")
            }
        }
        return failures
    }

    /// Spec: removable, orphaned, system-wide, a `.plist` below an allowed system root and no link.
    static func isRemovableSystemItem(_ item: StartupItem) -> Bool {
        item.canRemove && item.isBroken && (item.kind == .systemAgent || item.kind == .daemon)
            && item.path.hasSuffix(".plist") && !PathSafety.hasControlCharacters(item.path)
            && LeftoverFinder.isSafeSystemPath(item.path) && !isLink(item.path)
    }

    /// One root shell run: stop daemons, then each guarded move into the user's Trash, handed back to the user.
    static func systemScript(for items: [StartupItem], home: String, uid: uid_t, gid: gid_t) -> String {
        var lines = [RootScript.prelude(roots: RootScript.roots(home: home))]
        var taken = Set<String>()
        for item in items {
            if item.kind == .daemon {
                lines.append("/bin/launchctl bootout system \(RootScript.quote(item.path)) >/dev/null 2>&1")
            }
            let target = trashTarget(for: item.path, home: home, taken: &taken)
            lines.append(RootScript.move(item.path, to: target) + " && /usr/sbin/chown -h \(uid):\(gid) \(RootScript.quote(target))")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// A free name in `~/.Trash` (`name.plist`, `name 2.plist`, …), also free of names used earlier in the same run.
    static func trashTarget(for path: String, home: String, taken: inout Set<String>) -> String {
        let file = (path as NSString).lastPathComponent
        let base = (file as NSString).deletingPathExtension, ext = (file as NSString).pathExtension
        var candidate = home + "/.Trash/" + file
        var n = 2
        while taken.contains(candidate) || FileManager.default.fileExists(atPath: candidate) || isLink(candidate) {
            candidate = home + "/.Trash/\(base) \(n)" + (ext.isEmpty ? "" : "." + ext)
            n += 1
        }
        taken.insert(candidate)
        return candidate
    }
}
