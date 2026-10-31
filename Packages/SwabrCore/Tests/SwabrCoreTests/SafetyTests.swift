import Foundation
import Testing
@testable import SwabrCore

// MARK: M-01 control characters

@Test func pathsWithControlCharactersAreRefused() throws {
    let h = try FakeHome()
    for bad in ["Library/Caches/a\nb", "Library/Caches/a\u{0}b", "Library/Caches/a\u{1B}[2Jb", "Library/Caches/a\u{7F}"] {
        #expect(PathSafety.check(h.path + "/" + bad, home: h.path) != .ok, "\(bad.debugDescription)")
        #expect(AnalyzeTrash.refusal(for: h.path + "/" + bad, home: h.path) != nil)
    }
    #expect(!LeftoverFinder.isSafeSystemPath("/Library/Caches/com.acme\n/etc"))
    #expect(LeftoverFinder.isSafeSystemPath("/Library/Caches/com.acme.app"))
    try h.file("Library/Caches/ok/a")
    #expect(PathSafety.check(h.path + "/Library/Caches/ok", home: h.path) == .ok)
}

// MARK: M-02 apps started after the scan

/// A running-app answer that can change between scan and clean.
final class RunningSwitch: @unchecked Sendable {
    private let lock = NSLock()
    private var names: Set<String> = []
    func start(_ name: String) { lock.withLock { _ = names.insert(name) } }
    func isRunning(_ name: String) -> Bool { lock.withLock { names.contains(name) } }
}

@Test func cleanerSkipsAppStartedAfterScan() async throws {
    let h = try FakeHome()
    try h.file("Library/Application Support/Slack/Cache/a")
    let rules = [CleanRule(section: "apps", label: "Slack", kind: .cache,
                           paths: ["~/Library/Application Support/Slack/Cache/*"], skipIfRunning: "Slack")]
    let running = RunningSwitch()
    let items = await CleanScanner(rules: rules, whitelist: whitelist(h), home: h.path, isAppRunning: running.isRunning).scan()
    #expect(items.first?.isCleanable == true)

    running.start("Slack")
    let report = await Cleaner(home: h.path, whitelist: whitelist(h), mode: .permanent, log: OperationLog(home: h.path),
                               isAppRunning: running.isRunning).clean(items)
    #expect(report.removedCount == 0)
    #expect(report.failures.count == 1)
    #expect(h.exists("Library/Application Support/Slack/Cache/a"))
}

@Test func cleanerSkipsOwnerStartedAfterScan() async throws {
    let h = try FakeHome()
    try h.file("Library/Caches/com.acme.busy/a")
    try h.file("Library/Caches/com.acme.idle/a")
    let rules = [CleanRule(section: "app_caches", label: "App-Caches", kind: .cache, paths: ["~/Library/Caches/*/*"],
                           skipRunningOwner: true)]
    let running = RunningSwitch()
    let items = await CleanScanner(rules: rules, whitelist: whitelist(h), home: h.path, isAppRunning: running.isRunning).scan()
    #expect(items.first?.paths.count == 2)

    running.start("com.acme.busy")
    let report = await Cleaner(home: h.path, whitelist: whitelist(h), mode: .permanent, log: OperationLog(home: h.path),
                               isAppRunning: running.isRunning).clean(items)
    #expect(report.removedCount == 1)
    #expect(h.exists("Library/Caches/com.acme.busy/a"))
    #expect(!h.exists("Library/Caches/com.acme.idle/a"))
}

@Test func mergedItemKeepsRunningConditionsOfAllRules() async throws {
    let h = try FakeHome()
    try h.file("Library/Caches/plain/a")
    try h.file("Library/Caches/com.acme.app/a")
    let rules = [
        CleanRule(section: "app_caches", label: "App-Caches", kind: .cache, paths: ["~/Library/Caches/plain/*"]),
        CleanRule(section: "app_caches", label: "App-Caches", kind: .cache, paths: ["~/Library/Caches/com.acme.app/*"],
                  skipIfRunning: "Acme", skipRunningOwner: true),
    ]
    let items = await CleanScanner(rules: rules, whitelist: whitelist(h), home: h.path).scan()
    #expect(items.count == 1)
    #expect(items.first?.skipIfRunning == "Acme")
    #expect(items.first?.skipRunningOwner == true)
}

