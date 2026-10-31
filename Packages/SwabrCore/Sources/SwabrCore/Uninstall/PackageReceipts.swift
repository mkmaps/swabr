import Foundation

/// Installer receipts (`pkgutil`) as proof that a file in `/Library` belongs to an app: the packages that
/// installed the app bundle, or whose id is the bundle id, list every file they put on the disk.
enum PackageReceipts {
    static let pkgutil = "/usr/sbin/pkgutil"

    /// `/Library` folders the app's packages installed and no other package shares, at most two levels below
    /// a system root (`Application Support/<Vendor>/<Product>` when the vendor folder is shared).
    static func systemPaths(for app: InstalledApp) -> [String] {
        let owners = ownerPackages(appPath: app.path, bundleID: app.bundleID)
        guard !owners.isEmpty else { return [] }
        var files: [String] = []
        for pkg in owners {
            let info = Shell.run(pkgutil, ["--pkg-info", pkg], timeout: 10).output
            guard let location = field("location", in: info) else { continue }
            let list = Shell.run(pkgutil, ["--files", pkg], timeout: 30).output
            files += list.split(separator: "\n").map { absolute(location: location, file: String($0)) }
        }
        var out: [String] = []
        for top in children(of: files, depth: 1) {
            if ownedOnly(top, by: owners) {
                out.append(top)
            } else {
                // Shared vendor folder: only the product folders below it that are the app's alone.
                out += children(of: files.filter { $0.hasPrefix(top + "/") }, depth: 2).filter { ownedOnly($0, by: owners) }
            }
        }
        return out.filter { LeftoverFinder.isSafeSystemPath($0) && PathGlob.exists($0) }
    }

    /// Packages that installed the app bundle, plus those named after its bundle id. Apple's never count.
    static func ownerPackages(appPath: String, bundleID: String) -> Set<String> {
        var owners = Set(pkgIDs(inFileInfo: Shell.run(pkgutil, ["--file-info", appPath], timeout: 10).output))
        if LeftoverFinder.isReverseDNS(bundleID) {
            let all = Shell.run(pkgutil, ["--pkgs"], timeout: 15).output.split(separator: "\n").map(String.init)
            owners.formUnion(all.filter { $0 == bundleID || $0.hasPrefix(bundleID + ".") })
        }
        return owners.filter { !$0.hasPrefix("com.apple.") }
    }

    /// True when every package that lists `path` is one of `owners`.
    static func ownedOnly(_ path: String, by owners: Set<String>) -> Bool {
        let ids = pkgIDs(inFileInfo: Shell.run(pkgutil, ["--file-info", path], timeout: 10).output)
        return !ids.isEmpty && ids.allSatisfy(owners.contains)
    }

    /// `pkgid:` lines of `pkgutil --file-info`.
    static func pkgIDs(inFileInfo text: String) -> [String] {
        text.split(separator: "\n").compactMap { line in
            line.hasPrefix("pkgid: ") ? String(line.dropFirst("pkgid: ".count)).trimmingCharacters(in: .whitespaces) : nil
        }
    }

    /// `key: value` line of `pkgutil --pkg-info`.
    static func field(_ key: String, in text: String) -> String? {
        text.split(separator: "\n").first { $0.hasPrefix(key + ": ") }.map { String($0.dropFirst(key.count + 2)) }
    }

    /// A receipt path is relative to the package's install location, which is relative to `/`.
    static func absolute(location: String, file: String) -> String {
        let base = location.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let rel = file.hasPrefix("./") ? String(file.dropFirst(2)) : file
        return ("/" + [base, rel].filter { !$0.isEmpty }.joined(separator: "/") as NSString).standardizingPath
    }

    /// The folders `depth` levels below a system root that the listed files lie in or are.
    static func children(of files: [String], depth: Int) -> [String] {
        var out: [String] = []
        for file in files {
            guard let root = LeftoverFinder.systemRoots.first(where: { file.hasPrefix($0) }) else { continue }
            let parts = file.dropFirst(root.count).split(separator: "/")
            guard parts.count >= depth else { continue }
            let child = root + parts.prefix(depth).joined(separator: "/")
            if !out.contains(child) { out.append(child) }
        }
        return out
    }
}
