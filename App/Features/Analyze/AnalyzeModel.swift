import Foundation
import SwabrCore
import Observation

@MainActor @Observable
final class AnalyzeModel {
    struct Location: Hashable {
        let name: String
        /// Empty for the overview.
        let path: String
    }

    enum ViewMode: String, CaseIterable {
        case list, treemap
    }

    var stack: [Location] = [Location(name: String(localized: "Übersicht"), path: "")]
    var listings: [String: DirectoryListing] = [:]
    var loading = false
    var progress = (done: 0, total: 0)
    /// Row highlight (keyboard, Quick Look); actions use `checked`.
    var selection: Set<String> = []
    /// Ticked check boxes: the items an action applies to.
    var checked: Set<String> = []
    var filter = ""
    var viewMode = ViewMode.list
    var showLargeFiles = false
    var failures: [ProtectedPath] = []
    var freeSpace = VolumeInfo.freeSpace()
    private var loadTask: Task<Void, Never>?

    var current: Location { stack.last! }
    var listing: DirectoryListing? { listings[current.path] }

    var order = ListOrder(rawValue: UserDefaults.standard.string(forKey: "analyzeOrder") ?? "") ?? .size {
        didSet { UserDefaults.standard.set(order.rawValue, forKey: "analyzeOrder") }
    }

    var visibleEntries: [DiskEntry] {
        let all = listing?.entries ?? []
        let hits = filter.isEmpty ? all : all.filter { $0.name.localizedCaseInsensitiveContains(filter) }
        switch order {
        case .size, .natural: return hits
        case .name: return hits.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .newest, .oldest: return order.byDate(hits, \.modified)
        }
    }

    func start() {
        if listing == nil { load(force: false) }
    }

    func open(_ entry: DiskEntry) {
        guard entry.isDirectory else { return }
        stack.append(Location(name: entry.name, path: entry.path))
        selection = []
        checked = []
        filter = ""
        load(force: false)
    }

    /// Opens any folder (e.g. from the growth list) on top of the current location.
    func open(path: String) {
        stack.append(Location(name: (path as NSString).lastPathComponent, path: path))
        selection = []
        checked = []
        filter = ""
        load(force: false)
    }

    func go(to index: Int) {
        guard index < stack.count - 1 else { return }
        stack.removeSubrange((index + 1)...)
        selection = []
        checked = []
        load(force: false)
    }

    func back() { go(to: stack.count - 2) }

    func load(force: Bool) {
        let location = current
        if !force, listings[location.path] != nil { return }
        loadTask?.cancel()
        loading = true
        progress = (0, 0)
        let report: @Sendable (Int, Int) -> Void = { [weak self] done, total in
            Task { @MainActor in self?.progress = (done, total) }
        }
        loadTask = Task {
            let result = !location.path.isEmpty
                ? await DirectoryScanner.list(location.path, progress: report)
                : Edition.isStore
                    ? await DirectoryScanner.locations(FolderAccess.paths, progress: report)
                    : await DirectoryScanner.overview(progress: report)
            guard !Task.isCancelled else { return }
            listings[location.path] = result
            freeSpace = VolumeInfo.freeSpace()
            if current == location { loading = false }
        }
    }

    func moveToTrash(_ paths: [String]) async {
        let privileged: RootRunner? = Edition.isStore ? nil : Privileged.run
        let failed = await Task.detached { AnalyzeTrash.moveToTrash(paths, runPrivileged: privileged) }.value
        failures = failed
        selection = []
        checked = []
        // Sizes of this folder and every parent changed; drop them so they are measured again.
        for location in stack { listings[location.path] = nil }
        load(force: true)
    }

    /// The overview lists locations, not deletable items.
    var canTrash: Bool { !current.path.isEmpty }

    func toggleChecked(_ path: String) {
        if checked.contains(path) { checked.remove(path) } else { checked.insert(path) }
    }

    func checkAllVisible() { checked.formUnion(visibleEntries.map(\.path)) }

    func reviewLines(for items: [DiskEntry]) -> [ReviewLine] {
        items.sorted { $0.bytes > $1.bytes }.map { e in
            let impact = Impact.analyze(path: e.path, isDirectory: e.isDirectory, isCleanable: e.isCleanable)
            let refusal = AnalyzeTrash.refusal(for: e.path)
            return ReviewLine(
                id: e.path, title: e.name, iconPath: e.path, bytes: e.bytes,
                impact: refusal.map { String(localized: "Wird nicht verschoben: \($0)") } ?? impact.text,
                warning: impact.warning || refusal != nil)
        }
    }

    /// App Store edition: add folders to the start screen.
    func addFolders() {
        guard !FolderAccess.choose(prompt: String(localized: "Analysieren")).isEmpty else { return }
        go(to: 0)
        load(force: true)
    }

    func entries(for paths: Set<String>) -> [DiskEntry] {
        let all = (listing?.entries ?? []) + (listing?.largeFiles ?? [])
        return paths.compactMap { p in all.first { $0.path == p } }
    }
}
