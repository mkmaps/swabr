import Foundation
import Testing
@testable import SwabrCore

// MARK: Fakes

/// Answers command-line tools like a quiet Mac without running them (only `plutil -lint` runs for real,
/// it reads the test files). Every call is recorded.
final class FakeTools: @unchecked Sendable {
    private let lock = NSLock()
    private var log: [String] = []
    private var answers: [String: (Int32, String)]

    init(home: String, _ overrides: [String: (Int32, String)] = [:]) {
        answers = [
            "/usr/bin/defaults read com.apple.desktopservices DSDontWriteNetworkStores": (0, "1\n"),
            "/usr/bin/defaults read com.apple.desktopservices DSDontWriteUSBStores": (0, "1\n"),
            "/sbin/route -n get default": (1, "route: writing to routing socket: not in table\n"),
            "/usr/bin/mdutil -s /": (0, "/:\n\tIndexing enabled. \n"),
            "/usr/bin/getconf DARWIN_USER_DIR": (0, home + "/userdir/\n"),
            "/usr/sbin/diskutil verifyVolume /": (0, "The volume appears to be OK\n"),
        ].merging(overrides) { $1 }
    }

    var calls: [String] { lock.withLock { log } }

    func run(_ tool: String, _ args: [String]) -> (status: Int32, output: String) {
        let line = ([tool] + args).joined(separator: " ")
        lock.withLock { log.append(line) }
        if let a = lock.withLock({ answers[line] }) { return a }
        switch tool {
        case "/usr/bin/plutil": return Shell.run(tool, args, timeout: 10)
        case "/usr/bin/defaults" where args.first == "read": return (1, "The domain/default pair does not exist\n")
        case "/usr/bin/osascript": return (0, "/bin/ls\n")
        default: return (0, "")
        }
    }
}

func testContext(_ h: FakeHome, _ tools: FakeTools, running: Set<String> = []) -> OptimizeContext {
    let home = h.path
    var c = OptimizeContext(home: home, isAppRunning: { running.contains($0) }, log: OperationLog(home: home))
    c.run = { tool, args, _ in tools.run(tool, args) }
    c.trash = { path in
        do {
            try FileManager.default.createDirectory(atPath: home + "/.Trash", withIntermediateDirectories: true)
            try FileManager.default.moveItem(atPath: path, toPath: home + "/.Trash/" + (path as NSString).lastPathComponent)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
    c.appNames = { _ in [] }
    c.systemLaunchFolders = []
    c.spotlightConfigs = [home + "/Spotlight/VolumeConfiguration.plist"]
    c.periodicTool = home + "/bin/periodic"
    c.periodicLogs = home + "/log"
    c.busyTimeout = 50
    return c
}

func outcome(_ id: String, _ ctx: OptimizeContext) -> OptimizeOutcome? {
    guard let task = OptimizeCatalog.all.first(where: { $0.id == id }), case .done(let o) = task.prepare(ctx) else { return nil }
    return o
}

func adminStep(_ id: String, _ ctx: OptimizeContext) -> AdminStep? {
    guard let task = OptimizeCatalog.all.first(where: { $0.id == id }), case .admin(let step) = task.prepare(ctx) else { return nil }
    return step
}

func writePlist(_ value: Any, _ path: String) throws {
    try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try PropertyListSerialization.data(fromPropertyList: value, format: .xml, options: 0).write(to: URL(fileURLWithPath: path))
}

func setDate(_ path: String, daysAgo: Double) throws {
    try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-daysAgo * 86_400)], ofItemAtPath: path)
}

let notificationSchema = "CREATE TABLE record (rec_id INTEGER PRIMARY KEY, app_id INTEGER, data BLOB, delivered_date REAL);"

