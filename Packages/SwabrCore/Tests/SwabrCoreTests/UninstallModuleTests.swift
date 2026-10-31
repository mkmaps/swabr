import Foundation
import Testing
@testable import SwabrCore

// MARK: Helpers

private func rel(_ found: [Leftover], _ h: FakeHome) -> [String: Leftover] {
    Dictionary(uniqueKeysWithValues: found.map { ($0.path.replacingOccurrences(of: h.path + "/", with: ""), $0) })
}

private func writePlist(_ dict: [String: Any], to path: String) throws {
    try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0).write(to: URL(fileURLWithPath: path))
}


/// Records calls from the code under test.
private final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String] = []
    func add(_ s: String) { lock.withLock { items.append(s) } }
    var all: [String] { lock.withLock { items } }
}

/// A test environment: moves into the fake home's Trash, never calls launchctl or brew.
private func testEnv(_ h: FakeHome, systemRoot: String? = nil, launchctl: Recorder? = nil, brew: Recorder? = nil,
                     brewResult: @escaping (String) -> Bool = { _ in false },
                     trash: ((String) throws -> Void)? = nil) -> Uninstaller.Environment {
    let roots = systemRoot.map { [$0] } ?? []
    return Uninstaller.Environment(
        trash: trash ?? { try Uninstaller.moveToTrashFolder($0, home: h.path) },
        launchctl: { launchctl?.add($0.joined(separator: " ")) },
        brewUninstall: { brew?.add($0); return brewResult($0) },
        isSafeSystemPath: { LeftoverFinder.isSafe($0, roots: roots) },
        rootRoots: roots + AppCatalog.roots(home: h.path).map { $0 + "/" },
        uid: getuid(), gid: getgid())
}

private func runPlans(_ plans: [UninstallPlan], _ h: FakeHome, env: Uninstaller.Environment, keepApps: Bool = false,
                      privilegedTrash: Uninstaller.PrivilegedTrash? = nil,
                      runPrivileged: Uninstaller.RunPrivileged? = nil) -> UninstallReport {
    Uninstaller.run(plans, home: h.path, log: OperationLog(home: h.path), privilegedTrash: privilegedTrash,
                    runPrivileged: runPrivileged, keepApps: keepApps, progress: { _ in }, env: env)
}

private func logText(_ h: FakeHome) -> String {
    (try? String(contentsOfFile: OperationLog(home: h.path).url.path, encoding: .utf8)) ?? ""
}

// MARK: Evidence

