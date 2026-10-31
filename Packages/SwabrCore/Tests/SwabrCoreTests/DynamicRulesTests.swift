import Foundation
import Testing
@testable import SwabrCore

private let day: TimeInterval = 86_400

private func age(_ home: FakeHome, _ rel: String, days: Double) throws {
    try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-days * day)],
                                          ofItemAtPath: home.path + "/" + rel)
}

private func relative(_ paths: [String], _ home: FakeHome) -> Set<String> {
    Set(paths.map { String($0.dropFirst(home.path.count + 1)) })
}

private func writePlist(_ value: Any, to path: String) throws {
    try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0).write(to: URL(fileURLWithPath: path))
}

// MARK: - Tool caches

@Test func toolOutputMustBeOneAbsolutePath() {
    #expect(DynamicRules.singleAbsolutePath("/Users/x/.npm\n") == "/Users/x/.npm")
    #expect(DynamicRules.singleAbsolutePath("  /Users/x/cache/  ") == "/Users/x/cache")
    #expect(DynamicRules.singleAbsolutePath("npm warn something\n/Users/x/.npm") == nil)
    #expect(DynamicRules.singleAbsolutePath("relative/cache") == nil)
    #expect(DynamicRules.singleAbsolutePath("/Users/x/../y") == nil)
    #expect(DynamicRules.singleAbsolutePath("") == nil)
}

@Test func npmCacheFollowsToolOutput() throws {
    let h = try FakeHome()
    func npmPaths(_ output: String?) -> Set<String> {
        let rules = DynamicRules.toolCaches(home: h.path, environment: [:], npmCache: { _, _ in output })
        return relative(rules.filter { $0.label == "npm" || $0.kind == .log }.flatMap(\.paths), h)
    }
    #expect(npmPaths(h.path + "/custom/npm-cache\n") == ["custom/npm-cache/_cacache/*", "custom/npm-cache/_npx/*", "custom/npm-cache/_logs/*"])
    // Several lines or a relative answer: the documented default.
    #expect(npmPaths("warn\n" + h.path + "/custom") == [".npm/_cacache/*", ".npm/_npx/*", ".npm/_logs/*"])
    #expect(npmPaths("custom/npm-cache") == [".npm/_cacache/*", ".npm/_npx/*", ".npm/_logs/*"])
    // Outside the home folder: no npm rules at all.
    let outside = DynamicRules.toolCaches(home: h.path, environment: [:], npmCache: { _, _ in "/opt/npm-cache" })
    #expect(!outside.contains { $0.label == "npm" || $0.kind == .log })
    let logs = try #require(DynamicRules.toolCaches(home: h.path, environment: [:], npmCache: { _, _ in nil }).first { $0.kind == .log })
    #expect(logs.label == L("npm-Protokolle"))
    #expect(logs.section == "developer")
}

@Test func toolCachesHonourEnvironmentAndStayInHome() throws {
    let h = try FakeHome()
    let env = [
        "UV_CACHE_DIR": h.path + "/caches/uv",
        "BUN_INSTALL_CACHE_DIR": "/Volumes/External/bun",   // outside home: dropped
        "COREPACK_HOME": "relative/corepack",               // not absolute: default
        "RUSTUP_HOME": h.path + "/Documents",               // a protected folder: dropped
    ]
    let rules = DynamicRules.toolCaches(home: h.path, environment: env, npmCache: { _, _ in nil })
    let byLabel = Dictionary(uniqueKeysWithValues: rules.map { ($0.label, $0) })
    #expect(byLabel["uv"]?.paths == [h.path + "/caches/uv/*"])
    #expect(byLabel["Bun"] == nil)
    #expect(byLabel["Corepack"]?.paths == [h.path + "/.cache/node/corepack/*"])
    #expect(byLabel["rustup"] == nil)
    let defaults = DynamicRules.toolCaches(home: h.path, environment: [:], npmCache: { _, _ in nil })
    #expect(defaults.first { $0.label == "rustup" }?.paths == [h.path + "/.rustup/downloads/*", h.path + "/.rustup/tmp/*"])
    #expect(defaults.first { $0.label == "Bun" }?.paths == [h.path + "/.bun/install/cache/*"])
    #expect(defaults.allSatisfy { $0.section == "developer" && [.packages, .log].contains($0.kind) })
}

// MARK: - Leftovers