/// A home folder in which every task finds its input but nothing to do.
func quietHome() throws -> FakeHome {
    let h = try FakeHome()
    try h.file("Library/Saved Application State/com.fresh.app.savedState/window_1.data")
    try writePlist(["k": 1], h.path + "/Library/Preferences/com.vendor.fine.plist")
    try NSKeyedArchiver.archivedData(withRootObject: ["item"], requiringSecureCoding: true)
        .write(to: URL(fileURLWithPath: h.path + "/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.FavoriteItems.sfl4").creatingParent())
    try writePlist(["Exclusions": [h.path + "/Library"]], h.path + "/Spotlight/VolumeConfiguration.plist")
    try h.file("bin/periodic")
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: h.path + "/bin/periodic")
    for p in ["daily", "weekly", "monthly"] { try h.file("log/\(p).out") }
    try writePlist(["Label": "com.fine.agent", "ProgramArguments": ["/bin/ls"]], h.path + "/Library/LaunchAgents/com.fine.agent.plist")
    let recent = Date().addingTimeInterval(-86_400).timeIntervalSinceReferenceDate
    try makeDatabase(h.path + "/Library/Group Containers/group.com.apple.usernoted/db2/db",
                     notificationSchema + "INSERT INTO record(app_id, delivered_date) VALUES (1, \(recent));")
    try makeDatabase(h.path + "/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2",
                     "CREATE TABLE LSQuarantineEvent (LSQuarantineEventIdentifier TEXT PRIMARY KEY NOT NULL, LSQuarantineTimeStamp REAL);")
    try makeDatabase(h.path + "/Library/Mail/V10/MailData/Envelope Index", "CREATE TABLE messages(x);")
    return h
}

extension URL {
    func creatingParent() throws -> URL {
        try FileManager.default.createDirectory(at: deletingLastPathComponent(), withIntermediateDirectories: true)
        return self
    }
}

// MARK: Nothing to do

@Test func everyTaskReportsUnchangedWhenThereIsNothingToDo() throws {
    let h = try quietHome()
    let tools = FakeTools(home: h.path)
    let ctx = testContext(h, tools)
    // QuickLook offers no way to tell whether its caches are stale, so that reset always runs.
    for task in OptimizeCatalog.all where task.id != "finder.quicklook" {
        guard case .done(let o) = task.prepare(ctx) else { Issue.record("\(task.id) wants a root step"); continue }
        guard case .unchanged = o else { Issue.record("\(task.id): \(o)"); continue }
    }
    // Nothing was changed: no restarted daemons, no written settings, nothing in the Trash or the log.
    #expect(!tools.calls.contains { $0.contains("killall") || $0.contains("defaults write") || $0.contains("defaults delete") })
    #expect(!h.exists(".Trash"))
    #expect(History.load(OperationLog(home: h.path)).isEmpty)
    #expect(h.exists("Library/Saved Application State/com.fresh.app.savedState"))
}

// MARK: Runner

@Test func runnerHandsCatalogStepsToRootAsFixedCommands() throws {
    let h = try quietHome()
    let online = FakeTools(home: h.path, [
        "/sbin/route -n get default": (0, "   route to: default\n  interface: en0\n"),
        "/usr/bin/mdutil -s /": (0, "/:\n\tIndexing disabled.\n"),
    ])
    let ctx = testContext(h, online)
    let tasks = OptimizeCatalog.all.filter { ["dns.flush", "spotlight.check", "finder.dsstore"].contains($0.id) }
    let sent = OpsBox()
    let results = Optimizer.run(tasks, context: ctx) { ops in
        sent.value = ops
        // As the helper would answer: both steps print something, the second fails.
        return [RootResult(status: 0, output: "flushed\n"), RootResult(status: 1, output: "mdutil: error\n")]
    }
    #expect(sent.value == [.command(.flushDNS), .command(.rebuildSpotlightIndex)])
    #expect(results["dns.flush"] == .applied(L("DNS-Cache geleert")))
    #expect(results["spotlight.check"] == .failed(L("Neuaufbau konnte nicht gestartet werden") + ": mdutil: error"))
    #expect(results["finder.dsstore"] == .unchanged(L("Bereits eingestellt")))
    // No killall ran outside the (fake) root step.
    #expect(!online.calls.contains { $0.contains("killall") })
}

@Test func missingResultAndDeclinedPasswordAreReported() throws {
    let h = try quietHome()
    let ctx = testContext(h, FakeTools(home: h.path, ["/sbin/route -n get default": (0, "interface: en0\n")]))
    let dns = OptimizeCatalog.all.filter { $0.id == "dns.flush" }
    let cut = Optimizer.run(dns, context: ctx) { _ in [] }
    #expect(cut["dns.flush"] == .failed(L("Ergebnis nicht erkannt")))
    let declined = Optimizer.run(dns, context: ctx) { _ in nil }
    #expect(declined["dns.flush"] == .skipped(L("Administratorrechte nicht erteilt")))
}

