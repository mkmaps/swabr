import Foundation
import Testing
@testable import SwabrCore

/// A throwaway home directory with a few fake caches.
struct FakeHome {
    let path: String

    init() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "swabr-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        // Physical path (/private/var, not /var), as the root script compares each parent with `pwd -P`.
        guard let real = realpath(dir, nil) else { throw CocoaError(.fileNoSuchFile) }
        defer { free(real) }
        path = String(cString: real)
    }

    func file(_ rel: String, bytes: Int = 4096) throws {
        let url = URL(fileURLWithPath: path).appending(path: rel)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 1, count: bytes).write(to: url)
    }

    func exists(_ rel: String) -> Bool { FileManager.default.fileExists(atPath: path + "/" + rel) }
}

func whitelist(_ home: FakeHome, _ user: [String] = [], safety: [String] = []) -> Whitelist {
    Whitelist(home: home.path, userPatterns: user, safetyPatterns: safety)
}

@Test func bundledRulesLoad() throws {
    let rules = try RuleStore.cleanRules()
    #expect(rules.count > 40)
    #expect(Set(rules.map(\.section)).isSubset(of: Set(RuleStore.sectionOrder)))
    let protection = try RuleStore.protection()
    #expect(!protection.safetyWhitelist.isEmpty)
}

@Test func globSkipsDotfilesLikeBash() throws {
    let h = try FakeHome()
    try h.file("Library/Caches/a/x")
    try h.file("Library/Caches/.hidden")
    let found = PathGlob.expand("~/Library/Caches/*", home: h.path)
    #expect(found == [h.path + "/Library/Caches/a"])
}

@Test func firstRuleClaimsPath() async throws {
    let h = try FakeHome()
    try h.file("Library/Caches/Google/Chrome/Default/data")
    let rules = [
        CleanRule(section: "app_caches", label: "App-Caches", kind: .cache, paths: ["~/Library/Caches/*"]),
        CleanRule(section: "browsers", label: "Google Chrome", kind: .cache, paths: ["~/Library/Caches/Google/Chrome/*"]),
    ]
    let items = await CleanScanner(rules: rules, whitelist: whitelist(h), home: h.path).scan()
    #expect(items.map(\.label) == ["App-Caches"])
    #expect(items[0].bytes >= 4096)
}

@Test func whitelistProtectsMatchParentAndAncestor() throws {
    let h = try FakeHome()
    let w = whitelist(h, ["~/Library/Caches/com.apple.mail/*", "~/Library/Caches/Google/Chrome/*"])
    #expect(w.protectingPattern(for: h.path + "/Library/Caches/com.apple.mail/x") != nil)
    #expect(w.protectingPattern(for: h.path + "/Library/Caches/com.apple.mail") != nil)
    #expect(w.protectingPattern(for: h.path + "/Library/Caches/Google") != nil)
    #expect(w.protectingPattern(for: h.path + "/Library/Caches/Other") == nil)
}

@Test func safetyRefusesDangerousPaths() throws {
    let h = try FakeHome()
    try h.file("Library/Caches/x")
    #expect(PathSafety.check("/etc/hosts", home: h.path) != .ok)
    #expect(PathSafety.check(h.path + "/Library", home: h.path) != .ok)
    #expect(PathSafety.check(h.path + "/Library/Caches/../Keychains", home: h.path) != .ok)
    #expect(PathSafety.check(h.path + "/Library/Mobile Documents/x", home: h.path) != .ok)
    #expect(PathSafety.check(h.path + "/Library/Caches/x", home: h.path) == .ok)
}

