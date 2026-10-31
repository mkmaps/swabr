import AppKit
import SwabrCore
import SwiftUI

struct CleanView: View {
    @Bindable private var model = AppModels.shared.clean
    @State private var confirming = false
    /// Category shown on the right; nil picks the first one.
    @State private var category: String?
    @State private var search = ""
    @AppStorage("cleanOrder") private var order = ListOrder.size

    private static let largeDataID = "large-data"

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .navigationTitle("Aufräumen")
        .searchable(text: $search, placement: .toolbarPrincipal, prompt: "In Ergebnissen suchen")
        .toolbar {
            ToolbarItem(placement: .navigation) { SortMenu(order: $order) }
                .sharedBackgroundVisibility(.hidden)
        }
        .alert("Fehler", isPresented: .constant(model.errorMessage != nil)) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .sheet(isPresented: $confirming) {
            ReviewSheet(
                title: String(localized: "\(DiskSize.format(model.selectedBytes)) bereinigen?"),
                footnote: model.mode == .permanent
                    ? String(localized: "Endgültig: nicht wiederherstellbar. Jede Löschung wird protokolliert.")
                    : String(localized: "Landet im Papierkorb. Speicher wird erst beim Leeren frei."),
                confirmLabel: model.mode == .permanent ? String(localized: "Endgültig löschen") : "In den Papierkorb legen",
                lines: model.reviewLines
            ) {
                Task { await model.clean() }
            }
        }
    }

    private var subtitle: String {
        let arch = VolumeInfo.isAppleSilicon ? "Apple Silicon" : "Intel"
        let free = String(localized: "Freier Speicher: \(model.freeSpace.map(DiskSize.format) ?? "–")")
        if case .review = model.phase {
            return String(localized: "\(model.items.count) Einträge gefunden") + " · " + free
        }
        return "\(arch) · \(free)"
    }

    @ViewBuilder private var content: some View {
        switch model.phase {
        case .idle:
            PageHeader(String(localized: "Aufräumen"), subtitle: subtitle).padding(.horizontal, 28).padding(.top, 8)
            StartPanel(
                module: .clean, title: String(localized: "Bereit zum Scannen"),
                text: String(localized: "Es wird zuerst nur gesucht. Gelöscht wird erst, nachdem du die Liste geprüft und bestätigt hast."),
                action: String(localized: "Scan starten")
            ) { Task { await model.scan() } }
        case .scanning, .cleaning:
            PageHeader(String(localized: "Aufräumen"), subtitle: subtitle).padding(.horizontal, 28).padding(.top, 8)
            WorkingPanel(module: .clean, title: model.phase.isCleaning ? String(localized: "Bereinige …") : String(localized: "Scanne …"),
                         detail: model.currentStep)
        case .review:
            review
        case .done(let report, let freed):
            DoneView(report: report, freed: freed, freeSpace: model.freeSpace, mode: model.mode, cleaned: model.lastCleaned) {
                model.finish()
            }
        }
    }

    // MARK: Review

    /// Categories with only the entries that match the search.
    private var sections: [(name: String, items: [CleanItem])] {
        let q = search.trimmingCharacters(in: .whitespaces)
        let found: [(name: String, items: [CleanItem])] = q.isEmpty ? model.sections : model.sections.compactMap { s in
            let hits = s.items.filter { item in
                item.label.localizedCaseInsensitiveContains(q) || item.impact.localizedCaseInsensitiveContains(q)
                    || SectionNames.german(s.name).localizedCaseInsensitiveContains(q)
                    || item.paths.contains { $0.localizedCaseInsensitiveContains(q) }
            }
            return hits.isEmpty ? nil : (s.name, hits)
        }
        let bytes = { (list: [CleanItem]) in list.filter(\.isCleanable).reduce(Int64(0)) { $0 + $1.bytes } }
        switch order {
        case .size:
            return found.map { ($0.name, $0.items.sorted { $0.bytes > $1.bytes }) }.sorted { bytes($0.items) > bytes($1.items) }
        case .name:
            return found.map { ($0.name, $0.items.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }) }
                .sorted { SectionNames.german($0.name).localizedStandardCompare(SectionNames.german($1.name)) == .orderedAscending }
        case .newest, .oldest:
            let dates = model.itemDates
            return order.byDate(found.map { ($0.name, order.byDate($0.items) { dates[$0.id] }) }) { s in s.items.compactMap { dates[$0.id] }.max() }
        case .natural:
            return found
        }
    }

    private var largeData: [DynamicRules.LargeData] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return model.largeData }
        return model.largeData.filter { $0.label.localizedCaseInsensitiveContains(q) || $0.path.localizedCaseInsensitiveContains(q) }
    }

    private var categories: [String] {
        sections.map(\.name) + (largeData.isEmpty ? [] : [Self.largeDataID])
    }

    private var current: String? {
        if let category, categories.contains(category) { return category }
        return categories.first
    }

    private var review: some View {
        VStack(spacing: 14) {
            PageHeader(String(localized: "Aufräumen"), subtitle: subtitle) {
                HStack(spacing: 2) {
                    Button("Empfohlen") { model.selectRecommended() }.help("Nur Einträge der Stufe „Sicher“")
                    Button("Alle") { model.selectAll() }
                    Button("Keine") { model.selectNone() }
                }
                .buttonStyle(.softCompact)
                Button { Task { await model.scan() } } label: { Label("Neu scannen", systemImage: "arrow.clockwise") }
                    .buttonStyle(.softCompact)
            }
            if let undo = model.lastProtection {
                HStack {
                    Image(systemName: "shield.lefthalf.filled").foregroundStyle(.green)
                    Text("Geschützt: \(undo.title)").lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Rückgängig") { model.undoProtection() }.buttonStyle(.softCompact)
                }
                .font(.callout)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.green.opacity(0.1), in: .rect(cornerRadius: 12, style: .continuous))
            }
            if model.items.isEmpty && model.largeData.isEmpty {
                ContentUnavailableView("Alles sauber", systemImage: "checkmark.seal",
                                       description: Text("Es wurde nichts zum Aufräumen gefunden."))
            } else if categories.isEmpty {
                ContentUnavailableView.search(text: search)
            } else {
                HStack(alignment: .top, spacing: 14) {
                    categoryList.frame(width: 270)
                    detail
                }
            }
        }
        .padding(.horizontal, 28).padding(.top, 8).padding(.bottom, 20)
    }

    private var categoryList: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(sections, id: \.name) { section in
                    CategoryRow(section: section.name, items: section.items, model: model, selected: current == section.name) {
                        category = section.name
                    }
                }
                if !largeData.isEmpty {
                    Button { category = Self.largeDataID } label: {
                        HStack(spacing: 10) {
                            IconTile("eye", gradient: LinearGradient(colors: [.gray.opacity(0.6), .gray], startPoint: .top, endPoint: .bottom), size: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Große Datenbestände").font(.headline)
                                Text("nur Hinweis").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(DiskSize.format(largeData.reduce(0) { $0 + $1.bytes })).font(.headline).monospacedDigit()
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(current == Self.largeDataID ? AnyShapeStyle(.background) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 12, style: .continuous))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
        .background(.fill.quaternary, in: .rect(cornerRadius: 18, style: .continuous))
    }

    private var detail: some View {
        VStack(spacing: 0) {
            if current == Self.largeDataID {
                largeDataList
            } else if let name = current, let section = sections.first(where: { $0.name == name }) {
                let figures = model.selection.category(name)
                // The category's own figures: its full size, and what is ticked in it.
                HStack(spacing: 8) {
                    Text(SectionNames.german(name)).font(.headline)
                    Text("\(section.items.count) Einträge · \(DiskSize.format(figures?.total ?? 0)) gesamt")
                        .font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(figures?.selectedEntries ?? 0) ausgewählt · \(DiskSize.format(figures?.selectedBytes ?? 0))")
                        .font(.callout.weight(.medium)).monospacedDigit()
                        .foregroundStyle((figures?.selectedEntries ?? 0) == 0 ? Color.secondary : Color.accentColor)
                }
                .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 8)
                Label("Geschützt bleiben: laufende Apps, deine Ausnahmen und alles unter /System.", systemImage: "checkmark.shield")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(.green.opacity(0.1), in: .rect(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 18).padding(.bottom, 6)
                List {
                    ForEach(section.items) { item in
                        CleanRow(item: item, isOn: Binding(
                            get: { model.selected.contains(item.id) },
                            set: { on in
                                if on { model.selected.insert(item.id) } else { model.selected.remove(item.id) }
                            }), protect: { path, scope in model.protect(path: path, scope: scope) })
                        .contextMenu {
                            Button("Nie bereinigen (schützen)") { model.protect(item) }
                            Button("Im Finder zeigen") {
                                NSWorkspace.shared.activateFileViewerSelecting(item.paths.prefix(20).map { URL(fileURLWithPath: $0) })
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
            actionBar
        }
        .background(.fill.quaternary, in: .rect(cornerRadius: 18, style: .continuous))
        .clipShape(.rect(cornerRadius: 18, style: .continuous))
    }

    private var largeDataList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Große Datenbestände (nur Hinweis)").font(.headline).padding(.horizontal, 18).padding(.top, 14)
            Text("Diese Daten löscht Swabr nicht automatisch: ob sie weg können, entscheidest du in der jeweiligen App.")
                .font(.callout).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.top, 2).padding(.bottom, 6)
            List {
                ForEach(largeData) { d in
                    HStack(alignment: .top) {
                        Image(systemName: "eye").foregroundStyle(.secondary).frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.label)
                            Text(d.hint).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(DiskSize.format(d.bytes)).monospacedDigit()
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: d.path)])
                        } label: { Label("Im Finder zeigen", systemImage: "magnifyingglass").labelStyle(.iconOnly) }
                            .buttonStyle(.borderless).help("Im Finder zeigen")
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
        }
    }

    private var selectionCaption: String {
        let names = model.selection.selectedCategoryNames.map(SectionNames.german)
        guard !names.isEmpty else { return String(localized: "Nichts ausgewählt") }
        return String(localized: "Auswahl aus: \(names.joined(separator: ", "))")
    }

    private var actionBar: some View {
        ActionBar {
            // Everything ticked in all categories: exactly what the button removes. The caption names the
            // categories it comes from, so a total that is not in the open category is not a mystery.
            AmountLabel(amount: DiskSize.format(model.selectedBytes), caption: selectionCaption)
            if model.protectedCount > 0 {
                Label("\(model.protectedCount) geschützt", systemImage: "shield")
                    .font(.caption).foregroundStyle(.secondary)
                    .help("Orte, die die Whitelist, eine laufende App oder die Sicherheitsprüfung schützen. Aufklappen zeigt sie mit Grund.")
            }
        } trailing: {
            Toggle("Endgültig löschen", isOn: Binding(get: { model.mode == .permanent }, set: { model.mode = $0 ? .permanent : .trash }))
                .toggleStyle(.switch).controlSize(.small)
                .help("Aus: Alles landet im Papierkorb und lässt sich bis zum Leeren zurückholen.")
            Button { confirming = true } label: {
                Label(model.mode == .permanent ? String(localized: "Bereinigen") : String(localized: "In den Papierkorb"),
                      systemImage: "trash")
            }
            .buttonStyle(.prominent)
            .disabled(model.selectedItems.isEmpty)
        }
    }
}

private extension CleanModel.Phase {
    var isCleaning: Bool { if case .cleaning = self { true } else { false } }
}

/// A category in the left column: tile, name, how much of it is chosen, and a box for all of it.
private struct CategoryRow: View {
    let section: String
    let items: [CleanItem]
    let model: CleanModel
    let selected: Bool
    let select: () -> Void

    var body: some View {
        let cleanable = items.filter(\.isCleanable)
        let figures = model.selection.category(section)
        let allOn = figures?.isFullySelected ?? false
        let colors = SectionNames.colors(section)
        HStack(spacing: 10) {
            // Only the entries shown: while searching, hidden entries of the category keep their state.
            Toggle("", isOn: Binding(get: { allOn }, set: { on in
                for item in cleanable { if on { model.selected.insert(item.id) } else { model.selected.remove(item.id) } }
            }))
                .labelsHidden().toggleStyle(.checkbox).disabled(cleanable.isEmpty)
            IconTile(SectionNames.symbol(section),
                     gradient: LinearGradient(colors: [Color(hex: colors.0), Color(hex: colors.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                     size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(SectionNames.german(section)).font(.headline).lineLimit(1)
                Text("\(figures?.selectedEntries ?? 0)/\(cleanable.count) ausgewählt").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            // The big number is what "Clean" would remove from this category, so the column adds up to the
            // total in the action bar; the category's full size follows in small type when it differs.
            let total = figures?.total ?? 0
            let chosenBytes = figures?.selectedBytes ?? 0
            if cleanable.isEmpty {
                Text(DiskSize.format(total)).font(.headline).monospacedDigit().foregroundStyle(.secondary)
            } else {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(DiskSize.format(chosenBytes)).font(.headline).monospacedDigit()
                        .foregroundStyle(chosenBytes > 0 ? .primary : .secondary)
                    if chosenBytes != total {
                        Text("von \(DiskSize.format(total))").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(selected ? AnyShapeStyle(.background) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(selected ? 0.06 : 0), radius: 3, y: 1)
        .contentShape(.rect)
        .onTapGesture(perform: select)
    }
}

private struct CleanRow: View {
    let item: CleanItem
    @Binding var isOn: Bool
    let protect: (String, CleanModel.ProtectionScope) -> Void
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(item.paths.prefix(100), id: \.self) { path in
                    PathLine(path: path, note: nil)
                        .contextMenu {
                            Button("Nie bereinigen: dieser Ort") { protect(path, .path) }
                            if let o = ProtectionPattern.forOwner(of: path) {
                                Button("Nie bereinigen: alles von \(o.owner)") { protect(path, .owner) }
                            }
                            if let n = ProtectionPattern.forName(of: path) {
                                Button("Nie bereinigen: alle Ordner namens „\(n.name)“") { protect(path, .name) }
                            }
                        }
                }
                if item.paths.count > 100 {
                    Text("… und \(item.paths.count - 100) weitere").foregroundStyle(.secondary).font(.caption)
                }
                ForEach(item.protected, id: \.path) { p in
                    PathLine(path: p.path, note: p.reason)
                }
            }
            .padding(.leading, 28)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.checkbox).disabled(!item.isCleanable)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label).fontWeight(.medium)
                    Text(item.impact).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
                switch item.status {
                case .ready:
                    SafetyBadge(safety: item.safety)
                    Text(DiskSize.format(item.bytes)).fontWeight(.semibold).monospacedDigit().frame(minWidth: 72, alignment: .trailing)
                case .skipped(let why):
                    LevelBadge(title: String(localized: "übersprungen"), color: .red).help(why)
                    Text(DiskSize.format(item.bytes)).foregroundStyle(.secondary).monospacedDigit().frame(minWidth: 72, alignment: .trailing)
                }
            }
            .opacity(item.isCleanable ? 1 : 0.55)
        }
        .padding(.vertical, 2)
    }
}

private struct PathLine: View {
    let path: String
    let note: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: note == nil ? "doc" : "shield").foregroundStyle(note == nil ? Color.secondary : Color.green)
            Text(path.replacingOccurrences(of: UserHome.path, with: "~"))
                .font(.caption.monospaced()).lineLimit(1).truncationMode(.middle)
            if let note { Text(note).font(.caption).foregroundStyle(.green) }
            Spacer()
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            } label: { Label("Im Finder zeigen", systemImage: "magnifyingglass").labelStyle(.iconOnly) }
                .buttonStyle(.borderless).help("Im Finder zeigen")
        }
    }
}

