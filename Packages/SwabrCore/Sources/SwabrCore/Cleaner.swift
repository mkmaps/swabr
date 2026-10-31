import Darwin
import Foundation

public struct CleanReport: Sendable {
    public var removedBytes: Int64 = 0
    public var removedCount = 0
    public var failures: [ProtectedPath] = []
}

/// Removes scanned items. Every path is checked again right before removal,
/// because the disk may have changed since the scan.
public struct Cleaner: Sendable {
    public enum Mode: String, Sendable, CaseIterable {
        case permanent, trash
    }

    public let home: String
    public let whitelist: Whitelist
    public let mode: Mode
    public let log: OperationLog
    /// Asked again right before removal: an app started since the scan may have its cache open.
    public let isAppRunning: @Sendable (String) -> Bool
    /// Root step for items the user may not remove (they belong to root); nil in the App Store edition.
    public let runPrivileged: RootRunner?

    public init(home: String = UserHome.path, whitelist: Whitelist, mode: Mode, log: OperationLog,
                isAppRunning: @escaping @Sendable (String) -> Bool = { _ in false },
                runPrivileged: RootRunner? = nil) {
        self.home = home
        self.whitelist = whitelist
        self.mode = mode
        self.log = log
        self.isAppRunning = isAppRunning
        self.runPrivileged = runPrivileged
    }

    public func clean(_ items: [CleanItem], progress: @escaping @Sendable (String) -> Void = { _ in }) async -> CleanReport {
        var report = CleanReport()
        let fm = FileManager.default
        let trashRoot = home + "/.Trash/"
        var needRoot: [(path: String, bytes: Int64, label: String, error: ProtectedPath)] = []
        for item in items where item.isCleanable {
            progress(item.label)
            if let app = item.skipIfRunning, isAppRunning(app) {
                let why = String(localized: "\(app) wurde nach der Prüfung gestartet", bundle: .module)
                report.failures += item.paths.map { .init(path: $0, reason: why, kind: .running) }
                continue
            }
            for path in item.paths {
                var st = stat()
                guard lstat(path, &st) == 0 else { continue }
                if item.skipRunningOwner, let owner = CleanScanner.owners(of: path, home: home).first(where: isAppRunning) {
                    report.failures.append(.init(path: path, reason: String(localized: "\(owner) wurde nach der Prüfung gestartet", bundle: .module), kind: .running))
                    continue
                }
                // Measured first, so the checks below sit right before the change (A-03).
                let bytes = DiskSize.allocatedSize(of: path)
                if case .refused(let why) = PathSafety.check(path, home: home) {
                    report.failures.append(.init(path: path, reason: why, kind: .protectedPath))
                    continue
                }
                if let w = whitelist.protectingPattern(for: path) {
                    report.failures.append(.init(path: path, reason: "Whitelist: \(w)", kind: .whitelist))
                    continue
                }
                // Last look: the folder still resolves to itself, so no part of the way became a link meanwhile.
                let parent = (path as NSString).deletingLastPathComponent
                guard RootExecutor.realPath(parent) == parent else {
                    report.failures.append(.init(path: path, reason: String(localized: "Symlink im Pfad", bundle: .module), kind: .protectedPath))
                    continue
                }
                do {
                    // Items already in the Trash are always removed for good.
                    if mode == .trash && !path.hasPrefix(trashRoot) {
                        try fm.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
                    } else {
                        try fm.removeItem(atPath: path)
                    }
                    report.removedBytes += bytes
                    report.removedCount += 1
                    log.record(action: mode == .trash ? "TRASH" : "REMOVE", path: path, bytes: bytes, label: item.label)
                } catch {
                    let failure = ProtectedPath(path: path, error: error)
                    if failure.kind == .permission, runPrivileged != nil, !path.hasPrefix(trashRoot) {
                        needRoot.append((path, bytes, item.label, failure))
                    } else {
                        report.failures.append(failure)
                    }
                }
            }
        }
        guard let runPrivileged, !needRoot.isEmpty else { return report }

        // Root only moves them into the Trash and hands them back; deleting for good happens as the user.
        let moved = RootTrash.move(needRoot.map(\.path), home: home, allowedRoots: [home + "/"], runPrivileged: runPrivileged)
        for item in needRoot {
            guard let target = moved[item.path] else {
                report.failures.append(item.error)
                continue
            }
            if mode == .permanent { try? fm.removeItem(atPath: target) }
            report.removedBytes += item.bytes
            report.removedCount += 1
            log.record(action: mode == .trash ? "TRASH" : "REMOVE", path: item.path, bytes: item.bytes, label: item.label)
        }
        return report
    }
}

/// Append-only record of every removal (`operations.log`), the source of the history view.
public struct OperationLog: Sendable {
    public let url: URL

    /// Defaults to the app's own home, which is the sandbox container in the App Store edition (writable there).
    public init(home: String = NSHomeDirectory()) {
        url = URL(fileURLWithPath: home).appending(path: "Library/Application Support/Swabr/operations.log")
    }

    public func record(action: String, path: String, bytes: Int64, label: String) {
        let line = "\(Date().ISO8601Format())\t\(action)\t\(bytes)\t\(label)\t\(path)\n"
        let fm = FileManager.default
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let h = try? FileHandle(forWritingTo: url) {
            defer { try? h.close() }
            _ = try? h.seekToEnd()
            try? h.write(contentsOf: Data(line.utf8))
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }
}
