import Foundation
import Testing
@testable import SwabrCore

func fakeApp(_ h: FakeHome, name: String, id: String, protection: String? = nil) throws -> InstalledApp {
    try h.file("Applications/\(name).app/Contents/MacOS/\(name)", bytes: 50_000)
    return InstalledApp(name: name, path: h.path + "/Applications/\(name).app", bundleID: id, version: "1.0",
                        bytes: 50_000, lastUsed: nil, fromAppStore: false, protection: protection)
}

@Test func findsAndClassifiesLeftovers() throws {
    let h = try FakeHome()
    let app = try fakeApp(h, name: "Tidewell Notes", id: "com.acme.tidewell")
    try h.file("Library/Caches/com.acme.tidewell/blob")
    try h.file("Library/Application Support/Tidewell Notes/db")
    try h.file("Library/Application Support/TidewellNotes/x")
    try h.file("Library/Preferences/com.acme.tidewell.plist")
    try h.file("Library/Preferences/ByHost/com.acme.tidewell.ABC123.plist")
    try h.file("Library/Containers/com.acme.tidewell.ShareExtension/x")
    try h.file("Library/Group Containers/TEAM42.com.acme.tidewell/x")
    try h.file("Library/Saved Application State/com.acme.tidewell.savedState/w")
    try h.file("Library/Application Support/Other App/x")
    try h.file("Library/Caches/com.acme.tidewellclone/x")   // different app, same prefix

    let found = Dictionary(uniqueKeysWithValues: LeftoverFinder.find(for: app, otherApps: [app], home: h.path)
        .map { ($0.path.replacingOccurrences(of: h.path + "/", with: ""), $0.kind) })
    #expect(found["Library/Caches/com.acme.tidewell"] == .disposable)
    #expect(found["Library/Saved Application State/com.acme.tidewell.savedState"] == .disposable)
    #expect(found["Library/Application Support/Tidewell Notes"] == .personal)
    #expect(found["Library/Application Support/TidewellNotes"] == .personal)
    #expect(found["Library/Preferences/com.acme.tidewell.plist"] == .personal)
    #expect(found["Library/Preferences/ByHost/com.acme.tidewell.ABC123.plist"] == .personal)
    #expect(found["Library/Containers/com.acme.tidewell.ShareExtension"] == .personal)
    #expect(found["Library/Group Containers/TEAM42.com.acme.tidewell"] == .sensitive)
    #expect(found["Library/Application Support/Other App"] == nil)
    #expect(found["Library/Caches/com.acme.tidewellclone"] == nil)
}

@Test func launchAgentIsMatchedByProgramPath() throws {
    let h = try FakeHome()
    let app = try fakeApp(h, name: "Syncer", id: "io.syncer.app")
    try FileManager.default.createDirectory(atPath: h.path + "/Library/LaunchAgents", withIntermediateDirectories: true)
    let mine: [String: Any] = ["Label": "helper", "ProgramArguments": [app.path + "/Contents/MacOS/Syncer", "--bg"]]
    let other: [String: Any] = ["Label": "other", "Program": "/usr/local/bin/other"]
    try PropertyListSerialization.data(fromPropertyList: mine, format: .xml, options: 0)
        .write(to: URL(fileURLWithPath: h.path + "/Library/LaunchAgents/net.unrelated.helper.plist"))
    try PropertyListSerialization.data(fromPropertyList: other, format: .xml, options: 0)
        .write(to: URL(fileURLWithPath: h.path + "/Library/LaunchAgents/net.other.plist"))
    let agents = LeftoverFinder.find(for: app, otherApps: [], home: h.path).filter { $0.kind == .launchAgent }
    #expect(agents.map { ($0.path as NSString).lastPathComponent } == ["net.unrelated.helper.plist"])
}

@Test func commonNamesDoNotMatchByName() throws {
    let h = try FakeHome()
    let app = try fakeApp(h, name: "Notes", id: "com.thirdparty.notes")
    try h.file("Library/Application Support/Notes/keep")
    #expect(LeftoverFinder.find(for: app, otherApps: [], home: h.path).isEmpty)
}

