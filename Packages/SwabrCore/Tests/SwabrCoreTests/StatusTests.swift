import Foundation
import Testing
@testable import SwabrCore

@Test func healthScoreUsesOwnDeductionTable() {
    let calm = HealthScore.compute(diskFree: 500_000_000_000, diskTotal: 1_000_000_000_000, uptime: 3600)
    #expect(calm.score == 100 && calm.label == L("Ausgezeichnet") && calm.issues.isEmpty)

    // A single light finding costs 5 points.
    #expect(HealthScore.compute(cpuMinuteAverage: 75).score == 95)

    let busy = HealthScore.compute(diskFree: 20_000_000_000, diskTotal: 1_000_000_000_000, pressure: .critical,
                                   cpuMinuteAverage: 95, uptime: 20 * 86_400)
    #expect(busy.score == 100 - 25 - 25 - 15 - 5)
    #expect(busy.issues.contains(L("Festplatte fast voll")))
    #expect(busy.issues.contains(L("Neustart empfohlen")))
}

@Test func batteryHealthThresholds() {
    #expect(HealthScore.batteryHealth(cycles: 105, capacity: 87).severity == .ok)
    #expect(HealthScore.batteryHealth(cycles: 1000, capacity: 90).severity == .warn)
    #expect(HealthScore.batteryHealth(cycles: 100, capacity: 55).severity == .danger)
}

@Test func psOutputIsParsed() {
    let text = """
      1   0,3  12000 Ss   launchd
    420  45.0 900000 R    Google Chrome Helper
    777   0.0      0 Z    zombie
    """
    let p = StatusSampler.parsePS(text)
    #expect(p.count == 3)
    #expect(p.top.first?.name == "Google Chrome Helper")
    #expect(p.top.first?.memory == 900_000 * 1024)
    #expect(p.zombies.map(\.pid) == [777])
}

@Test func liveSampleIsPlausible() async throws {
    let s = StatusSampler()
    _ = s.sample()
    try await Task.sleep(for: .milliseconds(300))
    let snap = s.sample()
    #expect(!snap.cpu.perCore.isEmpty)
    #expect(snap.cpu.usage >= 0 && snap.cpu.usage <= 100)
    #expect(snap.memory.total > 1 << 30 && snap.memory.used <= snap.memory.total)
    #expect(snap.disk.total > 0 && snap.disk.free > 0)
    #expect(!snap.hardware.chip.isEmpty && snap.hardware.uptime > 0)
    #expect(snap.processes.count > 10)
}
