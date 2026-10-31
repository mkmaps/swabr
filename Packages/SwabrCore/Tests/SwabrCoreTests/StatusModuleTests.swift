import Darwin
import Foundation
import Testing
@testable import SwabrCore

private let tb: Int64 = 1_000_000_000_000
private let gib: UInt64 = 1 << 30
private let day: TimeInterval = 86_400

// MARK: Health score: one test per table row

@Test(arguments: [
    (Int64(500_000_000_000), 100),  // 50 % free
    (Int64(200_000_000_000), 100),  // exactly 20 %: no deduction
    (Int64(190_000_000_000), 95),   // < 20 %
    (Int64(90_000_000_000), 85),    // < 10 %
    (Int64(40_000_000_000), 75),    // < 5 %
])
func healthDiskRow(free: Int64, expected: Int) {
    #expect(HealthScore.compute(diskFree: free, diskTotal: tb).score == expected)
}

@Test func healthDiskBelowTenGigabytesIsSevereOnSmallVolumes() {
    // 9 GB of 50 GB is 18 % free, but under 10 GB counts as severe.
    let h = HealthScore.compute(diskFree: 9_000_000_000, diskTotal: 50_000_000_000)
    #expect(h.score == 75)
    #expect(h.issues == [L("Festplatte fast voll")])
    #expect(HealthScore.compute(diskFree: 190_000_000_000, diskTotal: tb).issues == [L("Wenig freier Speicherplatz")])
}

@Test func healthUnknownDiskIsNotPenalised() {
    #expect(HealthScore.compute(diskFree: nil, diskTotal: nil).score == 100)
    #expect(HealthScore.compute(diskFree: 0, diskTotal: 0).score == 100)
}

@Test func healthPressureRow() {
    #expect(HealthScore.compute(pressure: .normal).score == 100)
    let warn = HealthScore.compute(pressure: .warn)
    #expect(warn.score == 85 && warn.issues == [L("Erhöhter Speicherdruck")])
    let critical = HealthScore.compute(pressure: .critical)
    #expect(critical.score == 75 && critical.issues == [L("Kritischer Speicherdruck")])
}

@Test func healthSwapRow() {
    #expect(HealthScore.compute(swapUsed: 2 * gib).score == 100)
    #expect(HealthScore.compute(swapUsed: 2 * gib + 1).score == 95)
    #expect(HealthScore.compute(swapUsed: 8 * gib).score == 95)
    #expect(HealthScore.compute(swapUsed: 9 * gib).score == 85)
}

@Test func healthCPURow() {
    #expect(HealthScore.compute(cpuMinuteAverage: 70).score == 100)
    #expect(HealthScore.compute(cpuMinuteAverage: 70.5).score == 95)
    #expect(HealthScore.compute(cpuMinuteAverage: 90).score == 95)
    let high = HealthScore.compute(cpuMinuteAverage: 99)
    #expect(high.score == 85 && high.issues == [L("Hohe CPU-Last")])
}

@Test func healthBatteryRow() {
    #expect(HealthScore.compute(battery: .ok).score == 100)
    #expect(HealthScore.compute(battery: .unknown).score == 100)
    #expect(HealthScore.compute(battery: .warn).score == 95)
    #expect(HealthScore.compute(battery: .danger).score == 85)
}

@Test func healthUptimeRow() {
    #expect(HealthScore.compute(uptime: 14 * day).score == 100)
    #expect(HealthScore.compute(uptime: 15 * day).score == 95)
    #expect(HealthScore.compute(uptime: 30 * day).score == 95)
    let long = HealthScore.compute(uptime: 31 * day)
    #expect(long.score == 85 && long.issues == [L("Neustart empfohlen")])
}

@Test func healthZombieRow() {
    #expect(HealthScore.compute(zombies: 0).score == 100)
    #expect(HealthScore.compute(zombies: 1).score == 95)
    #expect(HealthScore.compute(zombies: 9).score == 95)
    #expect(HealthScore.compute(zombies: 10).score == 85)
}

