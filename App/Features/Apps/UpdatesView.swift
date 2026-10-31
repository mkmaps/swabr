import AppKit
import SwabrCore
import Observation
import SwiftUI

@MainActor @Observable
final class UpdatesModel {
    static let ignoredKey = "ignoredUpdates"

    var report = UpdateReport()
    var loading = false
    var checkedAt: Date?
    /// Per app path: progress or result of an update.
    var status: [String: String] = [:]
    var failed: Set<String> = []
    var working: Set<String> = []
    /// Ticked updates for "Ausgewählte aktualisieren".
    var selected: Set<String> = []
    var batchRunning = false
    /// "path|version" pairs the user chose to hide.
    var ignored: Set<String> = Set(UserDefaults.standard.stringArray(forKey: UpdatesModel.ignoredKey) ?? []) {
        didSet { UserDefaults.standard.set(Array(ignored), forKey: Self.ignoredKey) }
    }

    var visible: [AppUpdate] { report.updates.filter { !ignored.contains(key($0)) } }
    var hidden: [AppUpdate] { report.updates.filter { ignored.contains(key($0)) } }

    func key(_ u: AppUpdate) -> String { "\(u.app.path)|\(u.available)" }

    func check() async {
        loading = true
        if let protection = try? RuleStore.protection() {
            let apps = await AppCatalog.installedApps(protection: protection)
            report = await AppUpdateChecker.check(apps)
        }
        selected = selected.intersection(report.updates.map(\.id))
        checkedAt = Date()
        loading = false
        ScanSummary.shared.record(.uninstall, bytes: 0, count: visible.count)
    }

    func running(_ u: AppUpdate) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == u.app.bundleID }
    }

    /// App Store edition: the store may not install other apps (guideline 2.4.5 iv, vii), so it opens where the
    /// update comes from: the App Store's update page or the vendor's website.
    func openSource(_ u: AppUpdate) {
        if u.source == .appStore {
            NSWorkspace.shared.open(URL(string: "macappstore://showUpdatesPage")!)
            status[u.id] = String(localized: "Im App Store unter „Updates“ auf „Aktualisieren“ klicken")
        } else if let url = u.link ?? u.download {
            NSWorkspace.shared.open(url)
            status[u.id] = String(localized: "Website des Herstellers geöffnet")
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: u.app.path))
            status[u.id] = String(localized: "App geöffnet: dort nach Updates suchen")
        }
    }

    /// Quits the app if needed, updates it from its source and starts it again if it was running.
    func update(_ u: AppUpdate) async {
        if Edition.isStore { return openSource(u) }
        working.insert(u.id)
        failed.remove(u.id)
        defer { working.remove(u.id) }

        let wasRunning = running(u)
        if let app = wasRunning {
            status[u.id] = String(localized: "Beende \(u.app.name) …")
            app.terminate()
            for _ in 0..<20 where running(u) != nil { try? await Task.sleep(for: .milliseconds(500)) }
            if running(u) != nil { return fail(u, String(localized: "\(u.app.name) ließ sich nicht beenden. Bitte selbst beenden und erneut versuchen.")) }
        }

        let result: (ok: Bool, message: String)
        switch u.source {
        case .homebrew:
            status[u.id] = String(localized: "Homebrew aktualisiert …")
            let token = u.caskToken ?? ""
            result = await Task.detached { AppUpdateChecker.upgradeCask(token) }.value
        case .appStore:
            if let id = u.storeID, AppUpdateChecker.mas != nil {
                status[u.id] = String(localized: "App Store aktualisiert …")
                result = await Task.detached { AppUpdateChecker.upgradeStoreApp(id) }.value
            } else {
                NSWorkspace.shared.open(URL(string: "macappstore://showUpdatesPage")!)
                status[u.id] = String(localized: "Im App Store unter „Updates“ auf „Aktualisieren“ klicken")
                return
            }
        case .sparkle, .vendor:
            let id = u.id
            let report: @Sendable (String) -> Void = { [weak self] s in Task { @MainActor in self?.status[id] = s } }
            do {
                switch try await AppInstaller.install(u, privilegedTrash: FinderTrash.move, progress: report) {
                case .installed(let v): result = (true, String(localized: "Aktualisiert auf \(v)"))
                case .openedInstaller:
                    status[u.id] = String(localized: "Installationsprogramm geöffnet: dort abschließen")
                    return
                }
            } catch {
                result = (false, error.localizedDescription)
            }
        }

        if result.ok {
            status[u.id] = result.message.hasPrefix(String(localized: "Aktualisiert auf")) ? result.message : String(localized: "Aktualisiert auf \(u.available)")
            report.updates.removeAll { $0.id == u.id }
            report.upToDate.append(u.app)
            if wasRunning != nil { NSWorkspace.shared.open(URL(fileURLWithPath: u.app.path)) }
        } else {
            fail(u, result.message)
            if wasRunning != nil { NSWorkspace.shared.open(URL(fileURLWithPath: u.app.path)) }
        }
    }

    private func fail(_ u: AppUpdate, _ message: String) {
        failed.insert(u.id)
        status[u.id] = message
    }

    var selectedUpdates: [AppUpdate] { visible.filter { selected.contains($0.id) } }

    func toggle(_ u: AppUpdate) {
        if selected.contains(u.id) { selected.remove(u.id) } else { selected.insert(u.id) }
    }

    /// Updates the ticked apps one after another; App Store items are opened once at the end.
    func updateSelected() async {
        batchRunning = true
        defer { batchRunning = false }
        let chosen = selectedUpdates
        for u in chosen where u.source != .appStore || AppUpdateChecker.mas != nil {
            await update(u)
            if !failed.contains(u.id) { selected.remove(u.id) }
        }
        let store = chosen.filter { $0.source == .appStore && AppUpdateChecker.mas == nil }
        if !store.isEmpty {
            NSWorkspace.shared.open(URL(string: "macappstore://showUpdatesPage")!)
            for u in store {
                status[u.id] = String(localized: "Im App Store unter „Updates“ auf „Aktualisieren“ klicken")
                selected.remove(u.id)
            }
        }
    }
}

