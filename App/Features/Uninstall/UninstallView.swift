import AppKit
import SwabrCore
import SwiftUI

struct UninstallView: View {
    @Bindable private var model = AppModels.shared.uninstall
    @State private var reviewing = false
    @AppStorage(Prefs.Key.uninstallConfirm) private var confirmFirst = true

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                WorkingPanel(module: .uninstall, title: String(localized: "Programme werden gesucht …"))
            case .removing:
                WorkingPanel(module: .uninstall, title: String(localized: "Deinstalliere …"), detail: model.currentStep)
            case .done(let report):
                UninstallDone(report: report) { Task { await model.load() } }
            case .ready:
                HStack(alignment: .top, spacing: 14) {
                    appList.frame(minWidth: 380, idealWidth: 440, maxWidth: 520).pagePanel()
                    detail.frame(minWidth: 340, maxWidth: .infinity).pagePanel()
                }
            }
        }
        .searchable(text: $model.search, placement: .toolbarPrincipal, prompt: "Apps suchen")
        .toolbar {
            ToolbarItem(placement: .navigation) { SortMenu(order: $model.sort) }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItemGroup {
                Button { Task { await model.load() } } label: { Image(systemName: "arrow.clockwise") }
                    .help("Liste neu laden")
            }
        }
        .sheet(isPresented: $reviewing) {
            let running = model.runningCheckedApps.compactMap(\.localizedName)
            let admin = model.checkedApps.filter(\.needsAdmin).map(\.name)
            ReviewSheet(
                title: model.checkedApps.count == 1
                    ? String(localized: "„\(model.checkedApps[0].name)“ deinstallieren?")
                    : String(localized: "\(model.checkedApps.count) Apps deinstallieren?"),
                footnote: (running.isEmpty ? "" : String(localized: "Wird zuerst beendet: \(running.joined(separator: ", ")). "))
                    + (admin.isEmpty ? "" : String(localized: "Passwort nötig für: \(admin.joined(separator: ", ")). "))
                    + String(localized: "Alles landet im Papierkorb und ist bis zum Leeren wiederherstellbar."),
                confirmLabel: running.isEmpty ? String(localized: "In den Papierkorb legen") : String(localized: "Beenden und entfernen"),
                lines: model.reviewLines
            ) {
                Task { await model.uninstall() }
            }
        }
        .alert("Fehler", isPresented: .constant(model.errorMessage != nil)) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .task { if model.apps.isEmpty { await model.load() } }
    }

    private var appList: some View {
        VStack(spacing: 0) {
            Table(model.visibleApps, selection: Binding(get: { model.focused }, set: { model.focus($0) })) {
                TableColumn("") { app in
                    Toggle("", isOn: Binding(get: { model.checked.contains(app.path) }, set: { _ in model.toggle(app) }))
                        .labelsHidden().toggleStyle(.checkbox).disabled(!model.canRemove(app))
                        .help(app.protection ?? "")
                }
                .width(22)
                TableColumn(String(localized: "App")) { app in
                    HStack(spacing: 8) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.path)).resizable().frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 4) {
                                Text(app.name).lineLimit(1)
                                if !app.isRemovable { Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary) }
                                else if app.needsAdmin {
                                    Image(systemName: "person.badge.key").font(.caption).foregroundStyle(.secondary)
                                        .help("Gehört einem anderen Benutzer oder dem System: Löschen braucht dein Passwort")
                                }
                            }
                            if let v = app.version { Text(v).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    .opacity(app.isRemovable ? 1 : 0.55)
                }
                TableColumn(String(localized: "Größe")) { app in
                    Text(DiskSize.format(app.bytes)).monospacedDigit()
                }
                .width(min: 70, ideal: 80)
                TableColumn("Zuletzt benutzt") { app in
                    Text(app.lastUsed.map { $0.formatted(.relative(presentation: .named)) } ?? String(localized: "nie / unbekannt"))
                        .foregroundStyle(.secondary)
                }
                .width(min: 100, ideal: 120)
            }
            .scrollContentBackground(.hidden)
            .contextMenu(forSelectionType: String.self) { paths in
                if let path = paths.first, let app = model.apps.first(where: { $0.path == path }) {
                    Button("Nur Daten löschen …") { Task { await model.prepareReset(app) } }
                        .disabled(!app.isRemovable)
                    Button("Im Finder zeigen") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)]) }
                }
            }
            .confirmationDialog(resetTitle, isPresented: Binding(get: { model.resetCandidate != nil }, set: { if !$0 { model.resetCandidate = nil } }),
                                presenting: model.resetCandidate) { app in
                Button("Daten in den Papierkorb legen", role: .destructive) { Task { await model.reset(app) } }
                    .disabled(model.resetData(of: app).isEmpty)
            } message: { app in
                let data = model.resetData(of: app)
                if data.isEmpty {
                    Text("Swabr hat keine Daten dieser App gefunden.")
                } else {
                    Text("Die App bleibt installiert. \(data.count) Objekte (\(DiskSize.format(data.reduce(0) { $0 + $1.bytes }))) mit Einstellungen, Caches und Daten landen im Papierkorb; beim nächsten Start ist die App wie neu installiert. Gemeinsam genutzte Daten und Browser-Profile bleiben.")
                }
            }
            HStack {
                if model.checked.isEmpty {
                    Text("\(model.apps.count) Apps · Kästchen anklicken, um Apps auszuwählen").foregroundStyle(.secondary)
                    Spacer()
                } else {
                    AmountLabel(amount: DiskSize.format(model.totalBytes), caption: String(localized: "\(model.checked.count) ausgewählt"))
                    Spacer()
                    Button("Auswahl leeren") { model.checked = [] }.buttonStyle(.softCompact)
                    Button(confirmFirst ? String(localized: "Deinstallieren …") : String(localized: "Deinstallieren")) {
                        // Quitting a running app could lose unsaved work, so that is always confirmed.
                        if confirmFirst || !model.runningCheckedApps.isEmpty {
                            reviewing = true
                        } else {
                            Task { await model.uninstall() }
                        }
                    }
                        .buttonStyle(.destructiveProminent)
                }
            }
            .font(.callout)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(.fill.tertiary)
        }
    }

    @ViewBuilder private var detail: some View {
        if let app = model.focusedApp {
            AppDetail(app: app, model: model)
        } else {
            ContentUnavailableView("Keine App gewählt", systemImage: "app.dashed",
                                   description: Text("Wähle links eine App, um ihre Dateien zu sehen."))
        }
    }
}

