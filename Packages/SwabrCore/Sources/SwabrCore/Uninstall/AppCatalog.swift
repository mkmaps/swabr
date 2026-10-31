import CoreServices
import Darwin
import Foundation

/// An app bundle found in one of the Applications folders.
public struct InstalledApp: Identifiable, Sendable, Hashable {
    public let name: String
    public let path: String
    public let bundleID: String
    public let version: String?
    /// Allocated bytes of the bundle.
    public let bytes: Int64
    /// Spotlight's "last opened" date, if it has one.
    public let lastUsed: Date?
    public let fromAppStore: Bool
    /// An iPhone/iPad app in its App Store wrapper.
    public let isIOSApp: Bool
    /// Why the app is never uninstalled, or nil.
    public let protection: String?
    /// The user cannot move the bundle (owned by root or another account).
    public let needsAdmin: Bool
    /// The Homebrew cask that installed the app.
    public let caskToken: String?

    public var id: String { path }
    public var isRemovable: Bool { protection == nil }

    public init(name: String, path: String, bundleID: String, version: String?, bytes: Int64, lastUsed: Date?,
                fromAppStore: Bool, isIOSApp: Bool = false, protection: String?, needsAdmin: Bool = false,
                caskToken: String? = nil) {
        self.name = name
        self.path = path
        self.bundleID = bundleID
        self.version = version
        self.bytes = bytes
        self.lastUsed = lastUsed
        self.fromAppStore = fromAppStore
        self.isIOSApp = isIOSApp
        self.protection = protection
        self.needsAdmin = needsAdmin
        self.caskToken = caskToken
    }
}

/// Lists the apps in `/Applications` and `~/Applications`. Reads only, changes nothing.
public enum AppCatalog {
    public static func roots(home: String = UserHome.path) -> [String] {
        ["/Applications", home + "/Applications"]
    }

    public static func installedApps(home: String = UserHome.path, protection: ProtectionData,
                                     ownBundleID: String? = Bundle.main.bundleIdentifier) async -> [InstalledApp] {
        let paths = bundlePaths(in: roots(home: home))
        let casks = caskApps()
        // Sizes take a while for big bundles; a few at a time keeps the disk busy without flooding it.
        var found: [InstalledApp] = []
        var index = 0
        while index < paths.count {
            let batch = paths[index..<min(index + 8, paths.count)]
            index += batch.count
            await withTaskGroup(of: InstalledApp?.self) { group in
                for path in batch {
                    group.addTask { describe(path, protection: protection, ownBundleID: ownBundleID, casks: casks) }
                }
                for await app in group { if let app { found.append(app) } }
            }
        }
        return found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// `.app` bundles directly in each root and one vendor folder deep (`/Applications/Adobe X/X.app`).
    /// Links are skipped, except those macOS itself places there (`AppBundle.isSystemProtected`).
    static func bundlePaths(in roots: [String]) -> [String] {
        var out: [String] = []
        func visit(_ folder: String, depth: Int) {
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder) else { return }
            for name in names.sorted() where !name.hasPrefix(".") {
                let path = folder + "/" + name
                var st = stat()
                guard lstat(path, &st) == 0 else { continue }
                let type = st.st_mode & S_IFMT
                if type == S_IFLNK {
                    if name.hasSuffix(".app"), AppBundle.isSystemProtected(path) { out.append(path) }
                } else if type == S_IFDIR {
                    if name.hasSuffix(".app") {
                        out.append(path)
                    } else if depth == 0 {
                        visit(path, depth: 1)
                    }
                }
            }
        }
        for root in roots { visit(root, depth: 0) }
        return out
    }

    /// The facts of one bundle, or nil when it has no bundle id.
    public static func describe(_ path: String, protection: ProtectionData, ownBundleID: String?,
                                casks: [String: String] = [:]) -> InstalledApp? {
        let info = AppBundle.info(path)
        guard let id = nonEmpty(info["CFBundleIdentifier"]) else { return nil }
        let fileName = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        let name = nonEmpty(info["CFBundleDisplayName"]) ?? nonEmpty(info["CFBundleName"]) ?? fileName
        let store = isFromAppStore(path)
        return InstalledApp(
            name: name, path: path, bundleID: id,
            version: nonEmpty(info["CFBundleShortVersionString"]) ?? nonEmpty(info["CFBundleVersion"]),
            bytes: DiskWalker.walk(path, skipNames: [], trackLargeFiles: false).bytes,
            lastUsed: lastUsedDate(path), fromAppStore: store, isIOSApp: isIOSApp(path),
            protection: protectionReason(bundleID: id, name: name, protection: protection, ownBundleID: ownBundleID,
                                         fromAppStore: store, path: path),
            needsAdmin: !canMove(path),
            caskToken: casks[(path as NSString).lastPathComponent.lowercased()])
    }

