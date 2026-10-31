import Foundation
import Testing
@testable import SwabrCore

// MARK: Measuring

@Test func walkCountsHardLinkedFileOnce() throws {
    let h = try FakeHome()
    try h.file("d/one", bytes: 2_000_000)
    try FileManager.default.linkItem(atPath: h.path + "/d/one", toPath: h.path + "/d/two")
    try FileManager.default.createDirectory(atPath: h.path + "/d/sub", withIntermediateDirectories: true)
    try FileManager.default.linkItem(atPath: h.path + "/d/one", toPath: h.path + "/d/sub/three")
    let r = DiskWalker.walk(h.path + "/d")
    #expect(r.files == 1)
    #expect(r.bytes >= 2_000_000 && r.bytes < 4_000_000)
    #expect(r.largeFiles.files.count == 1)
    #expect(!r.partial)
}

@Test func walkDoesNotFollowSymlinks() throws {
    let h = try FakeHome()
    try h.file("big/blob", bytes: 3_000_000)
    try h.file("d/small", bytes: 4096)
    try FileManager.default.createSymbolicLink(atPath: h.path + "/d/link", withDestinationPath: h.path + "/big")
    let r = DiskWalker.walk(h.path + "/d")
    #expect(r.bytes < 1_000_000)
    #expect(r.files == 2)   // the file and the link itself
    #expect(r.largeFiles.files.isEmpty)
    // A link as the starting point is measured as itself, too.
    #expect(DiskWalker.walk(h.path + "/d/link").bytes < 1_000_000)
}

@Test func walkSkipsVolumeBookkeepingFolders() throws {
    let h = try FakeHome()
    try h.file("v/.Spotlight-V100/index", bytes: 500_000)
    try h.file("v/.fseventsd/log", bytes: 500_000)
    try h.file("v/data", bytes: 10_000)
    let r = DiskWalker.walk(h.path + "/v")
    #expect(r.files == 1)
    #expect(r.bytes < 500_000)
    // With an empty skip list everything is counted.
    #expect(DiskWalker.walk(h.path + "/v", skipNames: []).files == 3)
}

@Test func walkDoesNotEnterOtherVolumes() throws {
    let h = try FakeHome()
    try h.file("d/local", bytes: 10_000)
    let image = h.path + "/t.dmg", mount = h.path + "/d/mnt"
    try FileManager.default.createDirectory(atPath: mount, withIntermediateDirectories: true)
    guard run("/usr/bin/hdiutil", ["create", "-size", "8m", "-fs", "HFS+", "-volname", "SwabrTest", image]),
          run("/usr/bin/hdiutil", ["attach", image, "-nobrowse", "-noverify", "-mountpoint", mount]) else {
        Issue.record("hdiutil could not create or attach a test volume")
        return
    }
    defer { _ = run("/usr/bin/hdiutil", ["detach", mount, "-force"]) }
    try Data(repeating: 7, count: 3_000_000).write(to: URL(fileURLWithPath: mount + "/onvolume"))
    let r = DiskWalker.walk(h.path + "/d")
    #expect(r.bytes < 1_000_000)
    #expect(r.files == 1)
    // Measured on its own, the volume is counted.
    #expect(DiskWalker.walk(mount).bytes >= 3_000_000)
}

@Test func unreadableFolderMakesResultPartial() throws {
    let h = try FakeHome()
    try h.file("d/ok", bytes: 10_000)
    try h.file("d/locked/secret", bytes: 10_000)
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: h.path + "/d/locked")
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: h.path + "/d/locked") }
    let r = DiskWalker.walk(h.path + "/d")
    #expect(r.partial)
    #expect(r.files == 1)
    #expect(r.bytes >= 10_000)
}

@Test func largeFilesKeepsTheTwentyBiggestFromOneMegabyte() {
    var large = LargeFiles()
    #expect(large.threshold == LargeFiles.minimum)
    large.offer("/tiny", LargeFiles.minimum - 1)
    #expect(large.files.isEmpty)
    for i in 1...25 { large.offer("/f\(i)", Int64(i) * 1_000_000) }
    #expect(large.files.count == LargeFiles.limit)
    #expect(large.files.first?.path == "/f25")
    #expect(large.files.last?.path == "/f6")
    #expect(large.threshold == 6_000_000)
    large.offer("/same", 6_000_000)       // not bigger than the smallest kept one
    #expect(!large.files.contains { $0.path == "/same" })
    var other = LargeFiles()
    other.offer("/huge", 99_000_000)
    large.merge(other)
    #expect(large.files.first?.path == "/huge")
    #expect(large.threshold == 7_000_000)
}

