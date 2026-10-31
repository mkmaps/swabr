import Foundation
import Testing
@testable import SwabrCore

// The figures of the Clean Up page (A-04): categories, action bar, sidebar and overview must agree.

private func item(_ section: String, _ label: String, _ bytes: Int64, skipped: Bool = false, paths: Int = 1) -> CleanItem {
    CleanItem(section: section, label: label, paths: (0..<paths).map { "/x/\(label)/\($0)" }, bytes: bytes,
              status: skipped ? .skipped("läuft") : .ready, kind: .cache, safety: .safe, protected: [])
}

@Test func categoriesAddUpToWhatCleanRemoves() {
    let items = [
        item("app_caches", "a", 2_000), item("app_caches", "b", 1_000), item("app_caches", "c", 500, skipped: true),
        item("browsers", "d", 4_000, paths: 3), item("system", "e", 300),
    ]
    let ids = Dictionary(uniqueKeysWithValues: items.map { ($0.label, $0.id) })
    // "c" is ticked but skipped: it must not count anywhere.
    let s = CleanSelection(items: items, selected: [ids["a"]!, ids["c"]!, ids["d"]!])
    #expect(s.selectedBytes == 6_000)
    #expect(s.categories.reduce(0) { $0 + $1.selectedBytes } == s.selectedBytes)
    #expect(s.selectedEntries == 2 && s.selectedPaths == 4)

    let caches = s.category("app_caches")!
    #expect(caches.total == 3_000)                 // all cleanable entries, ticked or not
    #expect(caches.selectedBytes == 2_000 && caches.selectedEntries == 1 && caches.cleanableEntries == 2 && caches.entries == 3)
    #expect(!caches.isFullySelected)
    #expect(s.category("browsers")!.isFullySelected)
    #expect(s.selectedCategoryNames == ["browsers", "app_caches"])   // display order
}

@Test func nothingTickedMeansNothingAnywhere() {
    let items = [item("app_caches", "a", 2_000), item("browsers", "d", 4_000)]
    let s = CleanSelection(items: items, selected: [])
    #expect(s.selectedBytes == 0 && s.selectedEntries == 0 && s.selectedCategoryNames.isEmpty)
    #expect(s.category("app_caches")!.total == 2_000)
    // Unknown ids in the selection (from an older scan) change nothing.
    #expect(CleanSelection(items: items, selected: ["gone|x|cache"]).selectedBytes == 0)
}

@Test func informationalCategoriesShowTheirSizeButAreNeverSelected() {
    let items = [item("leftovers", "big", 9_000, skipped: true), item("app_caches", "a", 1_000)]
    let s = CleanSelection(items: items, selected: Set(items.map(\.id)))
    let info = s.category("leftovers")!
    #expect(info.isInformational && info.total == 9_000 && info.selectedBytes == 0)
    #expect(s.selectedBytes == 1_000)
}

@Test func unknownSectionsAreListedAfterTheKnownOnes() {
    let items = [item("zzz", "a", 1), item("system", "b", 1), item("aaa", "c", 1)]
    #expect(CleanSelection(items: items, selected: []).categories.map(\.name) == ["system", "aaa", "zzz"])
}
