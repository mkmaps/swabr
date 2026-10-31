import CoreGraphics
import Foundation
import Testing
@testable import SwabrCore

@Test func walkerCountsHardLinksOnceAndSkipsVMDirs() throws {
    let h = try FakeHome()
    try h.file("data/a", bytes: 100_000)
    try FileManager.default.linkItem(atPath: h.path + "/data/a", toPath: h.path + "/data/b")
    try h.file("data/OrbStack/huge", bytes: 500_000)
    let r = DiskWalker.walk(h.path + "/data")
    #expect(r.bytes >= 100_000 && r.bytes < 200_000)
    #expect(r.files == 1)
}

@Test func walkerTracksLargestFilesOutsideFoldDirs() throws {
    let h = try FakeHome()
    try h.file("p/big.bin", bytes: 3 << 20)
    try h.file("p/small.bin", bytes: 10_000)
    try h.file("p/node_modules/dep.bin", bytes: 4 << 20)
    let r = DiskWalker.walk(h.path + "/p")
    #expect(r.largeFiles.files.map(\.path) == [h.path + "/p/big.bin"])
}

@Test func listSortsChildrenAndFlagsCleanable() async throws {
    let h = try FakeHome()
    try h.file("proj/node_modules/x", bytes: 200_000)
    try h.file("proj/src/main.swift", bytes: 8_000)
    try h.file("proj/cache/CACHEDIR.TAG", bytes: 0)
    try Data("Signature: 8a477f597d28d172789f06886806bc55\n".utf8).write(to: URL(fileURLWithPath: h.path + "/proj/cache/CACHEDIR.TAG"))
    let listing = await DirectoryScanner.list(h.path + "/proj", home: h.path)
    #expect(listing.entries.first?.name == "node_modules")
    #expect(listing.entries.first?.isCleanable == true)
    #expect(listing.entries.first { $0.name == "cache" }?.isCleanable == true)
    #expect(listing.entries.first { $0.name == "src" }?.isCleanable == false)
}

@Test func overviewSeparatesLibraryFromHome() async throws {
    let h = try FakeHome()
    try h.file("Documents/doc", bytes: 50_000)
    try h.file("Library/stuff", bytes: 400_000)
    let o = await DirectoryScanner.overview(home: h.path)
    let home = try #require(o.entries.first { $0.name == L("Benutzerordner") })
    let lib = try #require(o.entries.first { $0.name == L("Benutzer-Library") })
    #expect(home.bytes < 200_000)
    #expect(lib.bytes >= 400_000)
}

@Test func analyzeTrashRefusesCriticalPaths() throws {
    let h = try FakeHome()
    #expect(AnalyzeTrash.refusal(for: "/Applications", home: h.path) != nil)
    #expect(AnalyzeTrash.refusal(for: "/System/Library", home: h.path) != nil)
    #expect(AnalyzeTrash.refusal(for: h.path, home: h.path) != nil)
    #expect(AnalyzeTrash.refusal(for: h.path + "/Library", home: h.path) != nil)
    #expect(AnalyzeTrash.refusal(for: h.path + "/Library/Mobile Documents/x", home: h.path) != nil)
    #expect(AnalyzeTrash.refusal(for: h.path + "/Downloads/big.dmg", home: h.path) == nil)
}

@Test func treemapFillsRectProportionally() {
    let rect = CGRect(x: 0, y: 0, width: 400, height: 300)
    let tiles = Treemap.layout([60, 0, 30, 10], in: rect)
    #expect(tiles.count == 3)
    let area = tiles.reduce(0) { $0 + $1.rect.width * $1.rect.height }
    #expect(abs(area - 120_000) < 1)
    let biggest = tiles.first { $0.index == 0 }!.rect
    #expect(abs(biggest.width * biggest.height - 72_000) < 1)
    for t in tiles { #expect(rect.insetBy(dx: -0.5, dy: -0.5).contains(t.rect)) }
}

@Test func stuckWalkIsAbandonedAfterTimeoutWithPartialTotals() async {
    let start = Date()
    let r = await DiskWalker.withTimeout(0.5) { counter in
        counter.add(bytes: 4096, files: 1)
        Thread.sleep(forTimeInterval: 5)   // stands in for a read blocked in the kernel
        return WalkResult(bytes: 1, files: 1)
    }
    #expect(Date().timeIntervalSince(start) < 2)
    #expect(r.partial)
    #expect(r.bytes == 4096)
}

@Test func finishedWalkBeatsTimeout() async throws {
    let h = try FakeHome()
    try h.file("d/a", bytes: 10_000)
    let r = await DiskWalker.withTimeout(5) { DiskWalker.walk(h.path + "/d", counter: $0) }
    #expect(!r.partial)
    #expect(r.bytes >= 10_000)
}

@Test func walkerRecordsFolderSizesToTheGivenDepth() throws {
    let h = try FakeHome()
    try h.file("a/b/c/big", bytes: 1_000_000)
    try h.file("a/x", bytes: 100_000)
    let r = DiskWalker.walk(h.path + "/a", folderDepth: 2)
    let b = try #require(r.folders[h.path + "/a/b"])
    let c = try #require(r.folders[h.path + "/a/b/c"])
    #expect(b >= c && c >= 1_000_000)
    #expect(r.folders[h.path + "/a/b/c/big"] == nil)   // files are not folders, depth 3 not recorded
}

@Test func growthNamesTheDeepestFolderThatGrew() {
    let gb: Int64 = 1 << 30
    let before = GrowthSnapshot(date: Date().addingTimeInterval(-86_400), used: 100 * gb,
                                folders: ["/h/Library": 10 * gb, "/h/Library/Caches": 2 * gb, "/h/Library/Caches/App": gb, "/h/Movies": gb],
                                files: [:])
    let now = GrowthSnapshot(used: 104 * gb,
                             folders: ["/h/Library": 13 * gb, "/h/Library/Caches": 5 * gb, "/h/Library/Caches/App": 4 * gb, "/h/Movies": gb],
                             files: ["/h/Downloads/big.dmg": 2 * gb])
    let report = try! #require(Growth.compare(before, now))
    #expect(report.volumeGrowth == 4 * gb)
    // Caches/App explains the growth of Caches and Library, so only it is named; the new file too.
    #expect(Set(report.items.map(\.path)) == ["/h/Library/Caches/App", "/h/Downloads/big.dmg"])
    // Below the 1 GB trigger nothing is reported.
    #expect(Growth.compare(before, GrowthSnapshot(used: 100 * gb + 1, folders: now.folders, files: [:])) == nil)
}