// MARK: M-05 root script

/// Runs the guarded move as the current user with test roots; returns the shell's exit status.
@discardableResult
func guardedMove(_ src: String, to dst: String, roots: [String]) -> Int32 {
    let script = RootScript.prelude(roots: roots) + "\n" + RootScript.move(src, to: dst)
    return Shell.run("/bin/sh", ["-c", script], timeout: 10).status
}

@Test func rootScriptMovesOnlyCheckedPaths() throws {
    let h = try FakeHome()
    let root = h.path + "/Library/Caches/"
    let trash = h.path + "/.Trash"
    try FileManager.default.createDirectory(atPath: trash, withIntermediateDirectories: true)

    // Allowed: below a root, real parent, free target.
    try h.file("Library/Caches/com.acme.app/a")
    #expect(guardedMove(root + "com.acme.app", to: trash + "/com.acme.app 1", roots: [root]) == 0)
    #expect(!h.exists("Library/Caches/com.acme.app"))
    #expect(h.exists(".Trash/com.acme.app 1/a"))

    // Outside every root.
    try h.file("Documents/keep/a")
    #expect(guardedMove(h.path + "/Documents/keep", to: trash + "/keep", roots: [root]) != 0)
    #expect(h.exists("Documents/keep/a"))

    // Parent swapped for a link after the scan: the move would land on another folder's item.
    try h.file("Documents/target/victim")
    try FileManager.default.createSymbolicLink(atPath: root + "Vendor", withDestinationPath: h.path + "/Documents/target")
    #expect(guardedMove(root + "Vendor/victim", to: trash + "/victim", roots: [root]) != 0)
    #expect(h.exists("Documents/target/victim"))

    // The item itself is a link.
    try FileManager.default.createSymbolicLink(atPath: root + "link", withDestinationPath: h.path + "/Documents/target")
    #expect(guardedMove(root + "link", to: trash + "/link", roots: [root]) != 0)

    // Traversal, Apple items and an occupied target.
    #expect(guardedMove(root + "../../Documents/keep", to: trash + "/x", roots: [root]) != 0)
    try h.file("Library/Caches/com.apple.thing/a")
    #expect(guardedMove(root + "com.apple.thing", to: trash + "/t", roots: [root]) != 0)
    try h.file("Library/Caches/com.acme.two/a")
    #expect(guardedMove(root + "com.acme.two", to: trash + "/com.acme.app 1", roots: [root]) != 0)
    #expect(h.exists("Library/Caches/com.acme.two/a"))

    // The root itself is never moved.
    #expect(guardedMove(String(root.dropLast()), to: trash + "/Caches", roots: [root]) != 0)
}

@Test func rootScriptQuotesAwkwardNames() throws {
    let h = try FakeHome()
    let root = h.path + "/Library/Caches/"
    try FileManager.default.createDirectory(atPath: h.path + "/.Trash", withIntermediateDirectories: true)
    let name = "it's $(touch pwned) `x` \"q\""
    try h.file("Library/Caches/\(name)/a")
    #expect(guardedMove(root + name, to: h.path + "/.Trash/moved", roots: [root]) == 0)
    #expect(h.exists(".Trash/moved/a"))
    #expect(!FileManager.default.fileExists(atPath: "pwned"))
}

// MARK: M-06 evidence