/// After cleaning: how much is free now, per category, and what to do next.
private struct DoneView: View {
    let report: CleanReport
    let freed: Int64?
    let freeSpace: Int64?
    let mode: Cleaner.Mode
    let cleaned: [CleanItem]
    let finish: () -> Void

    private var perSection: [(name: String, bytes: Int64)] {
        let failed = Set(report.failures.map(\.path))
        let groups = Dictionary(grouping: cleaned, by: \.section)
        return RuleStore.sectionOrder.compactMap { name in
            guard let list = groups[name] else { return nil }
            let bytes = list.filter { !$0.paths.allSatisfy(failed.contains) }.reduce(0) { $0 + $1.bytes }
            return bytes > 0 ? (name, bytes) : nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                SuccessHero()
                Text(String(localized: "\(DiskSize.format(report.removedBytes)) freigegeben"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(mode == .trash
                     ? String(localized: "\(report.removedCount) Elemente liegen im Papierkorb. Du kannst alles bis zum Leeren zurückholen.")
                     : String(localized: "\(report.removedCount) Elemente endgültig gelöscht. Jede Löschung steht im Verlauf."))
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                if !perSection.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(perSection.prefix(5), id: \.name) { s in
                            VStack(spacing: 3) {
                                Text(DiskSize.format(s.bytes)).font(.headline).monospacedDigit()
                                    .foregroundStyle(Color(hex: SectionNames.colors(s.name).1))
                                Text(SectionNames.german(s.name)).font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(.fill.quaternary, in: .rect(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .padding(.top, 6)
                }
                if let freeSpace {
                    let before = freeSpace - max(freed ?? 0, 0)
                    HStack {
                        Text("Freier Speicher").foregroundStyle(.secondary)
                        Spacer()
                        Text("\(DiskSize.format(before))  →  \(DiskSize.format(freeSpace))").fontWeight(.semibold).monospacedDigit()
                    }
                    .font(.callout)
                    .frame(maxWidth: 420)
                    .padding(.top, 4)
                }
                if !report.failures.isEmpty {
                    GroupBox("\(report.failures.count) nicht entfernt") {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(ProtectedPath.Kind.allCases, id: \.self) { kind in
                                    let group = report.failures.filter { $0.kind == kind }
                                    if !group.isEmpty {
                                        Text("\(kind.title) (\(group.count))").font(.caption.bold()).padding(.top, 4)
                                        ForEach(group, id: \.path) { PathLine(path: $0.path, note: $0.reason) }
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 180)
                    }
                    .frame(maxWidth: 640)
                }
                HStack(spacing: 10) {
                    Button { Navigator.shared.open(.history) } label: { Label("Im Verlauf ansehen", systemImage: "clock.arrow.circlepath") }
                        .buttonStyle(.soft)
                    if mode == .trash {
                        Button { NSWorkspace.shared.open(URL(fileURLWithPath: UserHome.path + "/.Trash")) } label: {
                            Label("Papierkorb öffnen", systemImage: "trash")
                        }
                        .buttonStyle(.soft)
                    }
                    Button("Fertig", action: finish).buttonStyle(.prominent)
                }
                .padding(.top, 10)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }
}
