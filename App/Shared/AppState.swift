import Foundation
import Observation
import SwabrCore

/// Which page is open. The overview, the sidebar and the menu bar all navigate through it.
@MainActor @Observable
final class Navigator {
    static let shared = Navigator()
    /// `-startModule clean` on the command line opens that page first (for screenshots and testing).
    var selection: Module? = Module(rawValue: UserDefaults.standard.string(forKey: "startModule") ?? "") ?? .initial

    func open(_ module: Module) { selection = module }
}

/// Pages whose results should survive switching pages: the overview scans them together, and coming
/// back to a page shows its last list instead of starting over.
@MainActor
final class AppModels {
    static let shared = AppModels()
    let clean = CleanModel()
    let projects = ProjectsModel()
    let installer = InstallerModel()
    let slim = SlimModel()
    let uninstall = UninstallModel()
}

/// What the last scan of each page found, kept across launches for the overview, the sidebar and the
/// menu bar. A value is a hint, not a promise: the page itself always scans again before removing.
@MainActor @Observable
final class ScanSummary {
    static let shared = ScanSummary()

    struct Entry: Codable, Equatable {
        /// What is ticked on the page (the sidebar shows this).
        var bytes: Int64
        var count: Int
        var date: Date
        /// Everything the scan found that could go, ticked or not (the overview and the menu bar show this).
        var found: Int64? = nil

        var foundBytes: Int64 { found ?? bytes }
    }

    private(set) var entries: [String: Entry] = [:]
    private let key = "scanSummary"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let stored = try? JSONDecoder().decode([String: Entry].self, from: data) {
            entries = stored
        }
    }

    func record(_ module: Module, bytes: Int64, count: Int, found: Int64? = nil) {
        entries[module.rawValue] = Entry(bytes: max(bytes, 0), count: count, date: Date(), found: found.map { max($0, 0) })
        if let data = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(data, forKey: key) }
    }

    func entry(_ module: Module) -> Entry? { entries[module.rawValue] }

    /// Areas whose finds can be removed, in the order the overview lists them.
    static let reclaimable: [Module] = [.clean, .purge, .installer, .slim]
    /// What "Prüfen & aufräumen" and the overview total are about: caches, build folders and installers.
    /// Slimming is a change to apps, not clean-up, so it has its own tile only.
    static let cleanup: [Module] = [.clean, .purge, .installer]

    /// Everything found in the clean-up areas, ticked or not.
    var reclaimableBytes: Int64 {
        Self.cleanup.filter(\.isAvailable).compactMap { entry($0)?.foundBytes }.reduce(0, +)
    }

    /// Time of the oldest of the reclaimable scans, nil while one of them never ran.
    var lastChecked: Date? {
        let dates = Self.reclaimable.filter(\.isAvailable).map { entry($0)?.date }
        guard !dates.contains(where: { $0 == nil }) else { return dates.compactMap { $0 }.min() }
        return dates.compactMap { $0 }.min()
    }

    var hasAny: Bool { Self.reclaimable.contains { entry($0) != nil } }

    /// Short text for the sidebar and the tiles.
    func badge(_ module: Module) -> String? {
        guard let e = entry(module) else { return nil }
        switch module {
        case .uninstall: return e.count > 0 ? "\(e.count)" : nil
        default: return e.bytes >= 1_000_000 ? DiskSize.format(e.bytes) : nil
        }
    }
}

extension Module {
    var isAvailable: Bool { Module.available.contains(self) }
}
