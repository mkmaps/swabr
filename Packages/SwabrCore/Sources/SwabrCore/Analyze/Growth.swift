import Foundation

/// Folder and file sizes from one complete overview measurement, kept for a few days.
public struct GrowthSnapshot: Codable, Sendable {
    public var date: Date
    /// Bytes in use on the home volume.
    public var used: Int64
    public var folders: [String: Int64]
    public var files: [String: Int64]

    public init(date: Date = Date(), used: Int64, folders: [String: Int64], files: [String: Int64]) {
        self.date = date
        self.used = used
        self.folders = folders
        self.files = files
    }
}

public struct GrowthItem: Identifiable, Sendable, Hashable {
    public var id: String { path }
    public let path: String
    public let isDirectory: Bool
    public let grown: Int64
    public let now: Int64
}

public struct GrowthReport: Sendable {
    public let since: Date
    /// Growth of the whole volume; may be larger than the items when the system itself grew.
    public let volumeGrowth: Int64
    public let items: [GrowthItem]
}

/// "What has grown since yesterday?": compares today's overview with an earlier one and names the
/// folders and files that account for the growth.
public enum Growth {
    /// The volume must have grown at least this much before anything is shown.
    public static let trigger: Int64 = 1 << 30
    /// Folders and files below this growth are not listed.
    static let itemMinimum: Int64 = 200 << 20
    /// Snapshots older than this are deleted.
    static let keepDays = 8

    static func directory(home: String) -> URL {
        URL(fileURLWithPath: home).appending(path: "Library/Application Support/Swabr/growth")
    }

    static let dayFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Stores today's snapshot (one per day, the latest wins) and removes old ones.
    public static func record(_ snapshot: GrowthSnapshot, home: String = UserHome.path) {
        let dir = directory(home: home)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: dayFormat.string(from: snapshot.date) + ".json")
        if let data = try? JSONEncoder().encode(snapshot) { try? data.write(to: url, options: .atomic) }
        let cutoff = snapshot.date.addingTimeInterval(-Double(keepDays) * 86_400)
        for file in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] {
            if let day = dayFormat.date(from: file.deletingPathExtension().lastPathComponent), day < cutoff {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    /// The newest snapshot taken at least 20 hours before `now`.
    public static func baseline(home: String = UserHome.path, now: Date = Date()) -> GrowthSnapshot? {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory(home: home), includingPropertiesForKeys: nil)) ?? []
        return files.compactMap { url -> GrowthSnapshot? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(GrowthSnapshot.self, from: data)
        }
        .filter { now.timeIntervalSince($0.date) >= 20 * 3600 }
        .max { $0.date < $1.date }
    }

    /// The growth report, or nil when the volume grew less than `trigger`.
    public static func compare(_ before: GrowthSnapshot, _ now: GrowthSnapshot) -> GrowthReport? {
        let volume = now.used - before.used
        guard volume >= trigger else { return nil }
        var grown: [String: (Int64, Int64)] = [:]
        for (path, size) in now.folders {
            let delta = size - (before.folders[path] ?? 0)
            if delta >= itemMinimum { grown[path] = (delta, size) }
        }
        // Name the deepest folder that explains the growth, not every parent above it.
        let folders = grown.filter { path, value in
            !grown.contains { other, o in other.hasPrefix(path + "/") && o.0 * 4 >= value.0 * 3 }
        }
        var items = folders.map { GrowthItem(path: $0.key, isDirectory: true, grown: $0.value.0, now: $0.value.1) }
        for (path, size) in now.files {
            let delta = size - (before.files[path] ?? 0)
            guard delta >= itemMinimum else { continue }
            // A file already explained by a listed folder adds nothing.
            if folders.keys.contains(where: { path.hasPrefix($0 + "/") }) { continue }
            items.append(GrowthItem(path: path, isDirectory: false, grown: delta, now: size))
        }
        items.sort { $0.grown > $1.grown }
        return GrowthReport(since: before.date, volumeGrowth: volume, items: Array(items.prefix(15)))
    }
}
