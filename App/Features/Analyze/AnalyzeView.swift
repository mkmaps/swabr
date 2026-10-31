import AppKit
import SwabrCore
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

struct AnalyzeView: View {
    @State private var model = AnalyzeModel()
    @State private var previewURL: URL?
    @State private var pendingTrash: [DiskEntry] = []

    var body: some View {
        VStack(spacing: 14) {
            PageHeader(String(localized: "Speicher"), subtitle: String(localized: "Frei: \(model.freeSpace.map(DiskSize.format) ?? "–")"))
            VStack(spacing: 0) {
            breadcrumb
            Divider()
            if model.current.path.isEmpty, let growth = model.listing?.growth {
                GrowthBanner(report: growth, open: { model.open(path: $0) })
                Divider()
            }
            ZStack {
                switch model.viewMode {
                case .list: table
                case .treemap:
                    TreemapView(
                        entries: model.visibleEntries, checked: model.checked, canCheck: model.canTrash,
                        toggle: model.toggleChecked, open: model.open)
                }
                if model.loading { loadingOverlay }
            }
            footer
            }
            .pagePanel()
        }
        .pagePadding()
        .navigationTitle("Speicher")
        .searchable(text: $model.filter, placement: .toolbarPrincipal, prompt: "Filtern")
        .toolbar { toolbar }
        .inspector(isPresented: $model.showLargeFiles) {
            LargeFilesView(files: model.listing?.largeFiles ?? [], preview: { previewURL = $0 }) { pendingTrash = [$0] }
                .inspectorColumnWidth(min: 280, ideal: 340)
        }
        .quickLookPreview($previewURL)
        .sheet(isPresented: Binding(get: { !pendingTrash.isEmpty }, set: { if !$0 { pendingTrash = [] } })) {
            let items = pendingTrash
            ReviewSheet(
                title: items.count == 1 ? String(localized: "„\(items[0].name)“ in den Papierkorb legen?") : String(localized: "\(items.count) Objekte in den Papierkorb legen?"),
                footnote: String(localized: "Lässt sich bis zum Leeren aus dem Papierkorb wiederherstellen."),
                confirmLabel: "In den Papierkorb legen",
                lines: model.reviewLines(for: items)
            ) {
                Task { await model.moveToTrash(items.map(\.path)) }
            }
        }
        .alert("Nicht alles verschoben", isPresented: .constant(!model.failures.isEmpty)) {
            Button("OK") { model.failures = [] }
        } message: {
            Text(model.failures.map { "\(($0.path as NSString).lastPathComponent): \($0.reason)" }.joined(separator: "\n"))
        }
        .overlay {
            if Edition.isStore, model.current.path.isEmpty, FolderAccess.paths.isEmpty {
                ContentUnavailableView {
                    Label("Ordner auswählen", systemImage: "folder.badge.plus")
                } description: {
                    Text("Wähle die Ordner, deren Speicherbelegung du sehen möchtest. Swabr merkt sich den Zugriff.")
                } actions: {
                    Button("Ordner hinzufügen …") { model.addFolders() }.buttonStyle(.prominent)
                }
                .background(.background)
            }
        }
        .task { model.start() }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button { model.back() } label: { Label("Zurück", systemImage: "chevron.left").labelStyle(.iconOnly) }
                .disabled(model.stack.count < 2).help("Zurück")
        }
        ToolbarItem(placement: .navigation) { SortMenu(order: $model.order) }
            .sharedBackgroundVisibility(.hidden)
        ToolbarItemGroup {
            if Edition.isStore {
                Button { model.addFolders() } label: { Label("Ordner hinzufügen", systemImage: "folder.badge.plus") }
                    .help("Ordner zum Analysieren auswählen")
            }
            Picker("Ansicht", selection: $model.viewMode) {
                Label("Liste", systemImage: "list.bullet").labelStyle(.iconOnly).tag(AnalyzeModel.ViewMode.list)
                Label("Kacheln", systemImage: "square.grid.2x2").labelStyle(.iconOnly).tag(AnalyzeModel.ViewMode.treemap)
            }
            .pickerStyle(.segmented)
            Button { model.load(force: true) } label: { Label("Neu messen", systemImage: "arrow.clockwise").labelStyle(.iconOnly) }
                .help("Neu messen")
            Toggle(isOn: $model.showLargeFiles) { Label("Größte Dateien", systemImage: "doc.badge.ellipsis").labelStyle(.iconOnly) }
                .help("Größte Dateien")
        }
    }

    private var breadcrumb: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(model.stack.enumerated()), id: \.offset) { index, location in
                    if index > 0 { Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) }
                    Button(location.name) { model.go(to: index) }
                        .buttonStyle(.borderless)
                        .fontWeight(index == model.stack.count - 1 ? .semibold : .regular)
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(.fill.tertiary)
        }
    }

    private var table: some View {
        let total = max(model.listing?.totalBytes ?? 1, 1)
        return Table(model.visibleEntries, selection: $model.selection) {
            TableColumn("") { e in
                Toggle("", isOn: Binding(get: { model.checked.contains(e.path) }, set: { _ in model.toggleChecked(e.path) }))
                    .labelsHidden().toggleStyle(.checkbox)
                    .disabled(!model.canTrash)
            }
            .width(22)
            TableColumn("Name") { e in
                HStack(spacing: 6) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: e.path)).resizable().frame(width: 18, height: 18)
                    Text(e.name).lineLimit(1)
                    if e.isCleanable { Badge(text: "entfernbar", color: .green) }
                    if let note = e.note { Badge(text: LocalizedStringKey(note), color: .secondary) }
                }
            }
            TableColumn("Art") { e in
                Text(FileKind.describe(e)).foregroundStyle(.secondary).lineLimit(1)
            }
            .width(min: 70, ideal: 110)
            TableColumn("Anteil") { e in
                let share = Double(e.bytes) / Double(total)
                HStack {
                    ProgressView(value: min(share, 1)).progressViewStyle(.linear)
                    Text(share.formatted(.percent.precision(.fractionLength(1)))).monospacedDigit()
                        .frame(width: 52, alignment: .trailing).foregroundStyle(.secondary)
                }
            }
            .width(min: 120, ideal: 170)
            TableColumn(String(localized: "Größe")) { e in
                Text(DiskSize.format(e.bytes) + (e.partial ? "+" : "")).monospacedDigit()
                    .help(e.partial ? String(localized: "Teilweise gemessen: einige Einträge waren nicht lesbar") : "")
            }
            .width(min: 80, ideal: 90)
            TableColumn(String(localized: "Geändert")) { e in
                Text(e.modified?.formatted(date: .abbreviated, time: .omitted) ?? "–").foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 100)
        }
        .scrollContentBackground(.hidden)
        .contextMenu(forSelectionType: String.self) { ids in
            let items = model.entries(for: ids)
            Button("Im Finder zeigen") {
                NSWorkspace.shared.activateFileViewerSelecting(items.map { URL(fileURLWithPath: $0.path) })
            }
            if let first = items.first {
                Button("Übersicht (Quick Look)") { previewURL = URL(fileURLWithPath: first.path) }
            }
            if model.canTrash {
                Button(items.allSatisfy { model.checked.contains($0.path) } ? String(localized: "Abwählen") : String(localized: "Auswählen")) {
                    let on = !items.allSatisfy { model.checked.contains($0.path) }
                    for i in items { if on { model.checked.insert(i.path) } else { model.checked.remove(i.path) } }
                }
                Divider()
                Button("In den Papierkorb …", role: .destructive) { pendingTrash = items }
            }
        } primaryAction: { ids in
            if let e = model.entries(for: ids).first {
                if e.isDirectory { model.open(e) } else { NSWorkspace.shared.open(URL(fileURLWithPath: e.path)) }
            }
        }
        .onKeyPress(.space) {
            guard let p = model.selection.first else { return .ignored }
            previewURL = previewURL == nil ? URL(fileURLWithPath: p) : nil
            return .handled
        }
    }

    private var loadingOverlay: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Messe \(model.current.name) …").font(.headline)
            if model.progress.total > 0 {
                Text("\(model.progress.done) von \(model.progress.total) Einträgen").foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
    }

    private var footer: some View {
        HStack {
            if let l = model.listing {
                Text("\(l.entries.count) Einträge · \(DiskSize.format(l.totalBytes))\(l.partial ? "+" : "")")
            }
            Text("· Frei: \(model.freeSpace.map(DiskSize.format) ?? "–")").foregroundStyle(.secondary)
            Spacer()
            if model.canTrash {
                let items = model.entries(for: model.checked)
                if items.isEmpty {
                    Text("Kästchen anklicken, um Objekte auszuwählen").foregroundStyle(.secondary)
                    Button("Alle auswählen") { model.checkAllVisible() }.disabled(model.visibleEntries.isEmpty)
                } else {
                    Text("\(items.count) ausgewählt · \(DiskSize.format(items.reduce(0) { $0 + $1.bytes }))")
                    Button("Auswahl leeren") { model.checked = [] }
                    Button("In den Papierkorb …", role: .destructive) { pendingTrash = items }
                        .buttonStyle(.destructiveProminent)
                }
            } else {
                Text("Doppelklick öffnet einen Ort").foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .padding(.horizontal, 18).padding(.vertical, 12)
            .background(.fill.tertiary)
    }
}

/// Short, human description of a file type for the "Art" column.
enum FileKind {
    static func describe(_ e: DiskEntry) -> String {
        let url = URL(fileURLWithPath: e.path)
        if e.isDirectory {
            if url.pathExtension == "app" { return String(localized: "App") }
            if e.isCleanable { return String(localized: "Entwicklerdateien") }
            return e.name.hasPrefix(".") ? String(localized: "Versteckter Ordner") : String(localized: "Ordner")
        }
        guard let type = UTType(filenameExtension: url.pathExtension) else { return String(localized: "Datei") }
        if type.conforms(to: .movie) { return String(localized: "Video") }
        if type.conforms(to: .audio) { return String(localized: "Audio") }
        if type.conforms(to: .image) { return String(localized: "Bild") }
        if type.conforms(to: .diskImage) { return String(localized: "Festplattenimage") }
        if type.conforms(to: .archive) { return String(localized: "Archiv") }
        if ["pkg", "mpkg"].contains(url.pathExtension.lowercased()) { return String(localized: "Installer") }
        if type.conforms(to: .sourceCode) { return String(localized: "Quellcode") }
        if type.conforms(to: .pdf) || type.conforms(to: .presentation) || type.conforms(to: .spreadsheet)
            || type.conforms(to: .text) { return String(localized: "Dokument") }
        if type.conforms(to: .database) { return String(localized: "Datenbank") }
        if url.pathExtension.lowercased() == "log" { return String(localized: "Protokoll") }
        return String(localized: "Datei")
    }
}

private struct Badge: View {
    let text: LocalizedStringKey
    let color: Color

    var body: some View {
        Text(text).font(.caption2.weight(.medium))
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(color.opacity(0.15), in: .capsule)
            .foregroundStyle(color)
    }
}

private struct LargeFilesView: View {
    let files: [DiskEntry]
    let preview: (URL) -> Void
    let trash: (DiskEntry) -> Void

    var body: some View {
        List {
            Section("Größte Dateien") {
                if files.isEmpty { Text("Keine Dateien über 1 MB").foregroundStyle(.secondary) }
                ForEach(files) { f in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(f.name).lineLimit(1)
                            Spacer()
                            Text(DiskSize.format(f.bytes)).monospacedDigit().bold()
                        }
                        Text((f.path as NSString).deletingLastPathComponent.replacingOccurrences(of: UserHome.path, with: "~"))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                    .contextMenu {
                        Button("Im Finder zeigen") {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: f.path)])
                        }
                        Button("Übersicht (Quick Look)") { preview(URL(fileURLWithPath: f.path)) }
                        Divider()
                        Button("In den Papierkorb …", role: .destructive) { trash(f) }
                    }
                }
            }
        }
    }
}