struct UpdatesView: View {
    @State private var model = UpdatesModel()
    @State private var confirmQuit: AppUpdate?
    @State private var confirmBatch = false
    @State private var showCurrent = false
    @State private var showUnknown = false
    @State private var search = ""
    @AppStorage("updatesOrder") private var order = ListOrder.name

    private var visible: [AppUpdate] {
        let q = search.trimmingCharacters(in: .whitespaces)
        let hits = q.isEmpty ? model.visible : model.visible.filter { $0.app.name.localizedCaseInsensitiveContains(q) }
        switch order {
        case .size: return hits.sorted { $0.app.bytes > $1.app.bytes }
        case .newest, .oldest: return order.byDate(hits) { $0.app.lastUsed }
        default: return hits.sorted { $0.app.name.localizedStandardCompare($1.app.name) == .orderedAscending }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !Prefs.onlineInfo {
                ContentUnavailableView {
                    Label("Online-Infos sind ausgeschaltet", systemImage: "network.slash")
                } description: {
                    Text("Für die Update-Prüfung fragt Swabr den Homebrew-Katalog (einmalig ca. 10 MB, danach 7 Tage zwischengespeichert), den App Store und die Update-Kanäle der Apps. Dabei werden die Kennungen deiner Apps übertragen, sonst nichts.")
                } actions: {
                    Button("Online-Infos einschalten") {
                        Prefs.onlineInfo = true
                        Task { await model.check() }
                    }
                    .buttonStyle(.prominent)
                }
            } else if model.loading && model.checkedAt == nil {
                ProgressView("Suche nach Updates für alle Apps …").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                list
            }
            footer
        }
        .searchable(text: $search, placement: .toolbarPrincipal, prompt: "App suchen")
        .toolbar {
            ToolbarItem(placement: .navigation) { SortMenu(order: $order) }
                .sharedBackgroundVisibility(.hidden)
        }
        .task { if model.checkedAt == nil && Prefs.onlineInfo { await model.check() } }
        .confirmationDialog("Laufende Apps werden beendet", isPresented: $confirmBatch) {
            Button("Beenden und aktualisieren") { Task { await model.updateSelected() } }
        } message: {
            let names = runningSelected.joined(separator: ", ")
            Text("Für die Updates werden \(names) kurz beendet und danach wieder geöffnet. Nicht gesicherte Änderungen vorher speichern.")
        }
        .confirmationDialog(
            String(localized: "\(confirmQuit?.app.name ?? "App") muss beendet werden"),
            isPresented: Binding(get: { confirmQuit != nil }, set: { if !$0 { confirmQuit = nil } }), presenting: confirmQuit
        ) { u in
            Button("Beenden und aktualisieren") { Task { await model.update(u) } }
        } message: { u in
            Text("Für das Update wird \(u.app.name) kurz beendet und danach wieder geöffnet. Nicht gesicherte Änderungen vorher speichern.")
        }
    }

