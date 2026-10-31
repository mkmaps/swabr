import AppKit
import Charts
import SwabrCore
import SwiftUI

struct StatusView: View {
    private let model = StatusModel.shared
    @State private var search = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                PageHeader(String(localized: "Status"), subtitle: subtitle) {
                    Label("live", systemImage: "circle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(.green)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.green.opacity(0.14), in: .capsule)
                    Button {
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
                    } label: { Label("Aktivitätsanzeige", systemImage: "gauge.with.dots.needle.67percent") }
                        .buttonStyle(.softCompact)
                }
                if let s = model.snapshot {
                    HStack(alignment: .top, spacing: 14) {
                        HealthHeader(snapshot: s).frame(width: 300)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                            CPUCard(cpu: s.cpu, history: model.cpuHistory)
                            MemoryCard(memory: s.memory)
                            DiskCard(disk: s.disk, read: model.readHistory, write: model.writeHistory)
                            NetworkCard(network: s.network, down: model.downHistory, up: model.upHistory)
                            PowerCard(battery: s.battery)
                            ProcessCard(processes: s.processes, cores: s.cpu.perCore.count, filter: search)
                        }
                    }
                } else {
                    WorkingPanel(module: .status, title: String(localized: "Messe …")).frame(minHeight: 300)
                }
            }
            .pagePadding()
        }
        .navigationTitle("Status")
        .searchable(text: $search, placement: .toolbarPrincipal, prompt: "Prozess suchen")
        .onAppear { model.acquire() }
        .onDisappear { model.release() }
    }

    private var subtitle: String? {
        guard let hw = model.snapshot?.hardware else { return nil }
        return "\(hw.model) · \(hw.chip) · \(Rate.memory(hw.memoryBytes)) · \(hw.osVersion)"
    }
}

// MARK: Header

/// Health score in the brand ring with the facts it is made of.
struct HealthHeader: View {
    let snapshot: StatusSnapshot

    var body: some View {
        let h = snapshot.health
        let s = snapshot
        VStack(spacing: 12) {
            GradientRing(value: Double(h.score) / 100, lineWidth: 14) {
                VStack(spacing: 0) {
                    Text("\(h.score)").font(.system(size: 48, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("von 100").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(width: 170, height: 170)
            .padding(.top, 6)
            Text("Zustand: \(h.label)").font(.title3.bold())
            Text(h.issues.isEmpty ? String(localized: "Keine Auffälligkeiten") : h.issues.joined(separator: " · "))
                .font(.callout).foregroundStyle(h.issues.isEmpty ? Color.secondary : .orange)
                .multilineTextAlignment(.center)
            VStack(spacing: 6) {
                fact("memorychip", .green, String(localized: "Speicherdruck"), pressure(s.memory.pressure))
                if let t = s.battery?.temperature { fact("thermometer.medium", .blue, String(localized: "Temperatur"), String(format: "%.0f °C", t)) }
                if let b = s.battery { fact("battery.100percent", .green, String(localized: "Akku · \(b.cycles) Zyklen"), "\(b.level) %") }
                fact("internaldrive", .purple, String(localized: "Freier Speicher"), DiskSize.format(s.disk.free))
                fact("clock", .secondary, String(localized: "Läuft seit"), uptime(s.hardware.uptime))
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 18)
        .animation(.easeInOut, value: h.score)
        .help("Berechnet aus CPU, Speicher, Festplatte, Ein-/Ausgabe, Akku und Laufzeit")
    }

    private func fact(_ symbol: String, _ color: Color, _ title: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 18)
            Text(title)
            Spacer()
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
        .font(.callout)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.fill.tertiary, in: .rect(cornerRadius: 11, style: .continuous))
    }

    private func pressure(_ p: StatusSnapshot.Memory.Pressure) -> String {
        switch p {
        case .normal: String(localized: "Normal")
        case .warn: String(localized: "Erhöht")
        case .critical: String(localized: "Kritisch")
        }
    }

    private func uptime(_ t: TimeInterval) -> String {
        let f = DateComponentsFormatter()
        f.allowedUnits = t >= 86_400 ? [.day, .hour] : [.hour, .minute]
        f.unitsStyle = .abbreviated
        return f.string(from: t) ?? "–"
    }
}

// MARK: Cards

private struct Card<Content: View>: View {
    let title: LocalizedStringKey
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .card(padding: 18)
    }
}

struct Meter: View {
    let label: LocalizedStringKey
    let value: Double
    var text: String?

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary).frame(width: 78, alignment: .leading)
            ProgressView(value: min(max(value, 0), 100), total: 100).tint(tint)
            Text(text ?? String(format: "%.1f %%", value)).monospacedDigit().frame(width: 92, alignment: .trailing)
        }
        .font(.callout)
    }

    private var tint: Color { value > 85 ? .red : value > 65 ? .orange : .accentColor }
}