@Test func everyBundleIDPlaceCountsAsIdentity() throws {
    let h = try FakeHome()
    let app = try fakeApp(h, name: "Tidewell", id: "com.acme.tidewell")
    let places = [
        "Library/Caches/com.acme.tidewell", "Library/Logs/com.acme.tidewell", "Library/Preferences/com.acme.tidewell.plist",
        "Library/Preferences/ByHost/com.acme.tidewell.0F1E2D.plist", "Library/Saved Application State/com.acme.tidewell.savedState",
        "Library/Containers/com.acme.tidewell", "Library/WebKit/com.acme.tidewell", "Library/HTTPStorages/com.acme.tidewell",
        "Library/Cookies/com.acme.tidewell.binarycookies", "Library/Application Scripts/com.acme.tidewell",
        "Library/Autosave Information/com.acme.tidewell", "Library/Application Support/com.acme.tidewell",
        "Library/Group Containers/ABCDE12345.com.acme.tidewell", "Library/Group Containers/group.com.acme.tidewell.shared",
    ]
    for p in places { try h.file(p + "/x") }
    try h.file("Library/Group Containers/ABCDE12345.com.acme.tidewellx/x")   // no id boundary
    let found = rel(LeftoverFinder.find(for: app, otherApps: [app], home: h.path), h)
    for p in places { #expect(found[p]?.evidence == .identity, "\(p)") }
    #expect(found["Library/Group Containers/ABCDE12345.com.acme.tidewellx"] == nil)
    #expect(found["Library/Cookies/com.acme.tidewell.binarycookies"]?.kind == .personal)
    #expect(found["Library/Logs/com.acme.tidewell"]?.kind == .disposable)
    #expect(found["Library/Group Containers/group.com.acme.tidewell.shared"]?.kind == .sensitive)
}

@Test func vendorAndProductFolderCountsAsIdentity() throws {
    let h = try FakeHome()
    let app = try fakeApp(h, name: "Brave Browser", id: "com.brave.Browser")
    try h.file("Library/Application Support/BraveSoftware/Brave-Browser/Default/Cookies")
    try h.file("Library/Application Support/BraveSoftware/Other/x")
    let found = rel(LeftoverFinder.find(for: app, otherApps: [app], home: h.path), h)
    #expect(found["Library/Application Support/BraveSoftware/Brave-Browser"]?.evidence == .identity)
    #expect(found["Library/Application Support/BraveSoftware/Brave-Browser"]?.kind == .sensitive)
    #expect(found["Library/Application Support/BraveSoftware/Other"] == nil)
}

@Test func launchAgentIsMatchedByLabel() throws {
    let h = try FakeHome()
    let app = try fakeApp(h, name: "Syncer", id: "io.syncer.app")
    try writePlist(["Label": "io.syncer.app.updater", "Program": "/usr/local/bin/x"], to: h.path + "/Library/LaunchAgents/updater.plist")
    try writePlist(["Label": "io.syncer.appx", "Program": "/usr/local/bin/y"], to: h.path + "/Library/LaunchAgents/other.plist")
    let agents = LeftoverFinder.find(for: app, otherApps: [], home: h.path).filter { $0.kind == .launchAgent }
    #expect(agents.map { ($0.path as NSString).lastPathComponent } == ["updater.plist"])
    #expect(agents.first?.preselected == true)
}

@Test func uuidContainerOfIPhoneAppIsItsLeftover() throws {
    let h = try FakeHome()
    let bundle = h.path + "/Applications/Solar.app"
    try writePlist(["CFBundleIdentifier": "com.example.solar", "CFBundleName": "Solar"], to: bundle + "/Wrapper/Inner.app/Info.plist")
    let app = try #require(AppCatalog.describe(bundle, protection: RuleStore.protection(), ownBundleID: nil))
    #expect(app.isIOSApp)
    let uuid = "4B6A2C1D-0000-4000-8000-112233445566"
    try h.file("Library/Containers/\(uuid)/Data/Documents/save")
    try writePlist(["MCMMetadataIdentifier": "com.example.solar"], to: h.path + "/Library/Containers/\(uuid)/.com.apple.containermanagerd.metadata.plist")
    let found = rel(LeftoverFinder.find(for: app, otherApps: [app], home: h.path), h)
    #expect(found["Library/Containers/\(uuid)"]?.evidence == .identity)
    #expect(found["Library/Containers/\(uuid)"]?.kind == .personal)
}

@Test func receiptsAndSystemFoldersGiveSystemLeftovers() throws {
    let h = try FakeHome()
    let sys = try FakeHome()
    let root = sys.path + "/Application Support/"
    let app = try fakeApp(h, name: "Tidewell", id: "com.acme.tidewell")
    try sys.file("Application Support/Acme Tools/a")
    try sys.file("Application Support/Acme Tools/inner/b")
    try sys.file("Application Support/com.acme.tidewell/c")
    try sys.file("Application Support/Tidewell/d")
    try sys.file("Application Support/com.apple.tidewell/e")
    let scope = LeftoverFinder.SystemScope(roots: [root], receipts: { _ in [root + "Acme Tools", root + "Acme Tools/inner", root + "Apple Thing"] })
    let found = LeftoverFinder.find(for: app, otherApps: [app], home: h.path, protection: try RuleStore.protection(), system: scope)
    let byPath = Dictionary(uniqueKeysWithValues: found.map { ($0.path, $0) })
    #expect(byPath[root + "Acme Tools"]?.evidence == .identity)
    #expect(byPath[root + "Acme Tools"]?.kind == .system)
    #expect(byPath[root + "Acme Tools/inner"] == nil)      // only the topmost
    #expect(byPath[root + "com.acme.tidewell"]?.evidence == .identity)
    #expect(byPath[root + "Tidewell"]?.evidence == .nameOnly)
    #expect(byPath[root + "com.apple.tidewell"] == nil)
    #expect(byPath[root + "Apple Thing"] == nil)
    #expect(found.filter { $0.kind == .system }.allSatisfy { !$0.preselected })

    // The same installer put another app of the suite on the disk: its files are shared.
    var shared = scope
    shared.sharesInstaller = { _, _ in true }
    let suite = LeftoverFinder.find(for: app, otherApps: [app], home: h.path, protection: try RuleStore.protection(), system: shared)
    #expect(!suite.contains { $0.path == root + "Acme Tools" })
    #expect(suite.contains { $0.path == root + "com.acme.tidewell" })
}

@Test func nameOnlyIsNeverPreselected() throws {
    let h = try FakeHome()
    let app = try fakeApp(h, name: "Tidewell Notes", id: "com.acme.tidewell")
    try h.file("Library/Caches/tidewell-notes/a")
    try h.file(".cache/tidewell_notes/a")
    let found = rel(LeftoverFinder.find(for: app, otherApps: [app], home: h.path), h)
    #expect(found["Library/Caches/tidewell-notes"]?.evidence == .nameOnly)
    #expect(found[".cache/tidewell_notes"]?.kind == .disposable)
    #expect(found.values.allSatisfy { !$0.preselected })
    for kind in Leftover.Kind.allCases {
        let weak = Leftover(path: "/x", kind: kind, bytes: 0, evidence: .nameOnly)
        #expect(!weak.preselected)
        #expect(weak.impact.count > Leftover(path: "/x", kind: kind, bytes: 0).impact.count)
    }
}

@Test func shortCommonAndSensitiveNamesAreNotMatched() throws {
    let h = try FakeHome()
    try h.file("Library/Application Support/Go/a")
    try h.file("Library/Application Support/Helper/a")
    try h.file("Library/Application Support/Keychain Tidy/a")
    try h.file("Library/Caches/com.1password.helper/a")
    let go = try fakeApp(h, name: "Go", id: "org.golang.go")
    let helper = try fakeApp(h, name: "Helper", id: "com.acme.helperapp")
    let tidy = try fakeApp(h, name: "Keychain Tidy", id: "com.acme.tidy")
    #expect(LeftoverFinder.find(for: go, otherApps: [], home: h.path).isEmpty)
    #expect(LeftoverFinder.find(for: helper, otherApps: [], home: h.path).isEmpty)
    #expect(LeftoverFinder.find(for: tidy, otherApps: [], home: h.path).isEmpty)
}

@Test func versionSuffixIsDroppedUnlessAnotherAppHasTheName() throws {
    let h = try FakeHome()
    let beta = try fakeApp(h, name: "Tidewell Beta", id: "com.acme.tidewell.beta")
    let stable = try fakeApp(h, name: "Tidewell", id: "com.other.tidewell")
    try h.file("Library/Application Support/Tidewell/a")
    #expect(LeftoverFinder.stripVersion("Tidewell Beta 2") == "tidewell")
    #expect(rel(LeftoverFinder.find(for: beta, otherApps: [beta], home: h.path), h)["Library/Application Support/Tidewell"]?.evidence == .nameOnly)
    #expect(rel(LeftoverFinder.find(for: beta, otherApps: [beta, stable], home: h.path), h)["Library/Application Support/Tidewell"] == nil)
}

@Test func moreSpecificBundleIDBelongsToTheOtherApp() throws {
    let h = try FakeHome()
    let main = try fakeApp(h, name: "Suite", id: "com.acme.suite")
    let part = try fakeApp(h, name: "Suite Writer", id: "com.acme.suite.writer")
    try h.file("Library/Caches/com.acme.suite/a")
    try h.file("Library/Caches/com.acme.suite.writer/a")
    let found = rel(LeftoverFinder.find(for: main, otherApps: [main, part], home: h.path), h)
    #expect(found["Library/Caches/com.acme.suite"] != nil)
    #expect(found["Library/Caches/com.acme.suite.writer"] == nil)
}

@Test func secondCopyWithSameIDInOtherCaseFindsNothing() throws {
    let h = try FakeHome()
    let a = try fakeApp(h, name: "Tool", id: "com.acme.Tool")
    let b = InstalledApp(name: "Tool", path: h.path + "/Applications/Old/Tool.app", bundleID: "com.acme.tool",
                         version: nil, bytes: 1, lastUsed: nil, fromAppStore: false, protection: nil)
    try h.file("Library/Preferences/com.acme.Tool.plist")
    #expect(LeftoverFinder.find(for: a, otherApps: [a, b], home: h.path).isEmpty)
}

@Test func cachesWithUserValueArePersonal() throws {
    let h = try FakeHome()
    let app = try fakeApp(h, name: "Spotify", id: "com.spotify.client")
    try h.file("Library/Caches/com.spotify.client/Storage/x")
    let found = rel(LeftoverFinder.find(for: app, otherApps: [app], home: h.path), h)
    #expect(found["Library/Caches/com.spotify.client"]?.kind == .personal)
    #expect(found["Library/Caches/com.spotify.client"]?.preselected == false)
}

@Test func systemPathRulesAreStrict() {
    #expect(!LeftoverFinder.isSafeSystemPath("/Library/Audio/Plug-Ins/HAL"))
    #expect(!LeftoverFinder.isSafeSystemPath("/Library/Audio/Plug-Ins/Thing"))
    #expect(LeftoverFinder.isSafeSystemPath("/Library/Audio/Plug-Ins/HAL/Acme.driver"))
    #expect(!LeftoverFinder.isSafeSystemPath("/Library/Application Support/Vendor/AppleStuff"))
    #expect(!LeftoverFinder.isSafeSystemPath("/Library/Application Support//x"))
    #expect(!LeftoverFinder.isSafeSystemPath("/Library/Keychains/x"))
    #expect(LeftoverFinder.isReverseDNS("com.acme.app") && !LeftoverFinder.isReverseDNS("Acme App") && !LeftoverFinder.isReverseDNS("com..x"))
}

// MARK: Catalogue

@Test func catalogueFindsVendorFoldersAndSkipsLinks() throws {
    let h = try FakeHome()
    let root = h.path + "/Applications"
    try h.file("Applications/A.app/Contents/Info.plist")
    try h.file("Applications/Vendor Suite/B.app/Contents/Info.plist")
    try h.file("Applications/Vendor Suite/Deeper/C.app/Contents/Info.plist")
    try FileManager.default.createSymbolicLink(atPath: root + "/Linked.app", withDestinationPath: root + "/A.app")
    try FileManager.default.createSymbolicLink(atPath: root + "/Calc.app", withDestinationPath: "/System/Applications/Calculator.app")
    let names = AppCatalog.bundlePaths(in: [root]).map { $0.replacingOccurrences(of: root + "/", with: "") }
    #expect(names == ["A.app", "Calc.app", "Vendor Suite/B.app"])
    let calc = try #require(AppCatalog.describe(root + "/Calc.app", protection: RuleStore.protection(), ownBundleID: nil))
    #expect(calc.protection != nil && !calc.isRemovable)
}

@Test func caskListKeepsOnlyValidTokens() {
    let text = "anki 25.07.5\nfoo-bar 1.0\n-rf 1\nEvil 2\nok@2 3\n"
    #expect(AppCatalog.parseCaskList(text) == ["anki", "foo-bar", "ok@2"])
}

@Test func refusalAcceptsOneVendorLevelOnly() throws {
    let h = try FakeHome()
    func app(_ rel: String) -> InstalledApp {
        InstalledApp(name: "X", path: h.path + "/" + rel, bundleID: "com.x.y", version: nil, bytes: 0, lastUsed: nil,
                     fromAppStore: false, protection: nil)
    }
    #expect(Uninstaller.refusal(forApp: app("Applications/Vendor/X.app"), home: h.path) == nil)
    #expect(Uninstaller.refusal(forApp: app("Applications/Vendor/Deep/X.app"), home: h.path) != nil)
    #expect(Uninstaller.refusal(forApp: app("Applications/Outer.app/X.app"), home: h.path) != nil)
    #expect(Uninstaller.refusal(forApp: app("Applications/../Desktop/X.app"), home: h.path) != nil)
    #expect(Uninstaller.refusal(forApp: app("Applications/Folder"), home: h.path) != nil)
}

// MARK: Removing

@Test func oneRootStepForSeveralAppsAndTheirSystemFiles() throws {
    let h = try FakeHome()
    let sys = try FakeHome()
    try h.file(".Trash/.keep")
    let root = sys.path + "/Application Support/"
    let a = try fakeApp(h, name: "Alpha", id: "com.acme.alpha")
    let b = try fakeApp(h, name: "Beta", id: "com.acme.beta")
    try sys.file("Application Support/com.acme.alpha/x")
    try sys.file("Application Support/com.acme.beta/x")
    for app in [a, b] { chmod(app.path, 0o555) }
    defer { for app in [a, b] { chmod(app.path, 0o755) } }
    let scripts = Recorder()
    let report = runPlans(
        [UninstallPlan(app: a, leftovers: [Leftover(path: root + "com.acme.alpha", kind: .system, bytes: 1)]),
         UninstallPlan(app: b, leftovers: [Leftover(path: root + "com.acme.beta", kind: .system, bytes: 1)])],
        h, env: testEnv(h, systemRoot: root),
        privilegedTrash: { _ in Issue.record("no per-item prompt expected"); return "x" },
        runPrivileged: { ops in
            scripts.add("\(ops)")
            for app in [a, b] { chmod(app.path, 0o755) }
            return rootAsUser(home: h.path, roots: [root])(ops)
        })
    #expect(scripts.all.count == 1)
    #expect(report.failures.isEmpty)
    #expect(Set(report.removedApps) == ["Alpha", "Beta"])
    #expect(h.exists(".Trash/Alpha.app") && h.exists(".Trash/Beta.app"))
    #expect(h.exists(".Trash/com.acme.alpha/x") && h.exists(".Trash/com.acme.beta/x"))
    #expect(logText(h).contains("Deinstallieren: Alpha (System)"))
}

@Test func appThatStaysKeepsItsSystemAndHomeData() throws {
    let h = try FakeHome()
    let sys = try FakeHome()
    try h.file(".Trash/.keep")
    let root = sys.path + "/Application Support/"
    let app = try fakeApp(h, name: "Stuck", id: "com.acme.stuck")
    try sys.file("Application Support/com.acme.stuck/x")
    try h.file("Library/Caches/com.acme.stuck/x")
    chmod(app.path, 0o555)
    defer { chmod(app.path, 0o755) }
    let report = runPlans(
        [UninstallPlan(app: app, leftovers: [Leftover(path: root + "com.acme.stuck", kind: .system, bytes: 1),
                                             Leftover(path: h.path + "/Library/Caches/com.acme.stuck", kind: .disposable, bytes: 1)])],
        h, env: testEnv(h, systemRoot: root),
        runPrivileged: rootAsUser(home: h.path, roots: [root]))   // still locked: the app move fails
    #expect(report.removedApps.isEmpty)
    #expect(report.failures.map(\.path) == [app.path])
    #expect(report.failures.first?.kind == .permission)
    #expect(sys.exists("Application Support/com.acme.stuck/x"))
    #expect(h.exists("Library/Caches/com.acme.stuck/x"))
}

@Test func rootOperationsStopDaemonsAndMoveFilesOnlyAfterTheApp() {
    let groups = [
        Uninstaller.RootGroup(app: .init(source: "/Applications/A.app", target: "/Users/u/.Trash/A.app"),
                              files: [.init(source: "/Library/LaunchDaemons/com.a.d.plist", target: "/Users/u/.Trash/com.a.d.plist")]),
        Uninstaller.RootGroup(app: nil, files: [.init(source: "/Library/Caches/com.b", target: "/Users/u/.Trash/com.b")]),
    ]
    let ops = Uninstaller.rootOperations(groups)
    #expect(ops == [
        .group(first: .trash(source: "/Applications/A.app", target: "/Users/u/.Trash/A.app"),
               then: [.stopDaemon(plist: "/Library/LaunchDaemons/com.a.d.plist"),
                      .trash(source: "/Library/LaunchDaemons/com.a.d.plist", target: "/Users/u/.Trash/com.a.d.plist")]),
        .trash(source: "/Library/Caches/com.b", target: "/Users/u/.Trash/com.b"),
    ])
}