@Test func leftoversOnlyAfterTheirAge() throws {
    let h = try FakeHome()
    try h.file("Library/Caches/com.gone.old/a")
    try h.file("Library/Caches/com.gone.recent/a")
    try h.file("Library/Caches/NoBundleName/a")
    try h.file("Library/Caches/com.vendor.app.ShipIt/a")
    try h.file("Library/Caches/com.elsewhere.app/a")
    try h.file("Library/Logs/com.gone.old/x.log")
    try h.file("Library/Saved Application State/com.gone.old.savedState/w")
    for rel in ["Library/Caches/com.gone.old", "Library/Caches/NoBundleName", "Library/Caches/com.vendor.app.ShipIt",
                "Library/Caches/com.elsewhere.app", "Library/Logs/com.gone.old",
                "Library/Saved Application State/com.gone.old.savedState"] {
        try age(h, rel, days: 45)
    }
    try age(h, "Library/Caches/com.gone.recent", days: 20)
    let rules = DynamicRules.orphans(home: h.path, installed: ["com.vendor.app"], protection: try RuleStore.protection(),
                                     ageDays: 30, isRegistered: { $0 == "com.elsewhere.app" })
    #expect(relative(rules.flatMap(\.paths), h) == ["Library/Caches/com.gone.old", "Library/Logs/com.gone.old",
                                                     "Library/Saved Application State/com.gone.old.savedState"])
    #expect(rules.map(\.label) == [L("Caches entfernter Apps"), L("Logs entfernter Apps"), L("Fensterzustände entfernter Apps")])
    #expect(rules.allSatisfy { $0.effectiveSafety == .review && $0.section == "leftovers" })
    // A shorter age setting also takes the recent one.
    let short = DynamicRules.orphans(home: h.path, installed: [], protection: try RuleStore.protection(),
                                     ageDays: 10, isRegistered: { _ in false })
    #expect(short.flatMap(\.paths).contains(h.path + "/Library/Caches/com.gone.recent"))
}

@Test func appleAndSensitiveIdsAreNeverLeftovers() throws {
    let h = try FakeHome()
    let ids = ["com.apple.Music", "com.apple.Safari", "com.1password.helper", "com.bitwarden.desktop",
               "org.example.Finder", "net.vendor.wallet-sync"]
    for id in ids {
        try h.file("Library/Caches/\(id)/a")
        try age(h, "Library/Caches/\(id)", days: 400)
    }
    let rules = DynamicRules.orphans(home: h.path, installed: [], protection: try RuleStore.protection(),
                                     isRegistered: { _ in false })
    #expect(rules.isEmpty)
    #expect(DynamicRules.isBundleID("com.vendor.app"))
    #expect(!DynamicRules.isBundleID("com.vendor"))
    #expect(!DynamicRules.isBundleID("com..app"))
    #expect(!DynamicRules.isBundleID("com.vendor.app [1]"))
}

// MARK: - Aerials

private let wallpaper = "Library/Application Support/com.apple.wallpaper"

private func aerialHome() throws -> FakeHome {
    let h = try FakeHome()
    try h.file("\(wallpaper)/aerials/videos/AAAA-1111.mov")
    try h.file("\(wallpaper)/aerials/videos/BBBB-2222.mov")
    return h
}

private func store(_ h: FakeHome, choices: [[String: Any]], shuffle: Any = "$null") throws {
    let content: [String: Any] = ["Choices": choices, "Shuffle": shuffle]
    try writePlist(["AllSpacesAndDisplays": ["Linked": ["Content": content]]], to: h.path + "/\(wallpaper)/Store/Index.plist")
}

@Test func aerialsInUseByWallpaperOrScreenSaverStay() throws {
    let h = try aerialHome()
    try store(h, choices: [["Provider": "default", "Files": []]])
    var rules = DynamicRules.unusedAerials(home: h.path)
    #expect(relative(rules.flatMap(\.paths), h) == ["\(wallpaper)/aerials/videos/AAAA-1111.mov", "\(wallpaper)/aerials/videos/BBBB-2222.mov"])
    #expect(rules.first?.kind == .aerials)
    #expect(rules.first?.section == "system")
    #expect(rules.first?.label == L("Luftaufnahmen"))

    // The screen saver shows one of them.
    let nested = try PropertyListSerialization.data(fromPropertyList: ["assetID": "aaaa-1111"], format: .binary, options: 0)
    try writePlist(["moduleDict": ["Configuration": nested]], to: h.path + "/Library/Preferences/ByHost/com.apple.screensaver.ABC.plist")
    rules = DynamicRules.unusedAerials(home: h.path)
    #expect(rules.flatMap(\.paths) == [h.path + "/\(wallpaper)/aerials/videos/BBBB-2222.mov"])
}

