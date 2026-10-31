import CoreServices
import Darwin
import Foundation

/// Rules that depend on this Mac: where tools keep their caches, data of apps that are gone, aerials nobody
/// uses, superseded JetBrains versions. They are plain `CleanRule`s and run through `CleanScanner` like the
/// catalogue. `largeData` only reports big places the owning app should clean up itself.
public enum DynamicRules {
    public static let orphanSection = "leftovers"
    public static let defaultOrphanAgeDays = 30

    /// Seconds a helper tool (npm, xcode-select, xcrun) may run.
    static let toolTimeout: TimeInterval = 10

    /// All dynamic rules, specific ones first.
    public static func rules(home: String = UserHome.path, installedBundleIDs: Set<String>, protection: ProtectionData,
                             orphanAgeDays: Int = defaultOrphanAgeDays) -> [CleanRule] {
        toolCaches(home: home)
            + orphans(home: home, installed: installedBundleIDs, protection: protection, ageDays: orphanAgeDays)
            + unusedAerials(home: home)
            + oldJetBrains(home: home)
    }

    // MARK: - Tool caches

    /// Raw output of `npm config get cache`, or nil when npm is missing or fails.
    typealias NPMQuery = (_ home: String, _ environment: [String: String]) -> String?

    /// Cache rules for tools whose cache can be moved, at the place the tool itself uses. A place outside
    /// the home folder, or one that is a protected folder itself, drops the rule.
    static func toolCaches(home: String, environment: [String: String] = ProcessInfo.processInfo.environment,
                           npmCache: NPMQuery = npmConfigCache) -> [CleanRule] {
        func env(_ name: String) -> String? {
            environment[name].flatMap(singleAbsolutePath)
        }
        let xdgCache = env("XDG_CACHE_HOME")
        var out: [CleanRule] = []
        /// `children` are the cache's subfolders whose content is removed; "" is the cache folder itself.
        func add(_ label: String, _ kind: RuleKind, _ dir: String, _ children: [String]) {
            guard usableLocation(dir, home: home) else { return }
            out.append(CleanRule(section: "developer", label: label, kind: kind, paths: children.map { $0.isEmpty ? dir + "/*" : dir + "/" + $0 + "/*" }))
        }

        // npm: `npm config get cache` (npm docs, "config: cache"); default ~/.npm. Content cache in
        // `_cacache`, npx installs in `_npx`, debug logs in `_logs` ("Logging" in the npm docs).
        let npm = npmCache(home, environment).flatMap(singleAbsolutePath) ?? home + "/.npm"
        add("npm", .packages, npm, ["_cacache", "_npx"])
        add(String(localized: "npm-Protokolle", bundle: .module), .log, npm, ["_logs"])

        // Bun: BUN_INSTALL_CACHE_DIR, else $BUN_INSTALL/install/cache, default ~/.bun/install/cache
        // (Bun docs, "Global cache").
        let bun = env("BUN_INSTALL_CACHE_DIR") ?? env("BUN_INSTALL").map { $0 + "/install/cache" } ?? home + "/.bun/install/cache"
        add("Bun", .packages, bun, [""])

        // uv: UV_CACHE_DIR, else $XDG_CACHE_HOME/uv, else ~/.cache/uv (uv docs, "Caching").
        let uv = env("UV_CACHE_DIR") ?? xdgCache.map { $0 + "/uv" } ?? home + "/.cache/uv"
        add("uv", .packages, uv, [""])

        // Corepack: COREPACK_HOME, else $XDG_CACHE_HOME/node/corepack, else ~/.cache/node/corepack
        // (Corepack README, "Environment variables").
        let corepack = env("COREPACK_HOME") ?? xdgCache.map { $0 + "/node/corepack" } ?? home + "/.cache/node/corepack"
        add("Corepack", .packages, corepack, [""])

        // rustup: RUSTUP_HOME, default ~/.rustup (rustup book, "Environment variables"). Only partial
        // downloads and scratch files; toolchains stay.
        let rustup = env("RUSTUP_HOME") ?? home + "/.rustup"
        add("rustup", .packages, rustup, ["downloads", "tmp"])

        return out
    }