private struct AppDetail: View {
    let app: InstalledApp
    let model: UninstallModel

    var body: some View {
        let found = model.leftovers[app.path]
        let removed = (found ?? []).filter { $0.kind == .disposable || $0.kind == .launchAgent }
        let personal = (found ?? []).filter { $0.kind == .personal || $0.kind == .sensitive }
        let system = (found ?? []).filter { $0.kind == .system }
        List {
            Section {
                HStack(spacing: 16) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.path)).resizable().frame(width: 72, height: 72)
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name).font(.system(size: 22, weight: .bold))
                        Text([app.version.map { String(localized: "Version \($0)") }, app.lastUsed.map { String(localized: "zuletzt geöffnet \($0.formatted(.relative(presentation: .named)))") }]
                            .compactMap { $0 }.joined(separator: " · "))
                            .font(.callout).foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            if app.fromAppStore { Chip(text: String(localized: "App Store")) }
                            if app.caskToken != nil { Chip(text: "Homebrew") }
                            Chip(text: app.bundleID).textSelection(.enabled)
                        }
                    }
                }
                .padding(.vertical, 6)
                if let token = app.caskToken { Text("Mit Homebrew installiert (\(token)): wird mit brew uninstall entfernt").font(.caption).foregroundStyle(.secondary) }
                if found != nil {
                    HStack(spacing: 10) {
                        SizeTile(title: String(localized: "App"), bytes: app.bytes)
                        SizeTile(title: String(localized: "Persönliche Daten"), bytes: personal.reduce(0) { $0 + $1.bytes })
                        SizeTile(title: String(localized: "Systemdateien"), bytes: system.reduce(0) { $0 + $1.bytes })
                    }
                }
                if let why = app.protection {
                    Label(why, systemImage: "lock.shield").foregroundStyle(.orange)
                } else if app.needsAdmin {
                    Label("Gehört „\(AppCatalog.owner(of: app.path) ?? String(localized: "einem anderen Benutzer"))“: macOS fragt beim Löschen nach deinem Passwort.",
                          systemImage: "person.badge.key")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            AppInfoSection(app: app, info: model.infos[app.path], loading: model.loadingInfo.contains(app.path))
            if found == nil {
                Section { HStack { ProgressView().controlSize(.small); Text("Suche zugehörige Dateien …") } }
            } else {
                Section("Wird entfernt") {
                    FileRow(path: app.path, bytes: app.bytes, note: String(localized: "Das Programm selbst"), isOn: nil)
                    ForEach(removed) { l in
                        FileRow(path: l.path, bytes: l.bytes, note: l.impact, warning: l.evidence == .nameOnly,
                                isOn: Binding(get: { model.chosenLeftovers.contains(l.path) }, set: { _ in model.toggleLeftover(l.path) }))
                    }
                }
                Section {
                    if personal.isEmpty {
                        Text("Keine gefunden").foregroundStyle(.secondary)
                    }
                    ForEach(personal) { l in
                        FileRow(path: l.path, bytes: l.bytes, note: l.impact, warning: true,
                                isOn: Binding(get: { model.chosenLeftovers.contains(l.path) }, set: { _ in model.toggleLeftover(l.path) }))
                    }
                } header: {
                    HStack {
                        Text("Persönliche Daten")
                        Spacer()
                        if personal.contains(where: { $0.kind == .personal }) {
                            let allOn = personal.filter { $0.kind == .personal }.allSatisfy { model.chosenLeftovers.contains($0.path) }
                            Button(allOn ? String(localized: "Behalten") : String(localized: "Alle mit entfernen")) { model.setPersonalData(for: app, !allOn) }
                                .buttonStyle(.borderless).font(.caption)
                        }
                    }
                } footer: {
                    Text("Bleiben standardmäßig erhalten, damit Einstellungen und Konten bei einer Neuinstallation wieder da sind. Nur angekreuzte Einträge werden entfernt.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if Edition.isStore && !FolderAccess.covers("/Library") {
                    Section {
                        HStack {
                            Text("Systemdateien in /Library werden erst nach einer Freigabe angezeigt.").font(.callout).foregroundStyle(.secondary)
                            Spacer()
                            Button("/Library freigeben …") { model.grantLibrary() }.controlSize(.small)
                        }
                    }
                }
                if !system.isEmpty {
                    Section {
                        ForEach(system) { l in
                            FileRow(path: l.path, bytes: l.bytes, note: l.impact, warning: true,
                                    isOn: Binding(get: { model.chosenLeftovers.contains(l.path) }, set: { _ in model.toggleLeftover(l.path) }))
                        }
                    } header: {
                        HStack {
                            Label("Systemdateien", systemImage: "lock")
                            Spacer()
                            let allOn = system.allSatisfy { model.chosenLeftovers.contains($0.path) }
                            Button(allOn ? String(localized: "Behalten") : String(localized: "Alle mit entfernen")) {
                                for l in system { if allOn { model.chosenLeftovers.remove(l.path) } else { model.chosenLeftovers.insert(l.path) } }
                            }
                            .buttonStyle(.borderless).font(.caption)
                        }
                    } footer: {
                        Text(Edition.isStore
                             ? String(localized: "Liegen in /Library und gelten für alle Benutzer. Angekreuzte Einträge legt macOS nach deiner Passwortbestätigung in den Papierkorb; Systemdienste enden mit dem nächsten Neustart.")
                             : String(localized: "Liegen in /Library und gelten für alle Benutzer. Angekreuzte Einträge werden mit einer Passwortabfrage in den Papierkorb gelegt, Systemdienste vorher gestoppt."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }
}

private struct Chip: View {
    let text: String

    var body: some View {
        Text(text).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(.fill.tertiary, in: .rect(cornerRadius: 7, style: .continuous))
    }
}

private struct SizeTile: View {
    let title: String
    let bytes: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(DiskSize.format(bytes)).font(.system(size: 20, weight: .semibold, design: .rounded)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.background, in: .rect(cornerRadius: 14, style: .continuous))
    }
}

/// Who made the app and what it does, with links to read more before removing it.
private struct AppInfoSection: View {
    let app: InstalledApp
    let info: AppInfo?
    let loading: Bool

    var body: some View {
        Section("Informationen") {
            if let info {
                if let summary = info.summary {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary).fixedSize(horizontal: false, vertical: true)
                        if let source = info.summarySource {
                            Text("Beschreibung: \(source)").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                } else if loading {
                    HStack { ProgressView().controlSize(.small); Text("Beschreibung wird gesucht …").foregroundStyle(.secondary) }
                } else {
                    Text("Keine Beschreibung gefunden. Die Websuche hilft weiter.").foregroundStyle(.secondary)
                }
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                    InfoRow("Entwickler", info.developer ?? "unbekannt")
                    if let c = info.category { InfoRow("Kategorie", c) }
                    if let v = app.version { InfoRow("Version", v) }
                    InfoRow("Zuletzt benutzt", app.lastUsed?.formatted(date: .long, time: .omitted) ?? String(localized: "nie / unbekannt"))
                    if let c = info.copyright { InfoRow("Copyright", c) }
                }
                .font(.callout)
                HStack {
                    if let url = info.homepage { Link(destination: url) { Label("Website", systemImage: "safari") } }
                    if let url = info.storeURL { Link(destination: url) { Label("App Store", systemImage: "bag") } }
                    if let url = info.homebrewURL { Link(destination: url) { Label("Homebrew", systemImage: "mug") } }
                    Link(destination: info.searchURL) { Label("Im Web suchen", systemImage: "magnifyingglass") }
                }
                .buttonStyle(.bordered).controlSize(.small)
            } else {
                ProgressView().controlSize(.small)
            }
        }
    }
}

private struct InfoRow: View {
    let title: LocalizedStringKey
    let value: String
    init(_ title: LocalizedStringKey, _ value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled).lineLimit(2)
        }
    }
}

private struct FileRow: View {
    let path: String
    let bytes: Int64
    let note: String
    var warning = false
    let isOn: Binding<Bool>?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if let isOn {
                Toggle("", isOn: isOn).labelsHidden().toggleStyle(.checkbox)
            } else {
                Image(systemName: "checkmark.square.fill").foregroundStyle(.secondary).help("Wird immer entfernt")
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(path.replacingOccurrences(of: UserHome.path, with: "~"))
                        .font(.caption.monospaced()).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Text(DiskSize.format(bytes)).font(.caption).monospacedDigit()
                }
                Text(note).font(.caption).foregroundStyle(warning ? .orange : .secondary)
            }
        }
        .contextMenu {
            Button("Im Finder zeigen") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }
        }
    }
}

