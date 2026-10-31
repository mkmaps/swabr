import AppKit
import SwabrCore
import SwiftUI

/// Every removal Swabr logged, grouped into runs.
struct HistoryView: View {
    @State private var entries: [HistoryEntry] = []
    @State private var search = ""
    @State private var expanded: Set<Int> = []
    @AppStorage("historyOrder") private var order = ListOrder.newest

    private var sessions: [HistorySession] {
        let filtered = search.isEmpty ? entries : entries.filter {
            $0.path.localizedCaseInsensitiveContains(search) || $0.displayLabel.localizedCaseInsensitiveContains(search)
        }
        let sessions = History.sessions(filtered)
        switch order {
        case .oldest: return sessions.reversed().map { HistorySession(id: $0.id, entries: $0.entries.reversed()) }
        case .size: return sessions.sorted { $0.bytes > $1.bytes }
        case .name: return sessions.sorted { $0.modules.joined(separator: ", ").localizedStandardCompare($1.modules.joined(separator: ", ")) == .orderedAscending }
        default: return sessions
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            PageHeader(String(localized: "Verlauf"), subtitle: String(localized: "Jede Löschung, jedes Verschieben in den Papierkorb und jede verschlankte App"))
            VStack(spacing: 0) {
            if entries.isEmpty {
                ContentUnavailableView("Noch nichts entfernt", systemImage: "clock.arrow.circlepath",
                                       description: Text("Hier erscheint jede Löschung, jedes Verschieben in den Papierkorb und jede verschlankte App."))
            } else {
                List {
                    ForEach(sessions) { session in
                        Section {
                            DisclosureGroup(isExpanded: Binding(
                                get: { expanded.contains(session.id) },
                                set: { if $0 { expanded.insert(session.id) } else { expanded.remove(session.id) } })) {
                                ForEach(session.entries) { e in EntryRow(entry: e) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(session.start.formatted(date: .abbreviated, time: .shortened)).fontWeight(.medium)
                                        Text(session.modules.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(session.entries.count) Einträge").foregroundStyle(.secondary)
                                    Text(DiskSize.format(session.bytes)).monospacedDigit().frame(width: 90, alignment: .trailing)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
            HStack {
                let total = entries.reduce(Int64(0)) { $0 + $1.bytes }
                Text("\(entries.count) Einträge · insgesamt \(DiskSize.format(total))").foregroundStyle(.secondary)
                Spacer()
                Button("Protokolldatei zeigen") {
                    NSWorkspace.shared.activateFileViewerSelecting([OperationLog().url])
                }
                .disabled(!FileManager.default.fileExists(atPath: OperationLog().url.path))
                Button { reload() } label: { Image(systemName: "arrow.clockwise") }.help("Neu laden")
            }
            .font(.callout)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(.fill.tertiary)
            }
            .pagePanel()
        }
        .pagePadding()
        .navigationTitle("Verlauf")
        .toolbar {
            ToolbarItem(placement: .navigation) { SortMenu(order: $order) }
                .sharedBackgroundVisibility(.hidden)
        }
        .searchable(text: $search, placement: .toolbarPrincipal, prompt: "Pfad oder Bereich suchen")
        .onAppear(perform: reload)
    }

    private func reload() {
        entries = History.load()
        if let newest = History.sessions(entries).first { expanded.insert(newest.id) }
    }
}

private struct EntryRow: View {
    let entry: HistoryEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.action == "TRASH" ? "trash" : entry.action == "REBUILT" ? "scissors" : "xmark.bin")
                .foregroundStyle(.secondary).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.path.replacingOccurrences(of: UserHome.path, with: "~"))
                    .font(.caption.monospaced()).lineLimit(1).truncationMode(.middle)
                Text("\(entry.actionTitle) · \(entry.displayLabel) · \(entry.date.formatted(date: .omitted, time: .standard))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text(DiskSize.format(entry.bytes)).font(.caption).monospacedDigit()
        }
        .contextMenu {
            if entry.action == "TRASH" {
                Button("Papierkorb öffnen") { NSWorkspace.shared.open(URL(fileURLWithPath: UserHome.path + "/.Trash")) }
            }
            Button("Pfad kopieren") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.path, forType: .string)
            }
        }
    }
}