private struct Line: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary).frame(width: 78, alignment: .leading)
            Text(value).textSelection(.enabled)
            Spacer()
        }
        .font(.callout)
    }
}

struct Sparkline: View {
    let series: [(String, [StatusModel.Point], Color)]
    var percent = false

    var body: some View {
        Chart {
            ForEach(series, id: \.0) { name, points, color in
                ForEach(points) { p in
                    AreaMark(x: .value("t", p.id), y: .value(name, p.value), series: .value("s", name))
                        .foregroundStyle(color.opacity(0.15))
                    LineMark(x: .value("t", p.id), y: .value(name, p.value), series: .value("s", name))
                        .foregroundStyle(color)
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 2)) { v in
                AxisGridLine()
                AxisValueLabel {
                    if let d = v.as(Double.self) { Text(percent ? "\(Int(d)) %" : Rate.format(d)).font(.caption2) }
                }
            }
        }
        .chartYScale(domain: percent ? 0...100 : 0...max(1, series.flatMap { $0.1.map(\.value) }.max() ?? 1))
        .frame(height: 60)
    }
}

private struct CPUCard: View {
    let cpu: StatusSnapshot.CPU
    let history: [StatusModel.Point]

    var body: some View {
        Card(title: "CPU", symbol: "cpu") {
            Meter(label: "Gesamt", value: cpu.usage)
            Line(label: "Last", value: String(format: "%.2f / %.2f / %.2f", cpu.load.0, cpu.load.1, cpu.load.2) + "  " + String(localized: "(\(cpu.perCore.count) Kerne)"))
            Sparkline(series: [("CPU", history, .accentColor)], percent: true)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(cpu.perCore.enumerated()), id: \.offset) { i, v in
                    VStack(spacing: 2) {
                        GeometryReader { g in
                            VStack { Spacer(minLength: 0); RoundedRectangle(cornerRadius: 2).fill(v > 85 ? Color.red : .accentColor)
                                .frame(height: max(2, g.size.height * v / 100)) }
                        }
                        Text("\(i + 1)").font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                    .help(String(localized: "Kern \(i + 1): \(Int(v.rounded())) %"))
                }
            }
            .frame(height: 40)
        }
    }
}

private struct MemoryCard: View {
    let memory: StatusSnapshot.Memory

    var body: some View {
        Card(title: "Arbeitsspeicher", symbol: "memorychip") {
            Meter(label: "Belegt", value: memory.usedPercent)
            Line(label: "Gesamt", value: String(localized: "\(Rate.memory(memory.used)) von \(Rate.memory(memory.total))"))
            Line(label: "Verfügbar", value: Rate.memory(memory.available))
            Line(label: "Fest/Kompr.", value: "\(Rate.memory(memory.wired)) · \(Rate.memory(memory.compressed))")
            Line(label: "Auslagerung", value: memory.swapTotal > 0 ? String(localized: "\(Rate.memory(memory.swapUsed)) von \(Rate.memory(memory.swapTotal))") : String(localized: "keine"))
            HStack {
                Text("Druck").foregroundStyle(.secondary).frame(width: 78, alignment: .leading)
                let (text, color): (String, Color) = switch memory.pressure {
                case .normal: (String(localized: "Normal"), .green)
                case .warn: (String(localized: "Erhöht"), .orange)
                case .critical: (String(localized: "Kritisch"), .red)
                }
                Label(text, systemImage: "circle.fill").foregroundStyle(color).labelStyle(.titleAndIcon)
            }
            .font(.callout)
        }
    }
}