final class OpsBox: @unchecked Sendable {
    private let lock = NSLock()
    private var ops: [RootOperation] = []
    var value: [RootOperation] {
        get { lock.withLock { ops } }
        set { lock.withLock { ops = newValue } }
    }
}

@Test func withoutRootRunnerAdminTasksDoNotRun() throws {
    let h = try quietHome()
    let probe = OptimizeTask(id: "x", title: "X", summary: "s", impact: "i", needsAdmin: true, noticeable: false) { _ in
        Issue.record("an admin task must not even be prepared without root")
        return .done(.applied("?"))
    }
    let sneaky = OptimizeTask(id: "y", title: "Y", summary: "s", impact: "i", needsAdmin: false, noticeable: false) { _ in
        .admin(AdminStep(command: .flushDNS) { _, _ in .applied("ran") })
    }
    let local = OptimizeTask(id: "z", title: "Z", summary: "s", impact: "i", needsAdmin: false, noticeable: false) { _ in .done(.unchanged("z")) }
    let results = Optimizer.run([probe, sneaky, local], context: testContext(h, FakeTools(home: h.path)))
    #expect(results["x"] == .unavailable(L("braucht Administratorrechte")))
    #expect(results["y"] == .unavailable(L("braucht Administratorrechte")))
    #expect(results["z"] == .unchanged("z"))
}


// MARK: Store

@Test func storeCatalogHoldsOnlySandboxSafeTasks() {
    let store = OptimizeCatalog.all.filter { OptimizeCatalog.sandboxSafeIDs.contains($0.id) }
    #expect(Set(store.map(\.id)) == ["state.old", "prefs.broken", "finder.sfl", "quarantine.history", "agents.orphans"])
    #expect(OptimizeCatalog.sandboxSafeIDs.isSubset(of: Set(OptimizeCatalog.all.map(\.id))))
    #expect(store.allSatisfy { !$0.needsAdmin })
}

@Test func unreadableFoldersAreUnavailableNotUnchanged() throws {
    let h = try quietHome()
    let prefs = h.path + "/Library/Preferences"
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: prefs)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: prefs) }
    let ctx = testContext(h, FakeTools(home: h.path))
    #expect(outcome("prefs.broken", ctx) == .unavailable(L("Kein Zugriff auf \("~/Library/Preferences")")))
    #expect(outcome("quarantine.history", ctx) == .unavailable(L("Kein Zugriff auf \("~/Library/Preferences")")))
}

// MARK: Preferences

@Test func brokenThirdPartyPreferencesGoToTheTrash() throws {
    let h = try FakeHome()
    let prefs = h.path + "/Library/Preferences"
    // A binary plist cut off mid-write, as left behind by a crash.
    let garbage = Data("bplist00\u{1}\u{2}\u{3}broken".utf8)
    try FileManager.default.createDirectory(atPath: prefs, withIntermediateDirectories: true)
    for name in ["com.vendor.broken.plist", "com.apple.something.plist", "loginwindow.plist",
                 "group.com.apple.notes.plist", "com.busy.app.plist"] {
        try garbage.write(to: URL(fileURLWithPath: prefs + "/" + name))
    }
    try writePlist(["k": 1], prefs + "/com.vendor.fine.plist")
    let ctx = testContext(h, FakeTools(home: h.path), running: ["com.busy.app"])

    #expect(OptimizeCatalog.brokenPreferenceFiles(in: prefs, ctx: ctx).map { ($0 as NSString).lastPathComponent }
            == ["com.busy.app.plist", "com.vendor.broken.plist"])
    let result = outcome("prefs.broken", ctx)
    #expect(result == .attention(L("\(1) beschädigte Einstellungsdateien in den Papierkorb gelegt") + " · " + L("Bitte zuerst schließen: \("com.busy.app")")))
    #expect(h.exists(".Trash/com.vendor.broken.plist") && !h.exists("Library/Preferences/com.vendor.broken.plist"))
    for kept in ["com.apple.something.plist", "loginwindow.plist", "group.com.apple.notes.plist", "com.busy.app.plist", "com.vendor.fine.plist"] {
        #expect(h.exists("Library/Preferences/" + kept), "\(kept)")
    }
    let entry = try #require(History.load(OperationLog(home: h.path)).first)
    #expect(entry.action == "TRASH" && entry.label == "Optimieren: Einstellungsdateien" && entry.path == prefs + "/com.vendor.broken.plist")
}