@Test func healthDeductionsAddUpWithOneIssueEach() {
    let h = HealthScore.compute(diskFree: 190_000_000_000, diskTotal: tb, pressure: .warn, swapUsed: 3 * gib,
                                cpuMinuteAverage: 75, uptime: 20 * day)
    #expect(h.score == 100 - 5 - 15 - 5 - 5 - 5)
    #expect(h.issues.count == 5)
    #expect(h.score == 65 && h.label == L("Mittel"))
}

@Test func healthNeverDropsBelowZero() {
    let h = HealthScore.compute(diskFree: 1, diskTotal: tb, pressure: .critical, swapUsed: 20 * gib,
                                cpuMinuteAverage: 100, battery: .danger, uptime: 90 * day, zombies: 50)
    #expect(h.score == 0)
    #expect(h.issues.count == 7)
    #expect(h.label == L("Kritisch"))
}

@Test func healthLabels() {
    #expect(HealthScore.label(for: 100) == L("Ausgezeichnet"))
    #expect(HealthScore.label(for: 90) == L("Ausgezeichnet"))
    #expect(HealthScore.label(for: 89) == L("Gut"))
    #expect(HealthScore.label(for: 75) == L("Gut"))
    #expect(HealthScore.label(for: 74) == L("Mittel"))
    #expect(HealthScore.label(for: 50) == L("Mittel"))
    #expect(HealthScore.label(for: 49) == L("Kritisch"))
    #expect(HealthScore.label(for: 0) == L("Kritisch"))
}

// MARK: Battery health

@Test func batteryHealthBoundaries() {
    #expect(HealthScore.batteryHealth(cycles: 999, capacity: 80).severity == .ok)
    #expect(HealthScore.batteryHealth(cycles: 1000, capacity: 80).severity == .warn)
    #expect(HealthScore.batteryHealth(cycles: 10, capacity: 79).severity == .warn)
    #expect(HealthScore.batteryHealth(cycles: 10, capacity: 70).severity == .warn)
    #expect(HealthScore.batteryHealth(cycles: 10, capacity: 69).severity == .danger)
    #expect(HealthScore.batteryHealth(cycles: 2000, capacity: 60).severity == .danger)
}

@Test func batteryHealthWithoutDataIsUnknown() {
    let h = HealthScore.batteryHealth(cycles: 0, capacity: 0)
    #expect(h.severity == .unknown && h.label.isEmpty)
    for (cycles, capacity) in [(10, 90), (1200, 90), (10, 50)] {
        #expect(!HealthScore.batteryHealth(cycles: cycles, capacity: capacity).label.isEmpty)
    }
}

@Test func batteryCapacityPercent() {
    // Apple silicon: MaxCapacity is a percentage, AppleRawMaxCapacity holds mAh.
    #expect(StatusSampler.capacityPercent(rawMax: 3812, max: 100, design: 4563) == 83)
    // Older Macs: MaxCapacity in mAh.
    #expect(StatusSampler.capacityPercent(rawMax: nil, max: 4000, design: 5000) == 80)
    #expect(StatusSampler.capacityPercent(rawMax: nil, max: 92, design: nil) == 92)
    #expect(StatusSampler.capacityPercent(rawMax: nil, max: nil, design: 5000) == 0)
}

@Test func batteryStatusText() {
    var b = StatusSnapshot.Battery(level: 50, isCharging: true, onACPower: true, isCharged: false, minutesRemaining: nil,
                                   cycles: 10, healthPercent: 95, temperature: nil)
    #expect(b.statusText == L("Lädt"))
    b.isCharging = false
    #expect(b.statusText == L("Angeschlossen, lädt nicht"))
    b.isCharged = true
    #expect(b.statusText == L("Geladen"))
    b.onACPower = false
    #expect(b.statusText == L("Akkubetrieb"))
}

// MARK: Network

