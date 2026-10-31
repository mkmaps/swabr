import Foundation

/// Builds the shell steps that run as root (one password prompt per run). Every move checks its path again
/// inside the root shell, because the scan ran as the user and some folders in `/Library` (Caches) are
/// writable by every account: between the scan and the root step a folder could be swapped for a link that
/// aims the move somewhere else.
enum RootScript {
    /// Defines `ss_mv SOURCE TARGET`. It refuses (exit status 1, nothing moved) unless
    /// - the source lies below one of `roots`, has no `..` or `.` component and no `com.apple.` part,
    /// - neither the source nor its parent is a link, and the parent resolves physically to itself,
    /// - the target's folder is a real folder (not a link) and the target does not exist yet.
    /// The move then runs from inside the pinned parent (`cd -P`), so a later swap cannot redirect it.
    static func prelude(roots: [String]) -> String {
        let cases = roots.map { quote($0) + "?*" }.joined(separator: "|")
        return """
        ss_mv() {
          src="$1"; dst="$2"
          case "$src" in \(cases)) : ;; *) echo "refused: $src" >&2; return 1 ;; esac
          case "$src" in */../*|*/..|*/./*|*/.|*//*|*/com.apple.*) echo "refused: $src" >&2; return 1 ;; esac
          parent="${src%/*}"; leaf="${src##*/}"
          [ -n "$leaf" ] && [ -e "$src" ] && [ ! -L "$src" ] && [ ! -L "$parent" ] || { echo "refused: $src" >&2; return 1; }
          dparent="${dst%/*}"
          [ -d "$dparent" ] && [ ! -L "$dparent" ] && [ ! -e "$dst" ] && [ ! -L "$dst" ] || { echo "refused: $dst" >&2; return 1; }
          ( cd -P "$parent" 2>/dev/null && [ "$(pwd -P)" = "$parent" ] && [ ! -L "./$leaf" ] && /bin/mv "./$leaf" "$dst" )
        }
        """
    }

    /// `/Library` folders of `LeftoverFinder.systemRoots` plus the app folders, for moving root-owned apps.
    static func roots(home: String) -> [String] {
        LeftoverFinder.systemRoots + AppCatalog.roots(home: home).map { $0 + "/" }
    }

    static func move(_ source: String, to target: String) -> String {
        "ss_mv \(quote(source)) \(quote(target))"
    }

    /// Single-quotes a string for /bin/sh.
    static func quote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
}

/// Moves items the user may not move (their folder belongs to root) into the user's Trash as root, all in
/// one privileged step, and hands them back to the user. Every move is checked again by `ss_mv`.
public enum RootTrash {
    /// Returns where each moved item now lies in the Trash; items still in place are left out.
    /// `allowedRoots` limits the root step (folders with a trailing "/"); default: RootScript's roots.
    public static func move(_ paths: [String], home: String = UserHome.path, allowedRoots: [String]? = nil,
                            runPrivileged: @Sendable (String) -> String?) -> [String: String] {
        let roots = allowedRoots ?? RootScript.roots(home: home)
        let usable = paths.filter { p in roots.contains { p.hasPrefix($0) } && !PathSafety.hasControlCharacters(p) }
        guard !usable.isEmpty else { return [:] }
        let stamp = Int(Date().timeIntervalSince1970)
        var targets: [String: String] = [:]
        var steps: [String] = []
        for (n, path) in usable.enumerated() {
            let target = "\(home)/.Trash/\((path as NSString).lastPathComponent) \(stamp)-\(n)"
            targets[path] = target
            steps.append(RootScript.move(path, to: target) + " && /usr/sbin/chown -R \(getuid()):\(getgid()) " + RootScript.quote(target))
        }
        _ = runPrivileged(RootScript.prelude(roots: roots) + "\n" + steps.joined(separator: "; "))
        return targets.filter { !PathGlob.exists($0.key) && PathGlob.exists($0.value) }
    }

    /// True when the error means the user lacks the rights, so the root step may help.
    public static func isPermission(_ error: Error) -> Bool { ProtectedPath(path: "", error: error).kind == .permission }
}