// MARK: Databases

@Test func compactHandlesIntactDamagedLargeAndLockedDatabases() throws {
    let h = try FakeHome()
    let fill = "CREATE TABLE t(x BLOB); WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM n WHERE i<200) INSERT INTO t SELECT randomblob(3000) FROM n;"

    let ok = h.path + "/ok.db"
    try makeDatabase(ok, fill + "DELETE FROM t WHERE rowid > 50;")
    guard case .compacted(let saved) = SQLiteMaintenance.compact(ok, timeoutMs: 50) else { Issue.record("expected compaction"); return }
    #expect(saved > 0)

    let large = h.path + "/large.db"
    try makeDatabase(large, fill + "DELETE FROM t WHERE rowid > 50;")
    let size = SQLiteMaintenance.footprint(large)
    #expect(SQLiteMaintenance.compact(large, sizeLimit: 10_000, timeoutMs: 50) == .tooLarge(size))
    #expect(SQLiteMaintenance.footprint(large) == size)

    let damaged = h.path + "/damaged.db"
    try makeDatabase(damaged, fill)
    let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: damaged))
    try handle.seek(toOffset: 4096 * 3)
    try handle.write(contentsOf: Data(repeating: 0xA5, count: 4096 * 4))
    try handle.close()
    let damagedBytes = try Data(contentsOf: URL(fileURLWithPath: damaged))
    #expect(SQLiteMaintenance.compact(damaged, timeoutMs: 50) == .damaged)
    #expect(try Data(contentsOf: URL(fileURLWithPath: damaged)) == damagedBytes)

    let locked = h.path + "/locked.db"
    try makeDatabase(locked, fill + "DELETE FROM t WHERE rowid > 50;")
    let holder = try SQLiteDatabase.open(locked, timeoutMs: 50).get()
    try holder.execute("BEGIN EXCLUSIVE; DELETE FROM t WHERE rowid = 1;")
    #expect(SQLiteMaintenance.compact(locked, timeoutMs: 50) == .locked)
    try holder.execute("ROLLBACK")
    holder.close()

    #expect(SQLiteMaintenance.compact(h.path + "/none.db") == .missing)
}

@Test func compactTaskSkipsRunningAppsAndReportsProblems() throws {
    let h = try FakeHome()
    let fill = "CREATE TABLE t(x BLOB); WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM n WHERE i<200) INSERT INTO t SELECT randomblob(3000) FROM n; DELETE FROM t WHERE rowid > 20;"
    try makeDatabase(h.path + "/Library/Mail/V10/MailData/Envelope Index", fill)
    try makeDatabase(h.path + "/Library/Messages/chat.db", fill)
    let messagesBefore = SQLiteMaintenance.footprint(h.path + "/Library/Messages/chat.db")

    // Messages runs under its German name.
    let ctx = testContext(h, FakeTools(home: h.path), running: ["Nachrichten"])
    guard case .applied(let text) = outcome("sqlite.compact", ctx) else { Issue.record("expected applied"); return }
    let parts = text.components(separatedBy: " · ")
    #expect(parts.count == 2 && parts.last == L("\(L("Nachrichten")) läuft"))
    #expect(SQLiteMaintenance.compact(h.path + "/Library/Mail/V10/MailData/Envelope Index") == .alreadyCompact)
    #expect(SQLiteMaintenance.footprint(h.path + "/Library/Messages/chat.db") == messagesBefore)

    var small = testContext(h, FakeTools(home: h.path))
    small.databaseSizeLimit = 1_000
    #expect(outcome("sqlite.compact", small) == .attention(L("\("Mail") zu groß (> 100 MB)") + " · " + L("\(L("Nachrichten")) zu groß (> 100 MB)")))
}

