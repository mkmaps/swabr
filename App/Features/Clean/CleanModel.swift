import Foundation
import SwabrCore
import Observation

@MainActor @Observable
final class CleanModel {
    enum Phase {
        case idle
        case scanning
        case review
        case cleaning
        case done(CleanReport, freedOnDisk: Int64?)
    }

    var phase: Phase = .idle
    var currentStep = ""
    var items: [CleanItem] = []
    /// The sidebar, overview and menu bar show what is ticked, so they follow every change of the selection.
    var selected: Set<String> = [] { didSet { if !items.isEmpty { recordSummary() } } }
    var errorMessage: String?
    /// Big data sets listed for review only, never cleaned.
    var largeData: [DynamicRules.LargeData] = []
    var freeSpace = VolumeInfo.freeSpace()
    /// The last "never clean", so it can be undone right in the list.
    var lastProtection: ProtectionUndo?
    var mode: Cleaner.Mode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "cleanMode") }
    }

    init() {
        mode = Cleaner.Mode(rawValue: UserDefaults.standard.string(forKey: "cleanMode") ?? "") ?? .permanent
    }

    var sections: [(name: String, items: [CleanItem])] {
        RuleStore.sectionOrder.compactMap { name in
            let list = items.filter { $0.section == name }
            return list.isEmpty ? nil : (name, list)
        }
    }

    /// All figures of the page, the sidebar and the overview come from here (tested in SwabrCore).
    var selection: CleanSelection { CleanSelection(items: items, selected: selected) }
    var selectedItems: [CleanItem] { items.filter { selected.contains($0.id) && $0.isCleanable } }
    var selectedBytes: Int64 { selection.selectedBytes }
    var selectedCount: Int { selection.selectedPaths }

    struct ProtectionUndo {
        let title: String
        let patterns: [String]
        let items: [CleanItem]
        let selected: Set<String>
    }

    /// What a path-level "never clean" covers.
    enum ProtectionScope {
        case path, owner, name
    }

    /// Matches the whitelist now leaves alone, summed over all items.
    var protectedCount: Int { items.reduce(0) { $0 + $1.protected.count } }

    func scan() async {
        phase = .scanning
        errorMessage = nil
        lastProtection = nil
        do {
            let protection = try RuleStore.protection()
            currentStep = String(localized: "Installierte Apps")
            let installed = Set(await AppCatalog.installedApps(protection: protection).map(\.bundleID))
            let ageDays = Prefs.orphanAgeDays
            let dynamic = await Task.detached {
                DynamicRules.rules(installedBundleIDs: installed, protection: protection, orphanAgeDays: ageDays)
            }.value
            // The Trash is the only rule a setting switches off: some people empty it themselves.
            // Dynamic rules come first: they know where tools keep their caches and which apps are gone.
            let rules = try (dynamic + RuleStore.cleanRules()).filter { Prefs.cleanEmptyTrash || $0.kind != .trash }
            let whitelist = try Whitelist.load(home: UserHome.path, protection: protection)
            let scanner = CleanScanner(rules: rules, whitelist: whitelist, isAppRunning: RunningApps.snapshot())
            let found = await scanner.scan { [weak self] label in
                Task { @MainActor in self?.currentStep = label }
            }
            items = found.filter { $0.bytes > 0 || !$0.protected.isEmpty || $0.status != .ready }
            currentStep = String(localized: "Große Datenbestände")
            largeData = await DynamicRules.largeData(minimum: Int64(Prefs.largeDataMinMB) * 1_048_576)
            applyPreselection()
            freeSpace = VolumeInfo.freeSpace()
            recordSummary()
            phase = .review
            await loadDates()
        } catch {
            errorMessage = error.localizedDescription
            phase = .idle
        }
    }

    func clean() async {
        let before = VolumeInfo.freeSpace()
        let chosen = selectedItems
        phase = .cleaning
        do {
            let whitelist = try Whitelist.load(home: UserHome.path, protection: RuleStore.protection())
            let cleaner = Cleaner(whitelist: whitelist, mode: mode, log: OperationLog(), isAppRunning: RunningApps.snapshot(),
                                  runPrivileged: Edition.isStore ? nil : Privileged.run)
            let report = await cleaner.clean(chosen) { [weak self] label in
                Task { @MainActor in self?.currentStep = label }
            }
            freeSpace = VolumeInfo.freeSpace()
            let freed = (before != nil && freeSpace != nil) ? freeSpace! - before! : nil
            lastCleaned = chosen
            let removed = Set(chosen.map(\.id))
            items.removeAll { item in removed.contains(item.id) && !report.failures.contains { item.paths.contains($0.path) } }
            selected = []
            recordSummary()
            phase = .done(report, freedOnDisk: freed)
        } catch {
            errorMessage = error.localizedDescription
            phase = .review
        }
    }

    /// Leaves the done page: back to what is left of the list, or to the start.
    func finish() {
        phase = items.contains(where: \.isCleanable) || !largeData.isEmpty ? .review : .idle
    }

    /// Newest change among each item's paths, for sorting by date (filled after a scan).
    var itemDates: [String: Date] = [:]

    private func loadDates() async {
        let list = items.map { ($0.id, Array($0.paths.prefix(50))) }
        itemDates = await Task.detached {
            var out: [String: Date] = [:]
            for (id, paths) in list {
                out[id] = paths.compactMap {
                    (try? URL(fileURLWithPath: $0).resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                }.max()
            }
            return out
        }.value
    }

    /// What the last run removed, for the summary on the done page.
    var lastCleaned: [CleanItem] = []

    /// Everything the scan found that can be removed, for the overview.
    var cleanableBytes: Int64 { items.filter(\.isCleanable).reduce(0) { $0 + $1.bytes } }

    private func recordSummary() {
        let s = selection
        ScanSummary.shared.record(.clean, bytes: s.selectedBytes, count: s.selectedEntries,
                                  found: s.categories.filter { !$0.isInformational }.reduce(0) { $0 + $1.total })
    }

    /// After a scan: what the setting says, nothing by default.
    func applyPreselection() {
        switch Prefs.preselect {
        case .none: selected = []
        case .recommended: selectRecommended()
        case .all: selectAll()
        }
    }

    /// Only items rated safe: the "recommended" preset.
    func selectRecommended() {
        selected = Set(items.filter { $0.isCleanable && $0.safety == .safe }.map(\.id))
    }


    func selectAll() { selected = Set(items.filter(\.isCleanable).map(\.id)) }
    func selectNone() { selected = [] }

    var reviewLines: [ReviewLine] {
        selectedItems.map { item in
            ReviewLine(
                id: item.id, title: item.label, iconPath: nil, bytes: item.bytes,
                impact: String(localized: "\(item.paths.count) Elemente · ") + item.impact, warning: item.safety == .review)
        }
    }

    /// "Never clean" for a whole item: stores its rule patterns, so later matches stay protected too.
    func protect(_ item: CleanItem) {
        addProtection(ProtectionPattern.forItem(item), title: item.label)
    }

    /// "Never clean" for one match, the app it belongs to or every folder with its name.
    func protect(path: String, scope: ProtectionScope) {
        switch scope {
        case .path:
            addProtection([ProtectionPattern.forPath(path)], title: path.replacingOccurrences(of: UserHome.path, with: "~"))
        case .owner:
            guard let o = ProtectionPattern.forOwner(of: path) else { return }
            addProtection([o.pattern], title: o.owner)
        case .name:
            guard let n = ProtectionPattern.forName(of: path) else { return }
            addProtection([n.pattern], title: String(localized: "alle Ordner namens „\(n.name)“"))
        }
    }

    private func addProtection(_ patterns: [String], title: String) {
        do {
            var w = try Whitelist.load(home: UserHome.path, protection: RuleStore.protection())
            let added = patterns.filter { !w.isProtected(pattern: $0) }
            for p in added { w.setProtected(p, true) }
            try w.save()
            let before = (items, selected)
            items = items.map { $0.applying(w) }
            selected = selected.filter { id in items.contains { $0.id == id && $0.isCleanable } }
            lastProtection = ProtectionUndo(title: title, patterns: added, items: before.0, selected: before.1)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func undoProtection() {
        guard let undo = lastProtection else { return }
        do {
            var w = try Whitelist.load(home: UserHome.path, protection: RuleStore.protection())
            for p in undo.patterns { w.setProtected(p, false) }
            try w.save()
            items = undo.items
            selected = undo.selected
            lastProtection = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleSection(_ name: String, on: Bool) {
        for item in items where item.section == name && item.isCleanable {
            if on { selected.insert(item.id) } else { selected.remove(item.id) }
        }
    }
}

enum SectionNames {
    static func german(_ section: String) -> String {
        switch section {
        case "system": "macOS"
        case "browsers": String(localized: "Browser")
        case "apps": String(localized: "Apps")
        case "developer": String(localized: "Entwicklerwerkzeuge")
        case "app_caches": String(localized: "App-Caches")
        case "leftovers": String(localized: "Reste entfernter Apps")
        default: section
        }
    }

    /// Tile colors of a category.
    static func colors(_ section: String) -> (UInt32, UInt32) {
        switch section {
        case "system": (0x8D93A8, 0x5D6377)
        case "browsers": (0xB07CFF, 0x8E44EC)
        case "apps": (0x2ED3CC, 0x12B5B0)
        case "developer": (0x3D8BFF, 0x0A6CFF)
        case "app_caches": (0x5EE07C, 0x2FB350)
        case "leftovers": (0xFF7AA5, 0xE8457A)
        default: (0xFFB347, 0xF08A00)
        }
    }

    static func symbol(_ section: String) -> String {
        switch section {
        case "system": "apple.logo"
        case "browsers": "globe"
        case "apps": "app.badge"
        case "developer": "chevron.left.forwardslash.chevron.right"
        case "app_caches": "square.stack.3d.up"
        case "leftovers": "shippingbox.and.arrow.backward"
        default: "externaldrive"
        }
    }
}
