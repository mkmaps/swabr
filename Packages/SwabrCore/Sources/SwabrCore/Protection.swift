import Darwin
import Foundation

/// User whitelist in `~/.config/swabr/whitelist`:
/// one glob per line; an existing file replaces the optional defaults,
/// safety patterns always apply.
public struct Whitelist: Sendable {
    public enum LoadError: Error, LocalizedError {
        case unreadable(String)
        public var errorDescription: String? {
            if case .unreadable(let p) = self { return String(localized: "Whitelist nicht lesbar: \(p)", bundle: .module) }
            return nil
        }
    }

    public let home: String
    public private(set) var userPatterns: [String]
    public let safetyPatterns: [String]

    public init(home: String, userPatterns: [String], safetyPatterns: [String]) {
        self.home = home
        self.userPatterns = userPatterns
        self.safetyPatterns = safetyPatterns
    }

    public static func fileURL(home: String) -> URL {
        URL(fileURLWithPath: home).appending(path: ".config/swabr/whitelist")
    }

    /// Loads the user file, or the defaults if none exists. An unreadable file is an error,
    /// so a cleanup never runs without the protections the user saved.
    public static func load(home: String, protection: ProtectionData) throws -> Whitelist {
        let url = fileURL(home: home)
        var patterns = protection.defaultWhitelist
        if FileManager.default.fileExists(atPath: url.path) {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                throw LoadError.unreadable(url.path)
            }
            patterns = text.split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.hasPrefix("#") }
                .map { $0.replacingOccurrences(of: "$HOME", with: "~") }
        }
        return Whitelist(home: home, userPatterns: patterns, safetyPatterns: protection.safetyWhitelist)
    }

    public func save() throws {
        let url = Self.fileURL(home: home)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let body = "# Swabr whitelist: one glob per line, ~ = home\n" + userPatterns.joined(separator: "\n") + "\n"
        try body.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Deletes the user file, so the built-in defaults apply again.
    public static func reset(home: String) throws {
        let url = fileURL(home: home)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    public mutating func setProtected(_ pattern: String, _ on: Bool) {
        userPatterns.removeAll { $0 == pattern }
        if on { userPatterns.append(pattern) }
    }

    public func isProtected(pattern: String) -> Bool { userPatterns.contains(pattern) }

    /// Returns the pattern that protects `path`, if any. A path is protected when it matches a
    /// pattern, when it is the parent of a `dir/*` pattern, or when it contains a protected path.
    public func protectingPattern(for path: String) -> String? {
        for pattern in safetyPatterns + userPatterns {
            if PathGlob.matches(path, pattern: pattern, home: home) { return pattern }
            if pattern.hasSuffix("/*"),
               PathGlob.matches(path, pattern: String(pattern.dropLast(2)), home: home) { return pattern }
            let prefix = PathGlob.literalPrefix(pattern, home: home)
            if prefix.hasPrefix(path + "/") { return pattern }
        }
        return nil
    }
}

/// Last-line checks applied right before anything is removed.
public enum PathSafety {
    /// Directories that are never removed themselves, even if a rule matches them.
    static let neverRemove = [
        "", "Library", "Library/Caches", "Library/Logs", "Library/Application Support",
        "Library/Containers", "Library/Group Containers", "Library/Preferences",
        "Documents", "Desktop", "Downloads", "Pictures", "Movies", "Music", "Public", ".Trash",
    ]
    /// Subtrees that are never touched.
    static let neverTouch = ["Library/Mobile Documents", "Library/Keychains", "Library/CloudStorage", ".ssh", ".gnupg"]

    public enum Verdict: Equatable, Sendable {
        case ok
        case refused(String)
    }

    public static func check(_ path: String, home: String) -> Verdict {
        guard path.hasPrefix("/") else { return .refused(String(localized: "kein absoluter Pfad", bundle: .module)) }
        if hasControlCharacters(path) { return .refused(String(localized: "Pfad enthält Steuerzeichen", bundle: .module)) }
        let comps = path.split(separator: "/")
        if comps.contains("..") || comps.contains(".") { return .refused(String(localized: "relativer Pfadbestandteil", bundle: .module)) }
        guard path.hasPrefix(home + "/") else { return .refused(String(localized: "außerhalb des Benutzerordners", bundle: .module)) }
        let rel = String(path.dropFirst(home.count + 1))
        if neverRemove.contains(rel) { return .refused(String(localized: "geschützter Ordner", bundle: .module)) }
        if neverTouch.contains(where: { rel == $0 || rel.hasPrefix($0 + "/") }) { return .refused(String(localized: "geschützter Bereich", bundle: .module)) }

        // No symlinked ancestor between home and the target, so a link cannot redirect a delete.
        var ancestor = (path as NSString).deletingLastPathComponent
        while ancestor.count > home.count {
            var st = stat()
            guard lstat(ancestor, &st) == 0 else { return .refused(String(localized: "übergeordneter Ordner fehlt", bundle: .module)) }
            if (st.st_mode & S_IFMT) == S_IFLNK { return .refused(String(localized: "Symlink im Pfad", bundle: .module)) }
            ancestor = (ancestor as NSString).deletingLastPathComponent
        }
        return .ok
    }

    /// NUL, line breaks, escape and the other C0 controls or DEL: no real app names a file like that, and
    /// in a log line or a shell step they would split or hide what is removed.
    public static func hasControlCharacters(_ path: String) -> Bool {
        path.unicodeScalars.contains { $0.value < 0x20 || $0.value == 0x7F }
    }
}

/// Whitelist patterns for the "never clean" actions of the clean list.
public enum ProtectionPattern {
    /// Everything the item's rules cover, now and in later scans.
    public static func forItem(_ item: CleanItem, home: String = UserHome.path) -> [String] {
        let source = item.patterns.isEmpty ? item.paths : item.patterns
        var out: [String] = []
        for p in source.flatMap(PathGlob.expandBraces) {
            let t = tilde(p, home: home)
            if !out.contains(t) { out.append(t) }
        }
        return out
    }

    /// This one file or folder.
    public static func forPath(_ path: String, home: String = UserHome.path) -> String { tilde(path, home: home) }

    /// Everything of the app that owns `path` (its folder below Caches, Application Support or Containers).
    public static func forOwner(of path: String, home: String = UserHome.path) -> (owner: String, pattern: String)? {
        for anchor in CleanScanner.ownerAnchors {
            let prefix = home + anchor
            guard path.hasPrefix(prefix), let first = path.dropFirst(prefix.count).split(separator: "/").first else { continue }
            // Only when the path lies below the owner's folder; the folder itself is covered by forPath.
            guard path.count > prefix.count + first.count + 1 else { return nil }
            return (String(first), "~" + anchor + first + "/*")
        }
        return nil
    }

    /// Every folder with this name, wherever a rule finds it (`*/<name>/*` also protects the folder itself).
    public static func forName(of path: String) -> (name: String, pattern: String)? {
        let name = (path as NSString).lastPathComponent
        guard !name.isEmpty, !"*?[]{}".contains(where: name.contains), DirectoryScanner.isDirectory(path) else { return nil }
        return (name, "*/" + name + "/*")
    }

    static func tilde(_ path: String, home: String) -> String {
        path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
    }
}
