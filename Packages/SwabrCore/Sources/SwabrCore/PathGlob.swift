import Darwin
import Foundation

public enum PathGlob {
    /// Replaces a leading `~` with `home`.
    public static func expandTilde(_ pattern: String, home: String) -> String {
        if pattern == "~" { return home }
        if pattern.hasPrefix("~/") { return home + pattern.dropFirst() }
        return pattern
    }

    /// Expands a glob pattern like bash without `dotglob`: `*` never matches a leading dot.
    public static func expand(_ pattern: String, home: String) -> [String] {
        let expanded = expandTilde(pattern, home: home)
        guard hasMagic(expanded) else {
            return exists(expanded) ? [expanded] : []
        }
        var g = glob_t()
        defer { globfree(&g) }
        guard glob(expanded, GLOB_BRACE | GLOB_NOSORT, nil, &g) == 0 else { return [] }
        var result: [String] = []
        for i in 0..<Int(g.gl_pathc) {
            if let p = g.gl_pathv[i] { result.append(String(cString: p)) }
        }
        return result.sorted()
    }

    /// fnmatch-style match where `*` may cross `/`, like bash `[[ $p == $pattern ]]`.
    public static func matches(_ path: String, pattern: String, home: String) -> Bool {
        fnmatch(expandTilde(pattern, home: home), path, 0) == 0
    }

    /// The leading path components of a pattern that contain no glob characters.
    public static func literalPrefix(_ pattern: String, home: String) -> String {
        let comps = expandTilde(pattern, home: home).split(separator: "/", omittingEmptySubsequences: false)
        var out: [Substring] = []
        for c in comps {
            if hasMagic(String(c)) { break }
            out.append(c)
        }
        return out.joined(separator: "/")
    }

    /// `a/{b,c}/d` → `a/b/d`, `a/c/d` (nested groups too). The whitelist matches with fnmatch, which knows no braces.
    public static func expandBraces(_ pattern: String) -> [String] {
        guard let open = pattern.firstIndex(of: "{") else { return [pattern] }
        var depth = 0
        var close: String.Index?
        var commas: [String.Index] = []
        var i = open
        while i < pattern.endIndex {
            switch pattern[i] {
            case "{": depth += 1
            case "}": depth -= 1; if depth == 0 { close = i }
            case "," where depth == 1: commas.append(i)
            default: break
            }
            if close != nil { break }
            i = pattern.index(after: i)
        }
        guard let close else { return [pattern] }
        let head = String(pattern[..<open]), tail = String(pattern[pattern.index(after: close)...])
        var bounds = [pattern.index(after: open)]
        for c in commas { bounds.append(pattern.index(after: c)) }
        var alternatives: [String] = []
        for (n, start) in bounds.enumerated() {
            let end = n + 1 < bounds.count ? commas[n] : close
            alternatives.append(String(pattern[start..<end]))
        }
        return alternatives.flatMap { expandBraces(head + $0 + tail) }
    }

    static func hasMagic(_ s: String) -> Bool {
        s.contains { "*?[{".contains($0) }
    }

    /// True for existing files, directories and dangling symlinks.
    static func exists(_ path: String) -> Bool {
        var st = stat()
        return lstat(path, &st) == 0
    }
}