@Test func symlinkedAncestorIsRefused() throws {
    let h = try FakeHome()
    try h.file("Documents/precious")
    try FileManager.default.createDirectory(atPath: h.path + "/Library", withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(atPath: h.path + "/Library/Caches", withDestinationPath: h.path + "/Documents")
    #expect(PathSafety.check(h.path + "/Library/Caches/precious", home: h.path) != .ok)
}

@Test func runningAppSkipsRule() async throws {
    let h = try FakeHome()
    try h.file("Library/Application Support/Slack/Cache/a")
    let rules = [CleanRule(section: "apps", label: "Slack", kind: .cache,
                           paths: ["~/Library/Application Support/Slack/Cache/*"], skipIfRunning: "Slack")]
    let items = await CleanScanner(rules: rules, whitelist: whitelist(h), home: h.path, isAppRunning: { $0 == "Slack" }).scan()
    #expect(items.first?.status == .skipped(L("\("Slack") läuft")))
    #expect(items.first?.isCleanable == false)
}

@Test func cleanerRemovesOnlyScannedAndLogs() async throws {
    let h = try FakeHome()
    try h.file("Library/Caches/app/a")
    try h.file("Library/Logs/DiagnosticReports/crash.ips")
    try h.file("Library/Logs/old.log")
    let rules = [
        CleanRule(section: "app_caches", label: "App-Caches", kind: .cache, paths: ["~/Library/Caches/*"]),
        CleanRule(section: "app_caches", label: "App-Protokolle", kind: .cache,
                  paths: ["~/Library/Logs/*", "~/Library/Logs/DiagnosticReports/*"],
                  keep: ["~/Library/Logs/DiagnosticReports"]),
    ]
    let w = whitelist(h)
    let items = await CleanScanner(rules: rules, whitelist: w, home: h.path).scan()
    let log = OperationLog(home: h.path)
    let report = await Cleaner(home: h.path, whitelist: w, mode: .permanent, log: log).clean(items)
    #expect(report.removedCount == 3)
    #expect(report.failures.isEmpty)
    #expect(!h.exists("Library/Caches/app"))
    #expect(h.exists("Library/Logs/DiagnosticReports"))
    #expect(!h.exists("Library/Logs/DiagnosticReports/crash.ips"))
    let logText = try String(contentsOf: log.url, encoding: .utf8)
    #expect(logText.split(separator: "\n").count == 3)
}

@Test func cleanerHonoursWhitelistAddedAfterScan() async throws {
    let h = try FakeHome()
    try h.file("Library/Caches/keepme/a")
    let rules = [CleanRule(section: "app_caches", label: "App-Caches", kind: .cache, paths: ["~/Library/Caches/*"])]
    let items = await CleanScanner(rules: rules, whitelist: whitelist(h), home: h.path).scan()
    let later = whitelist(h, ["~/Library/Caches/keepme"])
    let report = await Cleaner(home: h.path, whitelist: later, mode: .permanent, log: OperationLog(home: h.path)).clean(items)
    #expect(report.removedCount == 0)
    #expect(h.exists("Library/Caches/keepme/a"))
}

@Test func userWhitelistFileReplacesDefaults() throws {
    let h = try FakeHome()
    let p = ProtectionData(defaultWhitelist: ["~/.gradle/caches/*"], safetyWhitelist: ["~/Library/Caches/CloudKit*"],
                           systemCriticalBundles: [], sensitiveBundles: [], whitelistOptions: [])
    #expect(try Whitelist.load(home: h.path, protection: p).userPatterns == ["~/.gradle/caches/*"])
    var w = try Whitelist.load(home: h.path, protection: p)
    w.setProtected("~/.gradle/caches/*", false)
    w.setProtected("$HOME/x", true)
    try w.save()
    let reloaded = try Whitelist.load(home: h.path, protection: p)
    #expect(reloaded.userPatterns == ["~/x"])
    #expect(reloaded.protectingPattern(for: h.path + "/Library/Caches/CloudKit") != nil)
}

@Test func historyGroupsNearbyEntriesIntoRuns() {
    let text = """
    2026-10-25T08:00:00Z\tREMOVE\t100\tApp-Caches\t/Users/x/Library/Caches/a
    2026-10-25T08:02:00Z\tTRASH\t50\tOptimieren: defekte Einstellung\t/Users/x/Library/Preferences/b.plist
    broken line
    2026-10-25T09:30:00Z\tREBUILT\t7\tVerschlanken: Intel-Code entfernt\t/Applications/X.app
    """
    let entries = History.parse(text)
    #expect(entries.count == 3)
    let runs = History.sessions(entries)
    #expect(runs.count == 2)
    #expect(runs[0].entries.map(\.action) == ["REBUILT"])
    #expect(runs[1].bytes == 150)
    #expect(runs[1].modules == [L("Aufräumen"), L("Optimieren")])
}

@Test func orphanedLogsOfRemovedAppsAreFoundButProtectedOnesKept() throws {
    let h = try FakeHome()
    try h.file("Library/Logs/com.gone.app/old.log")
    try h.file("Library/Logs/com.installed.app/x.log")
    try h.file("Library/Logs/com.agilebits.1password7/x.log")
    try h.file("Library/Logs/com.gone.fresh/new.log")
    try h.file("Library/Saved Application State/com.gone.app.savedState/w")
    let old = Date().addingTimeInterval(-60 * 86_400)
    for rel in ["Library/Logs/com.gone.app", "Library/Logs/com.installed.app", "Library/Logs/com.agilebits.1password7",
                "Library/Saved Application State/com.gone.app.savedState"] {
        try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: h.path + "/" + rel)
    }
    let p = try RuleStore.protection()
    let rules = DynamicRules.orphans(home: h.path, installed: ["com.installed.app"], protection: p)
    let paths = Set(rules.flatMap(\.paths).map { String($0.dropFirst(h.path.count + 1)) })
    #expect(paths == ["Library/Logs/com.gone.app", "Library/Saved Application State/com.gone.app.savedState"])
    #expect(rules.allSatisfy { $0.section == DynamicRules.orphanSection })
}

@Test func toolCacheRulesStayInHome() throws {
    let h = try FakeHome()
    let rules = DynamicRules.toolCaches(home: h.path, environment: [:], npmCache: { _, _ in nil })
    #expect(rules.contains { $0.label == "uv" })
    #expect(rules.allSatisfy { $0.paths.allSatisfy { $0.hasPrefix(h.path + "/") } })
}

