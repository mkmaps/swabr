import Foundation

public struct AppUpdate: Identifiable, Sendable, Hashable {
    public enum Source: String, Sendable, Hashable {
        /// Installed with `brew install --cask`: updated with `brew upgrade`.
        case homebrew = "Homebrew"
        case appStore = "App Store"
        /// The app's own Sparkle feed: the vendor's download.
        case sparkle = "Hersteller (Update-Kanal)"
        /// Vendor download listed in the Homebrew catalogue; the app itself was installed some other way.
        case vendor = "Hersteller"

        public var title: String {
            switch self {
            case .homebrew: "Homebrew"
            case .appStore: "App Store"
            case .sparkle: String(localized: "Hersteller (Update-Kanal)", bundle: .module)
            case .vendor: String(localized: "Hersteller", bundle: .module)
            }
        }
    }

    public var id: String { app.path }
    public let app: InstalledApp
    public let installed: String
    public let available: String
    public let source: Source
    public var caskToken: String?
    /// Vendor download (dmg, zip or pkg) for Sparkle and vendor updates.
    public var download: URL?
    /// Expected SHA-256 of the download, when the catalogue has one.
    public var sha256: String?
    /// App Store item id for `mas upgrade`.
    public var storeID: Int?
    /// Store page or vendor website.
    public var link: URL?
}

/// Result for every installed app, so the list can show what is current too.
public struct UpdateReport: Sendable {
    public var updates: [AppUpdate] = []
    /// Apps with a known source that are on the latest version.
    public var upToDate: [InstalledApp] = []
    /// Apps without any source to compare against.
    public var unknown: [InstalledApp] = []

    public init() {}
}

/// Compares dotted versions numerically ("1.10" > "1.9"); text and build suffixes are ignored.
public enum Version {
    /// Homebrew versions carry build ids after a comma ("156.0.4314.42,f082dcef-…"); show only the version.
    public static func display(_ v: String) -> String {
        v.split(separator: ",").first.map(String.init) ?? v
    }

    public static func components(_ v: String) -> [Int] {
        display(v).split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
    }

    public static func isNewer(_ candidate: String, than installed: String) -> Bool {
        let a = components(candidate), b = components(installed)
        guard !a.isEmpty, !b.isEmpty else { return false }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}

public enum AppUpdateChecker {
    public static let brewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
    public static var brew: String? { brewPaths.first { FileManager.default.isExecutableFile(atPath: $0) } }
    public static let masPaths = ["/opt/homebrew/bin/mas", "/usr/local/bin/mas"]
    public static var mas: String? { masPaths.first { FileManager.default.isExecutableFile(atPath: $0) } }