@Test func nameOnlyLeftoversAreNotPreselected() throws {
    let h = try FakeHome()
    let app = try fakeApp(h, name: "Tidewell Notes", id: "com.acme.tidewell")
    try h.file("Library/Caches/com.acme.tidewell/a")    // bundle id
    try h.file("Library/Caches/Tidewell Notes/a")      // name only: another app may use it
    try h.file("Library/Caches/TidewellNotes/a")
    let found = Dictionary(uniqueKeysWithValues: LeftoverFinder.find(for: app, otherApps: [app], home: h.path)
        .map { ($0.path.replacingOccurrences(of: h.path + "/", with: ""), $0) })
    #expect(found["Library/Caches/com.acme.tidewell"]?.evidence == .identity)
    #expect(found["Library/Caches/com.acme.tidewell"]?.preselected == true)
    #expect(found["Library/Caches/Tidewell Notes"]?.evidence == .nameOnly)
    #expect(found["Library/Caches/Tidewell Notes"]?.preselected == false)
    #expect(found["Library/Caches/TidewellNotes"]?.preselected == false)
}

@Test func vendorNestedCountsAsIdentity() throws {
    let h = try FakeHome()
    let app = try fakeApp(h, name: "Google Chrome", id: "com.google.Chrome")
    try h.file("Library/Caches/Google/Chrome/Default/Cache/x")
    let cache = LeftoverFinder.find(for: app, otherApps: [app], home: h.path)
        .first { $0.path.hasSuffix("Library/Caches/Google/Chrome") }
    #expect(cache?.evidence == .identity)
    #expect(cache?.preselected == true)
}

// MARK: M-06b installer receipts

@Test func receiptOutputIsParsed() {
    let info = """
    volume: /
    path: /Library/Application Support/Blackmagic Design

    pkgid: com.blackmagic-design.DaVinciPanels
    pkg-version:
    pkgid: com.blackmagic-design.FairlightDriver
    """
    #expect(PackageReceipts.pkgIDs(inFileInfo: info) == ["com.blackmagic-design.DaVinciPanels", "com.blackmagic-design.FairlightDriver"])
    #expect(PackageReceipts.field("location", in: "volume: /\nlocation: Applications\n") == "Applications")
    #expect(PackageReceipts.absolute(location: "/", file: "Library/Extensions/X.kext") == "/Library/Extensions/X.kext")
    #expect(PackageReceipts.absolute(location: "Applications", file: "X.app") == "/Applications/X.app")
    let files = ["/Applications/X.app", "/Library/Application Support/Vendor", "/Library/Application Support/Vendor/X/a",
                 "/Library/LaunchDaemons/com.vendor.x.plist", "/Library/Application Support"]
    #expect(PackageReceipts.children(of: files, depth: 1) == ["/Library/Application Support/Vendor", "/Library/LaunchDaemons/com.vendor.x.plist"])
    #expect(PackageReceipts.children(of: files, depth: 2) == ["/Library/Application Support/Vendor/X"])
}

@Test func appleAppsHaveNoReceiptLeftovers() {
    let app = InstalledApp(name: "Calculator", path: "/System/Applications/Calculator.app", bundleID: "com.apple.calculator",
                           version: nil, bytes: 0, lastUsed: nil, fromAppStore: false, protection: nil)
    #expect(PackageReceipts.systemPaths(for: app).isEmpty)
}

// MARK: M-03/M-04 never clean

