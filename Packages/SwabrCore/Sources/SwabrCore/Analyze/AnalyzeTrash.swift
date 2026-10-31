import Darwin
import Foundation

/// Moving items chosen in the storage view to the Trash, with the places that are never moved.
public enum AnalyzeTrash {
    /// Label of the log entries (German, as `History` expects).
    static let logLabel = "Speicheranalyse"

    /// Exactly these folders are refused; what lies inside them is not (unless listed below).
    static let systemFolders: Set<String> = [
        "/", "/System", "/Library", "/Applications", "/Applications/Utilities", "/Users", "/Volumes", "/Network",
        "/private", "/private/etc", "/private/var", "/private/tmp", "/etc", "/var", "/tmp",
        "/usr", "/usr/local", "/bin", "/sbin", "/opt", "/opt/homebrew", "/dev", "/cores",
    ]
    /// Everything below these is refused: the sealed system volume and device files (`/usr/local` excepted).
    static let systemTrees = ["/System", "/usr", "/bin", "/sbin", "/dev", "/Library/Keychains"]
    /// Apps that are part of macOS and must stay where they are.
    static let systemApps: Set<String> = ["Finder.app", "Safari.app"]
    /// Below the home folder: keychains, iCloud Drive, and the disks of virtual machines
    /// (Docker Desktop docs, "Disk image location"; OrbStack docs, data location and ~/OrbStack).
    static let homeTrees = [
        "Library/Keychains",
        "Library/Mobile Documents",
        "Library/Containers/com.docker.docker",
        "Library/Group Containers/group.com.docker",
        "Library/Group Containers/HUAQ24HBR6.dev.orbstack",
        ".orbstack",
        "OrbStack",
    ]

    /// Why `path` must not be moved to the Trash, or nil. Checks the path as given and with links resolved.
    public static func refusal(for path: String, home: String = UserHome.path) -> String? {
        guard !path.isEmpty else { return String(localized: "ungültiger Pfad", bundle: .module) }
        guard path.hasPrefix("/") else { return String(localized: "kein absoluter Pfad", bundle: .module) }
        if PathSafety.hasControlCharacters(path) { return String(localized: "Pfad enthält Steuerzeichen", bundle: .module) }
        let parts = path.split(separator: "/")
        if parts.contains("..") || parts.contains(".") { return String(localized: "relativer Pfadbestandteil", bundle: .module) }

        let cleaned = "/" + parts.joined(separator: "/")
        let homeCleaned = "/" + home.split(separator: "/").joined(separator: "/")
        var paths = [cleaned]
        if let real = resolved(cleaned), real != cleaned { paths.append(real) }
        var homes = [homeCleaned]
        if let real = resolved(homeCleaned), real != homeCleaned { homes.append(real) }
        for p in paths {
            if let why = systemRefusal(p) { return why }
            for h in homes { if let why = homeRefusal(p, home: h) { return why } }
        }
        return nil
    }

    /// Moves each path to the Trash after `refusal` and logs it. Items the user may not move (their folder
    /// belongs to root, like `/Applications/Utilities`) go through `runPrivileged` in one step, if given.
    /// Returns what was not moved.
    public static func moveToTrash(_ paths: [String], home: String = UserHome.path, log: OperationLog = OperationLog(),
                                   runPrivileged: (@Sendable (String) -> String?)? = nil) -> [ProtectedPath] {
        moveToTrash(paths, home: home, log: log, runPrivileged: runPrivileged) {
            try FileManager.default.trashItem(at: $0, resultingItemURL: nil)
        }
    }

    static func moveToTrash(_ paths: [String], home: String, log: OperationLog,
                            runPrivileged: (@Sendable (String) -> String?)? = nil, trash: (URL) throws -> Void) -> [ProtectedPath] {
        var failed: [ProtectedPath] = []
        var needRoot: [(path: String, bytes: Int64, error: ProtectedPath)] = []
        for path in paths {
            if let why = refusal(for: path, home: home) {
                failed.append(ProtectedPath(path: path, reason: why, kind: .protectedPath))
                continue
            }
            let bytes = DiskWalker.walk(path, trackLargeFiles: false).bytes
            do {
                try trash(URL(fileURLWithPath: path))
                log.record(action: "TRASH", path: path, bytes: bytes, label: logLabel)
            } catch {
                let reason = ProtectedPath(path: path, error: error)
                guard reason.kind == .permission, runPrivileged != nil else {
                    failed.append(reason)
                    continue
                }
                // Root moves only where RootScript allows them (app folders and the app folders of /Library).
                if RootScript.roots(home: home).contains(where: { path.hasPrefix($0) }) {
                    needRoot.append((path, bytes, reason))
                } else {
                    failed.append(ProtectedPath(path: path, reason: String(localized: "Systembereich: Swabr entfernt hier nichts mit Administratorrechten", bundle: .module),
                                                kind: .protectedPath))
                }
            }
        }
        guard let runPrivileged, !needRoot.isEmpty else { return failed + needRoot.map(\.error) }
        let moved = RootTrash.move(needRoot.map(\.path), home: home, runPrivileged: runPrivileged)
        for item in needRoot {
            if moved[item.path] != nil {
                log.record(action: "TRASH", path: item.path, bytes: item.bytes, label: logLabel)
            } else {
                failed.append(ProtectedPath(path: item.path, reason: String(localized: "nicht entfernt (Passwort abgelehnt?)", bundle: .module),
                                            kind: .permission))
            }
        }
        return failed
    }

    static func systemRefusal(_ path: String) -> String? {
        let protectedFolder = String(localized: "geschützter Systemordner", bundle: .module)
        if systemFolders.contains(path) { return protectedFolder }
        if path.hasPrefix("/usr/local/") { return nil }
        if systemTrees.contains(where: { path.hasPrefix($0 + "/") }) { return protectedFolder }
        if path.split(separator: "/").contains(where: { systemApps.contains(String($0)) }) {
            return String(localized: "geschützte App", bundle: .module)
        }
        return nil
    }

    static func homeRefusal(_ path: String, home: String) -> String? {
        guard path == home || path.hasPrefix(home + "/") else { return nil }
        let rel = path == home ? "" : String(path.dropFirst(home.count + 1))
        if PathSafety.neverRemove.contains(rel) { return String(localized: "geschützter Ordner", bundle: .module) }
        if homeTrees.contains(where: { rel == $0 || rel.hasPrefix($0 + "/") }) {
            return String(localized: "Daten einer laufenden VM oder von iCloud/Schlüsselbund", bundle: .module)
        }
        return nil
    }

    /// `path` with every link resolved; for a missing item its folder is resolved instead.
    static func resolved(_ path: String) -> String? {
        if let real = realpath(path, nil) {
            defer { free(real) }
            return String(cString: real)
        }
        let parent = (path as NSString).deletingLastPathComponent
        guard parent != path, let real = realpath(parent, nil) else { return nil }
        defer { free(real) }
        let base = String(cString: real)
        return (base == "/" ? "" : base) + "/" + (path as NSString).lastPathComponent
    }
}
