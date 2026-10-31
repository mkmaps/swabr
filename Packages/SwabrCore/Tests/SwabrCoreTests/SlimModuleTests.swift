import Foundation
import Testing
@testable import SwabrCore

/// Tiny programs built once per run: thin arm64, thin x86_64 and a universal file made from both with
/// `lipo -create`. A constant table of 1.2 MB makes each slice big enough for the 1 MB threshold.
private struct Binaries: Sendable {
    let arm: String
    let intel: String
    let fat: String

    static let shared: Binaries? = {
        guard Shell.run("/usr/bin/xcode-select", ["-p"], timeout: 10).status == 0,
              FileManager.default.isExecutableFile(atPath: "/usr/bin/clang") else { return nil }
        let dir = FileManager.default.temporaryDirectory.appending(path: "swabr-slim-\(UUID().uuidString)").path
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let source = dir + "/main.c"
        let code = "const char table[1200000] = {1};\nint main(int argc, char **argv) { return table[argc]; }\n"
        guard (try? code.write(toFile: source, atomically: true, encoding: .utf8)) != nil else { return nil }
        let b = Binaries(arm: dir + "/arm", intel: dir + "/intel", fat: dir + "/fat")
        guard Shell.run("/usr/bin/clang", ["-arch", "arm64", "-o", b.arm, source], timeout: 120).status == 0,
              Shell.run("/usr/bin/clang", ["-arch", "x86_64", "-o", b.intel, source], timeout: 120).status == 0,
              Shell.run("/usr/bin/lipo", ["-create", b.arm, b.intel, "-output", b.fat], timeout: 60).status == 0
        else { return nil }
        return b
    }()
}

private let toolchain = Binaries.shared != nil

private enum Main { case fat, arm, intel }

/// A small app in the fake home: universal main program, a separately signed universal helper (sealed as
/// nested code) and an unsigned universal file in Resources (sealed by its hash).
private func makeApp(_ h: FakeHome, _ name: String, bundleID: String? = nil, main: Main = .fat, sign: Bool = true,
                     jit: Bool = false, fromAppStore: Bool = false, needsAdmin: Bool = false) throws -> InstalledApp {
    let b = try #require(Binaries.shared)
    let fm = FileManager.default
    let app = h.path + "/Applications/\(name).app"
    for dir in ["MacOS", "Helpers", "Resources"] {
        try fm.createDirectory(atPath: app + "/Contents/" + dir, withIntermediateDirectories: true)
    }
    let id = bundleID ?? "test.slim.\(name.lowercased())"
    let info: [String: Any] = ["CFBundleIdentifier": id, "CFBundleExecutable": name, "CFBundlePackageType": "APPL"]
    try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        .write(to: URL(fileURLWithPath: app + "/Contents/Info.plist"))
    let source = switch main { case .fat: b.fat; case .arm: b.arm; case .intel: b.intel }
    try fm.copyItem(atPath: source, toPath: app + "/Contents/MacOS/" + name)
    try fm.copyItem(atPath: b.fat, toPath: app + "/Contents/Helpers/tool")
    try fm.copyItem(atPath: b.fat, toPath: app + "/Contents/Resources/bin")
    if sign {
        try #require(Shell.run("/usr/bin/codesign", ["--force", "--sign", "-", app + "/Contents/Helpers/tool"]).status == 0)
        var args = ["--force", "--sign", "-"]
        if jit {
            let ent = h.path + "/\(name).entitlements"
            try PropertyListSerialization.data(fromPropertyList: ["com.apple.security.cs.allow-jit": true], format: .xml, options: 0)
                .write(to: URL(fileURLWithPath: ent))
            args += ["--options", "runtime", "--entitlements", ent]
        }
        try #require(Shell.run("/usr/bin/codesign", args + [app]).status == 0)
    }
    return InstalledApp(name: name, path: app, bundleID: id, version: nil, bytes: 0, lastUsed: nil,
                        fromAppStore: fromAppStore, protection: nil, needsAdmin: needsAdmin)
}

