import Foundation

/// The figures the Clean Up page, the sidebar, the overview and the menu bar show for a scan result and a
/// selection. Kept in one place (and tested) so they cannot contradict each other (A-04):
/// - the categories' selected sizes add up to `selectedBytes`, which is exactly what "Clean" removes;
/// - a category's `total` counts all of its cleanable entries, ticked or not;
/// - entries that cannot be cleaned (skipped, protected, informational) count nowhere but in an
///   informational category's own total.
public struct CleanSelection: Sendable, Equatable {
    public struct Category: Sendable, Equatable, Identifiable {
        public var id: String { name }
        public let name: String
        /// All cleanable entries of the category, ticked or not; for a category without any, all its entries.
        public let total: Int64
        public let selectedBytes: Int64
        public let selectedEntries: Int
        public let cleanableEntries: Int
        public let entries: Int

        /// Only listed, nothing in it can be cleaned.
        public var isInformational: Bool { cleanableEntries == 0 }
        public var isFullySelected: Bool { cleanableEntries > 0 && selectedEntries == cleanableEntries }
    }

    public let categories: [Category]
    /// What "Clean" removes: the ticked, cleanable entries of all categories.
    public let selectedBytes: Int64
    public let selectedEntries: Int
    /// Paths behind the ticked entries.
    public let selectedPaths: Int

    public init(items: [CleanItem], selected: Set<String>, order: [String] = RuleStore.sectionOrder) {
        let known = Set(order)
        let names = order + Array(Set(items.map(\.section)).subtracting(known)).sorted()
        var categories: [Category] = []
        for name in names {
            let all = items.filter { $0.section == name }
            guard !all.isEmpty else { continue }
            let cleanable = all.filter(\.isCleanable)
            let chosen = cleanable.filter { selected.contains($0.id) }
            categories.append(Category(
                name: name,
                total: (cleanable.isEmpty ? all : cleanable).reduce(0) { $0 + $1.bytes },
                selectedBytes: chosen.reduce(0) { $0 + $1.bytes },
                selectedEntries: chosen.count,
                cleanableEntries: cleanable.count,
                entries: all.count))
        }
        self.categories = categories
        let chosen = items.filter { $0.isCleanable && selected.contains($0.id) }
        selectedBytes = chosen.reduce(0) { $0 + $1.bytes }
        selectedEntries = chosen.count
        selectedPaths = chosen.reduce(0) { $0 + $1.paths.count }
    }

    public func category(_ name: String) -> Category? { categories.first { $0.name == name } }

    /// Categories something is ticked in, in display order.
    public var selectedCategoryNames: [String] { categories.filter { $0.selectedEntries > 0 }.map(\.name) }
}
