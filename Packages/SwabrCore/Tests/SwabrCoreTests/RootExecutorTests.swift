import Foundation
import Testing
@testable import SwabrCore

// The helper's own checks (A-01): it takes fixed operations only and refuses anything outside its rules,
// whatever the app sent. Run as the user on a fake home.

private func executor(_ h: FakeHome) -> RootExecutor {
    var e = RootExecutor(uid: getuid(), gid: getgid(), home: h.path, timeout: 10)
    e.sourceRoots = [h.path + "/Library/Caches/", "/Volumes/"]
    e.appRoots = [h.path + "/Applications/"]
    e.replacementRoots = [h.path + "/work/"]
    return e
}

@Test func helperRefusesTrashTargetsOutsideTheUsersTrash() throws {
    let h = try FakeHome()
    try h.file(".Trash/.keep")
    try h.file("Library/Caches/com.acme.a/x")
    let e = executor(h)
    // Into another folder, into a subfolder of the Trash, onto an existing name.
    #expect(!e.perform([.trash(source: h.path + "/Library/Caches/com.acme.a", target: h.path + "/Documents/a")])[0].ok)
    #expect(!e.perform([.trash(source: h.path + "/Library/Caches/com.acme.a", target: h.path + "/.Trash/sub/a")])[0].ok)
    #expect(!e.perform([.trash(source: h.path + "/Library/Caches/com.acme.a", target: h.path + "/.Trash/.keep")])[0].ok)
    #expect(h.exists("Library/Caches/com.acme.a/x"))
    #expect(e.perform([.trash(source: h.path + "/Library/Caches/com.acme.a", target: h.path + "/.Trash/a")])[0].ok)
    #expect(h.exists(".Trash/a/x"))
}

@Test func helperNeverTakesAVolumeOrItsTopLevel() {
    var e = RootExecutor(uid: getuid(), gid: getgid(), home: "/Users/nobody-\(UUID().uuidString)", timeout: 10)
    e.sourceRoots = ["/Volumes/"]
    for path in ["/Volumes/Data", "/Volumes/Data/Projects"] {
        #expect(e.perform([.trash(source: path, target: e.home + "/.Trash/x")])[0].status == 77, "\(path)")
    }
}

@Test func helperStopsOnlyLaunchPlistsInTheirFolders() {
    let e = RootExecutor(uid: getuid(), gid: getgid(), home: "/Users/nobody", timeout: 10)
    for bad in ["/etc/hosts", "/Library/LaunchDaemons/../../etc/x.plist", "/Library/LaunchDaemons/com.apple.foo.plist",
                "/Library/LaunchDaemons/sub/x.plist", "/Library/LaunchDaemons/x.conf"] {
        #expect(e.perform([.stopDaemon(plist: bad)])[0].status == 77, "\(bad)")
    }
    #expect(e.perform([.stopAgent(plist: "/Library/LaunchDaemons/com.acme.x.plist")])[0].status == 77)
}

@Test func helperChecksCommandArguments() {
    let e = RootExecutor(uid: getuid(), gid: getgid(), home: "/Users/nobody", timeout: 10)
    #expect(e.perform([.command(.flushRoutes(interfaces: ["en0; rm -rf /"]))])[0].status == 77)
    #expect(e.perform([.command(.flushRoutes(interfaces: []))])[0].status == 77)
    #expect(e.perform([.command(.periodic(names: ["daily", "/bin/sh"]))])[0].status == 77)
    #expect(RootExecutor.isInterfaceName("en0") && RootExecutor.isInterfaceName("utun3") && !RootExecutor.isInterfaceName("../en0"))
}

@Test func helperReplacesOnlyAppsInTheAppFoldersWithACopyOfTheSameName() throws {
    let h = try FakeHome()
    try h.file(".Trash/.keep")
    try h.file("Applications/Tool.app/Contents/MacOS/Tool", bytes: 2000)
    try h.file("work/Other.app/Contents/MacOS/Tool", bytes: 1000)
    try h.file("Documents/Tool.app/Contents/MacOS/Tool", bytes: 1000)
    let e = executor(h)
    let app = h.path + "/Applications/Tool.app"
    // Another name, or a copy from outside the work folders: refused, nothing moves.
    #expect(!e.perform([.replaceApp(original: app, replacement: h.path + "/work/Other.app", trash: h.path + "/.Trash/t1")])[0].ok)
    #expect(!e.perform([.replaceApp(original: app, replacement: h.path + "/Documents/Tool.app", trash: h.path + "/.Trash/t2")])[0].ok)
    #expect(h.exists("Applications/Tool.app") && !h.exists(".Trash/t1") && !h.exists(".Trash/t2"))
    // An original outside the app folders.
    #expect(!e.perform([.replaceApp(original: h.path + "/Documents/Tool.app", replacement: h.path + "/work/Other.app",
                                    trash: h.path + "/.Trash/t3")])[0].ok)
}

@Test func groupRunsItsRestOnlyAfterTheFirstStepWorked() throws {
    let h = try FakeHome()
    try h.file(".Trash/.keep")
    try h.file("Library/Caches/com.acme.files/x")
    let e = executor(h)
    let missing = RootOperation.trash(source: h.path + "/Library/Caches/com.acme.gone", target: h.path + "/.Trash/gone")
    let files = RootOperation.trash(source: h.path + "/Library/Caches/com.acme.files", target: h.path + "/.Trash/files")
    #expect(!e.perform([.group(first: missing, then: [files])])[0].ok)
    #expect(h.exists("Library/Caches/com.acme.files/x"))
}

@Test func helperStopsProgramsThatRunTooLong() {
    let start = Date()
    let r = RootExecutor.launch("/bin/sleep", ["30"], timeout: 1)
    #expect(r.status == 124)
    #expect(Date().timeIntervalSince(start) < 10)
}

@Test func requestsAndResultsSurviveTheTripThroughJSON() throws {
    let ops: [RootOperation] = [
        .group(first: .trash(source: "/Applications/A.app", target: "/Users/u/.Trash/A.app"), then: [.stopDaemon(plist: "/Library/LaunchDaemons/a.plist")]),
        .replaceApp(original: "/Applications/B.app", replacement: "/private/var/folders/x/B.app", trash: "/Users/u/.Trash/B.app 1"),
        .command(.flushRoutes(interfaces: ["en0"])), .command(.listBackgroundItems),
    ]
    let data = try JSONEncoder().encode(RootRequest(ops))
    #expect(try JSONDecoder().decode(RootRequest.self, from: data).operations == ops)
    let results = [RootResult(status: 0, output: "ok"), RootResult(status: 77, output: "refused: x")]
    #expect(try JSONDecoder().decode([RootResult].self, from: JSONEncoder().encode(results)) == results)
}
