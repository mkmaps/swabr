import AppKit
import SwabrCore
import Observation
import QuickLook
import SwiftUI

@MainActor @Observable
final class InstallerModel {
    var files: [InstallerFile] = []
    var selected: Set<String> = [] { didSet { if scanned { recordSummary() } } }
    var scanning = false
    var scanned = false
    var message: String?

    var chosen: [InstallerFile] { files.filter { selected.contains($0.id) } }

    private func recordSummary() {
        ScanSummary.shared.record(.installer, bytes: chosen.reduce(0) { $0 + $1.bytes }, count: chosen.count,
                                  found: files.reduce(0) { $0 + $1.bytes })
    }

    func scan() async {
        scanning = true
        files = await Task.detached { InstallerFinder.scan() }.value
        // The preselection setting: nothing by default; otherwise every installer (software that is already
        // installed no longer needs its installer).
        selected = Prefs.preselect == .none ? [] : Set(files.map(\.id))
        scanning = false
        scanned = true
        recordSummary()
    }

    /// Installers go to the Trash: they are often hard to download again.
    func remove() async {
        let items = chosen
        var removed = 0
        var bytes: Int64 = 0
        var failed: [String] = []
        var needRoot: [InstallerFile] = []
        let log = OperationLog()
        for f in items {
            guard f.path.hasPrefix(UserHome.path + "/"), PathSafety.check(f.path, home: UserHome.path) == .ok else {
                failed.append(f.name)
                continue
            }
            do {
                try FileManager.default.trashItem(at: URL(fileURLWithPath: f.path), resultingItemURL: nil)
                log.record(action: "TRASH", path: f.path, bytes: f.bytes, label: "Installer")
                removed += 1
                bytes += f.bytes
            } catch where RootTrash.isPermission(error) && !Edition.isStore {
                needRoot.append(f)
            } catch {
                failed.append(f.name)
            }
        }
        // Installers that belong to root go to the Trash in one administrator step (off the main thread:
        // the password prompt itself needs it).
        if !needRoot.isEmpty {
            let paths = needRoot.map(\.path)
            let moved = await Task.detached {
                RootTrash.move(paths, allowedRoots: [UserHome.path + "/"], runPrivileged: Privileged.run)
            }.value
            for f in needRoot {
                if moved[f.path] != nil {
                    log.record(action: "TRASH", path: f.path, bytes: f.bytes, label: "Installer")
                    removed += 1
                    bytes += f.bytes
                } else {
                    failed.append(f.name)
                }
            }
        }
        files.removeAll { f in items.contains(f) && !failed.contains(f.name) }
        selected = []
        recordSummary()
        let size = DiskSize.format(bytes)
        let names = failed.joined(separator: ", ")
        message = String(localized: "\(removed) Installer in den Papierkorb gelegt (\(size))")
            + (failed.isEmpty ? "" : String(localized: " · nicht möglich: \(names)"))
    }
}

struct InstallerView: View {
    @Bindable private var model = AppModels.shared.installer
    @State private var reviewing = false
    @State private var preview: URL?
    @State private var search = ""
    @AppStorage("installerOrder") private var order = ListOrder.newest

    private var files: [InstallerFile] {
        let q = search.trimmingCharacters(in: .whitespaces)
        let hits = q.isEmpty ? model.files : model.files.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.source.localizedCaseInsensitiveContains(q) }
        switch order {
        case .size, .natural: return hits.sorted { $0.bytes > $1.bytes }
        case .name: return hits.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .newest, .oldest: return order.byDate(hits, \.modified)
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            PageHeader(String(localized: "Installer"), subtitle: String(localized: "Durchsucht: Downloads, Schreibtisch, Dokumente, Mail und Telegram."))
            VStack(spacing: 0) {
            if model.scanning {
                WorkingPanel(module: .installer, title: String(localized: "Suche Installer …"))
            } else if model.files.isEmpty {
                ContentUnavailableView("Keine Installer gefunden", systemImage: "shippingbox",
                                       description: Text(model.message ?? String(localized: "Durchsucht: Downloads, Schreibtisch, Dokumente, Mail und Telegram.")))
            } else {
                List {
                    Section {
                        ForEach(files) { f in
                            HStack(spacing: 10) {
                                Toggle("", isOn: Binding(get: { model.selected.contains(f.id) },
                                                         set: { on in if on { model.selected.insert(f.id) } else { model.selected.remove(f.id) } }))
                                    .labelsHidden().toggleStyle(.checkbox)
                                Image(nsImage: NSWorkspace.shared.icon(forFile: f.path)).resizable().frame(width: 24, height: 24)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(f.name).lineLimit(1)
                                    Text("\(f.source) · \(f.modified?.formatted(date: .abbreviated, time: .omitted) ?? "–")")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(DiskSize.format(f.bytes)).monospacedDigit()
                            }
                            .contextMenu {
                                Button("Im Finder zeigen") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: f.path)]) }
                                Button("Übersicht (Quick Look)") { preview = URL(fileURLWithPath: f.path) }
                            }
                        }
                    } header: {
                        Text("\(model.files.count) Installer · \(DiskSize.format(model.files.reduce(0) { $0 + $1.bytes }))")
                    } footer: {
                        if let m = model.message { Text(m).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
            HStack {
                Text("\(model.chosen.count) ausgewählt · \(DiskSize.format(model.chosen.reduce(0) { $0 + $1.bytes }))")
                Button("Alle auswählen") { model.selected = Set(model.files.map(\.id)) }.controlSize(.small)
                Button("Alle abwählen") { model.selected = [] }.controlSize(.small)
                Spacer()
                Button("Neu suchen") { Task { await model.scan() } }.disabled(model.scanning)
                Button("In den Papierkorb …") { reviewing = true }
                    .buttonStyle(.destructiveProminent).disabled(model.chosen.isEmpty)
            }
            .font(.callout)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(.fill.tertiary)
            }
            .pagePanel()
        }
        .pagePadding()
        .navigationTitle("Installer")
        .toolbar {
            ToolbarItem(placement: .navigation) { SortMenu(order: $order) }
                .sharedBackgroundVisibility(.hidden)
        }
        .searchable(text: $search, placement: .toolbarPrincipal, prompt: "Installer suchen")
        .quickLookPreview($preview)
        .task { if !model.scanned { await model.scan() } }
        .sheet(isPresented: $reviewing) {
            ReviewSheet(
                title: String(localized: "\(model.chosen.count) Installer entfernen?"),
                footnote: String(localized: "Landet im Papierkorb und lässt sich bis zum Leeren wiederherstellen."),
                confirmLabel: String(localized: "In den Papierkorb legen"),
                lines: model.chosen.map {
                    ReviewLine(id: $0.id, title: $0.name, iconPath: $0.path, bytes: $0.bytes,
                               impact: String(localized: "Installationsdatei aus \($0.source). Bereits installierte Programme bleiben erhalten; für eine Neuinstallation musst du sie erneut laden."),
                               warning: false)
                }
            ) { Task { await model.remove() } }
        }
    }
}