    /// Accepts tool output only when it is exactly one absolute path without `.`/`..` parts.
    static func singleAbsolutePath(_ output: String) -> String? {
        let text = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("/"), !text.contains(where: \.isNewline), !PathSafety.hasControlCharacters(text) else { return nil }
        let parts = text.split(separator: "/")
        guard !parts.contains("."), !parts.contains("..") else { return nil }
        return "/" + parts.joined(separator: "/")
    }

    /// Inside home, not a folder whose content is the user's own, and safe to use in a glob.
    static func usableLocation(_ dir: String, home: String) -> Bool {
        guard dir.hasPrefix(home + "/"), !PathGlob.hasMagic(dir) else { return false }
        let rel = String(dir.dropFirst(home.count + 1))
        if PathSafety.neverRemove.contains(rel) { return false }
        return !PathSafety.neverTouch.contains { rel == $0 || rel.hasPrefix($0 + "/") }
    }

    /// Runs `npm config get cache`. A GUI app has no shell PATH, so the usual install places are tried too;
    /// npm's own folder goes first on PATH so its `#!/usr/bin/env node` finds the matching node.
    static func npmConfigCache(home: String, environment: [String: String]) -> String? {
        let pathDirs = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        let candidates = pathDirs + ["/opt/homebrew/bin", "/usr/local/bin", home + "/.volta/bin", home + "/.local/bin"]
        guard let npm = candidates.lazy.map({ $0 + "/npm" }).first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return nil
        }
        var env = environment
        env["HOME"] = env["HOME"] ?? home
        env["PATH"] = ([(npm as NSString).deletingLastPathComponent] + pathDirs + ["/usr/bin", "/bin"]).joined(separator: ":")
        guard case .exited(0, let data) = ToolRun.run(npm, ["config", "get", "cache"], timeout: toolTimeout, environment: env) else {
            return nil
        }
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Leftovers of removed apps

    /// Process names of macOS itself, never treated as an app that is gone (Activity Monitor names).
    static let systemProcessNames: Set<String> = [
        "finder", "dock", "loginwindow", "systemuiserver", "windowserver", "controlcenter", "control center",
        "systemsettings", "system settings", "systempreferences", "system preferences", "safari",
        "systemeinstellungen", "kontrollzentrum",
    ]

    /// Cache, log and window-state folders named by a bundle id that no installed app has, unchanged for
    /// `ageDays`. One rule per source, always rated review.
    static func orphans(home: String, installed: Set<String>, protection: ProtectionData,
                        ageDays: Int = defaultOrphanAgeDays, now: Date = Date(),
                        isRegistered: (String) -> Bool = launchServicesKnows) -> [CleanRule] {
        let installedIDs = Set(installed.map { $0.lowercased() })
        let cutoff = now.addingTimeInterval(-Double(max(0, ageDays)) * 86_400)
        let neverPatterns = protection.sensitiveBundles + protection.systemCriticalBundles

        func isOrphan(_ id: String, path: String) -> Bool {
            guard isBundleID(id), DirectoryScanner.isDirectory(path), !PathGlob.hasMagic(path) else { return false }
            let lower = id.lowercased()
            if lower.hasPrefix("com.apple.") { return false }
            if systemProcessNames.contains(lower) || systemProcessNames.contains(String(lower.split(separator: ".").last ?? "")) { return false }
            if neverPatterns.contains(where: { fnmatch($0, id, FNM_CASEFOLD) == 0 }) { return false }
            if installedIDs.contains(where: { related(lower, $0) }) { return false }
            // The id itself and its parents (`com.vendor.app.ShipIt` belongs to `com.vendor.app`).
            var probe = id
            while probe.split(separator: ".").count >= 3 {
                if isRegistered(probe) { return false }
                probe = String(probe[..<probe.lastIndex(of: ".")!])
            }
            guard let modified = DirectoryScanner.modified(path) else { return false }
            return modified <= cutoff
        }

        func found(in dir: String, suffix: String = "") -> [String] {
            children(of: dir).compactMap { name in
                guard name.hasSuffix(suffix) else { return nil }
                let id = String(name.dropLast(suffix.count))
                let path = dir + "/" + name
                return isOrphan(id, path: path) ? path : nil
            }
        }

        let library = home + "/Library"
        let sources: [(String, RuleKind, [String])] = [
            (String(localized: "Caches entfernter Apps", bundle: .module), .cache, found(in: library + "/Caches")),
            (String(localized: "Logs entfernter Apps", bundle: .module), .log, found(in: library + "/Logs")),
            (String(localized: "Fensterzustände entfernter Apps", bundle: .module), .state,
             found(in: library + "/Saved Application State", suffix: ".savedState")),
        ]
        return sources.filter { !$0.2.isEmpty }.map {
            CleanRule(section: orphanSection, label: $0.0, kind: $0.1, safety: .review, paths: $0.2)
        }
    }

