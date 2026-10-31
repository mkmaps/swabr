import AppKit
import SwabrCore
import Observation
import SwiftUI

@MainActor @Observable
final class ProjectsModel {
    /// Direct edition: config file (with defaults); App Store edition: the folders the user granted.
    var roots: [String] = Edition.isStore ? FolderAccess.paths : ProjectPurge.roots()
    var artifacts: [ProjectArtifact] = []
    var selected: Set<String> = []
    var scanning = false
    var scanned = false
    var toTrash = false
    var result: CleanReport?

    var projects: [(project: String, items: [ProjectArtifact])] {
        Dictionary(grouping: artifacts, by: \.project).map { ($0.key, $0.value) }
            .sorted { $0.items.reduce(0) { $0 + $1.bytes } > $1.items.reduce(0) { $0 + $1.bytes } }
    }

    var chosen: [ProjectArtifact] { artifacts.filter { selected.contains($0.id) } }
    var chosenBytes: Int64 { chosen.reduce(0) { $0 + $1.bytes } }

    func scan() async {
        scanning = true
        result = nil
        Prefs.applyToCore()
        artifacts = await ProjectPurge.scan(roots: roots)
        // Only artifacts untouched for the configured number of days (7 by default) start ticked.
        selected = Set(artifacts.filter { !$0.recent && !$0.inUse }.map(\.id))
        scanning = false
        scanned = true
        recordSummary()
    }

    func addRoot() {
        let picked = FolderAccess.choose(prompt: String(localized: "Als Suchort hinzufügen"))
        guard !picked.isEmpty else { return }
        roots = Array(Set(roots + picked)).sorted()
        if !Edition.isStore { try? ProjectPurge.saveRoots(roots) }
    }

    func removeRoot(_ root: String) {
        roots.removeAll { $0 == root }
        if Edition.isStore { FolderAccess.forget(root) } else { try? ProjectPurge.saveRoots(roots) }
    }

    func delete() async {
        let items = chosen, roots = roots, trash = toTrash
        let privileged: (@Sendable (String) -> String?)? = Edition.isStore ? nil : Privileged.run
        result = await Task.detached { ProjectPurge.delete(items, roots: roots, toTrash: trash, runPrivileged: privileged) }.value
        artifacts.removeAll { a in items.contains(a) && !(result?.failures.contains { $0.path == a.path } ?? false) }
        selected = []
        recordSummary()
    }

    var removableBytes: Int64 { artifacts.filter { !$0.inUse }.reduce(0) { $0 + $1.bytes } }

    private func recordSummary() {
        ScanSummary.shared.record(.purge, bytes: removableBytes, count: artifacts.filter { !$0.inUse }.count)
    }
}

struct ProjectsView: View {
    @Bindable private var model = AppModels.shared.projects
    @State private var reviewing = false
    @State private var search = ""
    @AppStorage("projectsOrder") private var order = ListOrder.size

