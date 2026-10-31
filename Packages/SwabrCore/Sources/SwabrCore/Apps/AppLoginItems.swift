import Foundation

/// A login item an app registered itself through Service Management (macOS 13 and later). System Events does
/// not list these; System Settings → General → Login Items shows them under "Open at Login".
public struct AppLoginItem: Sendable, Hashable {
    /// Name of the app the user knows (the parent app for an embedded helper).
    public let name: String
    /// The app bundle the item belongs to, or the helper's own path when its app is unknown.
    public let appPath: String
    /// The app registered the item.
    public let enabled: Bool
    /// System Settings lets it run (the user can switch it off there).
    public let allowed: Bool

    /// Starts at login.
    public var starts: Bool { enabled && allowed }
}

/// Reads the per-user records of the Background Task Management database from `sfltool dumpbtm`. Started from
/// an app, the tool makes macOS ask for authorization every time, so it only runs as root through
/// Swabr's helper (`runAsRoot`), which asks nothing. Only registered login items count: records of apps
/// that merely can register themselves stay out.
public enum AppLoginItems {
    /// The command for the root step.
    public static let command = "/usr/bin/sfltool dumpbtm"

    /// Nil when the root step is not available or failed.
    public static func list(uid: uid_t = getuid(), runAsRoot: (String) -> String?) -> [AppLoginItem]? {
        guard let output = runAsRoot(command), output.contains("Records for UID") else { return nil }
        return parse(output, uid: uid)
    }

    struct Record {
        var fields: [String: String] = [:]
        var type: String { (fields["Type"] ?? "").components(separatedBy: " (").first ?? "" }
        var flags: Set<String> {
            guard let d = fields["Disposition"], let open = d.firstIndex(of: "["), let close = d.firstIndex(of: "]") else { return [] }
            return Set(d[d.index(after: open)..<close].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        }
        var enabled: Bool { flags.contains("enabled") }
        var allowed: Bool { flags.contains("allowed") }
        var path: String? {
            guard var url = fields["URL"], url != "(null)", !url.isEmpty else { return nil }
            if url.hasPrefix("file://") { url = URL(string: url)?.path ?? String(url.dropFirst(7)) }
            while url.count > 1 && url.hasSuffix("/") { url.removeLast() }
            return url
        }
    }

    static func parse(_ text: String, uid: uid_t) -> [AppLoginItem] {
        var records: [Record] = []
        var inUser = false
        var current: Record?
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("Records for UID ") {
                if let r = current, inUser { records.append(r) }
                current = nil
                let number = line.dropFirst("Records for UID ".count).split(separator: " ").first.map(String.init) ?? ""
                inUser = number == String(uid)
                continue
            }
            guard inUser else { continue }
            if line.hasPrefix("#"), line.hasSuffix(":"), Int(line.dropFirst().dropLast()) != nil {
                if let r = current { records.append(r) }
                current = Record()
                continue
            }
            guard current != nil, let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            if current?.fields[key] == nil { current?.fields[key] = value }
        }
        if let r = current, inUser { records.append(r) }

        let apps = Dictionary(records.filter { $0.type == "app" }.compactMap { r in
            r.fields["Identifier"].flatMap { id in r.path.map { (id, (path: $0, name: r.fields["Name"])) } }
        }, uniquingKeysWith: { a, _ in a })

        var byPath: [String: AppLoginItem] = [:]
        for r in records where r.enabled {
            let path: String
            switch r.type {
            case "app":
                // The app registered itself (SMAppService.mainApp).
                guard let p = r.path else { continue }
                path = p
            case "login item":
                // A helper inside an app bundle; its URL is relative to the parent app.
                if let parent = r.fields["Parent Identifier"].flatMap({ apps[$0] }) {
                    path = parent.path
                } else if let p = r.path, p.hasPrefix("/") {
                    path = p
                } else {
                    continue
                }
            default:
                continue
            }
            let name = (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
            let old = byPath[path]
            byPath[path] = AppLoginItem(name: name, appPath: path, enabled: true,
                                        allowed: r.allowed || (old?.allowed ?? false))
        }
        return byPath.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