/// "Grown since yesterday": shown on the overview when the disk grew by 1 GB or more.
private struct GrowthBanner: View {
    let report: GrowthReport
    let open: (String) -> Void
    @State private var expanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            if report.items.isEmpty {
                Text("Der Zuwachs liegt außerhalb deines Benutzerordners, etwa bei System-Updates oder lokalen Time-Machine-Schnappschüssen.")
                    .font(.callout).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(report.items) { item in
                HStack(spacing: 8) {
                    Image(systemName: item.isDirectory ? "folder" : "doc").foregroundStyle(.secondary).frame(width: 16)
                    Text(verbatim: shortPath(item.path)).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Text(verbatim: "+" + DiskSize.format(item.grown)).monospacedDigit().foregroundStyle(.orange)
                    Text(verbatim: DiskSize.format(item.now)).monospacedDigit().foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                }
                .contentShape(.rect)
                .onTapGesture(count: 2) {
                    if item.isDirectory { open(item.path) } else { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)]) }
                }
                .contextMenu {
                    Button("Im Finder zeigen") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)]) }
                }
                .help("Doppelklick: öffnen")
            }
        } label: {
            Label {
                Text("Seit \(report.since.formatted(date: .abbreviated, time: .omitted)) um \(DiskSize.format(report.volumeGrowth)) gewachsen")
                    .font(.headline)
            } icon: {
                Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
            .background(.fill.tertiary)
        .background(Color.orange.opacity(0.06))
    }

    private func shortPath(_ path: String) -> String {
        path.hasPrefix(UserHome.path + "/") ? "~" + path.dropFirst(UserHome.path.count) : path
    }
}