    /// Reverse-DNS name with at least three labels (two dots), like Apple's CFBundleIdentifier format:
    /// letters, digits, hyphens and underscores.
    static func isBundleID(_ name: String) -> Bool {
        let labels = name.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 3, let first = labels.first?.first, first.isLetter else { return false }
        return labels.allSatisfy { label in
            !label.isEmpty && label.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
        }
    }

    /// Same app or one nested in the other's id space (helpers, updaters, team-prefixed ids).
    private static func related(_ a: String, _ b: String) -> Bool {
        a == b || a.hasPrefix(b + ".") || b.hasPrefix(a + ".") || a.hasSuffix("." + b)
    }

    /// Apps outside the Applications folders that Launch Services still knows.
    static func launchServicesKnows(_ bundleID: String) -> Bool {
        guard let urls = LSCopyApplicationURLsForBundleIdentifier(bundleID as CFString, nil)?.takeRetainedValue() as? [URL] else {
            return false
        }
        return !urls.isEmpty
    }

    // MARK: - Aerials

    /// Downloaded aerial videos that neither the wallpaper nor the screen saver refers to. When a setting
    /// cannot be read, or aerials are shuffled, nothing is offered.
    static func unusedAerials(home: String) -> [CleanRule] {
        let base = home + "/Library/Application Support/com.apple.wallpaper"
        let videos = base + "/aerials/videos"
        let movies = children(of: videos).filter { $0.lowercased().hasSuffix(".mov") }
        guard !movies.isEmpty else { return [] }

        // Wallpaper choices (macOS 14+ store), then the per-host screen saver preferences.
        var plists = [base + "/Store/Index.plist"]
        let byHost = home + "/Library/Preferences/ByHost"
        plists += children(of: byHost).filter { $0.hasPrefix("com.apple.screensaver") && $0.hasSuffix(".plist") }.map { byHost + "/" + $0 }
        var mentioned: [String] = []
        for file in plists {
            guard let data = FileManager.default.contents(atPath: file),
                  let root = try? PropertyListSerialization.propertyList(from: data, format: nil) else { return [] }
            guard collect(root, into: &mentioned, depth: 0) else { return [] }
        }
        let text = mentioned.joined(separator: "\n")
        let unused = movies.filter { name in
            let id = String(name.dropLast(4)).lowercased()
            return !id.isEmpty && !text.contains(id)
        }.map { videos + "/" + $0 }.filter { !PathGlob.hasMagic($0) }
        guard !unused.isEmpty else { return [] }
        return [CleanRule(section: "system", label: String(localized: "Luftaufnahmen", bundle: .module), kind: .aerials, paths: unused)]
    }

    /// Gathers every string (and key) of a property list, also inside data values holding nested plists.
    /// Returns false when a choice is shuffled, as the shown videos are then not listed by id.
    private static func collect(_ value: Any, into out: inout [String], depth: Int) -> Bool {
        guard depth < 12 else { return true }
        switch value {
        case let s as String:
            out.append(s.lowercased())
        case let d as Data:
            if !d.isEmpty, let nested = try? PropertyListSerialization.propertyList(from: d, format: nil) {
                return collect(nested, into: &out, depth: depth + 1)
            }
        case let a as [Any]:
            for v in a where !collect(v, into: &out, depth: depth + 1) { return false }
        case let dict as [String: Any]:
            for (k, v) in dict {
                if k == "Shuffle", isSet(v) { return false }
                out.append(k.lowercased())
                if !collect(v, into: &out, depth: depth + 1) { return false }
            }
        default:
            break
        }
        return true
    }