@Test func quarantineHistoryIsEmptied() throws {
    let h = try FakeHome()
    let path = h.path + "/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2"
    try makeDatabase(path, """
        CREATE TABLE LSQuarantineEvent (LSQuarantineEventIdentifier TEXT PRIMARY KEY NOT NULL, LSQuarantineTimeStamp REAL);
        INSERT INTO LSQuarantineEvent VALUES ('a', 1), ('b', 2);
        """)
    let ctx = testContext(h, FakeTools(home: h.path))
    #expect(outcome("quarantine.history", ctx) == .applied(L("\(2) Einträge gelöscht")))
    #expect(outcome("quarantine.history", ctx) == .unchanged(L("Download-Verlauf ist leer")))
    #expect(History.load(OperationLog(home: h.path)).first?.label == "Optimieren: Download-Verlauf")
}

@Test func oldNotificationsAreDeletedAndUsernotedRestarted() throws {
    let h = try FakeHome()
    let path = h.path + "/userdir/com.apple.notificationcenter/db2/db"
    let old = Date().addingTimeInterval(-40 * 86_400).timeIntervalSinceReferenceDate
    let recent = Date().addingTimeInterval(-86_400).timeIntervalSinceReferenceDate
    try makeDatabase(path, notificationSchema + "INSERT INTO record(app_id, delivered_date) VALUES (1, \(old)), (1, \(old)), (2, \(recent)), (2, NULL);")
    let tools = FakeTools(home: h.path)
    let ctx = testContext(h, tools)
    #expect(outcome("notifications.old", ctx) == .applied(L("\(2) alte Einträge gelöscht")))
    #expect(tools.calls.contains("/usr/bin/killall usernoted"))
    let db = try SQLiteDatabase.open(path, timeoutMs: 50).get()
    #expect(try db.integer("SELECT count(*) FROM record") == 2)
    db.close()

    // A database usernoted holds locked is left alone.
    try makeDatabase(path, "INSERT INTO record(app_id, delivered_date) VALUES (3, \(old));")
    let holder = try SQLiteDatabase.open(path, timeoutMs: 50).get()
    try holder.execute("BEGIN IMMEDIATE")
    #expect(outcome("notifications.old", ctx) == .skipped(L("Datenbank war gesperrt")))
    try holder.execute("ROLLBACK")
    holder.close()
}

// MARK: Files

@Test func oldSavedStatesOfClosedAppsAreRemoved() throws {
    let h = try FakeHome()
    let root = h.path + "/Library/Saved Application State"
    for name in ["com.old.app", "com.new.app", "com.running.app"] { try h.file("Library/Saved Application State/\(name).savedState/w") }
    for name in ["com.old.app", "com.running.app"] {
        try setDate(root + "/\(name).savedState/w", daysAgo: 40)
        try setDate(root + "/\(name).savedState", daysAgo: 40)
    }
    let ctx = testContext(h, FakeTools(home: h.path), running: ["com.running.app"])
    #expect(outcome("state.old", ctx) == .applied(L("\(1) alte Fensterzustände entfernt")))
    #expect(!h.exists("Library/Saved Application State/com.old.app.savedState"))
    #expect(h.exists("Library/Saved Application State/com.new.app.savedState"))
    #expect(h.exists("Library/Saved Application State/com.running.app.savedState"))
    #expect(History.load(OperationLog(home: h.path)).first?.label == "Optimieren: Fensterzustände")
}

@Test func unreadableSharedFileListsGoToTheTrash() throws {
    let h = try FakeHome()
    let root = h.path + "/Library/Application Support/com.apple.sharedfilelist"
    try NSKeyedArchiver.archivedData(withRootObject: ["ok"], requiringSecureCoding: true)
        .write(to: URL(fileURLWithPath: root + "/com.apple.LSSharedFileList.FavoriteItems.sfl4").creatingParent())
    try Data("not an archive".utf8)
        .write(to: URL(fileURLWithPath: root + "/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.vendor.app.sfl3").creatingParent())
    let tools = FakeTools(home: h.path)
    #expect(outcome("finder.sfl", testContext(h, tools)) == .applied(L("\(1) beschädigte Listen entfernt")))
    #expect(h.exists(".Trash/com.vendor.app.sfl3"))
    #expect(h.exists("Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.FavoriteItems.sfl4"))
    #expect(tools.calls.contains("/usr/bin/killall sharedfilelistd"))
}

