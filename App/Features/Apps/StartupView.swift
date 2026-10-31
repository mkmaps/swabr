import AppKit
import SwabrCore
import Observation
import SwiftUI

@MainActor @Observable
final class StartupModel {
    var loginItems: [LoginItems.Item] = []
    /// Login items apps registered themselves (macOS 13+); System Events does not list them.
    var appItems: [AppLoginItem] = []
    /// False when the helper is not set up, so apps that register themselves cannot be read.
    var appItemsKnown = true
    var apps: [InstalledApp] = []
    var services: [StartupItem] = []
    var loaded = false
    var search = ""
    var order = ListOrder(rawValue: UserDefaults.standard.string(forKey: "startupOrder") ?? "").flatMap { $0 == .natural ? nil : $0 } ?? .name {
        didSet { UserDefaults.standard.set(order.rawValue, forKey: "startupOrder") }
    }
    var error: String?
    var noAccess = false

    struct Row: Identifiable {
        var id: String { path }
        let name: String
        let path: String
        let item: LoginItems.Item?
        var appItem: AppLoginItem?
        /// Opens at login, by either kind of login item.
        var starts: Bool { item != nil || appItem?.starts == true }
        var registered: Bool { item != nil || appItem != nil }
        /// A login item whose app is no longer installed.
        var isOrphan: Bool { item != nil && !FileManager.default.fileExists(atPath: path) }
    }

    /// Login items and background services whose program no longer exists.
    var orphanLoginItems: [LoginItems.Item] { loginItems.filter { !FileManager.default.fileExists(atPath: $0.path) } }
    var orphanServices: [StartupItem] { services.filter { $0.isBroken && $0.canRemove } }
    var orphanCount: Int { orphanLoginItems.count + orphanServices.count }