@Test func permissionErrorFallsBackToPrivilegedTrash() throws {
    let h = try FakeHome()
    let app = try fakeApp(h, name: "Guarded", id: "com.acme.guarded")
    try h.file("Library/Caches/com.acme.guarded/x")
    let asked = Recorder()
    let env = testEnv(h, trash: { path in
        if path == app.path { throw CocoaError(.fileWriteNoPermission) }
        try Uninstaller.moveToTrashFolder(path, home: h.path)
    })
    let report = runPlans(
        [UninstallPlan(app: app, leftovers: [Leftover(path: h.path + "/Library/Caches/com.acme.guarded", kind: .disposable, bytes: 1)])],
        h, env: env,
        privilegedTrash: { path in
            asked.add(path)
            try? FileManager.default.removeItem(atPath: path)
            return nil
        })
    #expect(asked.all == [app.path])
    #expect(report.removedApps == ["Guarded"])
    #expect(report.failures.isEmpty)
    #expect(h.exists(".Trash/com.acme.guarded/x"))
}

@Test func invalidCaskTokenNeverReachesBrew() throws {
    let h = try FakeHome()
    let brew = Recorder()
    for (i, token) in ["evil; rm -rf ~", "-rf", "Upper", "a b"].enumerated() {
        try h.file("Applications/Bad\(i).app/Contents/MacOS/x")
        let app = InstalledApp(name: "Bad\(i)", path: h.path + "/Applications/Bad\(i).app", bundleID: "com.bad.app\(i)", version: nil,
                               bytes: 1, lastUsed: nil, fromAppStore: false, protection: nil, caskToken: token)
        let report = runPlans([UninstallPlan(app: app, leftovers: [])], h, env: testEnv(h, brew: brew))
        #expect(report.removedApps == ["Bad\(i)"])
        #expect(h.exists(".Trash/Bad\(i).app"))
    }
    #expect(brew.all.isEmpty)

    try h.file("Applications/Good.app/Contents/MacOS/x")
    let good = InstalledApp(name: "Good", path: h.path + "/Applications/Good.app", bundleID: "com.good.app", version: nil,
                            bytes: 1, lastUsed: nil, fromAppStore: false, protection: nil, caskToken: "good-app")
    let report = runPlans([UninstallPlan(app: good, leftovers: [])], h,
                          env: testEnv(h, brew: brew, brewResult: { _ in (try? FileManager.default.removeItem(atPath: good.path)) != nil }))
    #expect(brew.all == ["good-app"])
    #expect(report.removedApps == ["Good"])
    #expect(logText(h).contains("\tREMOVE\t"))
}