private final class Calls: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String] = []
    func add(_ s: String) { lock.lock(); items.append(s); lock.unlock() }
    var all: [String] { lock.lock(); defer { lock.unlock() }; return items }
}

/// Real codesign and lipo; launching, the Trash, notarization and the process list are stand-ins.
private func environment(_ h: FakeHome, probe: Bool = true, notarized: Bool = false, running: [String] = [],
                         probes: Calls = Calls()) -> AppSlimmer.Environment {
    var env = AppSlimmer.Environment.live
    let home = h.path
    env.appleSilicon = { true }
    env.runningExecutables = { running }
    env.isNotarized = { _ in notarized }
    env.launchProbe = { path in probes.add(path); return probe }
    env.trash = { url in
        let trash = home + "/.Trash"
        try FileManager.default.createDirectory(atPath: trash, withIntermediateDirectories: true)
        let dest = URL(fileURLWithPath: trash).appending(path: url.lastPathComponent)
        try FileManager.default.moveItem(at: url, to: dest)
        return dest
    }
    env.workFolder = { _ in
        let dir = home + "/work/" + UUID().uuidString
        return (try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)) != nil ? dir : nil
    }
    return env
}

private func leftovers(_ h: FakeHome) -> [String] {
    (try? FileManager.default.contentsOfDirectory(atPath: h.path + "/work")) ?? []
}

private func verifies(_ path: String) -> Bool {
    Shell.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", path]).status == 0
}

@Test(.enabled(if: toolchain)) func universalBinaryIsRecognisedByItsFatHeader() throws {
    let b = try #require(Binaries.shared)
    let all = try #require(AppSlimmer.slices(b.fat))
    #expect(all.count == 2)
    let intel = try #require(all.first { $0.cpuType == AppSlimmer.cpuX86_64 })
    #expect(AppSlimmer.removableIntelBytes(b.fat) == Int64(intel.size))
    #expect(Int64(intel.size) >= AppSlimmer.minimumSavings)
    #expect(AppSlimmer.removableIntelBytes(b.arm) == nil)
    #expect(AppSlimmer.removableIntelBytes(b.intel) == nil)
    #expect(AppSlimmer.hasArm64(b.arm) && AppSlimmer.hasArm64(b.fat) && !AppSlimmer.hasArm64(b.intel))

    // A Java class file starts with the same magic number.
    let h = try FakeHome()
    try Data([0xCA, 0xFE, 0xBA, 0xBE, 0x00, 0x00, 0x00, 0x34] + [UInt8](repeating: 7, count: 8000))
        .write(to: URL(fileURLWithPath: h.path + "/A.class"))
    #expect(AppSlimmer.slices(h.path + "/A.class") == nil)

    for lipo in ["/usr/bin/lipo", nil] {
        let f = h.path + "/tool-\(lipo == nil ? "cut" : "lipo")"
        try FileManager.default.copyItem(atPath: b.fat, toPath: f)
        #expect(AppSlimmer.removeIntel(f, lipo: lipo))
        #expect(AppSlimmer.hasArm64(f) && AppSlimmer.removableIntelBytes(f) == nil)
        #expect(FileManager.default.isExecutableFile(atPath: f))
        #expect(Shell.run("/usr/bin/lipo", ["-verify_arch", "x86_64", f]).status != 0)
        #expect(Shell.run("/usr/bin/lipo", ["-verify_arch", "arm64", f]).status == 0)
    }
}

