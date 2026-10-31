import Foundation
import SwabrCore
import Observation

@MainActor @Observable
final class StatusModel {
    struct Point: Identifiable {
        let id: Int
        let value: Double
    }

    static let historyLength = 60
    static var interval: Duration { .milliseconds(Int(Prefs.statusInterval * 1000)) }
    /// One sampler for the window and the menu bar, so nothing is measured twice.
    static let shared = StatusModel()

    private var consumers = 0
    private var loop: Task<Void, Never>?

    /// Starts sampling for one more consumer (window, menu bar); stops when the last one leaves.
    func acquire() {
        consumers += 1
        if loop == nil { loop = Task { await run() } }
    }

    func release() {
        consumers = max(0, consumers - 1)
        if consumers == 0 {
            loop?.cancel()
            loop = nil
        }
    }

    var snapshot: StatusSnapshot?
    var cpuHistory: [Point] = []
    var downHistory: [Point] = []
    var upHistory: [Point] = []
    var readHistory: [Point] = []
    var writeHistory: [Point] = []
    private var tick = 0
    private let sampler = StatusSampler()

    /// Samples until the loop task is cancelled.
    private func run() async {
        while !Task.isCancelled {
            let sampler = sampler
            let s = await Task.detached { sampler.sample() }.value
            record(s)
            try? await Task.sleep(for: Self.interval)
        }
    }

    private func record(_ s: StatusSnapshot) {
        // The first sample has no previous counters, so its rates are zero; keep the values, skip the graphs.
        defer { snapshot = s }
        guard snapshot != nil else { return }
        tick += 1
        func push(_ list: inout [Point], _ v: Double) {
            list.append(Point(id: tick, value: v))
            if list.count > Self.historyLength { list.removeFirst(list.count - Self.historyLength) }
        }
        push(&cpuHistory, s.cpu.usage)
        push(&downHistory, s.network.downRate)
        push(&upHistory, s.network.upRate)
        push(&readHistory, s.disk.readRate)
        push(&writeHistory, s.disk.writeRate)
    }
}

enum Rate {
    static func format(_ bytesPerSecond: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file) + "/s"
    }

    static func memory(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}
