import SwabrCore
import SwiftUI

/// Compact dashboard shown from the menu bar: health, what can go, live values and shortcuts into the app.
struct MenuBarDashboard: View {
    let model: StatusModel
    let openApp: () -> Void
    let openSettings: () -> Void
    var openModule: (Module) -> Void = { _ in }
    private let summary = ScanSummary.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let s = model.snapshot {
                header(s)
                reclaimable
                HStack(spacing: 8) {
                    mini("CPU", String(format: "%.0f %%", s.cpu.usage), s.cpu.usage / 100, Brand.blue)
                    mini("RAM", String(format: "%.0f %%", s.memory.usedPercent), s.memory.usedPercent / 100, Brand.purple)
                    mini("SSD", String(format: "%.0f %%", s.disk.usedPercent), s.disk.usedPercent / 100, Brand.teal)
                }
                Sparkline(series: [("CPU", model.cpuHistory, Brand.blue)], percent: true).frame(height: 40)
                HStack {
                    Text("↓ \(Rate.format(s.network.downRate))")
                    Spacer()
                    Text("↑ \(Rate.format(s.network.upRate))")
                    if let b = s.battery {
                        Spacer()
                        Label("\(b.level) %", systemImage: "battery.100percent")
                    }
                }
                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                actions
                footer
            } else {
                ProgressView("Messe …").frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private func header(_ s: StatusSnapshot) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text("Swabr").font(.headline)
                Text("Zustand \(s.health.score) · \(s.health.label)")
                    .font(.caption.weight(.medium)).foregroundStyle(HealthColor.of(s.health.score))
                if !s.health.issues.isEmpty {
                    Text(s.health.issues.joined(separator: " · ")).font(.caption2).foregroundStyle(.orange).lineLimit(1)
                }
            }
            Spacer()
            Button { openSettings() } label: { Image(systemName: "gearshape") }
                .buttonStyle(.borderless).help("Einstellungen")
        }
    }

    private var reclaimable: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                if summary.hasAny {
                    Text(DiskSize.format(summary.reclaimableBytes))
                        .font(.system(size: 22, weight: .semibold, design: .rounded)).monospacedDigit()
                    Text("können weg").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Noch nicht geprüft").font(.headline)
                    Text("Wie viel Platz kann weg?").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                openModule(.overview)
                if !summary.hasAny { Task { await OverviewModel.shared.scanAll() } }
            } label: { Label("Prüfen", systemImage: "sparkles") }
                .buttonStyle(.prominent)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(LinearGradient(colors: [Brand.blue.opacity(0.12), Brand.purple.opacity(0.12)], startPoint: .leading, endPoint: .trailing),
                    in: .rect(cornerRadius: 16, style: .continuous))
    }

    private func mini(_ label: String, _ value: String, _ fraction: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(value).font(.caption.weight(.semibold)).monospacedDigit()
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.fill.tertiary)
                    Capsule().fill(color).frame(width: g.size.width * max(0, min(fraction, 1)))
                }
            }
            .frame(height: 4)
        }
        .padding(10)
        .background(.fill.quaternary, in: .rect(cornerRadius: 12, style: .continuous))
    }

    private var actions: some View {
        VStack(spacing: 0) {
            action(.clean, summary.badge(.clean) ?? "")
            action(.optimize, "")
            action(.uninstall, summary.entry(.uninstall).map { String(localized: "\($0.count) Updates") } ?? "")
            action(.status, "")
        }
        .padding(.vertical, 4)
        .background(.fill.quaternary, in: .rect(cornerRadius: 14, style: .continuous))
    }

    private func action(_ module: Module, _ detail: String) -> some View {
        Button { openModule(module) } label: {
            HStack(spacing: 10) {
                IconTile(module: module, size: 26)
                Text(module.title).font(.callout.weight(.medium))
                Spacer()
                if !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(.secondary) }
                Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.shield.fill").foregroundStyle(.green)
            Text("Schutz aktiv").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Swabr öffnen", action: openApp).buttonStyle(.borderless).font(.caption.weight(.medium))
            Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                .buttonStyle(.borderless).help("Swabr beenden")
        }
    }
}
