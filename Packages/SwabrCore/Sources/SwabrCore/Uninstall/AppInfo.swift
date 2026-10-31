import Foundation
import Security

/// What is known about an app, to help decide whether it can go.
public struct AppInfo: Sendable, Hashable {
    public var developer: String?
    public var copyright: String?
    public var category: String?
    public var summary: String?
    public var summarySource: String?
    public var homepage: URL?
    public var storeURL: URL?
    public var homebrewURL: URL?
    public var searchURL: URL
}

public enum AppInfoLocal {
    /// Facts read from the bundle itself: no network.
    public static func read(_ app: InstalledApp) -> AppInfo {
        let info = AppBundle.info(app.path)
        let query = String(localized: "\(app.name) Mac App", bundle: .module).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? app.name
        return AppInfo(
            developer: signer(app.path),
            copyright: info["NSHumanReadableCopyright"] as? String,
            category: (info["LSApplicationCategoryType"] as? String).map(categoryName),
            searchURL: URL(string: "https://duckduckgo.com/?q=\(query)")!)
    }

    /// Name of whoever signed the app, from its leaf certificate
    /// ("Developer ID Application: Damien Elmes (7ZM8SLJM4P)" → "Damien Elmes").
    static func signer(_ path: String) -> String? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &code) == errSecSuccess, let code else {
            return nil
        }
        var dict: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &dict) == errSecSuccess,
              let info = dict as? [String: Any],
              let certs = info[kSecCodeInfoCertificates as String] as? [SecCertificate], let leaf = certs.first,
              let summary = SecCertificateCopySubjectSummary(leaf) as String?
        else { return nil }
        let isAppleID = (info[kSecCodeInfoIdentifier as String] as? String)?.hasPrefix("com.apple.") == true
        switch summary {
        case "Software Signing", "macOS Software Signing":
            return "Apple"
        case "Apple Mac OS Application Signing":
            // App Store re-signing hides the developer; the store lookup fills it in.
            return isAppleID ? "Apple" : nil
        default:
            var name = summary
            for prefix in ["Developer ID Application: ", "Apple Development: ", "Apple Distribution: ", "Mac Developer: "]
            where name.hasPrefix(prefix) { name.removeFirst(prefix.count) }
            if let paren = name.range(of: " (", options: .backwards) { name = String(name[..<paren.lowerBound]) }
            return name
        }
    }

    static func categoryName(_ uti: String) -> String {
        let names = [
            "productivity": String(localized: "Produktivität", bundle: .module), "utilities": String(localized: "Dienstprogramme", bundle: .module), "developer-tools": String(localized: "Entwicklung", bundle: .module),
            "education": String(localized: "Bildung", bundle: .module), "graphics-design": String(localized: "Grafik & Design", bundle: .module), "photography": String(localized: "Fotografie", bundle: .module),
            "video": String(localized: "Video", bundle: .module), "music": String(localized: "Musik", bundle: .module), "entertainment": String(localized: "Unterhaltung", bundle: .module), "games": String(localized: "Spiele", bundle: .module),
            "social-networking": String(localized: "Soziale Netze", bundle: .module), "business": String(localized: "Business", bundle: .module), "finance": String(localized: "Finanzen", bundle: .module),
            "reference": String(localized: "Nachschlagewerke", bundle: .module), "news": String(localized: "News", bundle: .module), "lifestyle": String(localized: "Lifestyle", bundle: .module),
            "healthcare-fitness": String(localized: "Gesundheit & Fitness", bundle: .module), "travel": String(localized: "Reisen", bundle: .module), "weather": String(localized: "Wetter", bundle: .module),
            "sports": String(localized: "Sport", bundle: .module), "medical": String(localized: "Medizin", bundle: .module),
        ]
        let key = uti.replacingOccurrences(of: "public.app-category.", with: "")
        return names[key] ?? key
    }
}

