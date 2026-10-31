import Darwin
import Foundation

/// A file or folder that belongs to an app and stays behind when only the bundle is removed.
public struct Leftover: Identifiable, Sendable, Hashable {
    public enum Kind: String, Sendable, Hashable, CaseIterable {
        /// Recreated by the app: caches, logs, window state.
        case disposable
        /// A background job in `~/Library/LaunchAgents` that would keep starting a removed app.
        case launchAgent
        /// Settings, accounts, documents.
        case personal
        /// Shared group data and browser, emulator or game profiles.
        case sensitive
        /// Outside the home folder, needs administrator rights.
        case system
    }

    /// How the item was tied to the app.
    public enum Evidence: String, Sendable, Hashable {
        /// Bundle id, container metadata, vendor/product, program path or installer receipt.
        case identity
        /// Only the app's name: another app may use the same folder.
        case nameOnly
    }

    public let path: String
    public let kind: Kind
    public let bytes: Int64
    public let evidence: Evidence

    public var id: String { path }

    public init(path: String, kind: Kind, bytes: Int64, evidence: Evidence = .identity) {
        self.path = path
        self.kind = kind
        self.bytes = bytes
        self.evidence = evidence
    }

    /// Regenerable data and background jobs start ticked, but only when the item is proven to be the app's.
    public var preselected: Bool {
        evidence == .identity && (kind == .disposable || kind == .launchAgent)
    }

    /// What removing the item means, in one sentence.
    public var impact: String {
        let base: String
        switch kind {
        case .disposable:
            base = String(localized: "Cache, Log oder Fensterzustand der App.", bundle: .module)
        case .launchAgent:
            base = String(localized: "Hintergrunddienst, der sonst weiter versucht, die entfernte App zu starten.", bundle: .module)
        case .personal:
            if path.contains("/Library/Caches/") || path.contains("/.cache/") {
                base = String(localized: "Cache mit Inhalten von bleibendem Wert (z. B. Offline-Musik oder Verlauf). Nur gezielt löschen.", bundle: .module)
            } else if path.contains("/Library/Preferences/") {
                base = String(localized: "Einstellungen der App. Bei Neuinstallation startet sie wie neu.", bundle: .module)
            } else if path.contains("/Library/Application Support/") {
                base = String(localized: "Persönliche Daten der App, z. B. Konten, Bibliotheken, Plugins.", bundle: .module)
            } else if path.contains("/Library/Containers/") {
                base = String(localized: "Daten der App: Dokumente, Konten, Einstellungen.", bundle: .module)
            } else {
                base = String(localized: "App-Daten ohne bekannte Funktion. Vor dem Löschen prüfen.", bundle: .module)
            }
        case .sensitive:
            base = path.contains("/Library/Group Containers/")
                ? String(localized: "App-Gruppen-Daten: können von anderen Apps desselben Herstellers mitgenutzt werden.", bundle: .module)
                : String(localized: "Browser- oder Spielprofil: Passwörter, Verlauf, Spielstände. Nur gezielt löschen.", bundle: .module)
        case .system:
            if path.hasPrefix("/Library/LaunchDaemons/") {
                base = String(localized: "Systemdienst der App, läuft mit Administratorrechten im Hintergrund.", bundle: .module)
            } else if path.hasPrefix("/Library/PrivilegedHelperTools/") {
                base = String(localized: "Hilfsprogramm mit Administratorrechten, das die App installiert hat.", bundle: .module)
            } else if path.hasPrefix("/Library/Extensions/") {
                base = String(localized: "Kernel-Erweiterung. Wird erst nach einem Neustart vollständig entfernt.", bundle: .module)
            } else {
                base = String(localized: "Systemweite Datei der App (für alle Benutzer). Entfernen braucht dein Passwort.", bundle: .module)
            }
        }
        guard evidence == .nameOnly else { return base }
        return base + " " + String(localized: "Nur über den Namen gefunden, bitte prüfen.", bundle: .module)
    }
}