@Test func networkRateIsSmoothedOverThreeValues() {
    var s = StatusSampler.RateSmoother()
    #expect(s.add(300) == 300)
    #expect(s.add(600) == 450)
    #expect(s.add(900) == 600)
    #expect(s.add(1200) == 900)  // 300 drops out
    #expect(s.add(0) == 700)
    s.reset()
    #expect(s.add(10) == 10)
}

@Test func proxyDescription() {
    #expect(StatusSampler.proxyDescription([:]) == nil)
    #expect(StatusSampler.proxyDescription(["HTTPEnable": 1, "HTTPProxy": "proxy.local", "HTTPPort": 3128]) == "proxy.local:3128")
    #expect(StatusSampler.proxyDescription(["HTTPEnable": 0, "HTTPProxy": "proxy.local"]) == nil)
    #expect(StatusSampler.proxyDescription(["ProxyAutoConfigEnable": 1]) == L("Automatisch (PAC)"))
}

// MARK: Memory

@Test func memoryFiguresFromFixedStatistics() {
    var vm = vm_statistics64()
    vm.active_count = 100
    vm.wire_count = 50
    vm.compressor_page_count = 25
    vm.inactive_count = 40
    vm.speculative_count = 10
    vm.external_page_count = 30
    vm.free_count = 999
    let page: UInt64 = 16_384
    let total = 1_000 * page
    let m = StatusSampler.memoryFigures(vm, pageSize: page, total: total)
    #expect(m.used == 175 * page)
    #expect(m.available == 825 * page)
    #expect(m.wired == 50 * page)
    #expect(m.compressed == 25 * page)
    #expect(m.cached == 80 * page)
}

@Test func memoryCacheNeverExceedsAvailable() {
    var vm = vm_statistics64()
    vm.active_count = 90
    vm.inactive_count = 50
    let m = StatusSampler.memoryFigures(vm, pageSize: 4096, total: 100 * 4096)
    #expect(m.used == 90 * 4096)
    #expect(m.available == 10 * 4096)
    #expect(m.cached == 10 * 4096)
}

@Test func memoryPressureLevels() {
    #expect(StatusSnapshot.Memory.Pressure(level: 1) == .normal)
    #expect(StatusSnapshot.Memory.Pressure(level: 2) == .warn)
    #expect(StatusSnapshot.Memory.Pressure(level: 4) == .critical)
    #expect(StatusSnapshot.Memory.Pressure(level: 0) == .normal)
}

// MARK: Hardware

@Test func modelNameFromProfilerOutput() {
    let json = #"{"SPHardwareDataType":[{"machine_model":"Mac14,2","machine_name":"MacBook Air"}]}"#
    #expect(ModelName.parse(Data(json.utf8)) == "MacBook Air")
    #expect(ModelName.parse(Data("garbage".utf8)) == nil)
}

// MARK: Live sanity (ranges only)

@Test func liveSamplesStayInRange() {
    let sampler = StatusSampler()
    let first = sampler.sample()
    #expect(first.cpu.usage == 0)
    #expect(first.network.downRate == 0 && first.disk.readRate == 0)
    let s = sampler.sample()
    #expect(s.cpu.usage >= 0 && s.cpu.usage <= 100)
    #expect(s.cpu.perCore.allSatisfy { $0 >= 0 && $0 <= 100 })
    #expect(s.memory.used + s.memory.available == s.memory.total)
    #expect(s.memory.cached <= s.memory.available)
    #expect(s.disk.free <= s.disk.total)
    #expect(s.network.downRate >= 0 && s.network.upRate >= 0)
    #expect(s.processes.top.count <= 5)
    #expect(s.processes.top.allSatisfy { $0.cpu >= 0 })
    #expect((0...100).contains(s.health.score))
    #expect(!s.health.label.isEmpty)
    if let b = s.battery {
        #expect((0...100).contains(b.level))
        #expect(b.healthPercent >= 0 && b.healthPercent <= 150)
    }
}