    private static func nonEmpty(_ value: Any?) -> String? {
        guard let s = (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return s
    }

    // MARK: Protection

    /// Why the app must stay, or nil: Swabr itself, part of macOS, or software that only its vendor's
    /// own uninstaller removes cleanly.
    public static func protectionReason(bundleID: String, name: String, protection: ProtectionData, ownBundleID: String?,
                                        fromAppStore: Bool = false, path: String? = nil) -> String? {
        if let own = ownBundleID, bundleID.caseInsensitiveCompare(own) == .orderedSame {
            return String(localized: "Diese App selbst", bundle: .module)
        }
        if let path, AppBundle.isSystemProtected(path) {
            return String(localized: "Systemkomponente von macOS", bundle: .module)
        }
        // A receipt proves the store installed it, so it is not part of the system.
        if !fromAppStore, matches(bundleID, protection.systemCriticalBundles),
           !matches(bundleID, protection.appleUninstallableApps) {
            return String(localized: "Systemkomponente von macOS", bundle: .module)
        }
        let lowerID = bundleID.lowercased()
        let words = wordsOf(name)
        for rule in protection.officialUninstallerRules {
            let byID = rule.bundlePrefixes.contains { lowerID.hasPrefix($0.lowercased()) }
            let byName = rule.nameFragments.contains { containsWords(words, wordsOf($0)) }
            if byID || byName {
                return String(localized: "Nur mit dem offiziellen \(rule.vendor)-Deinstallationsprogramm entfernen", bundle: .module)
            }
        }
        return nil
    }

    static func matches(_ id: String, _ patterns: [String]) -> Bool {
        patterns.contains { fnmatch($0, id, FNM_CASEFOLD) == 0 }
    }

    /// Lower-cased letter/digit runs: "ESET Endpoint-Security" → ["eset", "endpoint", "security"].
    static func wordsOf(_ text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    /// True when `part` occurs as a run of whole words in `words`.
    static func containsWords(_ words: [String], _ part: [String]) -> Bool {
        guard !part.isEmpty, part.count <= words.count else { return false }
        return (0...(words.count - part.count)).contains { Array(words[$0..<($0 + part.count)]) == part }
    }

    // MARK: Bundle facts

    /// Moving needs write access to the bundle (its `..` entry changes) and to the folder it lies in.
    public static func canMove(_ path: String) -> Bool {
        access(path, W_OK) == 0 && access((path as NSString).deletingLastPathComponent, W_OK) == 0
    }

    /// Account name of the bundle's owner.
    public static func owner(of path: String) -> String? {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.ownerAccountName] as? String
    }

    public static func lastUsedDate(_ path: String) -> Date? {
        guard let item = MDItemCreate(kCFAllocatorDefault, path as CFString) else { return nil }
        return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
    }

    public static func wrappedApp(_ path: String) -> String? { AppBundle.wrappedApp(path) }
    public static func isIOSApp(_ path: String) -> Bool { AppBundle.isIOSApp(path) }
    public static func isFromAppStore(_ path: String) -> Bool { AppBundle.isFromAppStore(path) }

    // MARK: Homebrew

    /// Lower-cased `.app` name → cask token, for every installed cask (`brew list --cask --versions`, then the
    /// app names from each cask's install record). Empty without Homebrew.
    public static func caskApps(brew: String? = AppUpdateChecker.brew) -> [String: String] {
        // Inside the App Store sandbox Homebrew's folders are out of reach.
        guard let brew, ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] == nil else { return [:] }
        let folder = (brew as NSString).deletingLastPathComponent
        let env = ["PATH": "\(folder):/usr/bin:/bin:/usr/sbin:/sbin", "HOME": UserHome.path,
                   "HOMEBREW_NO_AUTO_UPDATE": "1", "HOMEBREW_NO_ENV_HINTS": "1"]
        guard case .exited(0, let data) = ToolRun.run(brew, ["list", "--cask", "--versions"], timeout: 30, environment: env)
        else { return [:] }
        var out: [String: String] = [:]
        for token in parseCaskList(String(decoding: data, as: UTF8.self)) {
            for app in AppUpdateChecker.installedCaskApps(token) where out[app.lowercased()] == nil {
                out[app.lowercased()] = token
            }
        }
        return out
    }

    /// Tokens from `brew list --cask --versions` lines (`token version …`); anything that is no valid token is dropped.
    static func parseCaskList(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            line.split(separator: " ").first.map(String.init).flatMap { Uninstaller.isValidCaskToken($0) ? $0 : nil }
        }
    }
}
