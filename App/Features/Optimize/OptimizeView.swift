import SwabrCore
import SwiftUI

struct OptimizeView: View {
    @State private var model = OptimizeModel()
    @State private var reviewing = false
    @State private var search = ""
    @AppStorage("optimizeOrder") private var order = ListOrder.name

    private var tasks: [OptimizeTask] {
        let q = search.trimmingCharacters(in: .whitespaces)
        let hits = q.isEmpty ? model.tasks : model.tasks.filter { $0.title.localizedCaseInsensitiveContains(q) || $0.summary.localizedCaseInsensitiveContains(q) }
        switch order {
        case .name: return hits.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .newest, .oldest: return order.byDate(hits) { model.lastRun[$0.id] }
        // Tasks have no size: the ones with noticeable effects and administrator rights come first.
        case .size: return hits.sorted { ($0.noticeable ? 2 : 0) + ($0.needsAdmin ? 1 : 0) > ($1.noticeable ? 2 : 0) + ($1.needsAdmin ? 1 : 0) }
        case .natural: return hits
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            VStack(spacing: 0) {
            List {
                ForEach(tasks) { task in
                    TaskRow(task: task, isOn: model.selected.contains(task.id), result: model.results[task.id],
                            running: model.phase == .running) { model.toggle(task.id) }
                }
            }
            .listStyle(.inset)
                .scrollContentBackground(.hidden)
            footer
            }
            .pagePanel()
        }
        .pagePadding()
        .navigationTitle("Optimieren")
        .searchable(text: $search, placement: .toolbarPrincipal, prompt: "Aufgabe suchen")
        .toolbar {
            ToolbarItem(placement: .navigation) { SortMenu(order: $order) }
                .sharedBackgroundVisibility(.hidden)
        }
        .sheet(isPresented: $reviewing) {
            ReviewSheet(
                title: String(localized: "\(model.chosen.count) Wartungsaufgaben ausführen?"),
                footnote: model.adminCount > 0
                    ? String(localized: "\(model.adminCount) Aufgaben brauchen Administratorrechte: Das Passwort wird einmal für alle abgefragt.")
                    : String(localized: "Keine Aufgabe braucht ein Passwort."),
                confirmLabel: String(localized: "Optimieren"),
                lines: model.reviewLines
            ) {
                Task { await model.run() }
            }
        }
    }

    private var header: some View {
        PageHeader(String(localized: "Optimieren"),
                   subtitle: String(localized: "Wartung für Finder, Netzwerk, Datenbanken und macOS-Dienste. Unnötige Schritte werden mit Begründung übersprungen.")) {
            Button("Alle auswählen") { model.selected = Set(model.tasks.map(\.id)) }
                .disabled(model.selected.count == model.tasks.count)
            Button("Alle abwählen") { model.selected = [] }
                .disabled(model.selected.isEmpty)
        }
        .buttonStyle(.softCompact)
        .disabled(model.phase == .running)
    }

    private var footer: some View {
        HStack {
            switch model.phase {
            case .running:
                ProgressView().controlSize(.small)
                Text(model.currentStep).foregroundStyle(.secondary)
                Spacer()
            case .done:
                Label(model.summary, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                Spacer()
                Text("\(model.chosen.count) ausgewählt").foregroundStyle(.secondary)
                Button("Erneut ausführen …") { reviewing = true }.disabled(model.chosen.isEmpty)
            case .ready:
                Text("\(model.chosen.count) von \(model.tasks.count) ausgewählt" + (model.adminCount > 0 ? String(localized: " · \(model.adminCount) mit Passwort") : ""))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Optimieren …") { reviewing = true }
                    .buttonStyle(.prominent).disabled(model.chosen.isEmpty)
            }
        }
        .font(.callout)
        .padding(.horizontal, 18).padding(.vertical, 12)
            .background(.fill.tertiary)
    }
}

private struct TaskRow: View {
    let task: OptimizeTask
    let isOn: Bool
    let result: OptimizeOutcome?
    let running: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: Binding(get: { isOn }, set: { _ in toggle() }))
                .labelsHidden().toggleStyle(.checkbox).disabled(running)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(task.title).fontWeight(.medium)
                    if task.needsAdmin {
                        Label("Passwort", systemImage: "lock").font(.caption2).labelStyle(.titleAndIcon)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.secondary.opacity(0.15), in: .capsule).foregroundStyle(.secondary)
                    }
                    if task.noticeable {
                        Image(systemName: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                            .help("Spürbare Nebenwirkung, siehe Beschreibung")
                    }
                }
                Text(task.summary).font(.callout).foregroundStyle(.secondary)
                Text(task.impact).font(.caption).foregroundStyle(task.noticeable ? .orange : .secondary)
                if let result {
                    Label(result.message, systemImage: symbol(result)).font(.callout).foregroundStyle(color(result))
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func symbol(_ r: OptimizeOutcome) -> String {
        switch r {
        case .applied: "checkmark.circle.fill"
        case .unchanged: "equal.circle"
        case .skipped: "forward.circle"
        case .attention: "exclamationmark.triangle.fill"
        case .failed: "xmark.circle.fill"
        case .unavailable: "minus.circle"
        }
    }

    private func color(_ r: OptimizeOutcome) -> Color {
        switch r {
        case .applied: .green
        case .unchanged, .unavailable, .skipped: .secondary
        case .attention: .orange
        case .failed: .red
        }
    }
}