/// Finds the files an app left in the Library folders. Reads only, changes nothing.
public enum LeftoverFinder {
    /// `/Library` folders whose entries may be removed with administrator rights (REGELWERK S7). Audio
    /// plug-ins only in the per-format folders, never their shared parent.
    public static let systemRoots: [String] = [
        "/Library/Application Support/", "/Library/Caches/", "/Library/Logs/", "/Library/Preferences/",
        "/Library/LaunchAgents/", "/Library/LaunchDaemons/", "/Library/PrivilegedHelperTools/", "/Library/Receipts/",
        "/Library/Frameworks/", "/Library/Internet Plug-Ins/", "/Library/Input Methods/",
        "/Library/Audio/Plug-Ins/HAL/", "/Library/Audio/Plug-Ins/Components/", "/Library/Audio/Plug-Ins/VST/",
        "/Library/Audio/Plug-Ins/VST3/", "/Library/QuickLook/", "/Library/PreferencePanes/", "/Library/Screen Savers/",
        "/Library/Extensions/", "/Library/StartupItems/",
    ]

    /// Below an allowed root (never the root itself), no empty, `.` or `..` part, nothing of Apple's and no
    /// control characters.
    public static func isSafeSystemPath(_ path: String) -> Bool { isSafe(path, roots: systemRoots) }

    static func isSafe(_ path: String, roots: [String]) -> Bool {
        guard !PathSafety.hasControlCharacters(path), let root = roots.first(where: { path.hasPrefix($0) }) else { return false }
        let rest = path.dropFirst(root.count)
        guard !rest.isEmpty else { return false }
        for part in rest.split(separator: "/", omittingEmptySubsequences: false) {
            let lower = part.lowercased()
            if part.isEmpty || part == "." || part == ".." { return false }
            if lower.hasPrefix("com.apple.") || lower.hasPrefix("apple") { return false }
        }
        return true
    }