    /// The store writes `"$null"` for an unset option.
    private static func isSet(_ value: Any) -> Bool {
        switch value {
        case let s as String: !s.isEmpty && s != "$null"
        case let d as Data: !d.isEmpty
        case let a as [Any]: !a.isEmpty
        case let d as [String: Any]: !d.isEmpty
        default: false
        }
    }

    // MARK: - JetBrains

    /// JetBrains IDEs keep one settings and one log folder per version, `<Product><Year>.<Release>`
    /// (JetBrains docs, "Directories used by the IDE"). The newest per product stays.
    static func oldJetBrains(home: String) -> [CleanRule] {
        let roots = [home + "/Library/Application Support/JetBrains", home + "/Library/Logs/JetBrains"]
        var folders: [(product: String, version: (Int, Int), path: String)] = []
        for root in roots {
            for name in children(of: root) {
                let path = root + "/" + name
                guard DirectoryScanner.isDirectory(path), !PathGlob.hasMagic(path),
                      let m = name.wholeMatch(of: /([A-Za-z][A-Za-z-]*)(\d{4})\.(\d{1,4})/),
                      let year = Int(m.2), let release = Int(m.3) else { continue }
                folders.append((String(m.1), (year, release), path))
            }
        }
        var newest: [String: (Int, Int)] = [:]
        for f in folders where newest[f.product].map({ f.version > $0 }) ?? true { newest[f.product] = f.version }
        let old = folders.filter { $0.version < newest[$0.product]! }.map(\.path).sorted()
        guard !old.isEmpty else { return [] }
        return [CleanRule(section: "developer", label: String(localized: "Ältere JetBrains-Versionen", bundle: .module),
                          kind: .state, safety: .review, paths: old)]
    }

    // MARK: - Large data (hint only)

    public struct LargeData: Identifiable, Sendable, Hashable {
        public var id: String { path }
        public let label: String
        public let path: String
        public let bytes: Int64
        /// Where to clean it up.
        public let hint: String

        public init(label: String, path: String, bytes: Int64, hint: String) {
            self.label = label
            self.path = path
            self.bytes = bytes
            self.hint = hint
        }
    }

    /// Big places Swabr never removes, with the way to clean them up in their own app; only those of at
    /// least `minimum` bytes, largest first.
    public static func largeData(home: String = UserHome.path, minimum: Int64 = 500 * 1_048_576) async -> [LargeData] {
        await largeData(home: home, minimum: minimum, runtimes: { unusedSimulatorRuntimes() })
    }

    static func largeData(home: String, minimum: Int64, runtimes: @escaping @Sendable () -> [LargeData]) async -> [LargeData] {
        let places = largePlaces(home: home).filter { DirectoryScanner.isDirectory($0.path) }
        async let simulators = Task.detached { runtimes() }.value
        let measured = await DirectoryScanner.measure(places.map(\.path)) { path, counter in
            DiskWalker.walk(path, trackLargeFiles: false, counter: counter)
        }
        var out = zip(places, measured).map { place, m in
            LargeData(label: place.label, path: place.path, bytes: m.1.bytes, hint: place.hint)
        }
        out += await simulators
        return out.filter { $0.bytes >= minimum }.sorted { $0.bytes != $1.bytes ? $0.bytes > $1.bytes : $0.path < $1.path }
    }