    private var projects: [(project: String, items: [ProjectArtifact])] {
        let q = search.trimmingCharacters(in: .whitespaces)
        let hits: [(project: String, items: [ProjectArtifact])] = q.isEmpty ? model.projects : model.projects.compactMap { g in
            if g.project.localizedCaseInsensitiveContains(q) { return g }
            let hits = g.items.filter { $0.name.localizedCaseInsensitiveContains(q) }
            return hits.isEmpty ? nil : (g.project, hits)
        }
        switch order {
        case .size, .natural: return hits
        case .name: return hits.sorted { ($0.project as NSString).lastPathComponent.localizedStandardCompare(($1.project as NSString).lastPathComponent) == .orderedAscending }
        case .newest, .oldest: return order.byDate(hits) { $0.items.compactMap(\.lastActivity).max() }
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            PageHeader(String(localized: "Projekte"), subtitle: String(localized: "Build-Ordner, die sich jederzeit neu erzeugen lassen")) {
                Button("Ordner hinzufügen …") { model.addRoot() }.buttonStyle(.softCompact)
                Button { Task { await model.scan() } } label: { Label("Neu suchen", systemImage: "arrow.clockwise") }
                    .buttonStyle(.softCompact).disabled(model.scanning)
            }
            rootsBar
            VStack(spacing: 0) {
            if let r = model.result {
                Label(String(localized: "\(r.removedCount) Build-Ordner entfernt, \(DiskSize.format(r.removedBytes)) frei")
                      + (r.failures.isEmpty ? "" : String(localized: " · \(r.failures.count) nicht entfernt (\(r.failures.map(\.reason).joined(separator: ", ")))")),
                      systemImage: r.failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(r.failures.isEmpty ? .green : .orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18).padding(.vertical, 12)
            .background(.fill.tertiary)
                Divider()
            }
            content
            footer
            }
            .pagePanel()
        }
        .pagePadding()
        .navigationTitle("Projekte")
        .toolbar {
            ToolbarItem(placement: .navigation) { SortMenu(order: $order) }
                .sharedBackgroundVisibility(.hidden)
        }
        .searchable(text: $search, placement: .toolbarPrincipal, prompt: "Projekt oder Ordner suchen")
        .task { if !model.scanned { await model.scan() } }
        .sheet(isPresented: $reviewing) {
            ReviewSheet(
                title: String(localized: "\(model.chosen.count) Build-Ordner entfernen?"),
                footnote: model.toTrash ? String(localized: "Landet im Papierkorb, Speicher wird erst beim Leeren frei.")
                    : String(localized: "Wird endgültig gelöscht, lässt sich aber jederzeit neu erzeugen."),
                confirmLabel: model.toTrash ? String(localized: "In den Papierkorb legen") : String(localized: "Endgültig löschen"),
                lines: model.chosen.map {
                    ReviewLine(id: $0.id, title: "\(($0.project as NSString).lastPathComponent)/\($0.name)", iconPath: nil,
                               bytes: $0.bytes, impact: $0.impact, warning: $0.recent)
                }
            ) { Task { await model.delete() } }
        }
    }

    private var rootsBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.roots.isEmpty {
                Text("Kein Suchort. Füge den Ordner hinzu, in dem deine Projekte liegen.").foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(model.roots, id: \.self) { root in
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                            Text(root.replacingOccurrences(of: UserHome.path, with: "~")).lineLimit(1)
                            Button { model.removeRoot(root) } label: { Image(systemName: "xmark.circle.fill") }
                                .buttonStyle(.borderless).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.secondary.opacity(0.12), in: .capsule)
                    }
                }
            }
        }
        .font(.callout)
    }

    @ViewBuilder private var content: some View {
        if model.scanning {
            WorkingPanel(module: .purge, title: String(localized: "Suche Build-Ordner …"))
        } else if model.artifacts.isEmpty {
            ContentUnavailableView("Keine Build-Ordner gefunden", systemImage: "hammer",
                                   description: Text("Gesucht wird nach node_modules, target, build, dist, .venv, Pods und 28 weiteren Arten, bis 6 Ebenen tief."))
        } else {
            List {
                ForEach(projects, id: \.project) { group in
                    Section {
                        ForEach(group.items) { a in ArtifactRow(artifact: a, model: model) }
                    } header: {
                        HStack {
                            Image(systemName: "folder")
                            Text(group.project.replacingOccurrences(of: UserHome.path, with: "~")).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text(DiskSize.format(group.items.reduce(0) { $0 + $1.bytes })).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.inset)
                .scrollContentBackground(.hidden)
        }
    }

    private var footer: some View {
        HStack {
            Text("\(model.chosen.count) ausgewählt · \(DiskSize.format(model.chosenBytes))")
            Button("Alle auswählen") { model.selected = Set(model.artifacts.filter { !$0.inUse }.map(\.id)) }.controlSize(.small)
            Button("Alle abwählen") { model.selected = [] }.controlSize(.small)
            Spacer()
            Toggle("In den Papierkorb statt löschen", isOn: $model.toTrash).toggleStyle(.checkbox)
            Button("Entfernen …") { reviewing = true }
                .buttonStyle(.destructiveProminent).disabled(model.chosen.isEmpty)
        }
        .font(.callout)
        .padding(.horizontal, 18).padding(.vertical, 12)
            .background(.fill.tertiary)
    }
}

private struct ArtifactRow: View {
    let artifact: ProjectArtifact
    let model: ProjectsModel

    var body: some View {
        let a = artifact
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(get: { model.selected.contains(a.id) },
                                     set: { on in if on { model.selected.insert(a.id) } else { model.selected.remove(a.id) } }))
                .labelsHidden().toggleStyle(.checkbox)
                .disabled(a.inUse)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(a.name).font(.body.monospaced())
                    if a.inUse {
                        Text("Prozess läuft im Projekt").font(.caption2.weight(.medium))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(.red.opacity(0.15), in: .capsule).foregroundStyle(.red)
                            .help("Ein laufendes Programm arbeitet in diesem Projekt (z. B. ein Entwicklungsserver). Der Ordner wird nicht entfernt.")
                    } else if a.recent {
                        Text("in den letzten \(ProjectPurge.recentDays) Tagen benutzt").font(.caption2.weight(.medium))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(.orange.opacity(0.15), in: .capsule).foregroundStyle(.orange)
                    }
                }
                Text(a.impact).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(a.lastActivity.map { $0.formatted(.relative(presentation: .named)) } ?? "–").font(.caption).foregroundStyle(.secondary)
            Text(DiskSize.format(a.bytes)).monospacedDigit().frame(width: 80, alignment: .trailing)
        }
        .contextMenu {
            Button("Im Finder zeigen") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: a.path)]) }
        }
    }
}