@Test func userAgentsAreStoppedAndResetKeepsThem() throws {
    let h = try FakeHome()
    let app = try fakeApp(h, name: "Syncer", id: "io.syncer.app")
    let agent = h.path + "/Library/LaunchAgents/io.syncer.app.helper.plist"
    try writePlist(["Label": "io.syncer.app.helper"], to: agent)
    try h.file("Library/Caches/io.syncer.app/x")
    let found = LeftoverFinder.find(for: app, otherApps: [app], home: h.path)
    #expect(found.contains { $0.path == agent && $0.kind == .launchAgent })

    let calls = Recorder()
    let reset = runPlans([UninstallPlan(app: app, leftovers: found)], h, env: testEnv(h, launchctl: calls), keepApps: true)
    #expect(reset.dataOnly && reset.removedApps == ["Syncer"])
    #expect(calls.all.isEmpty)
    #expect(FileManager.default.fileExists(atPath: agent) && h.exists("Applications/Syncer.app"))
    #expect(!h.exists("Library/Caches/io.syncer.app"))
    #expect(logText(h).contains("Zurücksetzen: Syncer"))

    let full = runPlans([UninstallPlan(app: app, leftovers: [found.first { $0.path == agent }!])], h, env: testEnv(h, launchctl: calls))
    #expect(full.removedApps == ["Syncer"])
    #expect(calls.all == ["bootout gui/\(getuid()) \(agent)"])
    #expect(!FileManager.default.fileExists(atPath: agent))
}

