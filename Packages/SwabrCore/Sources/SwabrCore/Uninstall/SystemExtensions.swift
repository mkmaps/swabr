import Foundation

/// System extensions (network filters, drivers, endpoint security) keep running after their app is
/// gone until they are switched off in System Settings; only macOS itself may remove them.
public enum SystemExtensions {
    public struct Entry: Sendable, Hashable {
        public let bundleID: String
        public let name: String
        public let active: Bool
    }

    public static func list() -> [Entry] {
        parse(Shell.run("/usr/bin/systemextensionsctl", ["list"], timeout: 10).output)
    }

    /// Lines look like `*\t*\tTEAMID\tcom.vendor.ext (1.0/1)\tName\t[activated enabled]`.
    static func parse(_ text: String) -> [Entry] {
        text.split(separator: "\n").compactMap { line in
            let cols = line.split(separator: "\t", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            guard cols.count >= 6, let state = cols.last, state.hasPrefix("[") else { return nil }
            let id = cols[3].components(separatedBy: " (").first ?? cols[3]
            guard id.contains(".") else { return nil }
            return Entry(bundleID: id, name: cols[4], active: state.contains("activated"))
        }
    }

    /// Active extensions that belong to one of the apps: the extension id starts with the app's id or
    /// comes from the same vendor (`com.vendor.*`).
    public static func stillActive(for appBundleIDs: [String], in entries: [Entry] = list()) -> [Entry] {
        func vendor(_ id: String) -> String { id.split(separator: ".").prefix(2).joined(separator: ".").lowercased() }
        return entries.filter { e in
            e.active && appBundleIDs.contains { e.bundleID.hasPrefix($0 + ".") || vendor(e.bundleID) == vendor($0) }
        }
    }
}
