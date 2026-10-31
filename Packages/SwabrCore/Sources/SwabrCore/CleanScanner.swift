import Foundation

public struct CleanItem: Identifiable, Sendable, Hashable {
    public enum Status: Sendable, Hashable {
        case ready
        case skipped(String)
    }

    public var id: String { section + "|" + label + "|" + kind.rawValue }
    public let section: String
    public let label: String
    public let paths: [String]
    public let bytes: Int64
    public let status: Status
    public let kind: RuleKind
    public let safety: Safety
    /// Matches that were left alone, with the reason.
    public let protected: [ProtectedPath]
    /// The rule's running-app conditions, checked again by `Cleaner` right before removal.
    public var skipIfRunning: String? = nil
    public var skipRunningOwner = false
    /// Glob patterns of the rules behind this item, for "never clean".
    public var patterns: [String] = []

    public var isCleanable: Bool { status == .ready && !paths.isEmpty }

    /// The same item with every path the whitelist now protects moved to `protected`, without a new scan.
    public func applying(_ whitelist: Whitelist) -> CleanItem {
        var kept: [String] = []
        var newly: [ProtectedPath] = []
        var freed: Int64 = 0
        for path in paths {
            if let pattern = whitelist.protectingPattern(for: path) {
                newly.append(.init(path: path, reason: "Whitelist: \(pattern)", kind: .whitelist))
                freed += DiskSize.allocatedSize(of: path)
            } else {
                kept.append(path)
            }
        }
        guard !newly.isEmpty else { return self }
        return CleanItem(section: section, label: label, paths: kept, bytes: max(0, bytes - freed), status: status, kind: kind,
                         safety: safety, protected: protected + newly, skipIfRunning: skipIfRunning,
                         skipRunningOwner: skipRunningOwner, patterns: patterns)
    }
}

public struct ProtectedPath: Sendable, Hashable {
    /// Why an item was left alone, for grouping the result.
    public enum Kind: String, Sendable, Hashable, CaseIterable {
        case whitelist, protectedPath, running, permission, failed

        public var title: String {
            switch self {
            case .whitelist: String(localized: "Übersprungen: geschützte Daten", bundle: .module)
            case .protectedPath: String(localized: "Übersprungen: geschützter Ort", bundle: .module)
            case .running: String(localized: "Übersprungen: App läuft", bundle: .module)
            case .permission: String(localized: "Übersprungen: keine Berechtigung", bundle: .module)
            case .failed: String(localized: "Fehlgeschlagen", bundle: .module)
            }
        }
    }

    public let path: String
    public let reason: String
    public let kind: Kind

    public init(path: String, reason: String, kind: Kind = .failed) {
        self.path = path
        self.reason = reason
        self.kind = kind
    }

    /// Permission errors become `.permission`, everything else `.failed`.
    public init(path: String, error: Error) {
        let ns = error as NSError
        let denied = (ns.domain == NSCocoaErrorDomain && [NSFileWriteNoPermissionError, NSFileReadNoPermissionError].contains(ns.code))
            || (ns.domain == NSPOSIXErrorDomain && [Int(EACCES), Int(EPERM)].contains(ns.code))
            || ((ns.userInfo[NSUnderlyingErrorKey] as? NSError).map { $0.domain == NSPOSIXErrorDomain && [Int(EACCES), Int(EPERM)].contains($0.code) } ?? false)
        self.init(path: path, reason: error.localizedDescription, kind: denied ? .permission : .failed)
    }
}

/// Resolves every rule to concrete paths and sizes. Nothing is changed on disk.
public struct CleanScanner: Sendable {
    public let rules: [CleanRule]
    public let whitelist: Whitelist
    public let home: String
    public let isAppRunning: @Sendable (String) -> Bool

    public init(
        rules: [CleanRule], whitelist: Whitelist, home: String = UserHome.path,
        isAppRunning: @escaping @Sendable (String) -> Bool = { _ in false }
    ) {
        self.rules = rules
        self.whitelist = whitelist
        self.home = home
        self.isAppRunning = isAppRunning
    }

    struct Resolved: Sendable {
        let rule: CleanRule
        let paths: [String]
        let protected: [ProtectedPath]
        let status: CleanItem.Status
    }