private struct DiskCard: View {
    let disk: StatusSnapshot.Disk
    let read: [StatusModel.Point]
    let write: [StatusModel.Point]

    var body: some View {
        Card(title: "Festplatte", symbol: "internaldrive") {
            Meter(label: "Belegt", value: disk.usedPercent)
            Line(label: "Frei", value: String(localized: "\(DiskSize.format(disk.free)) von \(DiskSize.format(disk.total))"))
            Line(label: "Lesen", value: Rate.format(disk.readRate))
            Line(label: "Schreiben", value: Rate.format(disk.writeRate))
            Sparkline(series: [("Lesen", read, .blue), ("Schreiben", write, .pink)])
        }
    }
}

private struct PowerCard: View {
    let battery: StatusSnapshot.Battery?

    var body: some View {
        Card(title: "Energie", symbol: "battery.100percent.bolt") {
            if let b = battery {
                Meter(label: "Ladung", value: Double(b.level), text: "\(b.level) %")
                Line(label: "Status", value: b.statusText + (b.minutesRemaining.map { String(localized: " · noch \($0 / 60) h \($0 % 60) min") } ?? ""))
                let health = HealthScore.batteryHealth(cycles: b.cycles, capacity: b.healthPercent)
                Line(label: "Zustand", value: [health.label, b.healthPercent > 0 ? String(localized: "\(b.healthPercent) % Kapazität") : nil, String(localized: "\(b.cycles) Zyklen")]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                if let t = b.temperature { Line(label: "Temperatur", value: String(format: "%.1f °C", t)) }
            } else {
                Text("Kein Akku: Mac am Netzteil").foregroundStyle(.secondary)
            }
        }
    }
}

private struct NetworkCard: View {
    let network: StatusSnapshot.Network
    let down: [StatusModel.Point]
    let up: [StatusModel.Point]

    var body: some View {
        Card(title: "Netzwerk", symbol: "arrow.up.arrow.down") {
            Line(label: "Empfangen", value: Rate.format(network.downRate))
            Line(label: "Senden", value: Rate.format(network.upRate))
            Sparkline(series: [("Empfangen", down, .green), ("Senden", up, .orange)])
            Line(label: "Verbindung", value: [network.interface, network.address].compactMap { $0 }.joined(separator: " · ").ifEmpty("offline"))
            if let p = network.proxy { Line(label: "Proxy", value: p) }
        }
    }
}

private struct ProcessCard: View {
    let processes: StatusSnapshot.Processes
    let cores: Int
    var filter = ""

    var body: some View {
        Card(title: "Prozesse", symbol: "list.bullet.rectangle") {
            Line(label: "Anzahl", value: "\(processes.count)" + (processes.zombies.isEmpty ? "" : String(localized: " · \(processes.zombies.count) Zombies")))
            ForEach(processes.top.filter { filter.isEmpty || $0.name.localizedCaseInsensitiveContains(filter) }.prefix(7)) { p in
                HStack {
                    Text(p.name).lineLimit(1).frame(width: 150, alignment: .leading)
                    // ps reports per core, so a busy process can exceed 100 %.
                    ProgressView(value: min(p.cpu / Double(max(cores, 1)), 100), total: 100)
                    Text(String(format: "%.1f %%", p.cpu)).monospacedDigit().frame(width: 62, alignment: .trailing)
                    Text(Rate.memory(p.memory)).monospacedDigit().foregroundStyle(.secondary).frame(width: 70, alignment: .trailing)
                }
                .font(.callout)
                .help("PID \(p.pid)")
            }
            Button("Aktivitätsanzeige öffnen") {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
            }
            .buttonStyle(.link).font(.caption)
        }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}

enum HealthColor {
    static func of(_ score: Int) -> Color { score >= 85 ? .green : score >= 65 ? .yellow : score >= 45 ? .orange : .red }
}