@Test func withoutRootShellSystemFilesGoOneByOne() throws {
    let h = try FakeHome()
    let sys = try FakeHome()
    let root = sys.path + "/Application Support/"
    let app = try fakeApp(h, name: "Store", id: "com.acme.store")
    try sys.file("Application Support/com.acme.store/a")
    try sys.file("Application Support/com.acme.store.helper/b")
    let leftovers = [Leftover(path: root + "com.acme.store", kind: .system, bytes: 1),
                     Leftover(path: root + "com.acme.store.helper", kind: .system, bytes: 1)]
    let asked = Recorder()
    let report = runPlans([UninstallPlan(app: app, leftovers: leftovers)], h, env: testEnv(h, systemRoot: root),
                          privilegedTrash: { path in
                              asked.add(path)
                              try? FileManager.default.removeItem(atPath: path)
                              return nil
                          })
    #expect(asked.all == leftovers.map(\.path))
    #expect(report.failures.isEmpty)

    // Neither route available: the system file stays with a reason.
    try sys.file("Application Support/com.acme.store/a")
    let app2 = try fakeApp(h, name: "Store", id: "com.acme.store")
    let bare = runPlans([UninstallPlan(app: app2, leftovers: [leftovers[0]])], h, env: testEnv(h, systemRoot: root))
    #expect(bare.failures.map(\.kind) == [.permission])
    #expect(sys.exists("Application Support/com.acme.store/a"))
}