@Test func launchAgentsWithMissingProgramAreOnlyReported() throws {
    let h = try FakeHome()
    try writePlist(["Label": "com.gone.agent", "Program": "/nonexistent/bin/tool"], h.path + "/Library/LaunchAgents/com.gone.agent.plist")
    try writePlist(["Label": "com.fine.agent", "ProgramArguments": ["/bin/ls"]], h.path + "/Library/LaunchAgents/com.fine.agent.plist")
    #expect(outcome("agents.orphans", testContext(h, FakeTools(home: h.path))) == .attention(L("\(1) mit fehlendem Programm: ") + "com.gone.agent"))
    #expect(h.exists("Library/LaunchAgents/com.gone.agent.plist"))
}

// MARK: Settings and system tools

@Test func dsStoreAndLegacySwitchesAreWrittenOnlyWhenNeeded() throws {
    let h = try FakeHome()
    let tools = FakeTools(home: h.path, [
        "/usr/bin/defaults read com.apple.desktopservices DSDontWriteUSBStores": (1, "does not exist"),
        "/usr/bin/defaults read com.apple.frameworks.diskimages skip-verify": (0, "1\n"),
        "/usr/bin/defaults read -g NSAppSleepDisabled": (0, "0\n"),
    ])
    let ctx = testContext(h, tools)
    #expect(outcome("finder.dsstore", ctx) == .applied(L("Finder schreibt keine .DS_Store mehr auf Netz- und USB-Laufwerke")))
    #expect(tools.calls.contains("/usr/bin/defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true"))
    #expect(!tools.calls.contains("/usr/bin/defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true"))
    #expect(outcome("defaults.legacy", ctx) == .applied(L("\(1) alte Schalter entfernt")))
    #expect(tools.calls.filter { $0.hasPrefix("/usr/bin/defaults delete") } == ["/usr/bin/defaults delete com.apple.frameworks.diskimages skip-verify"])
}

@Test func networkTasksLeaveVPNAndManualSetupsAlone() throws {
    let h = try FakeHome()
    let vpn = testContext(h, FakeTools(home: h.path, ["/sbin/route -n get default": (0, "interface: utun3\n")]))
    #expect(outcome("dns.flush", vpn) == .skipped(L("VPN aktiv (\("utun3")), DNS bleibt unverändert")))
    #expect(outcome("net.routes", vpn) == .skipped(L("VPN aktiv (\("utun3")), Routen bleiben unverändert")))

    let lan = [
        "/sbin/route -n get default": (Int32(0), "interface: en0\n"),
        "/usr/sbin/scutil --nwi": (Int32(0), "Network interfaces: en0 en1\n"),
        "/usr/sbin/ipconfig getpacket en0": (Int32(0), "op = BOOTREPLY\n"),
    ]
    let manual = testContext(h, FakeTools(home: h.path, lan.merging(["/usr/sbin/ipconfig getpacket en1": (0, "")]) { $1 }))
    #expect(outcome("net.routes", manual) == .skipped(L("Schnittstelle \("en1") ist manuell eingerichtet, Routen bleiben unverändert")))

    let dhcp = testContext(h, FakeTools(home: h.path, lan.merging(["/usr/sbin/ipconfig getpacket en1": (0, "op = BOOTREPLY\n")]) { $1 }))
    let step = try #require(adminStep("net.routes", dhcp))
    #expect(step.command == .flushRoutes(interfaces: ["en0", "en1"]))
    #expect(step.interpret(0, "") == .applied(L("Routen geleert, Adressen neu angefordert")))
}

@Test func periodicRunsOnlyDuePeriodsAndIsUnavailableWithoutTheTool() throws {
    let h = try quietHome()
    try setDate(h.path + "/log/weekly.out", daysAgo: 8)
    try FileManager.default.removeItem(atPath: h.path + "/log/monthly.out")
    let ctx = testContext(h, FakeTools(home: h.path))
    #expect(adminStep("system.periodic", ctx)?.command == .periodic(names: ["weekly", "monthly"]))
    try FileManager.default.removeItem(atPath: h.path + "/bin/periodic")
    #expect(outcome("system.periodic", ctx) == .unavailable(L("Gibt es seit macOS 26 nicht mehr, das System erledigt das selbst")))
}