    /// Where apps keep large data they manage themselves.
    static func largePlaces(home: String) -> [(label: String, path: String, hint: String)] {
        let support = home + "/Library/Application Support"
        let models = String(localized: "LM-Studio-Modelle", bundle: .module)
        let modelsHint = String(localized: "Heruntergeladene KI-Modelle. In LM Studio unter „My Models“ löschen.", bundle: .module)
        let lima = String(localized: "Lima-Daten", bundle: .module)
        let limaHint = String(localized: "Virtuelle Maschinen von Lima/Colima.", bundle: .module)
        let claude = String(localized: "Claude: virtuelle Maschine", bundle: .module)
        let claudeHint = String(localized: "Arbeitsumgebung von Claude für Aufgaben am Computer. Wird bei Bedarf neu geladen; in Claude unter Einstellungen verwalten.", bundle: .module)
        return [
            // Apple support, "Locate backups of your iPhone, iPad and iPod touch".
            (String(localized: "iOS-Backups", bundle: .module), support + "/MobileSync/Backup",
             String(localized: "Backups von iPhone und iPad. Im Finder beim Gerät unter „Backups verwalten“ aufräumen.", bundle: .module)),
            // Mail keeps its mailboxes in ~/Library/Mail (Mail User Guide, "Import mailboxes").
            (String(localized: "Mail-Daten", bundle: .module), home + "/Library/Mail",
             String(localized: "Postfächer von Apple Mail. In Mail aufräumen, nicht direkt löschen.", bundle: .module)),
            // softwareupdate(8) downloads packages to /Library/Updates.
            (String(localized: "macOS-Updates", bundle: .module), "/Library/Updates",
             String(localized: "Heruntergeladene macOS-Updates.", bundle: .module)),
            // Xcode Organizer archives (Xcode Help, "Create an archive of your app").
            (String(localized: "Xcode-Archive", bundle: .module), home + "/Library/Developer/Xcode/Archives",
             String(localized: "Archivierte App-Builds. In Xcode im Organizer (Window → Organizer) löschen.", bundle: .module)),
            // Simulator devices of CoreSimulator (simctl help, "Devices and Simulators" window).
            (String(localized: "Xcode-Simulatoren", bundle: .module), home + "/Library/Developer/CoreSimulator/Devices",
             String(localized: "Simulatoren mit ihren Apps. In Xcode unter „Devices and Simulators“ verwalten.", bundle: .module)),
            // Docker Desktop docs, Settings → Resources → "Disk image location".
            (String(localized: "Docker-Daten", bundle: .module), home + "/Library/Containers/com.docker.docker/Data",
             String(localized: "Images und Container von Docker Desktop. Mit docker system prune aufräumen.", bundle: .module)),
            // OrbStack docs, FAQ "Where is data stored?".
            (String(localized: "OrbStack-Daten", bundle: .module), home + "/Library/Group Containers/HUAQ24HBR6.dev.orbstack/data",
             String(localized: "Container und VMs von OrbStack.", bundle: .module)),
            // Lima docs: LIMA_HOME defaults to ~/.lima; Colima README: its instances live in ~/.colima.
            (lima, home + "/.lima", limaHint),
            (lima, home + "/.colima", limaHint),
            // LM Studio docs, "Change models directory": ~/.lmstudio/models, older versions ~/.cache/lm-studio/models.
            (models, home + "/.lmstudio/models", modelsHint),
            (models, home + "/.cache/lm-studio/models", modelsHint),
            // Ollama FAQ, "Where are models stored?": ~/.ollama/models on macOS.
            (String(localized: "Ollama-Modelle", bundle: .module), home + "/.ollama/models",
             String(localized: "Heruntergeladene KI-Modelle. Mit ollama rm entfernen.", bundle: .module)),
            // Draw Things is sandboxed; its model folder sits in the app container's Documents.
            (String(localized: "Draw-Things-Modelle", bundle: .module), home + "/Library/Containers/com.liuliu.draw-things/Data/Documents/Models",
             String(localized: "Heruntergeladene Bildmodelle. In Draw Things unter Modelle verwalten.", bundle: .module)),
            // Maven settings reference: localRepository defaults to ${user.home}/.m2/repository.
            (String(localized: "Maven-Repository", bundle: .module), home + "/.m2/repository",
             String(localized: "Heruntergeladene Maven-Bibliotheken. Mit mvn dependency:purge-local-repository aufräumen.", bundle: .module)),
            // NuGet docs, "Managing the global packages, cache, and temp folders".
            (String(localized: "NuGet-Pakete", bundle: .module), home + "/.nuget/packages",
             String(localized: "Globaler Paketordner von NuGet. Mit dotnet nuget locals global-packages --clear aufräumen.", bundle: .module)),
            // pnpm docs, "storeDir": ~/Library/pnpm/store on macOS.
            (String(localized: "pnpm-Store", bundle: .module), home + "/Library/pnpm/store",
             String(localized: "Gemeinsamer Paketspeicher von pnpm. Mit pnpm store prune aufräumen.", bundle: .module)),
            // Claude desktop app: VM images for computer tasks (observed on a Mac with Claude installed).
            (claude, support + "/Claude/vm_bundles", claudeHint),
            (claude, support + "/Claude/claude-code-vm", claudeHint),
        ]
    }