@Test func stoppedCounterEndsWalkAsPartial() throws {
    let h = try FakeHome()
    try h.file("d/a/x", bytes: 10_000)
    let counter = WalkCounter()
    counter.stop()
    let r = DiskWalker.walk(h.path + "/d", counter: counter)
    #expect(r.partial)
    #expect(r.files == 0)
    #expect(DiskWalker.walk(h.path + "/d", counter: WalkCounter()).files == 1)
}

@Test func walkFeedsTheSharedCounter() throws {
    let h = try FakeHome()
    try h.file("d/a", bytes: 10_000)
    try h.file("d/s/b", bytes: 10_000)
    let counter = WalkCounter()
    let r = DiskWalker.walk(h.path + "/d", counter: counter)
    #expect(counter.files == 2)
    #expect(counter.bytes == r.bytes)
}

@Test func timeoutStopsWalkThatHonoursTheCounter() async {
    let start = Date()
    let r = await DiskWalker.withTimeout(0.3) { counter in
        counter.add(bytes: 8192, files: 2)
        while !counter.isStopped { Thread.sleep(forTimeInterval: 0.01) }
        var partial = WalkResult(bytes: 8192, files: 2)
        partial.largeFiles.offer("/seen", 5_000_000)
        return partial
    }
    #expect(Date().timeIntervalSince(start) < 2)
    #expect(r.partial)
    // The walk handed in its own result after the stop, with its large files, not the counter fallback.
    #expect(r.largeFiles.files.map(\.path) == ["/seen"])
}

@Test func measureKeepsOrderAndReportsProgress() async throws {
    let h = try FakeHome()
    for name in ["a", "b", "c", "d", "e"] { try h.file("\(name)/f", bytes: 4096) }
    let paths = ["e", "a", "c", "b", "d"].map { h.path + "/" + $0 }
    let seen = Seen()
    let r = await DirectoryScanner.measure(paths, progress: { done, total in seen.add(done, total) }) { p, c in
        DiskWalker.walk(p, counter: c)
    }
    #expect(r.map(\.0) == paths)
    #expect(r.allSatisfy { $0.1.files == 1 })
    #expect(seen.last?.0 == 5 && seen.last?.1 == 5)
}

// MARK: Listing

@Test func cleanableNeedsProjectFileNextToIt() throws {
    let h = try FakeHome()
    try h.file("php/composer.json")
    try h.file("php/vendor/x")
    try h.file("go/go.mod")
    try h.file("go/vendor/x")
    try h.file("net/app.csproj")
    try h.file("net/bin/x")
    try h.file("misc/bin/x")
    try h.file("rs/Cargo.toml")
    try h.file("rs/target/x")
    try h.file("py/env/.venv/pyvenv.cfg")
    #expect(Cleanable.isCleanableDirectory(h.path + "/php/vendor"))
    #expect(!Cleanable.isCleanableDirectory(h.path + "/go/vendor"))
    #expect(Cleanable.isCleanableDirectory(h.path + "/net/bin"))
    #expect(!Cleanable.isCleanableDirectory(h.path + "/misc/bin"))
    #expect(Cleanable.isCleanableDirectory(h.path + "/rs/target"))
    #expect(Cleanable.isCleanableDirectory(h.path + "/py/env/.venv"))
    #expect(!Cleanable.isCleanableDirectory(h.path + "/rs/Cargo.toml"))
}

@Test func listShowsFilesFoldersAndLargestFiles() async throws {
    let h = try FakeHome()
    try h.file("top/movie.mov", bytes: 2_000_000)
    try h.file("top/sub/deep.bin", bytes: 3_000_000)
    try h.file("top/sub/small", bytes: 4096)
    let listing = await DirectoryScanner.list(h.path + "/top", home: h.path)
    #expect(listing.entries.map(\.name) == ["sub", "movie.mov"])
    let sub = try #require(listing.entries.first)
    #expect(sub.isDirectory && sub.files == 2 && sub.modified != nil)
    #expect(listing.largeFiles.map(\.name) == ["deep.bin", "movie.mov"])
    #expect(listing.totalBytes == listing.entries.reduce(0) { $0 + $1.bytes })
    #expect(!listing.partial)
}