@Test func unknownSystemPathsAreRefused() throws {
    let h = try FakeHome()
    let app = try fakeApp(h, name: "Odd", id: "com.acme.odd")
    let report = runPlans([UninstallPlan(app: app, leftovers: [Leftover(path: "/etc/hosts", kind: .system, bytes: 1)])], h,
                          env: testEnv(h), privilegedTrash: { _ in Issue.record("must not escalate"); return nil },
                          runPrivileged: { _ in Issue.record("must not escalate"); return nil })
    #expect(report.failures.map(\.path) == ["/etc/hosts"])
    #expect(report.failures.first?.kind == .protectedPath)
    #expect(report.removedApps == ["Odd"])
}

@Test func homeLeftoversAreCheckedAgainBeforeTheyMove() throws {
    let h = try FakeHome()
    let app = try fakeApp(h, name: "Linky", id: "com.acme.linky")
    try h.file("Documents/precious/a")
    try FileManager.default.createDirectory(atPath: h.path + "/Library/Caches", withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(atPath: h.path + "/Library/Caches/link", withDestinationPath: h.path + "/Documents/precious")
    let report = runPlans([UninstallPlan(app: app, leftovers: [
        Leftover(path: h.path + "/Library/Caches/link/a", kind: .disposable, bytes: 1),
        Leftover(path: h.path + "/Library", kind: .personal, bytes: 1),
    ])], h, env: testEnv(h))
    #expect(Set(report.failures.map(\.kind)) == [.protectedPath])
    #expect(report.failures.count == 2)
    #expect(h.exists("Documents/precious/a") && h.exists("Library/Caches"))
}
