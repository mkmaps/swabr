import SwabrCore
import SwiftUI

/// Everything ticked in all categories, with the same boxes as the page: what "Clean" would remove.
struct SelectionSheet: View {
    @Bindable var model: CleanModel
    @Environment(\.dismiss) private var dismiss
    @State private var expanded: Set<String> = []

    private var categories: [(name: String, items: [CleanItem])] {
        model.sections.compactMap { s in
            let cleanable = s.items.filter(\.isCleanable)
            return cleanable.isEmpty ? nil : (s.name, cleanable.sorted { $0.bytes > $1.bytes })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Was gelöscht wird").font(.title2.bold())
                Text("Angehakte Einträge aller Kategorien. Änderungen hier gelten auch auf der Seite.")
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            Divider()
            List {
                ForEach(categories, id: \.name) { category in
                    Section {
                        ForEach(category.items) { item in entryRow(item) }
                    } header: {
                        header(category.name, items: category.items)
                    }
                }
            }
            .listStyle(.inset)
            Divider()
            HStack {
                AmountLabel(amount: DiskSize.format(model.selectedBytes),
                            caption: String(localized: "\(model.selection.selectedEntries) Einträge · \(model.selectedCount) Elemente"))
                Spacer()
                Button("Fertig") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 680, height: 600)
    }

    private func header(_ name: String, items: [CleanItem]) -> some View {
        let figures = model.selection.category(name)
        return HStack(spacing: 8) {
            // Same box as on the page: tick, dash for a part, empty for nothing.
            Toggle(sources: items.map { item in binding(item) }, isOn: \.self) { EmptyView() }
                .labelsHidden().toggleStyle(.checkbox)
            Text(SectionNames.german(name)).font(.headline)
            Spacer()
            Text("\(figures?.selectedEntries ?? 0)/\(items.count) ausgewählt · \(DiskSize.format(figures?.selectedBytes ?? 0))")
                .font(.callout).monospacedDigit().foregroundStyle(.secondary)
        }
    }

    private func entryRow(_ item: CleanItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Toggle(isOn: binding(item)) { EmptyView() }.labelsHidden().toggleStyle(.checkbox)
                Button {
                    if expanded.contains(item.id) { expanded.remove(item.id) } else { expanded.insert(item.id) }
                } label: {
                    Label(item.label, systemImage: expanded.contains(item.id) ? "chevron.down" : "chevron.right")
                }
                .buttonStyle(.borderless)
                if item.safety == .review {
                    Text("Prüfen").font(.caption2.weight(.semibold)).foregroundStyle(.orange)
                }
                Spacer()
                Text("\(item.paths.count) Elemente").font(.caption).foregroundStyle(.secondary)
                Text(DiskSize.format(item.bytes)).monospacedDigit().frame(minWidth: 70, alignment: .trailing)
            }
            if expanded.contains(item.id) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(item.paths.prefix(30), id: \.self) { path in
                        Text(PathDisplay.short(path)).font(.caption.monospaced()).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    if item.paths.count > 30 {
                        Text("… und \(item.paths.count - 30) weitere").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .padding(.leading, 30)
            }
        }
        .padding(.vertical, 2)
    }

    private func binding(_ item: CleanItem) -> Binding<Bool> {
        Binding(get: { model.selected.contains(item.id) },
                set: { on in if on { model.selected.insert(item.id) } else { model.selected.remove(item.id) } })
    }
}

/// Everything the scan found but leaves alone, grouped by the reason. Nothing of it is ever removed.
struct ProtectedSheet: View {
    let model: CleanModel
    @Environment(\.dismiss) private var dismiss

    private struct Entry: Identifiable {
        let id = UUID()
        let path: String
        let reason: String
        let label: String
    }

    private var groups: [(kind: ProtectedPath.Kind, entries: [Entry])] {
        var byKind: [ProtectedPath.Kind: [Entry]] = [:]
        for item in model.items {
            for p in item.protected {
                byKind[p.kind, default: []].append(Entry(path: p.path, reason: p.reason, label: item.label))
            }
        }
        return ProtectedPath.Kind.allCases.compactMap { kind in
            byKind[kind].map { (kind, $0.sorted { $0.path < $1.path }) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Geschützt – wird nicht gelöscht", systemImage: "shield.lefthalf.filled").font(.title2.bold())
                Text("Diese Orte hat der Scan gefunden, Swabr lässt sie aber stehen: laufende Apps, deine Ausnahmen und geschützte Bereiche.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            Divider()
            List {
                ForEach(groups, id: \.kind) { group in
                    Section("\(group.kind.title) (\(group.entries.count))") {
                        ForEach(group.entries) { e in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(PathDisplay.short(e.path)).font(.callout.monospaced()).lineLimit(1).truncationMode(.middle)
                                Text("\(e.label) · \(e.reason)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            .padding(.vertical, 1)
                        }
                    }
                }
            }
            .listStyle(.inset)
            Divider()
            HStack {
                Text("\(model.protectedCount) Orte geschützt").foregroundStyle(.secondary)
                Spacer()
                Button("Fertig") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 680, height: 560)
    }
}

/// Paths in the home folder written with "~", as people know them.
enum PathDisplay {
    static func short(_ path: String) -> String {
        let home = UserHome.path
        return path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
    }
}