@Test func broadRulesLeaveSpecificContentAndExcludedPathsAlone() async throws {
    let h = try FakeHome()
    try h.file("Library/Caches/Google/Chrome/a")
    try h.file("Library/Caches/com.example.app/b")
    try h.file("Library/Caches/com.apple.Music/c")
    let rules = [
        CleanRule(section: "browsers", label: "Google Chrome", kind: .browserCache, paths: ["~/Library/Caches/Google/Chrome/*"],
                  skipIfRunning: "Google Chrome"),
        CleanRule(section: "app_caches", label: "App-Caches", kind: .cache, paths: ["~/Library/Caches/*/*"],
                  exclude: ["~/Library/Caches/com.apple.*"]),
    ]
    // Chrome runs: its rule is skipped, and the broad rule must not take Chrome's cache instead.
    let items = await CleanScanner(rules: rules, whitelist: whitelist(h), home: h.path,
                                   isAppRunning: { $0 == "Google Chrome" }).scan()
    let broad = try #require(items.first { $0.label == "App-Caches" })
    #expect(broad.paths == [h.path + "/Library/Caches/com.example.app/b"])
    #expect(items.first { $0.label == "Google Chrome" }?.status == .skipped(L("\("Google Chrome") läuft")))
}

@Test func broadRulesSkipRunningOwnersAndNonChromiumFolders() async throws {
    let h = try FakeHome()
    try h.file("Library/Application Support/Chat/Code Cache/x")
    try h.file("Library/Application Support/Chat/Cache/y")
    try h.file("Library/Application Support/Editor/Code Cache/x")
    try h.file("Library/Application Support/Notes/Cache/precious")
    let rules = [CleanRule(section: "app_caches", label: "Chromium", kind: .cache,
                           paths: ["~/Library/Application Support/*/{Code Cache,Cache}"],
                           skipRunningOwner: true, chromiumOnly: true)]
    let items = await CleanScanner(rules: rules, whitelist: whitelist(h), home: h.path, isAppRunning: { $0 == "Editor" }).scan()
    let item = try #require(items.first)
    // Notes has no Chromium folders, so its "Cache" is app content; Editor is running.
    #expect(Set(item.paths) == [h.path + "/Library/Application Support/Chat/Code Cache",
                                h.path + "/Library/Application Support/Chat/Cache"])
    #expect(item.protected.map(\.path) == [h.path + "/Library/Application Support/Editor/Code Cache"])
}

@Test func onlyAerialsNoWallpaperUsesAreOffered() throws {
    let h = try FakeHome()
    let base = "Library/Application Support/com.apple.wallpaper"
    try h.file("\(base)/aerials/videos/AAAA-1111.mov")
    try h.file("\(base)/aerials/videos/BBBB-2222.mov")
    try h.file("\(base)/Store/.keep")
    // The chosen aerial sits in a nested property list, as macOS stores it.
    let nested = try PropertyListSerialization.data(fromPropertyList: ["assetID": "BBBB-2222"], format: .binary, options: 0)
    let store: [String: Any] = ["AllSpacesAndDisplays": ["Content": ["Choices": [["Configuration": nested, "Provider": "com.apple.wallpaper.choice.aerials"]]]]]
    try PropertyListSerialization.data(fromPropertyList: store, format: .binary, options: 0)
        .write(to: URL(fileURLWithPath: h.path + "/\(base)/Store/Index.plist"))
    let rules = DynamicRules.unusedAerials(home: h.path)
    #expect(rules.flatMap(\.paths) == [h.path + "/\(base)/aerials/videos/AAAA-1111.mov"])
}

@Test func olderJetBrainsVersionsAreOfferedTheNewestStays() throws {
    let h = try FakeHome()
    for v in ["IntelliJIdea2024.3", "IntelliJIdea2025.2", "PyCharm2025.1"] { try h.file("Library/Application Support/JetBrains/\(v)/options.xml") }
    let paths = DynamicRules.oldJetBrains(home: h.path).flatMap(\.paths)
    #expect(paths == [h.path + "/Library/Application Support/JetBrains/IntelliJIdea2024.3"])
}

@Test func minimumAgeKeepsFreshFiles() async throws {
    let h = try FakeHome()
    try h.file(".claude/shell-snapshots/new.sh")
    try h.file(".claude/shell-snapshots/old.sh")
    try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-10 * 86_400)],
                                          ofItemAtPath: h.path + "/.claude/shell-snapshots/old.sh")
    let rule = CleanRule(section: "developer", label: "Claude Code", kind: .temp, paths: ["~/.claude/shell-snapshots/*"], minAgeDays: 7)
    let items = await CleanScanner(rules: [rule], whitelist: whitelist(h), home: h.path).scan()
    #expect(items.first?.paths == [h.path + "/.claude/shell-snapshots/old.sh"])
}