private extension UninstallView {
    var resetTitle: String {
        model.resetCandidate.map { String(localized: "Daten von „\($0.name)“ löschen?") } ?? ""
    }
}

private struct UninstallDone: View {
    let report: UninstallReport
    let again: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            SuccessHero(failed: report.removedApps.isEmpty)
            Text(report.removedApps.isEmpty ? String(localized: "Nichts deinstalliert")
                 : report.dataOnly ? String(localized: "Daten zurückgesetzt") : String(localized: "Deinstallation abgeschlossen")).font(.title.bold())
            if !report.activeExtensions.isEmpty {
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Eine Systemerweiterung läuft noch", systemImage: "puzzlepiece.extension").font(.headline).foregroundStyle(.orange)
                        Text("\(report.activeExtensions.map(\.name).joined(separator: ", ")) arbeitet weiter, bis du sie ausschaltest. Nur macOS selbst darf Systemerweiterungen entfernen.")
                            .font(.callout).fixedSize(horizontal: false, vertical: true)
                        SettingsGearButton(String(localized: "Anmeldeobjekte & Erweiterungen öffnen")) { SystemSettingsPane.open(SystemSettingsPane.loginItems) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: 600)
            }
            if !report.removedApps.isEmpty {
                Text("\(report.removedApps.joined(separator: ", ")) · \(DiskSize.format(report.removedBytes)) im Papierkorb")
                    .foregroundStyle(.secondary)
                Text("Speicher wird frei, sobald du den Papierkorb leerst.").font(.callout).foregroundStyle(.secondary)
            }
            if !report.failures.isEmpty {
                GroupBox("\(report.failures.count) nicht entfernt") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(report.failures, id: \.path) { f in
                                VStack(alignment: .leading) {
                                    Text(f.path.replacingOccurrences(of: UserHome.path, with: "~")).font(.caption.monospaced())
                                    Text(f.reason).font(.caption).foregroundStyle(.orange)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 160)
                }
                .frame(maxWidth: 600)
            }
            Button("Zurück zur Liste", action: again).buttonStyle(.prominent).padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