@Test(.enabled(if: toolchain)) func scanPlansUniversalAppsAndNamesWhySkipped() async throws {
    let h = try FakeHome()
    let good = try makeApp(h, "Good")
    let store = try makeApp(h, "Store", fromAppStore: true)
    let apple = try makeApp(h, "Notes", bundleID: "com.apple.Notes")
    let admin = try makeApp(h, "Admin", needsAdmin: true)
    let busy = try makeApp(h, "Busy")
    let intel = try makeApp(h, "Intel", main: .intel)
    let unsigned = try makeApp(h, "Unsigned", sign: false)
    let jit = try makeApp(h, "Jit", jit: true)
    let running = [busy.path + "/Contents/MacOS/Busy"]

    let (candidates, skipped) = await AppSlimmer.scan([good, store, apple, admin, busy, intel, unsigned, jit], home: h.path,
                                                      env: environment(h, running: running))
    #expect(candidates.map(\.app.name) == ["Good"])
    let c = try #require(candidates.first)
    // The unsigned file in Resources is sealed by its hash and stays out of the plan.
    #expect(Set(c.plan.keys) == ["Contents/MacOS/Good", "Contents/Helpers/tool"])
    #expect(c.intelBytes >= 2 * AppSlimmer.minimumSavings)
    #expect(c.team == "")

    let reasons = Dictionary(uniqueKeysWithValues: skipped.map { ($0.app.name, $0.reason) })
    #expect(reasons["Store"] == L("aus dem App Store"))
    #expect(reasons["Notes"] == L("Apple-App"))
    #expect(reasons["Admin"] == L("braucht Administratorrechte"))
    #expect(reasons["Busy"] == L("läuft gerade"))
    #expect(reasons["Intel"] == L("Hauptprogramm enthält keinen Apple-Silicon-Code"))
    #expect(reasons["Unsigned"] == L("Code-Signatur ist bereits ungültig"))
    #expect(reasons["Jit"] == L("nutzt Ausnahmen der Hardened Runtime, die beim Neusignieren verloren gingen"))

    // Notarized, the exceptions are never at risk: such an app is not re-signed.
    let (notarized, _) = await AppSlimmer.scan([jit], home: h.path, env: environment(h, notarized: true))
    #expect(notarized.map(\.app.name) == ["Jit"])
}

@Test(.enabled(if: toolchain)) func thinArmOnlyAppHasNothingToRemove() async throws {
    let h = try FakeHome()
    let app = try makeApp(h, "Thin", main: .arm)
    try FileManager.default.removeItem(atPath: app.path + "/Contents/Helpers/tool")
    try #require(Shell.run("/usr/bin/codesign", ["--force", "--sign", "-", app.path]).status == 0)
    let (candidates, skipped) = await AppSlimmer.scan([app], home: h.path, env: environment(h))
    #expect(candidates.isEmpty)
    #expect(skipped.first?.reason == L("enthält keinen entfernbaren Intel-Code"))
}

@Test func intelMacsGetNothing() async throws {
    let h = try FakeHome()
    var env = environment(h)
    env.appleSilicon = { false }
    let app = InstalledApp(name: "X", path: h.path + "/X.app", bundleID: "x", version: nil, bytes: 0, lastUsed: nil,
                           fromAppStore: false, protection: nil)
    let (candidates, skipped) = await AppSlimmer.scan([app], home: h.path, env: env)
    #expect(candidates.isEmpty && skipped.isEmpty)
    #expect(!AppSlimmer.slim(SlimCandidate(app: app, team: "", plan: ["Contents/MacOS/X": 1]), home: h.path,
                             log: OperationLog(home: h.path), env: env).ok)
}

@Test(.enabled(if: toolchain)) func failedCheckOfNotarizedAppLeavesOriginalUntouched() async throws {
    let h = try FakeHome()
    let app = try makeApp(h, "Sealed")
    let main = app.path + "/Contents/MacOS/Sealed"
    let before = try Data(contentsOf: URL(fileURLWithPath: main))
    // Thinning the hash-sealed file breaks the developer's seal.
    let c = SlimCandidate(app: app, team: "", plan: ["Contents/MacOS/Sealed": 1, "Contents/Resources/bin": 1])
    let probes = Calls()
    let outcome = AppSlimmer.slim(c, home: h.path, log: OperationLog(home: h.path),
                                  env: environment(h, notarized: true, probes: probes))
    #expect(!outcome.ok)
    #expect(outcome.message == L("Notarisierte App wäre danach nicht mehr gültig signiert, nichts verändert"))
    #expect(try Data(contentsOf: URL(fileURLWithPath: main)) == before)
    #expect(verifies(app.path))
    #expect(probes.all.isEmpty)
    #expect(leftovers(h).isEmpty)
    #expect(!h.exists(".Trash/Sealed.app"))
    #expect(!h.exists("Library/Application Support/Swabr/operations.log"))
}

