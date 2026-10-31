import AppKit
import SwabrCore
import SwiftUI

/// One line of the "what will happen" review before anything is removed.
struct ReviewLine: Identifiable {
    let id: String
    let title: String
    let iconPath: String?
    let bytes: Int64
    let impact: String
    let warning: Bool
}

/// Final check before deleting: lists every item with what removing it means.
struct ReviewSheet: View {
    let title: String
    let footnote: String
    let confirmLabel: String
    let lines: [ReviewLine]
    let confirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var warnings: [ReviewLine] { lines.filter(\.warning) }
    private var others: [ReviewLine] { lines.filter { !$0.warning } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title2.bold())
                Text("\(lines.count) Einträge · \(DiskSize.format(lines.reduce(0) { $0 + $1.bytes }))")
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            Divider()
            List {
                if !warnings.isEmpty {
                    Section {
                        ForEach(warnings) { ReviewRow(line: $0) }
                    } header: {
                        Label("Bitte prüfen", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                }
                if !others.isEmpty {
                    Section("Auswirkungen") {
                        ForEach(others) { ReviewRow(line: $0) }
                    }
                }
            }
            .listStyle(.inset)
            Divider()
            HStack(alignment: .center) {
                Label(footnote, systemImage: "info.circle").font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Abbrechen", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(confirmLabel, role: .destructive) {
                    dismiss()
                    confirm()
                }
                .buttonStyle(.borderedProminent).tint(.red)
            }
            .padding(16)
        }
        .frame(width: 620, height: 520)
    }
}

private struct ReviewRow: View {
    let line: ReviewLine

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let p = line.iconPath {
                Image(nsImage: NSWorkspace.shared.icon(forFile: p)).resizable().frame(width: 24, height: 24)
            } else {
                Image(systemName: line.warning ? "exclamationmark.triangle" : "checkmark.circle")
                    .foregroundStyle(line.warning ? .orange : .green).frame(width: 24)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(line.title).bold().lineLimit(1)
                    Spacer()
                    Text(DiskSize.format(line.bytes)).monospacedDigit()
                }
                Text(line.impact).font(.callout).foregroundStyle(line.warning ? .orange : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}

struct SafetyBadge: View {
    let safety: Safety

    var body: some View {
        LevelBadge(title: safety.title, color: safety == .safe ? .green : .orange)
            .help(safety.help)
    }
}