/// Online descriptions: the Homebrew cask catalogue (cached for 7 days) and, for App Store apps, Apple's lookup API.
public actor AppInfoService {
    public static let shared = AppInfoService()

    struct Cask: Decodable {
        let token: String
        let desc: String?
        let homepage: String?
        let version: String?
        let url: String?
        let sha256: String?
        let artifacts: [Artifact]?

        struct Artifact: Decodable {
            let app: [AppItem]?
            init(from decoder: Decoder) throws {
                let c = try? decoder.container(keyedBy: Key.self)
                app = try? c?.decodeIfPresent([AppItem].self, forKey: .app)
            }
            enum Key: String, CodingKey { case app }
        }

        /// Entries are either "Foo.app" or {"target": "Foo.app"}.
        struct AppItem: Decodable {
            let name: String?
            init(from decoder: Decoder) throws {
                if let s = try? decoder.singleValueContainer().decode(String.self) {
                    name = s
                } else {
                    let c = try? decoder.container(keyedBy: Key.self)
                    name = try? c?.decodeIfPresent(String.self, forKey: .target)
                }
            }
            enum Key: String, CodingKey { case target }
        }
    }

    struct CaskHit: Sendable {
        let token: String
        let desc: String?
        let homepage: String?
        let version: String?
        let url: String?
        let sha256: String?
    }

    private var caskIndex: [String: CaskHit]?
    private let cacheURL: URL
    private let catalogURL = URL(string: "https://formulae.brew.sh/api/cask.json")!

    public init(cacheDir: URL = URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Library/Caches/de.knieriem.swabr")) {
        cacheURL = cacheDir.appending(path: "homebrew-casks.json")
    }

    /// Adds descriptions and links to the local facts. Network failures leave the local facts untouched.
    public func enrich(_ app: InstalledApp, _ local: AppInfo) async -> AppInfo {
        var info = local
        if let hit = await cask(forBundleNamed: (app.path as NSString).lastPathComponent) {
            info.summary = hit.desc
            info.summarySource = "Homebrew"
            info.homepage = hit.homepage.flatMap(URL.init(string:))
            info.homebrewURL = URL(string: "https://formulae.brew.sh/cask/\(hit.token)")
        }
        if app.fromAppStore, let store = await storeLookup(bundleID: app.bundleID) {
            info.storeURL = store.url
            info.developer = info.developer ?? store.seller
            if info.summary == nil {
                info.summary = store.description
                info.summarySource = String(localized: "App Store", bundle: .module)
            }
            info.homepage = info.homepage ?? store.sellerURL
        }
        return info
    }

    func cask(forBundleNamed bundle: String) async -> CaskHit? {
        if caskIndex == nil { caskIndex = await loadIndex() }
        return caskIndex?[bundle.lowercased()]
    }

    private func loadIndex() async -> [String: CaskHit] {
        let fm = FileManager.default
        let fresh = (try? cacheURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            .map { Date().timeIntervalSince($0) < 7 * 86_400 } ?? false
        var data = fresh ? try? Data(contentsOf: cacheURL) : nil
        if data == nil, let (downloaded, response) = try? await URLSession.shared.data(from: catalogURL),
           (response as? HTTPURLResponse)?.statusCode == 200 {
            data = downloaded
            try? fm.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? downloaded.write(to: cacheURL, options: .atomic)
        }
        // An outdated copy is still better than nothing when offline.
        if data == nil { data = try? Data(contentsOf: cacheURL) }
        guard let data, let casks = try? JSONDecoder().decode([Cask].self, from: data) else { return [:] }
        return Self.index(casks)
    }

    static func index(_ casks: [Cask]) -> [String: CaskHit] {
        var out: [String: CaskHit] = [:]
        for c in casks {
            for a in c.artifacts ?? [] {
                for item in a.app ?? [] {
                    guard let name = item.name.map({ ($0 as NSString).lastPathComponent.lowercased() }) else { continue }
                    if out[name] == nil { out[name] = CaskHit(token: c.token, desc: c.desc, homepage: c.homepage, version: c.version, url: c.url, sha256: c.sha256) }
                }
            }
        }
        return out
    }

    /// Current App Store version, for the update check.
    func storeVersion(bundleID: String) async -> (version: String, url: URL?, trackID: Int?)? {
        guard let hit = await storeLookup(bundleID: bundleID), let v = hit.version else { return nil }
        return (v, hit.url, hit.trackID)
    }

    struct StoreHit {
        let version: String?
        let trackID: Int?
        let url: URL?
        let seller: String?
        let sellerURL: URL?
        let description: String?
    }

    private func storeLookup(bundleID: String) async -> StoreHit? {
        guard let id = bundleID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(id)&country=\(storeCountry)&entity=macSoftware"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let r = (json["results"] as? [[String: Any]])?.first
        else { return nil }
        let desc = (r["description"] as? String).map { text in
            text.count > 400 ? String(text.prefix(400)) + " …" : text
        }
        return StoreHit(
            version: r["version"] as? String,
            trackID: r["trackId"] as? Int,
            url: (r["trackViewUrl"] as? String).flatMap(URL.init(string:)),
            seller: (r["sellerName"] as? String) ?? (r["artistName"] as? String),
            sellerURL: (r["sellerUrl"] as? String).flatMap(URL.init(string:)),
            description: desc)
    }
}

/// The App Store region to ask: the Mac's region, since prices, availability and versions differ by store.
var storeCountry: String {
    (Locale.current.region?.identifier ?? "US").lowercased()
}