@Test func unreadableOrShuffledSettingsOfferNoAerials() throws {
    let h = try aerialHome()
    // No wallpaper store at all.
    #expect(DynamicRules.unusedAerials(home: h.path).isEmpty)
    // Damaged store.
    try h.file("\(wallpaper)/Store/Index.plist", bytes: 64)
    #expect(DynamicRules.unusedAerials(home: h.path).isEmpty)
    // Readable store but a damaged screen saver file.
    try store(h, choices: [["Provider": "default"]])
    #expect(!DynamicRules.unusedAerials(home: h.path).isEmpty)
    try h.file("Library/Preferences/ByHost/com.apple.screensaver.XYZ.plist", bytes: 32)
    #expect(DynamicRules.unusedAerials(home: h.path).isEmpty)
    try FileManager.default.removeItem(atPath: h.path + "/Library/Preferences/ByHost/com.apple.screensaver.XYZ.plist")
    // Shuffled aerials are not listed by id.
    try store(h, choices: [["Provider": "com.apple.wallpaper.choice.aerials"]], shuffle: ["Type": "continuous"])
    #expect(DynamicRules.unusedAerials(home: h.path).isEmpty)
}

// MARK: - JetBrains

@Test func jetBrainsKeepsNewestPerProduct() throws {
    let h = try FakeHome()
    let support = "Library/Application Support/JetBrains"
    for v in ["IntelliJIdea2025.1", "IntelliJIdea2025.2", "IntelliJIdea2025.10", "PyCharm2025.1", "PyCharm2025.2", "Toolbox"] {
        try h.file("\(support)/\(v)/options.xml")
    }
    try h.file("Library/Logs/JetBrains/PyCharm2025.1/idea.log")
    try h.file("Library/Logs/JetBrains/PyCharm2025.2/idea.log")
    let rules = DynamicRules.oldJetBrains(home: h.path)
    #expect(relative(rules.flatMap(\.paths), h) == ["\(support)/IntelliJIdea2025.1", "\(support)/IntelliJIdea2025.2",
                                                     "\(support)/PyCharm2025.1", "Library/Logs/JetBrains/PyCharm2025.1"])
    let rule = try #require(rules.first)
    #expect(rule.kind == .state && rule.effectiveSafety == .review && rule.section == "developer")
    #expect(rule.label == L("Ältere JetBrains-Versionen"))
}

// MARK: - Large data

@Test func largeDataRespectsMinimumAndSortsBySize() async throws {
    let h = try FakeHome()
    try h.file(".m2/repository/lib.jar", bytes: 3_000_000)
    try h.file(".nuget/packages/pkg.nupkg", bytes: 2_000_000)
    try h.file(".ollama/models/small", bytes: 10_000)
    let runtime = DynamicRules.LargeData(label: "Simulator", path: "/Library/Developer/CoreSimulator/Images/x.dmg",
                                         bytes: 5_000_000, hint: "")
    // Some places (/Library/Updates) lie outside the home folder and hold whatever this Mac downloaded.
    let ours = { (list: [DynamicRules.LargeData]) in list.filter { $0.path.hasPrefix(h.path + "/") || $0.path == runtime.path } }
    let found = ours(await DynamicRules.largeData(home: h.path, minimum: 1_000_000, runtimes: { [runtime] }))
    #expect(found.map(\.path) == [runtime.path, h.path + "/.m2/repository", h.path + "/.nuget/packages"])
    #expect(found[1].label == L("Maven-Repository"))
    #expect(found.allSatisfy { $0.bytes >= 1_000_000 })
    let none = ours(await DynamicRules.largeData(home: h.path, minimum: 100_000_000, runtimes: { [] }))
    #expect(none.isEmpty)
}

@Test func onlyLongUnusedSimulatorRuntimesAreReported() throws {
    let now = Date()
    let iso = ISO8601DateFormatter()
    let json: [String: Any] = [
        "OLD-1": ["identifier": "OLD-1", "lastUsedAt": iso.string(from: now.addingTimeInterval(-90 * day)), "sizeBytes": 8_000_000_000,
                  "runtimeIdentifier": "com.apple.CoreSimulator.SimRuntime.iOS-17-5", "version": "17.5", "deletable": true,
                  "path": "/Library/Developer/CoreSimulator/Images/OLD-1.dmg"],
        "NEW-2": ["identifier": "NEW-2", "lastUsedAt": iso.string(from: now.addingTimeInterval(-5 * day)), "sizeBytes": 9_000_000_000],
        "KEEP-3": ["identifier": "KEEP-3", "lastUsedAt": iso.string(from: now.addingTimeInterval(-90 * day)), "sizeBytes": 1,
                   "deletable": false],
        "NEVER-4": ["identifier": "NEVER-4", "sizeBytes": 7_000_000_000],
    ]
    let data = try JSONSerialization.data(withJSONObject: json)
    let found = DynamicRules.unusedRuntimes(json: data, now: now)
    #expect(found.map(\.path) == ["/Library/Developer/CoreSimulator/Images/OLD-1.dmg"])
    #expect(found.first?.label == L("Simulator-Laufzeit \("iOS 17.5")"))
    #expect(found.first?.hint.contains("OLD-1") == true)
    #expect(DynamicRules.unusedRuntimes(json: Data("not json".utf8)).isEmpty)
}