    // MARK: - Simulator runtimes

    /// Days without use after which a simulator runtime is reported.
    static let runtimeUnusedDays = 60

    /// Runtimes from `xcrun simctl runtime list -j`, only with a full Xcode selected (the command line
    /// tools have no simctl, and xcrun would offer to install them).
    static func unusedSimulatorRuntimes() -> [LargeData] {
        guard case .exited(0, let dir) = ToolRun.run("/usr/bin/xcode-select", ["-p"], timeout: toolTimeout),
              let developer = singleAbsolutePath(String(decoding: dir, as: UTF8.self)),
              FileManager.default.isExecutableFile(atPath: developer + "/usr/bin/simctl"),
              case .exited(0, let json) = ToolRun.run("/usr/bin/xcrun", ["simctl", "runtime", "list", "-j"], timeout: toolTimeout)
        else { return [] }
        return unusedRuntimes(json: json)
    }

    /// Parses simctl's runtime list (an object keyed by runtime id with `lastUsedAt`, `sizeBytes`, `path`).
    /// A runtime without a last-use date, or one simctl cannot delete, is left out.
    static func unusedRuntimes(json: Data, now: Date = Date()) -> [LargeData] {
        guard let all = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any] else { return [] }
        let cutoff = now.addingTimeInterval(-Double(runtimeUnusedDays) * 86_400)
        let plain = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var out: [LargeData] = []
        for (key, value) in all {
            guard let r = value as? [String: Any],
                  let used = (r["lastUsedAt"] as? String).flatMap({ plain.date(from: $0) ?? fractional.date(from: $0) }),
                  used < cutoff,
                  (r["deletable"] as? Bool) ?? true,
                  let size = (r["sizeBytes"] as? NSNumber)?.int64Value, size > 0 else { continue }
            let id = (r["identifier"] as? String) ?? key
            guard !PathSafety.hasControlCharacters(id) else { continue }
            out.append(LargeData(label: String(localized: "Simulator-Laufzeit \(runtimeName(r, fallback: id))", bundle: .module),
                                 path: (r["path"] as? String) ?? "/Library/Developer/CoreSimulator/Images",
                                 bytes: size,
                                 hint: String(localized: "Seit über 60 Tagen nicht benutzt. Entfernen in Xcode → Einstellungen → Komponenten oder mit xcrun simctl runtime delete \(id).", bundle: .module)))
        }
        return out
    }

    /// `com.apple.CoreSimulator.SimRuntime.iOS-18-2` with version 18.2 → "iOS 18.2".
    private static func runtimeName(_ r: [String: Any], fallback: String) -> String {
        guard let runtime = (r["runtimeIdentifier"] as? String)?.split(separator: ".").last else { return fallback }
        let parts = runtime.split(separator: "-")
        guard let platform = parts.first else { return fallback }
        let version = (r["version"] as? String) ?? parts.dropFirst().joined(separator: ".")
        return version.isEmpty ? String(platform) : "\(platform) \(version)"
    }

    // MARK: - Helpers

    /// Names in a folder, sorted; empty when it cannot be read.
    private static func children(of dir: String) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).sorted()
    }
}