@Test(.enabled(if: toolchain)) func failedLaunchProbeLeavesOriginalUntouched() async throws {
    let h = try FakeHome()
    let app = try makeApp(h, "Crashy")
    let (candidates, _) = await AppSlimmer.scan([app], home: h.path, env: environment(h))
    let c = try #require(candidates.first)
    let probes = Calls()
    let outcome = AppSlimmer.slim(c, home: h.path, log: OperationLog(home: h.path), env: environment(h, probe: false, probes: probes))
    #expect(!outcome.ok)
    #expect(outcome.message == L("Verschlankte Kopie ließ sich nicht starten, nichts verändert"))
    #expect(probes.all.count == 1 && probes.all.first != app.path)
    #expect(AppSlimmer.removableIntelBytes(app.path + "/Contents/MacOS/Crashy") != nil)
    #expect(leftovers(h).isEmpty)
    #expect(!h.exists(".Trash/Crashy.app"))
}

@Test(.enabled(if: toolchain)) func runningAppIsNotTouched() async throws {
    let h = try FakeHome()
    let app = try makeApp(h, "Open")
    let (candidates, _) = await AppSlimmer.scan([app], home: h.path, env: environment(h))
    let c = try #require(candidates.first)
    let outcome = AppSlimmer.slim(c, home: h.path, log: OperationLog(home: h.path),
                                  env: environment(h, running: [app.path + "/Contents/MacOS/Open"]))
    #expect(!outcome.ok && outcome.message == L("\(app.name) läuft"))
    #expect(AppSlimmer.removableIntelBytes(app.path + "/Contents/MacOS/Open") != nil)
}

@Test(.enabled(if: toolchain)) func successfulSlimSwapsAndKeepsOriginalInTrash() async throws {
    let h = try FakeHome()
    let app = try makeApp(h, "Slim")
    let (candidates, _) = await AppSlimmer.scan([app], home: h.path, env: environment(h))
    let c = try #require(candidates.first)
    let probes = Calls()
    let log = OperationLog(home: h.path)
    let outcome = AppSlimmer.slim(c, home: h.path, log: log, env: environment(h, probes: probes))
    #expect(outcome.ok, "\(outcome.message)")

    // The probe ran on the copy, not on the installed app.
    #expect(probes.all.count == 1 && probes.all.first != app.path)
    for rel in c.plan.keys {
        #expect(AppSlimmer.removableIntelBytes(app.path + "/" + rel) == nil)
        #expect(AppSlimmer.hasArm64(app.path + "/" + rel))
        #expect(AppSlimmer.removableIntelBytes(h.path + "/.Trash/Slim.app/" + rel) != nil)
    }
    #expect(verifies(app.path))
    #expect(leftovers(h).isEmpty)

    let line = try String(contentsOf: log.url, encoding: .utf8)
    #expect(line.contains("\tVerschlanken: Slim\t" + app.path))
    let bytes = try #require(line.split(separator: "\t").dropFirst(2).first.flatMap { Int64($0) })
    #expect(bytes >= 2 * AppSlimmer.minimumSavings)
    #expect(outcome.message == L("\(DiskSize.format(bytes)) Intel-Code entfernt"))
}

@Test(.enabled(if: toolchain)) func appThatIsNotNotarizedIsSignedAdHocAfterwards() async throws {
    let h = try FakeHome()
    let app = try makeApp(h, "Local")
    let c = SlimCandidate(app: app, team: "", plan: ["Contents/MacOS/Local": 1, "Contents/Resources/bin": 1])
    let outcome = AppSlimmer.slim(c, home: h.path, log: OperationLog(home: h.path), env: environment(h, notarized: false))
    #expect(outcome.ok, "\(outcome.message)")
    #expect(AppSlimmer.removableIntelBytes(app.path + "/Contents/Resources/bin") == nil)
    #expect(verifies(app.path))
    #expect(h.exists(".Trash/Local.app"))
}
