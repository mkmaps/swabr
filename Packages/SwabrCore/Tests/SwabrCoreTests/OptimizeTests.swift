import Foundation
import Testing
@testable import SwabrCore

@Test func catalogHasTheSpecifiedTasksOnce() {
    let ids = OptimizeCatalog.all.map(\.id)
    #expect(ids == [
        "finder.quicklook", "state.old", "prefs.broken", "dns.flush", "net.routes", "finder.dsstore", "defaults.legacy",
        "home.permissions", "spotlight.check", "spotlight.orphans", "system.periodic", "finder.sfl", "disk.verify",
        "login.audit", "quarantine.history", "agents.orphans", "notifications.old", "sqlite.compact",
    ])
    #expect(Set(ids).count == ids.count)
    #expect(OptimizeCatalog.all.allSatisfy { !$0.title.isEmpty && !$0.impact.isEmpty && !$0.summary.isEmpty })
    let admin = Set(OptimizeCatalog.all.filter(\.needsAdmin).map(\.id))
    #expect(admin == ["dns.flush", "net.routes", "home.permissions", "spotlight.check", "spotlight.orphans", "system.periodic"])
    let noticeable = Set(OptimizeCatalog.all.filter(\.noticeable).map(\.id))
    #expect(noticeable == ["net.routes", "home.permissions", "spotlight.check"])
    // No task promises speed.
    for t in OptimizeCatalog.all {
        for s in [t.title, t.summary, t.impact] {
            #expect(!s.lowercased().contains("schneller") && !s.lowercased().contains("beschleunig"), "\(t.id)")
        }
    }
}

@Test func adminStepsRunInOneRootRunAndAreSplitPerTask() {
    let ok = OptimizeTask(id: "a", title: "A", summary: "s", impact: "i", needsAdmin: true, noticeable: false) { _ in
        .admin(AdminStep(command: .flushDNS) { status, out in status == 0 && out == "hello" ? .applied("ok") : .failed(out) })
    }
    let bad = OptimizeTask(id: "b", title: "B", summary: "s", impact: "i", needsAdmin: true, noticeable: false) { _ in
        .admin(AdminStep(command: .rebuildSpotlightIndex) { status, out in status == 3 && out == "oops" ? .failed("rc3") : .applied("?") })
    }
    let local = OptimizeTask(id: "c", title: "C", summary: "s", impact: "i", needsAdmin: false, noticeable: false) { _ in
        .done(.unchanged("nothing"))
    }
    let ctx = OptimizeContext(isAppRunning: { _ in false })
    // One root run with both commands, in order; each result goes to its task.
    let calls = Counter()
    let results = Optimizer.run([ok, bad, local], context: ctx) { ops in
        calls.add()
        #expect(ops == [.command(.flushDNS), .command(.rebuildSpotlightIndex)])
        return [RootResult(status: 0, output: "hello\n"), RootResult(status: 3, output: "oops")]
    }
    #expect(calls.value == 1)
    #expect(results["a"] == .applied("ok"))
    #expect(results["b"] == .failed("rc3"))
    #expect(results["c"] == .unchanged("nothing"))

    let cancelled = Optimizer.run([ok, local], context: ctx) { _ in nil }
    #expect(cancelled["a"] == .skipped(L("Administratorrechte nicht erteilt")))
    #expect(cancelled["c"] == .unchanged("nothing"))
}

@Test func vacuumSkipsCompactDatabasesAndFreesSpaceOtherwise() throws {
    let h = try FakeHome()
    let path = h.path + "/test.db"
    try makeDatabase(path, "CREATE TABLE t(x BLOB); WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i+1 FROM n WHERE i<300) INSERT INTO t SELECT randomblob(4000) FROM n;")
    #expect(SQLiteMaintenance.compact(path) == .alreadyCompact)
    try makeDatabase(path, "DELETE FROM t WHERE rowid % 2 = 0;")
    guard case .compacted(let saved) = SQLiteMaintenance.compact(path) else { Issue.record("expected vacuum"); return }
    #expect(saved > 100_000)
    #expect(SQLiteMaintenance.compact(path) == .alreadyCompact)
}

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func add() { lock.withLock { count += 1 } }
    var value: Int { lock.withLock { count } }
}

/// Creates the file if needed and runs the statements on it.
func makeDatabase(_ path: String, _ sql: String) throws {
    let fm = FileManager.default
    try fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    if !fm.fileExists(atPath: path) { fm.createFile(atPath: path, contents: nil) }
    let db = try SQLiteDatabase.open(path, timeoutMs: 1_000).get()
    try db.execute(sql)
    db.close()
}