    /// At least two dot-separated parts of letters, digits, `-` and `_`, starting with a letter.
    public static func isReverseDNS(_ s: String) -> Bool {
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 2, s.first?.isASCII == true, s.first?.isLetter == true else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
        }
    }

    /// The bundle id a sandbox container belongs to, from the metadata macOS keeps in it.
    public static func containerOwner(_ container: String) -> String? {
        let url = URL(fileURLWithPath: container).appending(path: ".com.apple.containermanagerd.metadata.plist")
        guard let data = try? Data(contentsOf: url),
              let dict = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any],
              let id = dict["MCMMetadataIdentifier"] as? String, !id.isEmpty else { return nil }
        return id
    }

    /// Containers in `folder` whose metadata names `bundleID` or one of its extensions (`<id>.<more>`).
    static func containers(owning bundleID: String, in folder: String) -> [String] {
        let id = bundleID.lowercased()
        return children(of: folder) { !$0.hasPrefix(".") }.filter { path in
            guard let owner = containerOwner(path)?.lowercased() else { return false }
            return owner == id || owner.hasPrefix(id + ".")
        }
    }

    /// Full paths of the entries in `folder` whose name passes `filter`, sorted by name.
    public static func children(of folder: String, where filter: (String) -> Bool) -> [String] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder) else { return [] }
        return names.filter(filter).sorted().map { folder + "/" + $0 }
    }

    // MARK: Word lists

    /// Names that never count as a name match. Apple's own apps (Apple Support, "Apps included with your Mac",
    /// and the Utilities folder of macOS), generic words app makers use for helper folders, and vendor names
    /// that are folders shared by several products. Compared without spaces, dashes and underscores.
    static let commonNames: Set<String> = [
        // Apple apps
        "appstore", "automator", "books", "calculator", "calendar", "chess", "clock", "contacts", "dictionary",
        "facetime", "findmy", "fontbook", "freeform", "games", "home", "imagecapture", "imageplayground",
        "iphonemirroring", "journal", "launchpad", "mail", "maps", "messages", "missioncontrol", "music", "news",
        "notes", "passwords", "phone", "photobooth", "photos", "podcasts", "preview", "quicktimeplayer", "reminders",
        "safari", "shortcuts", "siri", "stickies", "stocks", "systemsettings", "systempreferences", "textedit",
        "timemachine", "tips", "tv", "voicememos", "weather", "finder", "activitymonitor", "airportutility",
        "audiomidisetup", "bluetoothfileexchange", "bootcampassistant", "colorsyncutility", "console",
        "digitalcolormeter", "diskutility", "grapher", "keychainaccess", "migrationassistant", "screenshot",
        "screensharing", "scripteditor", "systeminformation", "terminal", "voiceoverutility",
        // generic words
        "helper", "helpers", "agent", "agents", "update", "updates", "updater", "launcher", "installer", "uninstaller",
        "setup", "service", "services", "daemon", "app", "apps", "application", "applications", "support", "data",
        "cache", "caches", "log", "logs", "settings", "preferences", "config", "configuration", "plugin", "plugins",
        "extension", "extensions", "tool", "tools", "utility", "utilities", "browser", "player", "editor", "viewer",
        "reader", "manager", "client", "server", "sync", "backup", "backups", "desktop", "mac", "macos", "pro",
        "lite", "free", "default", "shared", "common", "temp", "tmp", "files", "documents", "downloads", "movies",
        "pictures", "library", "storage", "database", "cookies", "webkit", "code", "studio", "test", "demo",
        "crashpad", "crashreporter", "crashes", "sentry", "sparkle", "squirrel", "electron", "assistant",
        "dashboard", "developer", "account", "accounts", "notifications", "widget", "widgets",
        // shared vendor folders
        "apple", "google", "microsoft", "adobe", "mozilla", "jetbrains", "autodesk", "oracle",
    ]

    /// Release-channel words dropped from the end of a name ("Tidewell Beta" → "Tidewell"): the channel names
    /// of Chrome (Beta, Dev, Canary), Firefox (Beta, Developer Edition, Nightly), VS Code (Insiders),
    /// Safari (Technology Preview) and JetBrains (EAP).
    static let versionSuffixes = [
        "technology preview", "developer edition", "early access", "beta", "alpha", "nightly", "canary", "dev",
        "preview", "insiders", "insider", "eap", "rc",
    ]

    /// Second parts of bundle ids that name no vendor (`com.github.<project>`, Electron's default id).
    static let genericVendorParts: Set<String> = [
        "app", "apps", "mac", "macos", "osx", "software", "github", "gitlab", "sourceforge", "electron", "example",
    ]

    /// Caches whose content the user wants to keep, so they count as personal data: Spotify's offline music
    /// (Spotify support, "Storage" setting), Raycast's history, the Mullvad Browser (its data lives
    /// there; Mullvad help, "Mullvad Browser").
    static let valuableCaches: Set<String> = [
        "com.spotify.client", "spotify", "com.raycast.macos", "raycast",
        "net.mullvad.mullvadbrowser", "mullvadbrowser", "mullvad browser",
    ]

    /// Profile folders below Application Support that hold passwords, history or saved games: browsers
    /// (their documented profile locations), emulators (save-state folders named in their docs) and game
    /// launchers. Lower-cased paths relative to Application Support.
    static let profileFolders: Set<String> = [
        "google/chrome", "google/chrome beta", "google/chrome dev", "google/chrome canary", "chromium",
        "bravesoftware", "microsoft edge", "microsoft edge beta", "microsoft edge dev", "microsoft edge canary",
        "vivaldi", "com.operasoftware.opera", "arc", "firefox", "thunderbird", "zen", "torbrowser-data",
        "mullvadbrowser", "orion",
        "dolphin", "openemu", "retroarch", "ppsspp", "ryujinx", "pcsx2", "duckstation", "mgba", "cemu", "rpcs3",
        "steam", "epic", "minecraft", "battle.net", "blizzard", "gog.com", "crossover",
    ]

    /// Bundle id prefixes of the same browsers, emulators and launchers, so their containers count as profiles.
    static let profileBundles = [
        "com.google.chrome", "org.chromium.", "com.brave.browser", "com.microsoft.edgemac", "com.vivaldi.",
        "com.operasoftware.", "company.thebrowser.", "org.mozilla.", "org.torproject.", "com.kagi.kagimacos",
        "app.zen-browser.", "org.dolphin-emu.", "org.openemu.", "com.libretro.", "com.valvesoftware.steam",
        "com.epicgames.", "com.codeweavers.",
    ]

    // MARK: Search places

    /// Library folders whose entries are named by bundle id (`<id>`, `<id>.plist`, `<id>.savedState` …).
    static let idFolders = [
        "Library/Application Support", "Library/Caches", "Library/Logs", "Library/Preferences",
        "Library/Preferences/ByHost", "Library/Saved Application State", "Library/Containers", "Library/WebKit",
        "Library/HTTPStorages", "Library/Cookies", "Library/Application Scripts", "Library/Autosave Information",
    ]
    /// Folders where a team or group prefix stands in front of the id (`TEAM.<id>`, `group.<id>`).
    static let groupFolders = ["Library/Group Containers", "Library/Application Scripts"]
    /// Folders where apps name their entries after themselves.
    static let nameFolders = ["Library/Application Support", "Library/Caches", "Library/Logs", ".cache"]
    /// Folders with vendor/product subfolders (`Google/Chrome`).
    static let vendorFolders = ["Library/Application Support", "Library/Caches", "Library/Logs"]
    /// Places below home whose content is regenerated.
    static let disposableFolders = ["Library/Caches/", "Library/Logs/", "Library/Saved Application State/", ".cache/"]

    /// Where to look outside the home folder.
    struct SystemScope: Sendable {
        var roots: [String]
        var receipts: @Sendable (InstalledApp) -> [String]
        /// True when the package that installed the app also installed one of the other apps; its files are
        /// then shared and prove nothing about this app.
        var sharesInstaller: @Sendable (InstalledApp, [InstalledApp]) -> Bool = { _, _ in false }

        static let none = SystemScope(roots: [], receipts: { _ in [] })
        static var live: SystemScope {
            SystemScope(roots: LeftoverFinder.systemRoots, receipts: PackageReceipts.systemPaths,
                        sharesInstaller: LeftoverFinder.sharesInstaller)
        }
    }

    /// Asks the receipts of the app and of other installed apps from the same vendor (`com.vendor.*`), the
    /// usual case of one installer for a suite.
    static func sharesInstaller(_ app: InstalledApp, _ others: [InstalledApp]) -> Bool {
        func vendor(_ id: String) -> String? {
            let parts = id.lowercased().split(separator: ".")
            return parts.count >= 3 ? parts.prefix(2).joined(separator: ".") : nil
        }
        guard let mine = vendor(app.bundleID) else { return false }
        let peers = others.filter { vendor($0.bundleID) == mine }
        guard !peers.isEmpty else { return false }
        // An empty bundle id leaves out the packages named after it: only the installers of the bundles count.
        let owners = PackageReceipts.ownerPackages(appPath: app.path, bundleID: "")
        guard !owners.isEmpty else { return false }
        return peers.contains { !PackageReceipts.ownerPackages(appPath: $0.path, bundleID: "").isDisjoint(with: owners) }
    }

    static let defaultProtection: ProtectionData? = try? RuleStore.protection()

    // MARK: Search

    /// Everything that belongs to `app`. System files are looked up only for the real home folder.
    public static func find(for app: InstalledApp, otherApps: [InstalledApp], home: String = UserHome.path) -> [Leftover] {
        find(for: app, otherApps: otherApps, home: home, protection: defaultProtection,
             system: home == UserHome.path ? .live : .none)
    }

    static func find(for app: InstalledApp, otherApps: [InstalledApp], home: String, protection: ProtectionData?,
                     system: SystemScope) -> [Leftover] {
        let others = otherApps.filter { $0.path != app.path }
        // A second copy still needs the data.
        if others.contains(where: { $0.bundleID.caseInsensitiveCompare(app.bundleID) == .orderedSame }) { return [] }
        let search = Search(app: app, others: others, home: home, protection: protection, system: system)
        return search.run()
    }

    /// One search for one app; collects path → evidence, identity winning over a name match.
    private struct Search {
        let app: InstalledApp
        let others: [InstalledApp]
        let home: String
        let protection: ProtectionData?
        let system: SystemScope
        let id: String
        let idParts: [String]
        let names: Set<String>
        let exactNames: Set<String>

        init(app: InstalledApp, others: [InstalledApp], home: String, protection: ProtectionData?, system: SystemScope) {
            self.app = app
            self.others = others
            self.home = home
            self.protection = protection
            self.system = system
            id = app.bundleID.lowercased()
            idParts = id.split(separator: ".").map(String.init)
            names = LeftoverFinder.nameVariants(of: app, stripVersions: true)
            exactNames = LeftoverFinder.nameVariants(of: app, stripVersions: false)
        }

        func run() -> [Leftover] {
            var hits: [String: Leftover.Evidence] = [:]
            func add(_ path: String, _ evidence: Leftover.Evidence) {
                if hits[path] != .identity { hits[path] = evidence }
            }

            if LeftoverFinder.isReverseDNS(app.bundleID) {
                for folder in LeftoverFinder.idFolders {
                    for path in LeftoverFinder.children(of: home + "/" + folder, where: { idMatch($0) }) { add(path, .identity) }
                }
                for folder in LeftoverFinder.groupFolders {
                    for path in LeftoverFinder.children(of: home + "/" + folder, where: { groupMatch($0) }) { add(path, .identity) }
                }
                for folder in ["Library/Containers", "Library/Group Containers"] {
                    for path in LeftoverFinder.containers(owning: app.bundleID, in: home + "/" + folder) { add(path, .identity) }
                }
                for folder in LeftoverFinder.vendorFolders {
                    for path in vendorProduct(in: home + "/" + folder) { add(path, .identity) }
                }
            }
            for path in launchJobs(in: home + "/Library/LaunchAgents") { add(path, .identity) }
            for folder in LeftoverFinder.nameFolders {
                for path in LeftoverFinder.children(of: home + "/" + folder, where: { nameMatch($0) }) { add(path, .nameOnly) }
            }

            if !system.roots.isEmpty {
                for root in system.roots {
                    let folder = String(root.dropLast(root.hasSuffix("/") ? 1 : 0))
                    if LeftoverFinder.isReverseDNS(app.bundleID) {
                        for path in LeftoverFinder.children(of: folder, where: { idMatch($0) }) { add(path, .identity) }
                    }
                    if folder.hasSuffix("/LaunchAgents") || folder.hasSuffix("/LaunchDaemons") {
                        for path in launchJobs(in: folder) { add(path, .identity) }
                    }
                    if ["/Application Support", "/Caches", "/Logs"].contains(where: folder.hasSuffix) {
                        if LeftoverFinder.isReverseDNS(app.bundleID) {
                            for path in vendorProduct(in: folder) { add(path, .identity) }
                        }
                        for path in LeftoverFinder.children(of: folder, where: { nameMatch($0) }) { add(path, .nameOnly) }
                    }
                }
                let receipts = system.receipts(app)
                if !receipts.isEmpty, !system.sharesInstaller(app, others) {
                    for path in receipts { add(path, .identity) }
                }
            }

            let accepted = hits.filter { accept($0.key) }
            // Only the topmost of nested hits.
            let sorted = accepted.keys.sorted()
            var kept: [String] = []
            for path in sorted where !kept.contains(where: { path.hasPrefix($0 + "/") }) { kept.append(path) }
            return kept.map { path in
                Leftover(path: path, kind: kind(of: path), bytes: DiskSize.allocatedSize(of: path), evidence: accepted[path] ?? .nameOnly)
            }
        }

        // MARK: Matching

        /// `<id>` or `<id>.<more>`. Two-part ids (`com.vendor`) only exactly, so a vendor's other apps stay out.
        func idMatch(_ name: String) -> Bool {
            LeftoverFinder.idMatches(name.lowercased(), id: id, parts: idParts.count)
        }

        /// `TEAM.<id>`, `group.<id>`, `TEAM.<id>.<more>`, or the id itself.
        func groupMatch(_ name: String) -> Bool {
            let lower = name.lowercased()
            if idMatch(lower) { return true }
            guard let dot = lower.firstIndex(of: "."), dot != lower.startIndex else { return false }
            return LeftoverFinder.idMatches(String(lower[lower.index(after: dot)...]), id: id, parts: idParts.count)
        }

        func nameMatch(_ name: String) -> Bool {
            guard !name.hasPrefix(".") else { return false }
            let lower = name.lowercased()
            return names.contains(lower) || names.contains((lower as NSString).deletingPathExtension)
        }

        /// `<Vendor>/<Product>` from the bundle id: the vendor folder starts with the id's second part, the
        /// product folder is the id's last part or the app's name (also without the vendor word).
        func vendorProduct(in folder: String) -> [String] {
            guard idParts.count >= 3, idParts[0] != "com" || idParts[1] != "apple" else { return [] }
            let vendor = idParts[1]
            guard vendor.count >= 3, !LeftoverFinder.genericVendorParts.contains(vendor) else { return [] }
            var products = exactNames
            if let last = idParts.last, !LeftoverFinder.commonNames.contains(LeftoverFinder.compact(last)) { products.insert(last) }
            let withoutVendor = app.name.lowercased().split(separator: " ").filter { !$0.hasPrefix(vendor) && !vendor.hasPrefix($0) }
            if !withoutVendor.isEmpty {
                let rest = withoutVendor.joined(separator: " ")
                if rest.count >= 3, !LeftoverFinder.commonNames.contains(LeftoverFinder.compact(rest)) { products.insert(rest) }
            }
            var out: [String] = []
            for vendorFolder in LeftoverFinder.children(of: folder, where: { $0.lowercased().hasPrefix(vendor) }) {
                guard DirectoryScanner.isDirectory(vendorFolder), !isLink(vendorFolder) else { continue }
                out += LeftoverFinder.children(of: vendorFolder) { name in
                    let normal = name.lowercased().replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")
                    return products.contains(normal) || products.contains(LeftoverFinder.compact(normal))
                }
            }
            return out
        }

        /// launchd plists whose program lies inside the app or whose label is the app's id or starts with it.
        func launchJobs(in folder: String) -> [String] {
            LeftoverFinder.children(of: folder) { $0.hasSuffix(".plist") }.filter { path in
                let file = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
                guard let data = FileManager.default.contents(atPath: path),
                      let dict = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
                else { return LeftoverFinder.isReverseDNS(app.bundleID) && idMatch(file) }
                let label = (dict["Label"] as? String) ?? file
                let program = (dict["Program"] as? String) ?? ((dict["ProgramArguments"] as? [Any])?.first as? String)
                if let program, program.hasPrefix(app.path + "/") { return true }
                return LeftoverFinder.isReverseDNS(app.bundleID) && idMatch(label)
            }
        }

        // MARK: Filters

        func accept(_ path: String) -> Bool {
            var st = stat()
            guard lstat(path, &st) == 0 else { return false }
            let inHome = path.hasPrefix(home + "/")
            if inHome {
                guard case .ok = PathSafety.check(path, home: home) else { return false }
                let rel = String(path.dropFirst(home.count + 1))
                // Never a base folder itself.
                if PathSafety.neverRemove.contains(rel) || LeftoverFinder.idFolders.contains(rel)
                    || LeftoverFinder.groupFolders.contains(rel) || LeftoverFinder.nameFolders.contains(rel)
                    || rel == "Library/LaunchAgents" { return false }
            } else {
                guard LeftoverFinder.isSafe(path, roots: system.roots), !isLink(path) else { return false }
            }
            let name = (path as NSString).lastPathComponent
            let lower = name.lowercased()
            if lower.hasPrefix("com.apple."), !id.hasPrefix("com.apple.") { return false }
            if belongsToOtherApp(lower, path: path) { return false }
            // Data of password, key, wallet and VPN tools is never another app's leftover.
            if let sensitive = protection?.sensitiveBundles {
                // The entry and, for vendor/product hits, its vendor folder.
                let parent = ((path as NSString).deletingLastPathComponent as NSString).lastPathComponent
                for pattern in sensitive where !LeftoverFinder.matchesGlob(pattern, app.bundleID) {
                    if LeftoverFinder.matchesGlob(pattern, name) || LeftoverFinder.matchesGlob(pattern, parent) { return false }
                }
            }
            return true
        }

        /// The entry is named after another installed app: a more specific bundle id or its name.
        func belongsToOtherApp(_ lowerName: String, path: String) -> Bool {
            for other in others {
                let oid = other.bundleID.lowercased()
                if oid.count > id.count, LeftoverFinder.idMatches(lowerName, id: oid, parts: oid.split(separator: ".").count) { return true }
                // Another app's exact name wins over this app's version-stripped or vendor-less name.
                let otherNames = LeftoverFinder.nameVariants(of: other, stripVersions: false)
                let bare = (lowerName as NSString).deletingPathExtension
                if (otherNames.contains(lowerName) || otherNames.contains(bare)) && !exactNames.contains(lowerName)
                    && !exactNames.contains(bare) { return true }
            }
            return false
        }

        // MARK: Kind

        func kind(of path: String) -> Leftover.Kind {
            guard path.hasPrefix(home + "/") else { return .system }
            let rel = String(path.dropFirst(home.count + 1))
            if rel.hasPrefix("Library/LaunchAgents/") { return .launchAgent }
            if rel.hasPrefix("Library/Group Containers/") { return .sensitive }
            if LeftoverFinder.disposableFolders.contains(where: rel.hasPrefix) {
                let top = rel.split(separator: "/").dropFirst(rel.hasPrefix(".cache/") ? 1 : 2).first.map { $0.lowercased() } ?? ""
                return LeftoverFinder.valuableCaches.contains(top) ? .personal : .disposable
            }
            let support = "Library/Application Support/"
            if rel.hasPrefix(support) {
                let inner = rel.dropFirst(support.count).lowercased()
                if LeftoverFinder.profileFolders.contains(where: { inner == $0 || inner.hasPrefix($0 + "/") }) { return .sensitive }
            }
            if LeftoverFinder.profileBundles.contains(where: { id.hasPrefix($0) }) { return .sensitive }
            if let sensitive = protection?.sensitiveBundles, LeftoverFinder.matches(app.bundleID, sensitive) { return .sensitive }
            return .personal
        }

        func isLink(_ path: String) -> Bool {
            var st = stat()
            return lstat(path, &st) == 0 && (st.st_mode & S_IFMT) == S_IFLNK
        }
    }

    // MARK: Helpers

    /// `name` is `id` or `id.<more>`; with a two-part id only `id` plus a file extension.
    static func idMatches(_ name: String, id: String, parts: Int) -> Bool {
        if name == id { return true }
        guard name.hasPrefix(id + ".") else { return false }
        if parts >= 3 { return true }
        return ["plist", "savedstate", "binarycookies"].contains(String(name.dropFirst(id.count + 1)))
    }

    static func matchesGlob(_ pattern: String, _ text: String) -> Bool { fnmatch(pattern, text, FNM_CASEFOLD) == 0 }
    static func matches(_ id: String, _ patterns: [String]) -> Bool { patterns.contains { matchesGlob($0, id) } }

    /// Lower case without spaces, dashes and underscores.
    static func compact(_ s: String) -> String {
        String(s.lowercased().filter { $0 != " " && $0 != "-" && $0 != "_" })
    }

    /// Lower-cased spellings of the app's name and bundle file name: as is, without spaces, with `-` or `_`,
    /// and (with `stripVersions`) without a release-channel or version suffix. Short and common names are dropped.
    static func nameVariants(of app: InstalledApp, stripVersions: Bool) -> Set<String> {
        let file = ((app.path as NSString).lastPathComponent as NSString).deletingPathExtension
        var bases = Set([app.name.lowercased(), file.lowercased()])
        if stripVersions { bases.formUnion(bases.map(stripVersion)) }
        var out = Set<String>()
        for base in bases {
            let words = base.split(separator: " ").map(String.init)
            guard !words.isEmpty else { continue }
            let key = compact(base)
            guard key.count >= 3, !commonNames.contains(key), !commonNames.contains(base) else { continue }
            for variant in [words.joined(separator: " "), words.joined(), words.joined(separator: "-"), words.joined(separator: "_")] {
                out.insert(variant)
            }
        }
        return out
    }

    /// "Tidewell Beta 2" → "tidewell": trailing release-channel words and version numbers removed.
    static func stripVersion(_ name: String) -> String {
        var words = name.lowercased().split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "_" }).map(String.init)
        var changed = true
        while changed && words.count > 1 {
            changed = false
            if let last = words.last, last.range(of: #"^v?\d+(\.\d+)*$"#, options: .regularExpression) != nil {
                words.removeLast()
                changed = true
                continue
            }
            for suffix in versionSuffixes {
                let parts = suffix.split(separator: " ").map(String.init)
                if words.count > parts.count, Array(words.suffix(parts.count)) == parts {
                    words.removeLast(parts.count)
                    changed = true
                    break
                }
            }
        }
        return words.joined(separator: " ")
    }
}