@Test func reportTasksFlagWhatIsMissing() throws {
    let h = try quietHome()
    try writePlist(["Exclusions": [h.path + "/Library", h.path + "/gone", "/Volumes/NotMounted-\(UUID().uuidString)/x"]],
                   h.path + "/Spotlight/VolumeConfiguration.plist")
    let tools = FakeTools(home: h.path, [
        "/usr/sbin/diskutil verifyVolume /": (1, "Error: -69845: File system verify or repair failed\n"),
    ])
    var ctx = testContext(h, tools)
    #expect(outcome("spotlight.orphans", ctx) == .attention(L("\(1) Ausschlüsse ohne Ort: ") + "~/gone"))
    #expect(outcome("disk.verify", ctx) == .attention(L("Fehler gefunden: im Festplattendienstprogramm „Erste Hilfe“ ausführen")))
    // Not readable as the user (the real file belongs to root): read in the admin step instead.
    ctx.spotlightConfigs = [h.path + "/nothing.plist"]
    let step = try #require(adminStep("spotlight.orphans", ctx))
    #expect(step.command == .readSpotlightConfiguration)
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict><key>Exclusions</key><array><string>\(h.path)/gone</string></array></dict></plist>
    """
    #expect(step.interpret(0, xml) == .attention(L("\(1) Ausschlüsse ohne Ort: ") + "~/gone"))
    #expect(step.interpret(0, "<plist version=\"1.0\"><dict/></plist>") == .unchanged(L("Alle Spotlight-Ausschlüsse sind vorhanden")))
    #expect(step.interpret(1, "") == .unavailable(L("Spotlight-Einstellungen nicht lesbar")))
    // The step itself only reads: run it as the user on a readable copy.
    let copy = h.path + "/copy.plist"
    try writePlist(["Exclusions": [h.path + "/gone"]], copy)
    ctx.spotlightConfigs = [h.path + "/missing.plist", copy]
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: copy)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: copy) }
    let read = try #require(adminStep("spotlight.orphans", ctx))
    try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: copy)
    // The root step prints the configuration as XML; the same conversion on the readable copy:
    let run = Shell.run("/usr/bin/plutil", ["-convert", "xml1", "-o", "-", copy])
    #expect(run.status == 0)
    #expect(read.interpret(run.status, run.output) == .attention(L("\(1) Ausschlüsse ohne Ort: ") + "~/gone"))
}

@Test func loginItemsWithMissingProgramsAreReported() throws {
    let h = try FakeHome()
    let script = OptimizeCatalog.loginItemScript.flatMap { ["-e", $0] }.joined(separator: " ")
    let tools = FakeTools(home: h.path, ["/usr/bin/osascript " + script: (0, "/bin/ls\n/Applications/Gone-\(UUID().uuidString).app\n")])
    guard case .attention(let text) = outcome("login.audit", testContext(h, tools)) else { Issue.record("expected attention"); return }
    #expect(text.contains("Gone-") && !text.contains("/bin/ls"))
    let denied = FakeTools(home: h.path, ["/usr/bin/osascript " + script: (1, "execution error: Not authorized to send Apple events to System Events. (-1743)")])
    guard case .skipped = outcome("login.audit", testContext(h, denied)) else { Issue.record("expected skipped"); return }
}

@Test func homePermissionCheckFindsForeignOwnersAndReadOnlyFolders() throws {
    let h = try FakeHome()
    try h.file("Documents/a")
    #expect(!OptimizeCatalog.hasPermissionProblems(home: h.path, uid: getuid()))
    #expect(OptimizeCatalog.hasPermissionProblems(home: h.path, uid: getuid() + 1))
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: h.path + "/Documents")
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: h.path + "/Documents") }
    #expect(OptimizeCatalog.hasPermissionProblems(home: h.path, uid: getuid()))
    let step = try #require(adminStep("home.permissions", testContext(h, FakeTools(home: h.path))))
    #expect(step.command == .resetUserPermissions)
}