    public static func check(_ apps: [InstalledApp], info: AppInfoService = .shared) async -> UpdateReport {
        var report = UpdateReport()
        var brewManaged = Set<String>()
        let byBundleName = Dictionary(apps.map { (($0.path as NSString).lastPathComponent.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })

        // 1. Casks installed through Homebrew.
        if let brew {
            let r = await Task.detached { Shell.run(brew, ["outdated", "--cask", "--greedy", "--json=v2"], timeout: 120) }.value
            for o in parseBrewOutdated(r.output) {
                for name in o.apps {
                    guard let app = byBundleName[name.lowercased()] else { continue }
                    brewManaged.insert(app.path)
                    report.updates.append(AppUpdate(
                        app: app, installed: app.version ?? Version.display(o.installed), available: Version.display(o.current),
                        source: .homebrew, caskToken: o.token, link: URL(string: "https://formulae.brew.sh/cask/\(o.token)")))
                }
            }
        }

        // 2. Everything else, in parallel.
        // At most eight lookups at a time: the App Store refuses bursts.
        let pending = apps.filter { !brewManaged.contains($0.path) && $0.isRemovable }
        await withTaskGroup(of: (InstalledApp, AppUpdate?, Bool).self) { group in
            var next = 0
            func addNext() {
                guard next < pending.count else { return }
                let app = pending[next]
                next += 1
                group.addTask {
                    let (update, known) = await otherSourceUpdate(app, info: info)
                    return (app, update, known)
                }
            }
            for _ in 0..<8 { addNext() }
            for await (app, update, known) in group {
                if let update { report.updates.append(update) } else if known { report.upToDate.append(app) } else { report.unknown.append(app) }
                addNext()
            }
        }
        let byName = { (a: InstalledApp, b: InstalledApp) in a.name.localizedStandardCompare(b.name) == .orderedAscending }
        report.updates.sort { byName($0.app, $1.app) }
        report.upToDate.sort(by: byName)
        report.unknown.sort(by: byName)
        return report
    }

    /// The update, if any, and whether a source to compare against was found at all.
    static func otherSourceUpdate(_ app: InstalledApp, info: AppInfoService) async -> (AppUpdate?, Bool) {
        // Safari web apps are web pages in a wrapper; they have nothing to update.
        guard let installed = app.version, !app.bundleID.hasPrefix("com.apple.Safari.WebApp") else { return (nil, false) }
        // A placeholder display version ("1.0") means the real one is in CFBundleVersion; otherwise that field
        // is a build number in another scheme (Chrome: 8059.85) and must not be compared.
        let build = ["1", "1.0", "1.0.0"].contains(installed) ? bundleVersion(app) : nil
        func newer(_ v: String) -> Bool { Version.isNewer(v, than: installed) && build.map { Version.isNewer(v, than: $0) } ?? true }

        if app.fromAppStore {
            guard let store = await info.storeVersion(bundleID: app.bundleID) else { return (nil, false) }
            guard newer(store.version) else { return (nil, true) }
            return (AppUpdate(app: app, installed: installed, available: store.version, source: .appStore,
                              storeID: store.trackID, link: store.url), true)
        }
        var known = false
        if let feed = sparkleFeed(app), let latest = await sparkleLatest(feed) {
            known = true
            if newer(latest.version) {
                return (AppUpdate(app: app, installed: installed, available: latest.version, source: .sparkle,
                                  download: latest.url), true)
            }
        }
        if let hit = await info.cask(forBundleNamed: (app.path as NSString).lastPathComponent),
           let v = hit.version.map(Version.display), v != "latest" {
            known = true
            if newer(v) {
                return (AppUpdate(app: app, installed: installed, available: v, source: .vendor, caskToken: hit.token,
                                  download: hit.url.flatMap(URL.init(string:)),
                                  sha256: hit.sha256 == "no_check" ? nil : hit.sha256,
                                  link: hit.homepage.flatMap(URL.init(string:))), true)
            }
        }
        return (nil, known)
    }

    static func bundleVersion(_ app: InstalledApp) -> String? {
        AppBundle.info(app.path)["CFBundleVersion"] as? String
    }

    struct Outdated {
        let token: String
        let installed: String
        let current: String
        let apps: [String]
    }

    static func parseBrewOutdated(_ json: String) -> [Outdated] {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let casks = root["casks"] as? [[String: Any]] else { return [] }
        return casks.compactMap { c in
            guard let token = c["name"] as? String ?? c["token"] as? String,
                  let current = c["current_version"] as? String else { return nil }
            let installed = (c["installed_versions"] as? [String])?.first ?? ""
            return Outdated(token: token, installed: installed, current: current, apps: installedCaskApps(token))
        }
    }

    /// The .app names a cask installed, from Homebrew's own install record.
    static func installedCaskApps(_ token: String) -> [String] {
        for prefix in ["/opt/homebrew", "/usr/local"] {
            let dir = "\(prefix)/Caskroom/\(token)/.metadata"
            guard let e = FileManager.default.enumerator(atPath: dir) else { continue }
            for case let rel as String in e where rel.hasSuffix(".json") && rel.contains("Casks/") {
                guard let data = FileManager.default.contents(atPath: dir + "/" + rel),
                      let cask = try? JSONDecoder().decode(AppInfoService.Cask.self, from: data) else { continue }
                let names = (cask.artifacts ?? []).flatMap { $0.app ?? [] }.compactMap { $0.name.map { ($0 as NSString).lastPathComponent } }
                if !names.isEmpty { return names }
            }
        }
        return []
    }

    static func sparkleFeed(_ app: InstalledApp) -> URL? {
        guard let feed = AppBundle.info(app.path)["SUFeedURL"] as? String, let url = URL(string: feed), url.scheme == "https" else { return nil }
        return url
    }

    static func sparkleLatest(_ feed: URL) async -> (version: String, url: URL?)? {
        var request = URLRequest(url: feed, timeoutInterval: 15)
        request.setValue("Swabr", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return parseAppcastItem(String(decoding: data, as: UTF8.self))
    }

    /// Newest `<item>` of an appcast: its version and enclosure download.
    static func parseAppcastItem(_ xml: String) -> (version: String, url: URL?)? {
        func first(_ pattern: String, in text: String) -> String? {
            let re = try! NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
            guard let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let r = Range(m.range(at: 1), in: text) else { return nil }
            return String(text[r])
        }
        let itemRE = try! NSRegularExpression(pattern: "<item>(.*?)</item>", options: [.dotMatchesLineSeparators])
        let items = itemRE.matches(in: xml, range: NSRange(xml.startIndex..., in: xml)).compactMap { Range($0.range(at: 1), in: xml).map { String(xml[$0]) } }
        var best: (String, URL?)?
        for item in items.isEmpty ? [xml] : items {
            guard let v = first(#"sparkle:shortVersionString="([^"]+)""#, in: item) ?? first(#"<sparkle:shortVersionString>([^<]+)<"#, in: item)
                ?? first(#"sparkle:version="([^"]+)""#, in: item) ?? first(#"<sparkle:version>([^<]+)<"#, in: item) else { continue }
            // Delta updates need the old build; take the full download only.
            let url = first(#"<enclosure[^>]*\surl="([^"]+)""#, in: item).flatMap(URL.init(string:))
            if best == nil || Version.isNewer(v, than: best!.0) { best = (v, url) }
        }
        return best
    }

    /// Kept for the tests and callers that only need the version.
    static func parseAppcast(_ xml: String) -> String? { parseAppcastItem(xml)?.version }

    /// `brew upgrade --cask <token>` as the user. Casks with a .pkg installer may still ask for a password and then fail here.
    public static func upgradeCask(_ token: String) -> (ok: Bool, message: String) {
        guard let brew, token.range(of: #"^[a-z0-9@._+-]+$"#, options: .regularExpression) != nil else {
            return (false, String(localized: "Homebrew nicht gefunden", bundle: .module))
        }
        let r = Shell.run(brew, ["upgrade", "--cask", token], timeout: 900)
        if r.status == 0 { return (true, "Aktualisiert") }
        let line = r.output.split(separator: "\n").last { $0.contains("rror") } ?? r.output.split(separator: "\n").last
        return (false, line.map(String.init) ?? String(localized: "Homebrew-Fehler", bundle: .module))
    }

    /// `mas upgrade <id>`; without mas the caller opens the App Store instead.
    public static func upgradeStoreApp(_ id: Int) -> (ok: Bool, message: String) {
        guard let mas else { return (false, String(localized: "mas nicht installiert", bundle: .module)) }
        let r = Shell.run(mas, ["upgrade", String(id)], timeout: 900)
        return r.status == 0 ? (true, "Aktualisiert") : (false, r.output.split(separator: "\n").last.map(String.init) ?? String(localized: "App-Store-Fehler", bundle: .module))
    }
}