@Test func overviewPlacesAddUpWithoutDoubleCounting() async throws {
    let h = try FakeHome()
    try h.file("Library/Developer/Xcode/blob", bytes: 300_000)
    try h.file("Library/Preferences/p", bytes: 20_000)
    try h.file(".Trash/old", bytes: 50_000)
    try h.file("misc", bytes: 10_000)
    let o = await DirectoryScanner.overview(home: h.path)
    let dev = try #require(o.entries.first { $0.path == h.path + "/Library/Developer" })
    let lib = try #require(o.entries.first { $0.path == h.path + "/Library" })
    let trash = try #require(o.entries.first { $0.path == h.path + "/.Trash" })
    #expect(dev.bytes >= 300_000)
    #expect(lib.bytes < 300_000 && lib.bytes >= 20_000)
    #expect(trash.name == L("Papierkorb"))
    #expect(!o.entries.contains { $0.path == "/Applications" })   // only for the real home
    // A complete overview leaves a growth snapshot behind.
    #expect(FileManager.default.fileExists(atPath: h.path + "/Library/Application Support/Swabr/growth"))
}

// MARK: Trash

@Test func trashRefusesEveryProtectedPlace() throws {
    let h = try FakeHome()
    let home = h.path
    let refused = [
        "", "relative/path", "/Users/x/../y", home + "/./Downloads", home + "/a\u{7}b",
        "/", "/System", "/System/Library/CoreServices", "/Library", "/Applications", "/Users", "/Volumes",
        "/private", "/private/etc", "/private/var", "/private/tmp", "/etc", "/var", "/tmp",
        "/usr", "/usr/bin/true", "/usr/local", "/bin", "/bin/ls", "/sbin", "/opt", "/opt/homebrew", "/dev", "/dev/null", "/cores",
        "/Applications/Safari.app", "/System/Library/CoreServices/Finder.app", "/Applications/Safari.app/Contents",
        home, home + "/", home + "//Library", home + "/Documents", home + "/Downloads", home + "/.Trash",
        home + "/Library/Caches", home + "/Library/Application Support",
        home + "/Library/Keychains", home + "/Library/Keychains/login.keychain-db",
        home + "/Library/Mobile Documents", home + "/Library/Mobile Documents/com~apple~CloudDocs/a.txt",
        home + "/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw",
        home + "/Library/Group Containers/HUAQ24HBR6.dev.orbstack/data", home + "/.orbstack/vm",
    ]
    for p in refused { #expect(AnalyzeTrash.refusal(for: p, home: home) != nil, "\(p.debugDescription)") }

    let allowed = [home + "/Downloads/big.dmg", home + "/Library/Caches/com.acme", "/usr/local/lib/old",
                   "/Applications/Foo.app", "/Volumes/Ext/movie.mov", home + "/Projects/node_modules"]
    for p in allowed { #expect(AnalyzeTrash.refusal(for: p, home: home) == nil, "\(p)") }
}

@Test func trashChecksTheResolvedPathToo() throws {
    let h = try FakeHome()
    for dir in ["Downloads", "Library/Mobile Documents", "Library/Keychains"] {
        try FileManager.default.createDirectory(atPath: h.path + "/" + dir, withIntermediateDirectories: true)
    }
    try FileManager.default.createSymbolicLink(atPath: h.path + "/Downloads/sys", withDestinationPath: "/System")
    try FileManager.default.createSymbolicLink(atPath: h.path + "/Downloads/icloud", withDestinationPath: h.path + "/Library/Mobile Documents")
    try FileManager.default.createSymbolicLink(atPath: h.path + "/stuff", withDestinationPath: h.path + "/Library")
    #expect(AnalyzeTrash.refusal(for: h.path + "/Downloads/sys", home: h.path) != nil)
    #expect(AnalyzeTrash.refusal(for: h.path + "/Downloads/icloud/x", home: h.path) != nil)
    #expect(AnalyzeTrash.refusal(for: h.path + "/stuff/Keychains", home: h.path) != nil)
    // The same home given through the /var link still protects the physical paths.
    let viaLink = h.path.replacingOccurrences(of: "/private/var/", with: "/var/")
    #expect(AnalyzeTrash.refusal(for: h.path + "/Documents", home: viaLink) != nil)
}

@Test func moveToTrashLogsAndReportsFailures() throws {
    let h = try FakeHome()
    try h.file("Downloads/old.dmg", bytes: 50_000)
    let log = OperationLog(home: h.path)
    let trashed = Box()
    let failed = AnalyzeTrash.moveToTrash(
        [h.path + "/Downloads/old.dmg", h.path + "/Library", h.path + "/Downloads/missing"], home: h.path, log: log
    ) { url in
        guard FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileNoSuchFile) }
        trashed.paths.append(url.path)
    }
    #expect(trashed.paths == [h.path + "/Downloads/old.dmg"])
    #expect(failed.count == 2)
    #expect(failed.first { $0.path == h.path + "/Library" }?.kind == .protectedPath)
    #expect(failed.first { $0.path == h.path + "/Downloads/missing" }?.kind == .failed)
    let entries = History.load(log)
    #expect(entries.count == 1)
    let e = try #require(entries.first)
    #expect(e.action == "TRASH" && e.label == "Speicheranalyse" && e.path == h.path + "/Downloads/old.dmg")
    #expect(e.bytes >= 50_000)
    #expect(e.module == L("Speicher"))
}