@Test func secondCopyKeepsSharedData() throws {
    let h = try FakeHome()
    let a = try fakeApp(h, name: "Tool", id: "com.acme.tool")
    let b = InstalledApp(name: "Tool", path: h.path + "/Applications/Old/Tool.app", bundleID: "com.acme.tool",
                         version: "0.9", bytes: 1, lastUsed: nil, fromAppStore: false, protection: nil)
    try h.file("Library/Caches/com.acme.tool/x")
    #expect(LeftoverFinder.find(for: a, otherApps: [a, b], home: h.path).isEmpty)
}

@Test func protectionReasonsFollowTheProtectionData() throws {
    let p = try RuleStore.protection()
    #expect(AppCatalog.protectionReason(bundleID: "com.apple.Safari", name: "Safari", protection: p, ownBundleID: nil) != nil)
    #expect(AppCatalog.protectionReason(bundleID: "com.apple.dt.Xcode", name: "Xcode", protection: p, ownBundleID: nil) == nil)
    #expect(AppCatalog.protectionReason(bundleID: "com.crowdstrike.falcon.App", name: "Falcon", protection: p, ownBundleID: nil)?.contains("CrowdStrike") == true)
    #expect(AppCatalog.protectionReason(bundleID: "io.github.mkmaps.swabr", name: "Swabr", protection: p, ownBundleID: "io.github.mkmaps.swabr") != nil)
    #expect(AppCatalog.protectionReason(bundleID: "com.spotify.client", name: "Spotify", protection: p, ownBundleID: nil) == nil)
}

@Test func uninstallerRefusesAppsOutsideApplications() throws {
    let h = try FakeHome()
    let stray = InstalledApp(name: "X", path: h.path + "/Desktop/X.app", bundleID: "com.x.y", version: nil,
                             bytes: 0, lastUsed: nil, fromAppStore: false, protection: nil)
    #expect(Uninstaller.refusal(forApp: stray, home: h.path) != nil)
    let ok = try fakeApp(h, name: "Fine", id: "com.fine.app")
    #expect(Uninstaller.refusal(forApp: ok, home: h.path) == nil)
}

@Test func vendorNestedFoldersComeFromBundleID() throws {
    let h = try FakeHome()
    let app = try fakeApp(h, name: "Google Chrome", id: "com.google.Chrome")
    try h.file("Library/Application Support/Google/Chrome/Default/History")
    try h.file("Library/Caches/Google/Chrome/Default/Cache/x")
    try h.file("Library/Application Support/Google/Drive/keep")
    let found = Dictionary(uniqueKeysWithValues: LeftoverFinder.find(for: app, otherApps: [app], home: h.path)
        .map { ($0.path.replacingOccurrences(of: h.path + "/", with: ""), $0.kind) })
    #expect(found["Library/Application Support/Google/Chrome"] == .sensitive)
    #expect(found["Library/Caches/Google/Chrome"] == .disposable)
    #expect(found["Library/Application Support/Google/Drive"] == nil)
}