@Test func protectionPatternsCoverItemsOwnersAndNames() async throws {
    let h = try FakeHome()
    try h.file("Library/Application Support/Slack/Cache/a")
    try h.file("Library/Application Support/Slack/Code Cache/b")
    try h.file("Library/Caches/com.acme.app/data/x")
    let rules = [CleanRule(section: "apps", label: "Slack", kind: .cache,
                           paths: ["~/Library/Application Support/Slack/{Cache,Code Cache}/*"]),
                 CleanRule(section: "app_caches", label: "App-Caches", kind: .cache, paths: ["~/Library/Caches/*/*"])]
    let items = await CleanScanner(rules: rules, whitelist: whitelist(h), home: h.path).scan()
    let slack = try #require(items.first { $0.label == "Slack" })
    // Braces are expanded: the whitelist matches with fnmatch.
    #expect(ProtectionPattern.forItem(slack, home: h.path)
            == ["~/Library/Application Support/Slack/Cache/*", "~/Library/Application Support/Slack/Code Cache/*"])

    // Item-level protection also covers matches that appear later.
    let w = whitelist(h, ProtectionPattern.forItem(slack, home: h.path))
    try h.file("Library/Application Support/Slack/Cache/new")
    let again = await CleanScanner(rules: rules, whitelist: w, home: h.path).scan()
    #expect(again.first { $0.label == "Slack" }?.paths.isEmpty == true)

    let cachePath = h.path + "/Library/Caches/com.acme.app/data"
    #expect(ProtectionPattern.forOwner(of: cachePath, home: h.path)?.pattern == "~/Library/Caches/com.acme.app/*")
    #expect(ProtectionPattern.forOwner(of: h.path + "/Library/Caches/com.acme.app", home: h.path) == nil)
    let name = try #require(ProtectionPattern.forName(of: cachePath))
    #expect(name.pattern == "*/data/*")
    let byName = whitelist(h, [name.pattern])
    #expect(byName.protectingPattern(for: cachePath) != nil)
    #expect(byName.protectingPattern(for: cachePath + "/x") != nil)
    #expect(byName.protectingPattern(for: h.path + "/Library/Caches/com.acme.app/other") == nil)
}

@Test func applyingWhitelistMovesPathsWithoutRescan() async throws {
    let h = try FakeHome()
    try h.file("Library/Caches/one/a", bytes: 8192)
    try h.file("Library/Caches/two/a", bytes: 8192)
    let rules = [CleanRule(section: "app_caches", label: "App-Caches", kind: .cache, paths: ["~/Library/Caches/*"])]
    let item = try #require(await CleanScanner(rules: rules, whitelist: whitelist(h), home: h.path).scan().first)
    let after = item.applying(whitelist(h, ["~/Library/Caches/one"]))
    #expect(after.paths == [h.path + "/Library/Caches/two"])
    #expect(after.protected.map(\.kind) == [.whitelist])
    #expect(after.bytes < item.bytes)
}

@Test func braceExpansionHandlesNesting() {
    #expect(PathGlob.expandBraces("a/{b,c}/d") == ["a/b/d", "a/c/d"])
    #expect(PathGlob.expandBraces("x/{a,b{1,2}}/*") == ["x/a/*", "x/b1/*", "x/b2/*"])
    #expect(PathGlob.expandBraces("plain/*") == ["plain/*"])
}

// MARK: M-09 result kinds

@Test func permissionErrorsAreTold() {
    let denied = ProtectedPath(path: "/x", error: CocoaError(.fileWriteNoPermission))
    #expect(denied.kind == .permission)
    let other = ProtectedPath(path: "/x", error: CocoaError(.fileWriteOutOfSpace))
    #expect(other.kind == .failed)
}

// MARK: M-10 startup items

@Test func securityAndOwnStartupItemsAreProtected() throws {
    let p = try RuleStore.protection()
    func reason(_ label: String, program: String? = nil) -> String? {
        StartupItems.protectionReason(label: label, path: "/Users/x/Library/LaunchAgents/\(label).plist", program: program, protection: p)
    }
    #expect(reason("io.github.mkmaps.swabr.helper") != nil)
    #expect(reason("com.crowdstrike.falcon.UserAgent") != nil)
    #expect(reason("com.tailscale.ipn.macsys.login-item-helper") != nil)
    #expect(reason("com.1password.browser-helper") != nil)
    #expect(reason("com.example.resetdns") == nil)       // "eset" only as a whole word
    #expect(reason("com.google.keystone.agent") == nil)

    let item = StartupItem(label: "com.tailscale.ipn", path: "/tmp/x.plist", kind: .userAgent, program: "/bin/sh",
                           appPath: nil, disabled: false, loaded: true, protectedReason: "VPN")
    #expect(!item.canRemove)
    #expect(StartupItems.block(item) == "VPN")
}
