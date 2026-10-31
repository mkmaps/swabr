import Foundation

/// Where root steps may take something from, as the app sees it (the helper checks again with its own rules).
enum RootScript {
    /// `/Library` folders of `LeftoverFinder.systemRoots` plus the app folders, for moving root-owned apps.
    static func roots(home: String) -> [String] {
        LeftoverFinder.systemRoots + AppCatalog.roots(home: home).map { $0 + "/" }
    }
}

/// Moves items the user may not move (their folder belongs to root) into the user's Trash as root, all in
/// one privileged step, and hands them back to the user. The helper checks every move itself.
public enum RootTrash {
    /// Returns where each moved item now lies in the Trash; items still in place are left out.
    /// `allowedRoots` limits what is handed to root (folders with a trailing "/"); default: RootScript's roots.
    public static func move(_ paths: [String], home: String = UserHome.path, allowedRoots: [String]? = nil,
                            runPrivileged: RootRunner) -> [String: String] {
        let roots = allowedRoots ?? RootScript.roots(home: home)
        let usable = paths.filter { p in roots.contains { p.hasPrefix($0) } && !PathSafety.hasControlCharacters(p) }
        guard !usable.isEmpty else { return [:] }
        let stamp = Int(Date().timeIntervalSince1970)
        var targets: [String: String] = [:]
        for (n, path) in usable.enumerated() {
            targets[path] = "\(home)/.Trash/\((path as NSString).lastPathComponent) \(stamp)-\(n)"
        }
        _ = runPrivileged(usable.map { .trash(source: $0, target: targets[$0]!) })
        return targets.filter { !PathGlob.exists($0.key) && PathGlob.exists($0.value) }
    }

    /// True when the error means the user lacks the rights, so the root step may help.
    public static func isPermission(_ error: Error) -> Bool { ProtectedPath(path: "", error: error).kind == .permission }
}
