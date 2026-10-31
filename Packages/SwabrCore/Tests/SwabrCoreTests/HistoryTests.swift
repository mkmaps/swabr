import Foundation
import Testing
@testable import SwabrCore

private func logFile(_ h: FakeHome, _ text: String) throws -> OperationLog {
    let log = OperationLog(home: h.path)
    try FileManager.default.createDirectory(at: log.url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: log.url)
    return log
}

@Test func historyOfMissingOrEmptyLogIsEmpty() throws {
    let h = try FakeHome()
    #expect(History.load(OperationLog(home: h.path)).isEmpty)
    #expect(History.load(try logFile(h, "")).isEmpty)
    #expect(History.load(try logFile(h, "\n\n")).isEmpty)
}

@Test func historySkipsBrokenLines() throws {
    let h = try FakeHome()
    let log = try logFile(h, """
    2026-10-25T08:00:00Z\tREMOVE\t10\tPapierkorb\t/a
    2026-10-25T08:00:01Z\tREMOVE\t10\tzu wenig Felder
    gestern\tREMOVE\t10\tPapierkorb\t/b
    2026-13-40T08:00:00Z\tREMOVE\t10\tPapierkorb\t/c
    2026-10-25T08:00:02Z\tTRASH\tviel\tPapierkorb\t/d

    2026-10-25T08:00:03.500Z\tTRASH\t5\tPapierkorb\t/e
    2026-10-25T10:00:04+02:00\tTRASH\t1\tPapierkorb\t/f\r
    """)
    let entries = History.load(log)
    #expect(entries.map(\.path) == ["/f", "/e", "/a"])
    #expect(entries[0].date == Date(timeIntervalSince1970: 1_792_915_204))
    #expect(entries[1].date == Date(timeIntervalSince1970: 1_792_915_203.5))
    #expect(entries[2].date == Date(timeIntervalSince1970: 1_792_915_200))
}

@Test func historyKeepsTabsInPath() {
    let entries = History.parse("2026-10-25T08:00:00Z\tTRASH\t1\tPapierkorb\t/x/a\tb\t\tc\n")
    #expect(entries.count == 1)
    #expect(entries[0].path == "/x/a\tb\t\tc")
    #expect(entries[0].label == "Papierkorb")
}

@Test func historyIsNewestFirstWithFileOrderAsTieBreak() {
    let entries = History.parse("""
    2026-10-25T08:00:00Z\tREMOVE\t1\tA\t/1
    2026-10-25T09:00:00Z\tREMOVE\t1\tA\t/2
    2026-10-25T08:30:00Z\tREMOVE\t1\tA\t/3
    2026-10-25T09:00:00Z\tREMOVE\t1\tA\t/4
    """)
    #expect(entries.map(\.path) == ["/4", "/2", "/3", "/1"])
    #expect(entries.map(\.id) == [3, 1, 2, 0])
}

@Test func historySessionBoundaryIsInclusive() {
    let entries = History.parse("""
    2026-10-25T08:00:00Z\tREMOVE\t1\tA\t/1
    2026-10-25T08:05:00Z\tREMOVE\t2\tA\t/2
    2026-10-25T08:10:01Z\tREMOVE\t4\tA\t/3
    """)
    let runs = History.sessions(entries)
    #expect(runs.count == 2)
    #expect(runs[0].entries.map(\.path) == ["/3"])
    #expect(runs[1].entries.map(\.path) == ["/2", "/1"])
    #expect(runs[1].start == entries[2].date)
    #expect(runs[1].bytes == 3)
    #expect(Set(runs.map(\.id)).count == 2)
    #expect(History.sessions(entries, gap: 301).count == 1)
    #expect(History.sessions([]).isEmpty)
}

@Test func historyLocalizesModulePrefixes() {
    let entries = History.parse("""
    2026-10-25T08:00:00Z\tTRASH\t1\tDeinstallieren: Foo\t/1
    2026-10-25T08:00:01Z\tTRASH\t1\tZurücksetzen: Foo: Bar\t/2
    2026-10-25T08:00:02Z\tREMOVE\t1\tProjekte: node_modules\t/3
    2026-10-25T08:00:03Z\tTRASH\t1\tSpeicheranalyse\t/4
    2026-10-25T08:00:04Z\tTRASH\t1\tStartobjekt (System)\t/5
    2026-10-25T08:00:05Z\tREMOVE\t1\tPapierkorb\t/6
    2026-10-25T08:00:06Z\tCOPIED\t1\tIrgendwas Neues: x\t/7
    2026-10-25T08:00:07Z\tTRASH\t1\tInstaller\t/8
    """).sorted { $0.id < $1.id }
    #expect(entries.map(\.module) == [L("Deinstallieren"), L("Zurücksetzen"), L("Projekte"), L("Speicher"),
                                      L("Start"), L("Aufräumen"), L("Aufräumen"), L("Installer")])
    #expect(entries[0].displayLabel == L("Deinstallieren") + ": Foo")
    #expect(entries[1].displayLabel == L("Zurücksetzen") + ": Foo: Bar")
    #expect(entries[2].displayLabel == L("Projekte") + ": node_modules")
    #expect(entries[3].displayLabel == L("Speicheranalyse"))
    #expect(entries[4].displayLabel == L("Startobjekt (System)"))
    #expect(entries[5].displayLabel == L("Papierkorb"))
    #expect(entries[6].displayLabel == "Irgendwas Neues: x")
    #expect(entries[7].displayLabel == L("Installer"))
    #expect(entries[0].actionTitle == L("In den Papierkorb"))
    #expect(entries[2].actionTitle == L("Gelöscht"))
    #expect(entries[6].actionTitle == "COPIED")
}

@Test func historyLoadsLargeLogQuickly() throws {
    let h = try FakeHome()
    var text = ""
    text.reserveCapacity(10_000_000)
    let base = 1_792_915_200
    for i in 0..<100_000 {
        let stamp = Date(timeIntervalSince1970: TimeInterval(base + i)).ISO8601Format()
        text += "\(stamp)\tTRASH\t\(i)\tDeinstallieren: App \(i % 50)\t/Users/x/Library/Caches/com.example.app\(i)/data\n"
    }
    let log = try logFile(h, text)
    let clock = ContinuousClock()
    var entries: [HistoryEntry] = []
    let elapsed = clock.measure { entries = History.load(log) }
    #expect(entries.count == 100_000)
    #expect(entries.first?.bytes == 99_999)
    #expect(elapsed < .seconds(1))
}