    /// Rules run in order and each path belongs to the first rule that claims it. A rule skipped because
    /// its app runs still claims its paths, so a broader rule further down cannot pick them up.
    func resolve() -> [Resolved] {
        var claimed = Set<String>()
        /// Ancestors of claimed paths: a broad rule must not take a folder whose content a specific rule owns.
        var claimedAncestors = Set<String>()
        func claim<S: Sequence>(_ paths: S) where S.Element == String {
            for p in paths {
                claimed.insert(p)
                var a = (p as NSString).deletingLastPathComponent
                while a.count > home.count, claimedAncestors.insert(a).inserted {
                    a = (a as NSString).deletingLastPathComponent
                }
            }
        }
        func isClaimed(_ p: String) -> Bool {
            if claimed.contains(p) || claimedAncestors.contains(p) { return true }
            var a = (p as NSString).deletingLastPathComponent
            while a.count > home.count {
                if claimed.contains(a) { return true }
                a = (a as NSString).deletingLastPathComponent
            }
            return false
        }

        var out: [Resolved] = []
        for rule in rules {
            let keep = Set((rule.keep ?? []).map { PathGlob.expandTilde($0, home: home) })
            let exclude = rule.exclude ?? []
            var paths: [String] = []
            var protected: [ProtectedPath] = []
            for pattern in rule.paths {
                for path in PathGlob.expand(pattern, home: home) {
                    if keep.contains(path) || isClaimed(path) || paths.contains(path) { continue }
                    if exclude.contains(where: { PathGlob.matches(path, pattern: $0, home: home) }) { continue }
                    if rule.chromiumOnly == true, !Self.isChromiumAppFolder(of: path, home: home) { continue }
                    if let days = rule.minAgeDays,
                       let modified = DirectoryScanner.modified(path), modified > Date().addingTimeInterval(-Double(days) * 86_400) { continue }
                    if rule.skipRunningOwner == true, let owner = Self.owners(of: path, home: home).first(where: isAppRunning) {
                        claim([path])
                        protected.append(.init(path: path, reason: String(localized: "\(owner) läuft", bundle: .module), kind: .running))
                        continue
                    }
                    if let w = whitelist.protectingPattern(for: path) {
                        protected.append(.init(path: path, reason: "Whitelist: \(w)", kind: .whitelist))
                        continue
                    }
                    if case .refused(let why) = PathSafety.check(path, home: home) {
                        protected.append(.init(path: path, reason: why, kind: .protectedPath))
                        continue
                    }
                    paths.append(path)
                }
            }
            var status = CleanItem.Status.ready
            if let app = rule.skipIfRunning, !paths.isEmpty, isAppRunning(app) {
                status = .skipped(String(localized: "\(app) läuft", bundle: .module))
            }
            claim(paths)
            if !paths.isEmpty || !protected.isEmpty {
                out.append(Resolved(rule: rule, paths: paths, protected: protected, status: status))
            }
        }
        return out
    }

    /// Folders whose child names the owning app: `Caches/<id>`, `Application Support/<name>`,
    /// `Containers/<id>`.
    static let ownerAnchors = ["/Library/Caches/", "/Library/Application Support/", "/Library/Containers/"]

    /// Names or bundle ids the app a path belongs to may run under: the folder below an anchor, the one
    /// below that for vendor folders (`BraveSoftware/Brave-Browser-Beta`, also without dashes) and, for a
    /// container named by a UUID (iPhone/iPad apps), the bundle id from its metadata.
    static func owners(of path: String, home: String) -> [String] {
        for anchor in ownerAnchors {
            let prefix = home + anchor
            guard path.hasPrefix(prefix) else { continue }
            let parts = path.dropFirst(prefix.count).split(separator: "/").map(String.init)
            guard let first = parts.first else { return [] }
            var out = [first]
            if parts.count > 1 { out += [parts[1], parts[1].replacingOccurrences(of: "-", with: " ")] }
            if anchor == "/Library/Containers/", let id = LeftoverFinder.containerOwner(prefix + first) { out.append(id) }
            // A container nested in a container (Safari web apps) belongs to the inner bundle id.
            if anchor == "/Library/Containers/", parts.count > 4, parts[1...3] == ["Data", "Library", "Containers"] {
                out.append(parts[4])
            }
            return out
        }
        return []
    }

    /// True when Chromium's own cache folders sit next to the match (or up to two levels above it, for
    /// `Service Worker/CacheStorage`), i.e. it belongs to an Electron app or a Chromium browser profile
    /// and a folder named `Cache` holds web data.
    static func isChromiumAppFolder(of path: String, home: String) -> Bool {
        let root = home + "/Library/Application Support"
        var dir = (path as NSString).deletingLastPathComponent
        for _ in 0..<3 where dir.count > root.count {
            if ["Code Cache", "GPUCache"].contains(where: { FileManager.default.fileExists(atPath: dir + "/" + $0) }) { return true }
            dir = (dir as NSString).deletingLastPathComponent
        }
        return false
    }

    /// Merges rules with the same section, label and kind into one item and measures them in parallel.
    /// Different kinds stay apart, so a reviewed rule never inherits a safe rating.
    public func scan(progress: @escaping @Sendable (String) -> Void = { _ in }) async -> [CleanItem] {
        let resolved = resolve()
        var merged: [String: Resolved] = [:]
        var order: [String] = []
        for r in resolved {
            let key = r.rule.section + "|" + r.rule.label + "|" + r.rule.kind.rawValue
            if let prev = merged[key] {
                // The merged item keeps every running-app condition of its rules for the check before removal.
                var rule = prev.rule
                rule.skipIfRunning = rule.skipIfRunning ?? r.rule.skipIfRunning
                if r.rule.skipRunningOwner == true { rule.skipRunningOwner = true }
                rule.paths += r.rule.paths
                merged[key] = Resolved(
                    rule: rule, paths: prev.paths + r.paths, protected: prev.protected + r.protected,
                    status: prev.status == .ready ? r.status : prev.status)
            } else {
                merged[key] = r
                order.append(key)
            }
        }

        return await withTaskGroup(of: (Int, CleanItem).self) { group in
            for (index, key) in order.enumerated() {
                let r = merged[key]!
                group.addTask {
                    progress(r.rule.label)
                    let bytes = r.paths.reduce(Int64(0)) { $0 + DiskSize.allocatedSize(of: $1) }
                    return (index, CleanItem(
                        section: r.rule.section, label: r.rule.label, paths: r.paths,
                        bytes: bytes, status: r.status, kind: r.rule.kind, safety: r.rule.effectiveSafety,
                        protected: r.protected, skipIfRunning: r.rule.skipIfRunning,
                        skipRunningOwner: r.rule.skipRunningOwner == true, patterns: r.rule.paths))
                }
            }
            var items: [(Int, CleanItem)] = []
            for await item in group { items.append(item) }
            return items.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }
}