// MARK: Helpers

private func run(_ tool: String, _ args: [String]) -> Bool {
    Shell.run(tool, args, timeout: 120).status == 0
}

private final class Box { var paths: [String] = [] }

private final class Seen: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [(Int, Int)] = []
    func add(_ done: Int, _ total: Int) { lock.withLock { values.append((done, total)) } }
    var last: (Int, Int)? { lock.withLock { values.max { $0.0 < $1.0 } } }
}

/// Folders the user may not move (their parent belongs to root) go through one privileged step.
@Test func rootOwnedItemsGoThroughThePrivilegedStep() throws {
    let h = try FakeHome()
    try FileManager.default.createDirectory(atPath: h.path + "/Applications/Utilities/Adobe Installers", withIntermediateDirectories: true)
    try FileManager.default.createDirectory(atPath: h.path + "/.Trash", withIntermediateDirectories: true)
    let target = h.path + "/Applications/Utilities/Adobe Installers"
    let denied: (URL) throws -> Void = { _ in throw CocoaError(.fileWriteNoPermission) }
    final class Calls: @unchecked Sendable { var count = 0 }
    let calls = Calls()
    let log = OperationLog(home: h.path)

    // Password declined: nothing moves, the item is reported.
    var failed = AnalyzeTrash.moveToTrash([target], home: h.path, log: log, runPrivileged: { _ in calls.count += 1; return nil }, trash: denied)
    #expect(calls.count == 1)
    #expect(failed.map(\.kind) == [.permission])
    #expect(FileManager.default.fileExists(atPath: target))

    // Stand-in for root: run the script as given; RootScript checks every move itself.
    failed = AnalyzeTrash.moveToTrash([target], home: h.path, log: log, runPrivileged: { script in
        calls.count += 1
        return Shell.run("/bin/sh", ["-c", script]).status == 0 ? "" : nil
    }, trash: denied)
    #expect(calls.count == 2)
    #expect(failed.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: target))
    #expect(try FileManager.default.contentsOfDirectory(atPath: h.path + "/.Trash").contains { $0.hasPrefix("Adobe Installers ") })
    #expect(History.load(log).count == 1)

    // Outside the places RootScript allows, nothing is handed to root.
    try FileManager.default.createDirectory(atPath: h.path + "/opt/tool", withIntermediateDirectories: true)
    failed = AnalyzeTrash.moveToTrash([h.path + "/opt/tool"], home: h.path, log: log, runPrivileged: { _ in calls.count += 1; return "" }, trash: denied)
    #expect(calls.count == 2)
    #expect(failed.map(\.kind) == [.protectedPath])

    // Without a privileged runner (App Store edition) the permission error is simply reported.
    try FileManager.default.createDirectory(atPath: target, withIntermediateDirectories: true)
    failed = AnalyzeTrash.moveToTrash([target], home: h.path, log: log, trash: denied)
    #expect(failed.map(\.kind) == [.permission])
}

@Test func utilitiesFolderItselfIsNeverMoved() {
    #expect(AnalyzeTrash.refusal(for: "/Applications/Utilities") != nil)
    #expect(AnalyzeTrash.refusal(for: "/Applications/Utilities/Adobe Installers") == nil)
}
