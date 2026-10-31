import AppKit
import SwabrCore
import Observation
import SwiftUI

@MainActor @Observable
final class SlimModel {
    var candidates: [SlimCandidate] = []
    var skipped: [SlimSkip] = []
    var selected: Set<String> = []
    var scanning = false
    var scanned = false
    var working: String?
    var results: [String: AppSlimmer.Outcome] = [:]

    var chosen: [SlimCandidate] { candidates.filter { selected.contains($0.id) } }

    /// Intel code that is still in the apps (slimmed ones no longer count).
    var remainingBytes: Int64 { candidates.filter { results[$0.id]?.ok != true }.reduce(0) { $0 + $1.intelBytes } }

    private func recordSummary() {
        ScanSummary.shared.record(.slim, bytes: remainingBytes, count: candidates.filter { results[$0.id]?.ok != true }.count)
    }

    func scan() async {
        scanning = true
        results = [:]
        if let protection = try? RuleStore.protection() {
            let apps = await AppCatalog.installedApps(protection: protection)
            let privileged: RootRunner? = Edition.isStore ? nil : Privileged.run
            (candidates, skipped) = await AppSlimmer.scan(apps, runPrivileged: privileged)
        }
        selected = []
        scanning = false
        scanned = true
        recordSummary()
    }

    func slimSelected() async {
        for c in chosen {
            working = c.app.name
            let privileged: RootRunner? = Edition.isStore ? nil : Privileged.run
            let outcome = await Task.detached { AppSlimmer.slim(c, runPrivileged: privileged) }.value
            results[c.id] = outcome
            if outcome.ok { selected.remove(c.id) }
        }
        working = nil
        recordSummary()
    }
}

struct SlimView: View {
    @Bindable private var model = AppModels.shared.slim
    @State private var reviewing = false
    @State private var showSkipped = false
    @State private var search = ""
    @AppStorage("slimOrder") private var order = ListOrder.size

    private var candidates: [SlimCandidate] {
        let q = search.trimmingCharacters(in: .whitespaces)
        let hits = q.isEmpty ? model.candidates : model.candidates.filter { $0.app.name.localizedCaseInsensitiveContains(q) }
        switch order {
        case .name: return hits.sorted { $0.app.name.localizedStandardCompare($1.app.name) == .orderedAscending }
        case .newest, .oldest: return order.byDate(hits) { $0.app.lastUsed }
        default: return hits.sorted { $0.intelBytes > $1.intelBytes }
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            VStack(spacing: 0) {
            if !AppSlimmer.isAppleSilicon {
                ContentUnavailableView("Nur auf Apple-Silicon-Macs", systemImage: "cpu",
                                       description: Text("Auf einem Intel-Mac wird der Intel-Code gebraucht."))
            } else if model.scanning {
                ProgressView("Prüfe Apps auf Intel-Code …").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
            }
            footer
            }
            .pagePanel()
        }
        .pagePadding()
        .navigationTitle("Verschlanken")
        .searchable(text: $search, placement: .toolbarPrincipal, prompt: "App suchen")
        .toolbar {
            ToolbarItem(placement: .navigation) { SortMenu(order: $order) }
                .sharedBackgroundVisibility(.hidden)
        }
        .task { if !model.scanned && AppSlimmer.isAppleSilicon { await model.scan() } }
        .sheet(isPresented: $reviewing) {
            ReviewSheet(
                title: String(localized: "\(model.chosen.count) Apps verschlanken?"),
                footnote: String(localized: "Die Originale landen im Papierkorb. Ein App-Update bringt den Intel-Code zurück."),
                confirmLabel: String(localized: "Verschlanken"),
                lines: model.chosen.map {
                    ReviewLine(id: $0.id, title: $0.app.name, iconPath: $0.app.path, bytes: $0.intelBytes,
                               impact: String(localized: "Entfernt den Intel-Code aus \($0.plan.count) Dateien. Die App läuft danach nur noch auf Apple-Silicon-Macs, nicht mehr mit Rosetta oder auf Intel-Macs."),
                               warning: false)
                }
            ) { Task { await model.slimSelected() } }
        }
    }

    private var header: some View {
        PageHeader(String(localized: "Verschlanken"),
                   subtitle: String(localized: "Universal-Apps enthalten Code für Intel- und Apple-Silicon-Macs. Auf diesem Mac wird nur der Apple-Silicon-Teil genutzt."))
    }

    private var list: some View {
        List {
            Section {
                if model.candidates.isEmpty {
                    Text("Keine App mit entfernbarem Intel-Code gefunden.").foregroundStyle(.secondary)
                }
                ForEach(candidates) { c in
                    HStack(spacing: 10) {
                        Toggle("", isOn: Binding(get: { model.selected.contains(c.id) },
                                                 set: { on in if on { model.selected.insert(c.id) } else { model.selected.remove(c.id) } }))
                            .labelsHidden().toggleStyle(.checkbox)
                            .disabled(model.working != nil)
                        Image(nsImage: NSWorkspace.shared.icon(forFile: c.app.path)).resizable().frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.app.name).fontWeight(.medium)
                            if let r = model.results[c.id] {
                                Label(r.message, systemImage: r.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .font(.caption).foregroundStyle(r.ok ? .green : .red)
                            } else if model.working == c.app.name {
                                HStack { ProgressView().controlSize(.mini); Text("Wird verschlankt und geprüft …").font(.caption) }
                            } else {
                                Text("App \(DiskSize.format(c.app.bytes)) · \(c.plan.count) Dateien mit Intel-Code").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text("− \(DiskSize.format(c.intelBytes))").monospacedDigit().foregroundStyle(.green)
                    }
                }
            } header: {
                Text("Geeignete Apps · zusammen \(DiskSize.format(model.candidates.reduce(0) { $0 + $1.intelBytes }))")
            } footer: {
                Text("Jede App wird an einer Kopie verschlankt. Die Kopie ersetzt das Original nur, wenn sie den Apple-Silicon-Code behält, Code-Signatur und Gatekeeper besteht und vom selben Entwickler signiert ist.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                DisclosureGroup("Übersprungen (\(model.skipped.count))", isExpanded: $showSkipped) {
                    ForEach(model.skipped) { s in
                        HStack {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: s.app.path)).resizable().frame(width: 20, height: 20)
                            Text(s.app.name)
                            Spacer()
                            Text(s.reason).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
                .scrollContentBackground(.hidden)
    }

    private var footer: some View {
        HStack {
            Text("\(model.chosen.count) ausgewählt · \(DiskSize.format(model.chosen.reduce(0) { $0 + $1.intelBytes }))")
            Button("Alle auswählen") { model.selected = Set(model.candidates.map(\.id)) }.controlSize(.small)
            Button("Alle abwählen") { model.selected = [] }.controlSize(.small)
            Spacer()
            Button("Neu prüfen") { Task { await model.scan() } }.disabled(model.scanning || model.working != nil)
            Button("Verschlanken …") { reviewing = true }
                .buttonStyle(.prominent).disabled(model.chosen.isEmpty || model.working != nil)
        }
        .font(.callout)
        .padding(.horizontal, 18).padding(.vertical, 12)
            .background(.fill.tertiary)
    }
}