@Test func caskIndexMapsAppBundleNames() throws {
    let json = #"""
    [{"token":"anki","desc":"Memory training application","homepage":"https://apps.ankiweb.net/",
      "artifacts":[{"app":["Anki.app"]},{"zap":[{"trash":["~/x"]}]}]},
     {"token":"foo","desc":null,"homepage":"https://foo.example","artifacts":[{"app":[{"target":"Foo Pro.app"}]}]}]
    """#
    let casks = try JSONDecoder().decode([AppInfoService.Cask].self, from: Data(json.utf8))
    let index = AppInfoService.index(casks)
    #expect(index["anki.app"]?.desc == "Memory training application")
    #expect(index["foo pro.app"]?.token == "foo")
}

@Test func signerNameIsReadFromSystemApp() {
    #expect(AppInfoLocal.signer("/System/Applications/Calculator.app") == "Apple")
}

/// Records which paths were handed to the privileged route.
final class FallbackSpy: @unchecked Sendable {
    let lock = NSLock()
    var paths: [String] = []
}

@Test func readOnlyAppGoesThroughPrivilegedTrash() throws {
    let h = try FakeHome()
    let app = try fakeApp(h, name: "Locked", id: "com.locked.app")
    let fm = FileManager.default
    try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: app.path)
    #expect(!AppCatalog.canMove(app.path))

    let spy = FallbackSpy()
    let report = Uninstaller.run(
        [UninstallPlan(app: app, leftovers: [])], home: h.path, log: OperationLog(home: h.path),
        privilegedTrash: { path in
            spy.lock.withLock { spy.paths.append(path) }
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
            try? FileManager.default.removeItem(atPath: path)
            return nil
        })
    #expect(spy.paths == [app.path])
    #expect(report.removedApps == ["Locked"])
    #expect(report.failures.isEmpty)
}

@Test func failedPrivilegedTrashKeepsLeftovers() throws {
    let h = try FakeHome()
    let app = try fakeApp(h, name: "Locked2", id: "com.locked.two")
    try h.file("Library/Caches/com.locked.two/c")
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: app.path)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: app.path) }
    let leftover = Leftover(path: h.path + "/Library/Caches/com.locked.two", kind: .disposable, bytes: 1)
    let report = Uninstaller.run(
        [UninstallPlan(app: app, leftovers: [leftover])], home: h.path, log: OperationLog(home: h.path),
        privilegedTrash: { _ in "Abgebrochen" })
    #expect(report.removedApps.isEmpty)
    #expect(report.failures.first?.reason == "Abgebrochen")
    #expect(h.exists("Library/Caches/com.locked.two/c"))
}

@Test func systemPathsStayInsideKnownLibraryFolders() {
    #expect(LeftoverFinder.isSafeSystemPath("/Library/Application Support/Foo"))
    #expect(LeftoverFinder.isSafeSystemPath("/Library/LaunchDaemons/com.foo.helper.plist"))
    #expect(!LeftoverFinder.isSafeSystemPath("/Library/Application Support/"))
    #expect(!LeftoverFinder.isSafeSystemPath("/Library/Application Support/../Keychains"))
    #expect(!LeftoverFinder.isSafeSystemPath("/Library/LaunchDaemons/com.apple.foo.plist"))
    #expect(!LeftoverFinder.isSafeSystemPath("/System/Library/Foo"))
    #expect(!LeftoverFinder.isSafeSystemPath("/Library/Application Support/Apple"))
}

@Test func iPhoneAppsOnTheMacAreListed() throws {
    let h = try FakeHome()
    let app = h.path + "/Applications/Solar.app"
    try h.file("Applications/Solar.app/Wrapper/Inner.app/Inner")
    let info: [String: Any] = ["CFBundleIdentifier": "com.example.solar", "CFBundleShortVersionString": "2.1", "CFBundleDisplayName": "Solar"]
    try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        .write(to: URL(fileURLWithPath: app + "/Wrapper/Inner.app/Info.plist"))
    try Data().write(to: URL(fileURLWithPath: app + "/Wrapper/iTunesMetadata.plist"))
    let p = try RuleStore.protection()
    let found = try #require(AppCatalog.describe(app, protection: p, ownBundleID: nil))
    #expect(found.bundleID == "com.example.solar" && found.version == "2.1")
    #expect(found.isIOSApp && found.fromAppStore)
    #expect(found.name == "Solar")
}

@Test func uuidContainersOfIPhoneAppsAreFoundByTheirMetadata() throws {
    let h = try FakeHome()
    let uuid = "9A6B620E-B924-4131-B85A-CE410D3445DA"
    try h.file("Library/Containers/\(uuid)/Data/x")
    try h.file("Library/Containers/0B1C2D3E-0000-1111-2222-333344445555/Data/y")
    let meta: [String: Any] = ["MCMMetadataIdentifier": "com.example.solar"]
    try PropertyListSerialization.data(fromPropertyList: meta, format: .xml, options: 0)
        .write(to: URL(fileURLWithPath: h.path + "/Library/Containers/\(uuid)/.com.apple.containermanagerd.metadata.plist"))
    #expect(LeftoverFinder.containers(owning: "com.example.solar", in: h.path + "/Library/Containers")
        == [h.path + "/Library/Containers/\(uuid)"])
}

@Test func webAppsAndAppStoreAppsByAppleAreNotSystemComponents() throws {
    let p = try RuleStore.protection()
    func reason(_ id: String, store: Bool = false) -> String? {
        AppCatalog.protectionReason(bundleID: id, name: "x", protection: p, ownBundleID: nil, fromAppStore: store)
    }
    #expect(reason("com.apple.Safari.WebApp.67EF00DD-528F-49C8-B96A-0D3D092DCE2C") == nil)
    #expect(reason("com.apple.pixelmator") == nil)
    #expect(reason("com.apple.FinalCut", store: true) == nil)
    #expect(reason("com.apple.Safari") != nil)
}

/// Apps the user may not move (owned by root) go to the Trash in one administrator step for the whole run.
@Test func lockedAppsShareOneAdministratorStep() throws {
    let h = try FakeHome()
    try h.file(".Trash/.keep")
    let a = try fakeApp(h, name: "Alpha", id: "com.acme.alpha")
    let b = try fakeApp(h, name: "Beta", id: "com.acme.beta")
    // Without write permission on the bundle a normal user cannot move it, like a root-owned app.
    for app in [a, b] { chmod(app.path, 0o555) }
    final class Calls: @unchecked Sendable { var count = 0 }
    let calls = Calls()
    let report = Uninstaller.run(
        [UninstallPlan(app: a, leftovers: []), UninstallPlan(app: b, leftovers: [])], home: h.path,
        log: OperationLog(home: h.path),
        privilegedTrash: { _ in Issue.record("no per-item prompt expected"); return "x" },
        runPrivileged: { ops in
            calls.count += 1
            // Stand-in for root: make the bundles movable, then carry out the operations.
            for app in [a, b] { chmod(app.path, 0o755) }
            return rootAsUser(home: h.path)(ops)
        })
    #expect(calls.count == 1)
    #expect(report.failures.isEmpty)
    #expect(Set(report.removedApps) == ["Alpha", "Beta"])
    #expect(h.exists(".Trash/Alpha.app") && h.exists(".Trash/Beta.app"))
}

@Test func vendorUninstallerNamesMatchWholeWordsOnly() throws {
    let p = try RuleStore.protection()
    func reason(_ name: String, _ id: String = "com.example.x") -> String? {
        AppCatalog.protectionReason(bundleID: id, name: name, protection: p, ownBundleID: nil)
    }
    #expect(reason("Reset Tool") == nil)
    #expect(reason("Falcon Pro") == nil)
    #expect(reason("ESET Endpoint Security") != nil)
    #expect(reason("Agent", "com.crowdstrike.falcon.App") != nil)
}

@Test func runningOwnerIsFoundInVendorFolders() {
    let owners = CleanScanner.owners(of: "/Users/x/Library/Application Support/BraveSoftware/Brave-Browser-Beta/Default/Cache", home: "/Users/x")
    #expect(owners.contains("Brave Browser Beta"))
}

@Test func resetRemovesDataButKeepsTheApp() throws {
    let h = try FakeHome()
    try h.file(".Trash/.keep")
    let app = try fakeApp(h, name: "Notes Pro", id: "com.acme.notes")
    try h.file("Library/Preferences/com.acme.notes.plist")
    let leftovers = LeftoverFinder.find(for: app, otherApps: [], home: h.path)
    let report = Uninstaller.run([UninstallPlan(app: app, leftovers: leftovers)], home: h.path,
                                 log: OperationLog(home: h.path), keepApps: true)
    #expect(report.dataOnly && report.failures.isEmpty)
    #expect(h.exists("Applications/Notes Pro.app"))
    #expect(!h.exists("Library/Preferences/com.acme.notes.plist"))
}

@Test func systemExtensionsOfRemovedAppsAreFound() {
    let text = """
    --- com.apple.system_extension.network_extension
    enabled\tactive\tteamID\tbundleID (version)\tname\t[state]
    *\t*\tW5364U7YZB\tio.tailscale.ipn.macsys.network-extension (1.96.5/101.96.5)\tTailscale Network Extension\t[activated enabled]
    \t*\t52444FG85C\tcom.silabs.cp210x (6.0.2/1)\tcom.silabs.cp210x\t[terminated waiting to uninstall on reboot]
    """
    let entries = SystemExtensions.parse(text)
    #expect(entries.count == 2)
    #expect(SystemExtensions.stillActive(for: ["io.tailscale.ipn.macsys"], in: entries).map(\.name) == ["Tailscale Network Extension"])
    #expect(SystemExtensions.stillActive(for: ["com.silabs.CP210xVCPDriver"], in: entries).isEmpty)
}