    /// Every installed app plus login items of apps no longer installed; switched-on ones first.
    var rows: [Row] {
        let byPath = Dictionary(loginItems.map { ($0.path, $0) }, uniquingKeysWith: { a, _ in a })
        let appByPath = Dictionary(appItems.map { ($0.appPath, $0) }, uniquingKeysWith: { a, _ in a })
        var out = apps.map { Row(name: $0.name, path: $0.path, item: byPath[$0.path], appItem: appByPath[$0.path]) }
        let known = Set(apps.map(\.path))
        out += loginItems.filter { !known.contains($0.path) }.map { Row(name: $0.name, path: $0.path, item: $0, appItem: appByPath[$0.path]) }
        let listed = known.union(loginItems.map(\.path))
        out += appItems.filter { !listed.contains($0.appPath) }.map { Row(name: $0.name, path: $0.appPath, item: nil, appItem: $0) }
        let filtered = search.isEmpty ? out : out.filter { $0.name.localizedCaseInsensitiveContains(search) }
        // Apps that start at login stay on top; the chosen order applies within each group.
        let info = Dictionary(apps.map { ($0.path, $0) }, uniquingKeysWith: { a, _ in a })
        return filtered.sorted { a, b in
            if a.registered != b.registered { return a.registered }
            if a.starts != b.starts { return a.starts }
            let x = info[a.path], y = info[b.path]
            switch order {
            case .size:
                if (x?.bytes ?? 0) != (y?.bytes ?? 0) { return (x?.bytes ?? 0) > (y?.bytes ?? 0) }
            case .newest, .oldest:
                switch (x?.lastUsed, y?.lastUsed) {
                case let (p?, q?) where p != q: return order == .oldest ? p < q : p > q
                case (_?, nil): return true
                case (nil, _?): return false
                default: break
                }
            default: break
            }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    /// Apps whose login item is switched on, of both kinds.
    var startingCount: Int { rows.filter(\.starts).count }

    func load() async {
        if !Edition.isStore {
            reloadLoginItems()
            // Only through the helper: run any other way, sfltool makes macOS ask for authorization each time.
            if PrivilegedHelper.state == .enabled {
                let found = await Task.detached {
                    AppLoginItems.list(runAsRoot: { PrivilegedHelper.perform($0) })
                }.value
                appItems = found ?? []
                appItemsKnown = found != nil
            } else {
                appItems = []
                appItemsKnown = false
            }
        }
        if apps.isEmpty, let protection = try? RuleStore.protection() {
            apps = await AppCatalog.installedApps(protection: protection)
        }
        services = await listServices()
        loaded = true
    }

    /// App Store edition: only the user's own agents of apps inside granted folders.
    private func listServices() async -> [StartupItem] {
        let store = Edition.isStore
        let granted = FolderAccess.paths
        return await Task.detached {
            store ? StartupItems.storeEdition(StartupItems.list(), grantedFolders: granted) : StartupItems.list()
        }.value
    }

    func reloadLoginItems() {
        do {
            loginItems = try LoginItems.list()
            noAccess = false
        } catch LoginItems.Failure.noAccess {
            noAccess = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    func change(_ work: () throws -> Void) {
        do {
            try work()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        reloadLoginItems()
    }

    func perform(_ action: @escaping @Sendable (StartupItem) -> String?, on item: StartupItem) async {
        error = await Task.detached { action(item) }.value
        services = await listServices()
    }

    /// Removes services: own agents directly, system-wide ones together under one password prompt.
    func remove(_ items: [StartupItem]) async {
        let own = items.filter { $0.policy == .manageable }
        let system = items.filter { $0.policy != .manageable && $0.canRemove }
        var reasons: [String] = []
        for item in own {
            if let why = await Task.detached(operation: { StartupItems.remove(item) }).value { reasons.append(why) }
        }
        if !system.isEmpty {
            let failures = await Task.detached {
                Edition.isStore
                    ? StartupItems.removeSystem(system, runPrivileged: nil, privilegedTrash: WorkspaceTrash.move)
                    : StartupItems.removeSystem(system, runPrivileged: Privileged.run)
            }.value
            reasons += Set(failures.values)
        }
        error = reasons.first
        services = await listServices()
    }

    /// Removes every login item and service whose program is gone.
    func removeOrphans() async {
        if !Edition.isStore { change { for item in orphanLoginItems { try LoginItems.remove(item) } } }
        await remove(orphanServices)
    }
}

struct StartupView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var model = StartupModel()
    @State private var removing: StartupItem?
    @State private var confirmOrphans = false
    @State private var showServices = false

    var body: some View {
        VStack(spacing: 0) {
            if !model.loaded {
                ProgressView("Startobjekte werden gelesen …").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if Edition.isStore {
                        // Login items belong to System Events, which App Store apps may not script.
                        Section {
                            HStack {
                                Text("Welche Apps beim Anmelden starten, stellst du in den Systemeinstellungen ein. Swabr zeigt hier die Hintergrunddienste in deinem Benutzerordner.")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                SettingsGearButton(String(localized: "Systemeinstellungen → Anmeldeobjekte öffnen")) { SystemSettingsPane.open(SystemSettingsPane.loginItems) }
                            }
                        }
                    } else {
                        if model.noAccess { accessHint }
                        loginSection
                    }
                    servicesSection
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
            HStack {
                Text("\(model.startingCount) Apps starten beim Anmelden").foregroundStyle(.secondary)
                if let e = model.error { Text(e).foregroundStyle(.red).lineLimit(1) }
                Spacer()
                if model.orphanCount > 0 {
                    Button("Verwaiste entfernen (\(model.orphanCount)) …", role: .destructive) { confirmOrphans = true }
                        .help("Einträge, deren Programm nicht mehr installiert ist")
                }
                SettingsGearButton(String(localized: "Systemeinstellungen → Anmeldeobjekte öffnen")) { SystemSettingsPane.open(SystemSettingsPane.loginItems) }
                Button { Task { await model.load() } } label: { Label("Neu laden", systemImage: "arrow.clockwise").labelStyle(.iconOnly) }.help("Neu laden")
            }
            .font(.callout)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(.fill.tertiary)
        }
        .searchable(text: $model.search, placement: .toolbarPrincipal, prompt: "App suchen")
        .toolbar {
            ToolbarItem(placement: .navigation) { SortMenu(order: $model.order) }
                .sharedBackgroundVisibility(.hidden)
        }
        .task {
            if !model.loaded { await model.load() }
            if model.services.contains(where: \.isBroken) { showServices = true }
        }
        .confirmationDialog("Verwaiste Startobjekte entfernen?", isPresented: $confirmOrphans) {
            Button("Entfernen", role: .destructive) { Task { await model.removeOrphans() } }
        } message: {
            Text(orphanMessage)
        }
        .confirmationDialog("Hintergrunddienst entfernen?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                            presenting: removing) { item in
            Button("In den Papierkorb legen", role: .destructive) {
                Task { await model.remove([item]) }
            }
        } message: { item in
            if item.policy == .manageable {
                Text("„\(item.displayName)“ startet nicht mehr mit macOS. Die Datei lässt sich aus dem Papierkorb wiederherstellen.")
            } else {
                Text("„\(item.displayName)“ gilt für alle Benutzer, sein Programm fehlt. macOS fragt beim Entfernen nach deinem Passwort; die Datei lässt sich aus dem Papierkorb wiederherstellen.")
            }
        }
    }

    private var orphanMessage: String {
        let names = model.orphanLoginItems.map(\.name) + model.orphanServices.map(\.displayName)
        var text = String(localized: "Diese Einträge verweisen auf Programme, die nicht mehr installiert sind: \(names.joined(separator: ", ")).")
        if model.orphanServices.contains(where: { $0.policy != .manageable }) {
            text += " " + String(localized: "Für systemweite Einträge fragt macOS nach deinem Passwort.")
        }
        return text + " " + String(localized: "Dateien landen im Papierkorb.")
    }

    private var accessHint: some View {
        Section {
            HStack {
                Label("Swabr braucht die Erlaubnis, „System Events“ zu steuern, um die Anmeldeobjekte zu lesen und zu ändern.",
                      systemImage: "hand.raised").foregroundStyle(.orange)
                Spacer()
                SettingsGearButton(String(localized: "Systemeinstellungen → Datenschutz & Sicherheit → Automation öffnen")) { SystemSettingsPane.open(SystemSettingsPane.automation) }
            }
        }
    }

    /// One list of all apps with a switch each; apps that start at login come first.
    private var loginSection: some View {
        Section {
            if !model.appItemsKnown && !Edition.isStore {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "key.fill").foregroundStyle(.orange)
                    Text("Apps, die sich selbst anmelden (z. B. über „Beim Anmelden öffnen“ in der App), zeigt Swabr nur mit eingerichtetem Hilfsdienst für Administratorrechte.")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Button("Anleitung") { openWindow(id: HelpWindow.id, value: HelpTopic.adminHelper) }
                        .buttonStyle(.softCompact)
                    SettingsGearButton(String(localized: "Swabr-Einstellungen → Verhalten → Administratorrechte öffnen")) {
                        WindowOpener.shared.openSettings(tab: SettingsTab.behavior)
                    }
                }
                .padding(.vertical, 4)
            }
            ForEach(model.rows) { row in
                HStack(spacing: 10) {
                    AppIcon(path: row.path)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.name).fontWeight(row.starts ? .medium : .regular)
                        if let a = row.appItem, row.item == nil {
                            Text(a.starts ? String(localized: "Von der App angemeldet · in den Systemeinstellungen verwaltet")
                                          : String(localized: "Von der App angemeldet · in den Systemeinstellungen ausgeschaltet"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if row.isOrphan {
                            Text("Programm fehlt: \(row.path)").font(.caption).foregroundStyle(.orange).lineLimit(1)
                        }
                    }
                    Spacer()
                    if row.isOrphan, let item = row.item {
                        Button("Aus der Liste entfernen", role: .destructive) { model.change { try LoginItems.remove(item) } }
                            .disabled(model.noAccess)
                            .help("Die App ist nicht mehr installiert; der Eintrag wird aus den Anmeldeobjekten gelöscht")
                    }
                    if let item = row.item {
                        Toggle("Versteckt", isOn: Binding(get: { item.hidden }, set: { on in model.change { try LoginItems.setHidden(item, on) } }))
                            .toggleStyle(.switch).controlSize(.mini)
                            .help("Die App startet im Hintergrund, ohne ein Fenster zu öffnen")
                    }
                    if let a = row.appItem, row.item == nil {
                        // Only the app itself or System Settings may switch these; macOS offers no way for other apps.
                        SettingsGearButton(String(localized: "Diese App meldet sich selbst an. Ein- und ausschalten lässt sie sich in den Systemeinstellungen oder in der App.")) {
                            SystemSettingsPane.open(SystemSettingsPane.loginItems)
                        }
                        Toggle("Beim Anmelden starten", isOn: .constant(a.starts))
                            .labelsHidden().toggleStyle(.switch).disabled(true)
                    } else {
                        Toggle("Beim Anmelden starten", isOn: Binding(get: { row.item != nil }, set: { on in
                            model.change {
                                if on { try LoginItems.add(path: row.path, hidden: false) } else if let item = row.item { try LoginItems.remove(item) }
                            }
                        }))
                        .labelsHidden().toggleStyle(.switch)
                        .disabled(model.noAccess)
                        .help("Beim Anmelden starten")
                    }
                }
                .padding(.vertical, 1)
            }
        } header: {
            HStack {
                Text("Beim Anmelden starten")
                Spacer()
                Text("\(model.startingCount) eingeschaltet").foregroundStyle(.secondary)
            }
        } footer: {
            Text("Eingeschaltete Apps öffnet macOS automatisch nach der Anmeldung. Dieselbe Liste wie in Systemeinstellungen → Allgemein → Anmeldeobjekte. Apps, die sich selbst anmelden, schaltest du dort oder in der App selbst um.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var servicesSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showServices) {
                ForEach(model.services) { item in
                    ServiceRow(item: item, model: model) { removing = item }
                }
            } label: {
                let broken = model.services.filter(\.isBroken).count
                Text("Hintergrunddienste von Apps (\(model.services.count))" + (broken > 0 ? String(localized: " · \(broken) mit fehlendem Programm") : ""))
                    .foregroundStyle(broken > 0 ? .orange : .primary)
            }
        } footer: {
            Text("Updater und Hilfsprogramme, die Apps selbst einrichten. Eigene Dienste lassen sich hier blockieren oder entfernen, systemweite nur in den Systemeinstellungen.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct AppIcon: View {
    let path: String
    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 32, height: 32)
    }
}

private struct ServiceRow: View {
    let item: StartupItem
    let model: StartupModel
    let remove: () -> Void
    @State private var confirmBlock = false

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let app = item.appPath, FileManager.default.fileExists(atPath: app) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app)).resizable()
                } else {
                    Image(systemName: "gearshape.2").resizable().scaledToFit().foregroundStyle(.secondary).padding(3)
                }
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(item.displayName)
                    badge
                }
                Text("\(item.label) · \(item.kind.title)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if let why = item.protectedReason {
                    Label(why, systemImage: "lock.shield").font(.caption).foregroundStyle(.orange).lineLimit(1)
                }
            }
            Spacer()
            if item.policy == .manageable, !Edition.isStore, !item.isBroken {
                Toggle("Start erlaubt", isOn: Binding(get: { !item.disabled }, set: setAllowed))
                    .toggleStyle(.switch).controlSize(.small)
            }
            if item.canRemove {
                Button("Entfernen …", role: .destructive, action: remove)
            }
        }
        .contextMenu {
            Button("Plist im Finder zeigen") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)]) }
        }
        .confirmationDialog("Geschützten Dienst blockieren?", isPresented: $confirmBlock) {
            Button("Trotzdem blockieren", role: .destructive) { Task { await model.perform({ StartupItems.block($0, confirmed: true) }, on: item) } }
        } message: {
            Text("„\(item.displayName)“ gehört zu Sicherheits-, Netzwerk- oder Passwortsoftware. Ohne diesen Dienst kann sie ihren Schutz oder ihre Verbindung verlieren. Du kannst ihn hier jederzeit wieder erlauben.")
        }
    }

    private func setAllowed(_ on: Bool) {
        if !on && item.isProtected { confirmBlock = true; return }
        Task {
            if on {
                await model.perform({ StartupItems.allow($0) }, on: item)
            } else {
                await model.perform({ StartupItems.block($0) }, on: item)
            }
        }
    }

    @ViewBuilder private var badge: some View {
        let (text, color): (String, Color) =
            item.isBroken ? (String(localized: "Programm fehlt"), .orange)
            : item.disabled ? (String(localized: "Blockiert"), .secondary)
            : item.loaded ? (String(localized: "Läuft"), .green)
            : (String(localized: "Erlaubt"), .secondary)
        Text(text).font(.caption2.weight(.medium))
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(color.opacity(0.15), in: .capsule).foregroundStyle(color)
    }
}