    private var list: some View {
        List {
            Section {
                if visible.isEmpty {
                    Label("Alle geprüften Apps sind aktuell", systemImage: "checkmark.seal").foregroundStyle(.green)
                }
                ForEach(visible) { u in UpdateRow(update: u, model: model, start: start) }
            } header: {
                HStack {
                    Text("\(model.visible.count) Updates verfügbar")
                    Spacer()
                    if !model.visible.isEmpty {
                        Button("Alle auswählen") { model.selected = Set(model.visible.map(\.id)) }
                            .disabled(model.selected.count == model.visible.count)
                        Button("Alle abwählen") { model.selected = [] }
                            .disabled(model.selected.isEmpty)
                    }
                }
                .buttonStyle(.borderless).font(.callout)
            }
            if !model.hidden.isEmpty {
                Section("Ausgeblendete Updates (\(model.hidden.count))") {
                    ForEach(model.hidden) { u in UpdateRow(update: u, model: model, start: start) }
                }
            }
            Section {
                DisclosureGroup("Aktuell (\(model.report.upToDate.count))", isExpanded: $showCurrent) {
                    ForEach(model.report.upToDate) { app in
                        PlainAppRow(app: app, note: model.status[app.path] ?? String(localized: "Neueste Version"))
                    }
                }
                DisclosureGroup("Nicht prüfbar (\(model.report.unknown.count))", isExpanded: $showUnknown) {
                    ForEach(model.report.unknown) { app in
                        PlainAppRow(app: app, note: app.bundleID.hasPrefix("com.apple.Safari.WebApp")
                                    ? String(localized: "Web-App aus Safari") : String(localized: "Keine Update-Quelle bekannt: aktualisiert sich ggf. selbst"))
                    }
                }
            } footer: {
                Text("Quellen: Homebrew, App Store, die Update-Kanäle der Apps und die Herstellerdownloads aus dem Homebrew-Katalog. Herstellerdownloads werden nur installiert, wenn Prüfsumme, Entwickler-Signatur und Gatekeeper passen. Die alte Version landet im Papierkorb.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .listStyle(.inset)
                .scrollContentBackground(.hidden)
    }

    /// Names of ticked apps that are open and would be quit (App Store updates leave them alone).
    private var runningSelected: [String] {
        model.selectedUpdates.filter { $0.source != .appStore && model.running($0) != nil }.map(\.app.name)
    }

    private func start(_ u: AppUpdate) {
        if model.running(u) != nil, u.source != .appStore { confirmQuit = u } else { Task { await model.update(u) } }
    }

    private var footer: some View {
        HStack {
            if model.loading { ProgressView().controlSize(.small) }
            if let at = model.checkedAt {
                Text("Geprüft \(at.formatted(.relative(presentation: .named)))").foregroundStyle(.secondary)
            }
            Spacer()
            Button("Erneut prüfen") { Task { await model.check() } }.disabled(model.loading || !model.working.isEmpty)
            if !model.selected.isEmpty {
                Text("\(model.selectedUpdates.count) ausgewählt").foregroundStyle(.secondary)
            }
            Button(Edition.isStore ? String(localized: "Ausgewählte öffnen (\(model.selectedUpdates.count))") : String(localized: "Ausgewählte aktualisieren (\(model.selectedUpdates.count))")) {
                if runningSelected.isEmpty { Task { await model.updateSelected() } } else { confirmBatch = true }
            }
            .buttonStyle(.prominent)
            .disabled(model.selectedUpdates.isEmpty || !model.working.isEmpty || model.batchRunning)
            .help("Aktualisiert alle angekreuzten Apps nacheinander. Laufende Apps werden beendet und danach wieder geöffnet.")
        }
        .font(.callout)
        .padding(.horizontal, 18).padding(.vertical, 12)
            .background(.fill.tertiary)
    }
}

private struct UpdateRow: View {
    let update: AppUpdate
    let model: UpdatesModel
    let start: (AppUpdate) -> Void

    var body: some View {
        let u = update
        let hidden = model.ignored.contains(model.key(u))
        HStack(spacing: 10) {
            if !hidden {
                Toggle("", isOn: Binding(get: { model.selected.contains(u.id) }, set: { _ in model.toggle(u) }))
                    .labelsHidden().toggleStyle(.checkbox)
                    .disabled(model.batchRunning)
            }
            Image(nsImage: NSWorkspace.shared.icon(forFile: u.app.path)).resizable().frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(u.app.name).fontWeight(.medium)
                HStack(spacing: 6) {
                    Text("\(u.installed) → \(u.available)").monospacedDigit()
                    Text(u.source.title).font(.caption2.weight(.medium))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(.secondary.opacity(0.15), in: .capsule)
                }
                .font(.callout).foregroundStyle(.secondary)
                if let s = model.status[u.id] {
                    Text(s).font(.caption).foregroundStyle(model.failed.contains(u.id) ? .red : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            if model.working.contains(u.id) {
                ProgressView().controlSize(.small)
            } else {
                Button(Edition.isStore ? String(localized: "Zum Update") : String(localized: "Aktualisieren")) { start(u) }
                    .buttonStyle(.prominent)
                    .disabled(!model.working.isEmpty)
                    .help(help(u))
            }
            Menu {
                Button(hidden ? String(localized: "Wieder anzeigen") : String(localized: "Dieses Update ausblenden")) {
                    if hidden { model.ignored.remove(model.key(u)) } else { model.ignored.insert(model.key(u)) }
                }
                if let link = u.link { Button(u.source == .appStore ? String(localized: "Im App Store ansehen") : String(localized: "Website des Herstellers")) { NSWorkspace.shared.open(link) } }
                Button("Im Finder zeigen") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: u.app.path)]) }
            } label: { Label("Weitere Aktionen", systemImage: "ellipsis.circle").labelStyle(.iconOnly) }
                .menuStyle(.borderlessButton).fixedSize()
        }
        .padding(.vertical, 3)
    }

    private func help(_ u: AppUpdate) -> String {
        switch u.source {
        case .homebrew: String(localized: "Mit Homebrew aktualisieren")
        case .appStore: AppUpdateChecker.mas != nil ? String(localized: "Über den App Store aktualisieren (mas)") : String(localized: "Öffnet die Updates im App Store")
        case .sparkle, .vendor: String(localized: "Lädt \(u.available) vom Hersteller (\(u.download?.host() ?? ")String(localized: ")) und ersetzt die App")
        }
    }
}

private struct PlainAppRow: View {
    let app: InstalledApp
    let note: String

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path)).resizable().frame(width: 32, height: 32)
            Text(app.name)
            if let v = app.version { Text(v).foregroundStyle(.secondary).monospacedDigit() }
            Spacer()
            Text(note).font(.caption).foregroundStyle(.secondary)
        }
    }
}
