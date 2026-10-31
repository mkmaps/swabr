import AppKit
import ServiceManagement
import SwabrCore
import SwiftUI

/// Tabs of the settings window; other views open a tab by setting `SettingsTab.key` first.
enum SettingsTab {
    static let key = "settingsTab"
    static let general = "general", behavior = "behavior", protected = "protected", access = "access", about = "about"
}

struct SettingsView: View {
    @AppStorage(SettingsTab.key) private var tab = SettingsTab.general

    var body: some View {
        TabView(selection: $tab) {
            Tab("Allgemein", systemImage: "gearshape", value: SettingsTab.general) { GeneralSettingsView() }
            Tab("Verhalten", systemImage: "slider.horizontal.3", value: SettingsTab.behavior) { BehaviorSettingsView() }
            Tab("Geschützte Daten", systemImage: "shield.lefthalf.filled", value: SettingsTab.protected) { ProtectedDataView() }
            if Edition.isStore {
                Tab("Freigaben", systemImage: "folder.badge.person.crop", value: SettingsTab.access) { AccessSettingsView() }
            }
            Tab("Über", systemImage: "info.circle", value: SettingsTab.about) { AboutView() }
        }
        .frame(width: 700, height: 600)
    }
}

// MARK: General

struct GeneralSettingsView: View {
    @AppStorage(MenuBarSettings.enabledKey) private var menuBar = true
    @AppStorage(MenuBarSettings.displayKey) private var display = MenuBarDisplay.health.rawValue
    @AppStorage(MenuBarSettings.hoverKey) private var hover = true
    @AppStorage(Appearance.key) private var appearance = Appearance.system.rawValue
    @AppStorage(Prefs.Key.onlineInfo) private var onlineInfo = !Edition.isStore
    @AppStorage(Prefs.Key.startHintFullDiskAccess) private var hintFullDisk = true
    @AppStorage(Prefs.Key.startHintAdminHelper) private var hintAdmin = true
    @State private var language = Prefs.language
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            if !Edition.isStore {
                Section {
                    Toggle("Fehlenden Festplattenvollzugriff beim Start melden", isOn: $hintFullDisk)
                    Toggle("Fehlenden Hilfsdienst für Administratorrechte beim Start melden", isOn: $hintAdmin)
                } header: {
                    Text("Hinweise beim Start")
                } footer: {
                    Text("Erscheinen nur, solange das Recht fehlt. Jeder Hinweis lässt sich auch direkt im Fenster abschalten.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Darstellung") {
                Picker("Erscheinungsbild", selection: $appearance) {
                    ForEach(Appearance.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .onChange(of: appearance) { _, new in Appearance.apply(Appearance(rawValue: new) ?? .system) }
                Picker("Sprache", selection: $language) {
                    Text("Wie System").tag("system")
                    ForEach(Prefs.languages, id: \.code) { Text(verbatim: $0.name).tag($0.code) }
                }
                .onChange(of: language) { _, new in Prefs.language = new }
                if language != Prefs.languageAtLaunch {
                    HStack {
                        Text("Die Sprache wechselt beim nächsten Start.").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Jetzt neu starten") { relaunch() }.controlSize(.small)
                    }
                }
            }
            Section {
                Toggle("Status in der Menüleiste anzeigen", isOn: $menuBar)
                Picker("Anzeige", selection: $display) {
                    ForEach(MenuBarDisplay.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .disabled(!menuBar)
                Toggle("Dashboard öffnen, wenn der Mauszeiger darüberfährt", isOn: $hover)
                    .disabled(!menuBar)
            } header: {
                Text("Menüleiste")
            } footer: {
                Text("Ein Klick auf das Symbol hält das Dashboard offen. Solange die Menüleiste aktiv ist, läuft Swabr nach dem Schließen des Fensters weiter.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Start") {
                Toggle("Beim Anmelden starten", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.orange) }
            }
            Section {
                Toggle("Online-Infos verwenden", isOn: $onlineInfo)
            } header: {
                Text("Datenschutz")
            } footer: {
                Text("Für App-Beschreibungen und Update-Prüfung lädt Swabr den öffentlichen Homebrew-Katalog (ca. 10 MB, 7 Tage zwischengespeichert), fragt Apple nach App-Store-Daten und liest die Update-Kanäle deiner Apps. Übertragen werden nur App-Kennungen, keine persönlichen Daten. Ausgeschaltet arbeitet Swabr komplett offline.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if SMAppService.mainApp.status == .requiresApproval {
            loginError = String(localized: "Bitte in Systemeinstellungen → Allgemein → Anmeldeobjekte erlauben.")
        }
    }

    private func relaunch() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", path]
        try? task.run()
        NSApp.terminate(nil)
    }
}

// MARK: Behavior

/// Thresholds and defaults the user can change.
struct BehaviorSettingsView: View {
    @AppStorage("cleanMode") private var cleanMode = Cleaner.Mode.permanent.rawValue
    @AppStorage(Prefs.Key.cleanEmptyTrash) private var emptyTrash = true
    @AppStorage(Prefs.Key.cleanPreselectReview) private var preselectReview = false
    @AppStorage(Prefs.Key.orphanAgeDays) private var orphanDays = DynamicRules.defaultOrphanAgeDays
    @AppStorage(Prefs.Key.largeDataMinMB) private var largeMB = 500
    @AppStorage(Prefs.Key.uninstallPersonalData) private var personalData = false
    @AppStorage(Prefs.Key.uninstallSystemFiles) private var systemFiles = false
    @AppStorage(Prefs.Key.uninstallConfirm) private var uninstallConfirm = true
    @AppStorage(Prefs.Key.purgeRecentDays) private var recentDays = 7
    @AppStorage(Prefs.Key.purgeMaxDepth) private var maxDepth = 6
    @AppStorage(Prefs.Key.analyzeTimeout) private var timeout = 30
    @AppStorage(Prefs.Key.statusInterval) private var interval = 2.0

    var body: some View {
        Form {
            Section {
                Picker("Gelöschtes", selection: $cleanMode) {
                    Text("Endgültig löschen").tag(Cleaner.Mode.permanent.rawValue)
                    Text("In den Papierkorb legen").tag(Cleaner.Mode.trash.rawValue)
                }
                Toggle("Papierkorb beim Aufräumen mit leeren", isOn: $emptyTrash)
                Toggle("Auch Einträge der Stufe „Prüfen“ vorauswählen", isOn: $preselectReview)
                Stepper(value: $orphanDays, in: 7...365, step: 7) {
                    LabeledContent("Reste entfernter Apps nach", value: String(localized: "\(orphanDays) Tagen"))
                }
                Stepper(value: $largeMB, in: 100...10_000, step: 100) {
                    LabeledContent("Große Datenbestände ab", value: DiskSize.format(Int64(largeMB) * 1_048_576))
                }
            } header: {
                Text("Aufräumen")
            } footer: {
                Text("Endgültig löschen gibt Speicher sofort frei. Im Papierkorb lässt sich alles wiederherstellen, der Platz wird aber erst beim Leeren frei.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Toggle("Persönliche Daten standardmäßig mit entfernen", isOn: $personalData)
                Toggle("Systemdateien standardmäßig mit entfernen", isOn: $systemFiles)
                VStack(alignment: .leading, spacing: 2) {
                    Toggle("Vor dem Deinstallieren die Prüfliste zeigen", isOn: $uninstallConfirm)
                    Text("Ausgeschaltet wird sofort entfernt. Laufende Apps fragen weiterhin nach, bevor sie beendet werden. Alles landet im Papierkorb.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Text("Deinstallieren")
            } footer: {
                Text("Ausgeschaltet (Standard) bleiben Einstellungen, Konten und Daten erhalten, falls du die App später neu installierst. Browser-Profile und App-Gruppen-Daten werden nie automatisch ausgewählt.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !Edition.isStore { HelperSettingsSection() }
            Section("Projekte") {
                Stepper(value: $recentDays, in: 1...90) {
                    LabeledContent("Nicht vorauswählen, wenn benutzt in den letzten", value: String(localized: "\(recentDays) Tagen"))
                }
                Stepper(value: $maxDepth, in: 2...12) {
                    LabeledContent("Suchtiefe", value: String(localized: "\(maxDepth) Ebenen"))
                }
            }
            Section("Speicher und Status") {
                Stepper(value: $timeout, in: 10...300, step: 10) {
                    LabeledContent("Zeitlimit pro Ort", value: String(localized: "\(timeout) Sekunden"))
                }
                Picker("Messintervall", selection: $interval) {
                    Text("1 Sekunde").tag(1.0)
                    Text("2 Sekunden").tag(2.0)
                    Text("5 Sekunden").tag(5.0)
                    Text("10 Sekunden").tag(10.0)
                }
            }
            Section {
                Button("Alle Werte auf Standard zurücksetzen") {
                    for key in [Prefs.Key.cleanEmptyTrash, Prefs.Key.cleanPreselectReview, Prefs.Key.orphanAgeDays, Prefs.Key.largeDataMinMB,
                                Prefs.Key.uninstallPersonalData, Prefs.Key.uninstallSystemFiles, Prefs.Key.uninstallConfirm, Prefs.Key.purgeRecentDays,
                                Prefs.Key.purgeMaxDepth, Prefs.Key.analyzeTimeout, Prefs.Key.statusInterval, "cleanMode"] {
                        UserDefaults.standard.removeObject(forKey: key)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: recentDays) { Prefs.applyToCore() }
        .onChange(of: maxDepth) { Prefs.applyToCore() }
        .onChange(of: timeout) { Prefs.applyToCore() }
    }
}

// MARK: Protected data (whitelist)

/// The whitelist, explained: switched-on entries are never cleaned.
struct ProtectedDataView: View {
    @State private var whitelist: Whitelist?
    @State private var protection: ProtectionData?
    @State private var sizes: [String: Int64] = [:]
    @State private var search = ""
    @State private var newPattern = ""
    @State private var error: String?

    private var home: String { UserHome.path }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("So funktioniert der Schutz", systemImage: "shield.lefthalf.filled").font(.headline)
                    Text("Eingeschaltete Einträge fasst Swabr beim Aufräumen nie an, auch wenn eine Regel sie sonst erfassen würde. Schütze, was du behalten willst, z. B. große Caches, die lange neu zu laden sind (Gradle, Xcode, KI-Modelle).")
                        .font(.callout).foregroundStyle(.secondary)
                    Text("Änderungen werden sofort gespeichert. Zusätzlich gelten immer die Sicherheitsregeln unten.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                TextField("Suchen", text: $search).textFieldStyle(.roundedBorder)
            }
            if let whitelist, let protection {
                ForEach(categories(protection), id: \.self) { category in
                    Section(Self.categoryTitle(category)) {
                        ForEach(options(protection, category)) { option in
                            optionRow(option, whitelist: whitelist, isDefault: protection.defaultWhitelist.contains(option.pattern))
                        }
                    }
                }
                Section {
                    let custom = customPatterns(whitelist, protection)
                    if custom.isEmpty { Text("Noch keine eigenen Einträge.").foregroundStyle(.secondary) }
                    ForEach(custom, id: \.self) { pattern in
                        HStack {
                            Image(systemName: "folder.badge.minus").foregroundStyle(.secondary)
                            VStack(alignment: .leading) {
                                Text(pattern).font(.callout.monospaced())
                                Text(matchSummary(pattern)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Entfernen") { update { $0.setProtected(pattern, false) } }.controlSize(.small)
                        }
                    }
                    HStack {
                        TextField("Pfad oder Muster, z. B. ~/Library/Caches/MeineApp*", text: $newPattern)
                            .font(.callout.monospaced())
                        Button("Hinzufügen") { addPattern(newPattern) }.disabled(newPattern.trimmingCharacters(in: .whitespaces).isEmpty)
                        Button("Ordner wählen …") { chooseFolder() }
                    }
                    if !newPattern.isEmpty { Text(matchSummary(normalized(newPattern))).font(.caption).foregroundStyle(.secondary) }
                } header: {
                    Text("Eigene Einträge")
                } footer: {
                    Text("„~“ steht für deinen Benutzerordner, „*“ für beliebige Zeichen. „~/Library/Caches/Foo/*“ schützt alles in diesem Ordner, „~/Library/Caches/Foo*“ alle Ordner, die so beginnen.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    ForEach(protection.safetyWhitelist, id: \.self) { pattern in
                        HStack {
                            Image(systemName: "lock.fill").foregroundStyle(.secondary)
                            Text(pattern).font(.caption.monospaced())
                        }
                    }
                } header: {
                    Text("Sicherheitsregeln (immer aktiv)")
                } footer: {
                    Text("Ohne diese Daten funktionieren Spotlight, Schriften, iCloud oder Python-Umgebungen nicht mehr richtig. Zusätzlich sind iCloud Drive, Schlüsselbund, Dokumente, Schreibtisch und alles außerhalb deines Benutzerordners grundsätzlich tabu.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    HStack {
                        Text("Gespeichert in \(Whitelist.fileURL(home: home).path)").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Auf Standard zurücksetzen") {
                            try? Whitelist.reset(home: home)
                            load()
                        }
                    }
                    if let error { Text(error).foregroundStyle(.red) }
                }
            }
        }
        .formStyle(.grouped)
        .task { load() }
    }

    private func optionRow(_ option: WhitelistOption, whitelist: Whitelist, isDefault: Bool) -> some View {
        Toggle(isOn: Binding(get: { whitelist.isProtected(pattern: option.pattern) },
                             set: { on in update { $0.setProtected(option.pattern, on) } })) {
            HStack(spacing: 6) {
                Text(verbatim: option.label)
                if isDefault {
                    Text("Standard").font(.caption2.weight(.medium))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.secondary.opacity(0.15), in: .capsule).foregroundStyle(.secondary)
                }
            }
            Text("\(option.pattern) · \(sizes[option.pattern].map(DiskSize.format) ?? "–")")
                .font(.caption.monospaced())
        }
        .toggleStyle(.switch)
    }

    static func categoryTitle(_ c: String) -> LocalizedStringKey {
        switch c {
        case "system_cache": "System und Apple-Apps"
        case "ide_cache": "Entwicklungsumgebungen"
        case "compiler_cache": "Build- und Compiler-Caches"
        case "package_manager": "Paketmanager"
        case "ai_ml_cache": "KI und Modelle"
        case "browser_cache": "Browser"
        case "container_cache": "Container und VMs"
        case "network_tools": "Netzwerk-Werkzeuge"
        case "apps": "Apps"
        default: LocalizedStringKey(c)
        }
    }

    private func categories(_ p: ProtectionData) -> [String] {
        var seen: [String] = []
        for o in p.whitelistOptions where !seen.contains(o.category) && !options(p, o.category).isEmpty { seen.append(o.category) }
        return seen
    }

    private func options(_ p: ProtectionData, _ category: String) -> [WhitelistOption] {
        p.whitelistOptions.filter {
            $0.category == category
                && (search.isEmpty || $0.label.localizedCaseInsensitiveContains(search) || $0.pattern.localizedCaseInsensitiveContains(search)
                    || String(localized: String.LocalizationValue($0.label)).localizedCaseInsensitiveContains(search))
        }
    }

    private func customPatterns(_ w: Whitelist, _ p: ProtectionData) -> [String] {
        let known = Set(p.whitelistOptions.map(\.pattern))
        return w.userPatterns.filter { !known.contains($0) && !p.defaultWhitelist.contains($0) }
    }

    private func normalized(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix(home + "/") ? "~" + t.dropFirst(home.count) : t
    }

    private func matchSummary(_ pattern: String) -> String {
        let matches = PathGlob.expand(pattern, home: home)
        if matches.isEmpty { return String(localized: "trifft derzeit nichts") }
        return String(localized: "trifft \(matches.count) Einträge")
    }

    private func addPattern(_ raw: String) {
        let p = normalized(raw)
        guard !p.isEmpty else { return }
        update { $0.setProtected(p, true) }
        newPattern = ""
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: home + "/Library/Caches")
        panel.prompt = String(localized: "Schützen")
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { addPattern(url.path) }
    }

    private func update(_ change: (inout Whitelist) -> Void) {
        guard var w = whitelist else { return }
        change(&w)
        do {
            try w.save()
            whitelist = w
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func load() {
        do {
            let p = try RuleStore.protection()
            protection = p
            whitelist = try Whitelist.load(home: home, protection: p)
            let patterns = p.whitelistOptions.map(\.pattern)
            let h = home
            Task.detached {
                var out: [String: Int64] = [:]
                for pattern in patterns {
                    out[pattern] = PathGlob.expand(pattern, home: h).reduce(Int64(0)) { $0 + DiskSize.allocatedSize(of: $1) }
                }
                await MainActor.run { sizes = out }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: App Store folder grants

/// App Store edition: folders the user granted, with a way to take access back.
struct AccessSettingsView: View {
    @State private var paths = FolderAccess.paths

    var body: some View {
        Form {
            Section {
                if paths.isEmpty { Text("Noch keine Ordner freigegeben.").foregroundStyle(.secondary) }
                ForEach(paths, id: \.self) { path in
                    HStack {
                        Image(systemName: "folder")
                        Text(path.replacingOccurrences(of: UserHome.path, with: "~"))
                        Spacer()
                        Button("Widerrufen") {
                            FolderAccess.forget(path)
                            paths = FolderAccess.paths
                        }
                    }
                }
            } header: {
                Text("Freigegebene Ordner")
            } footer: {
                Text("Swabr kann nur in diesen Ordnern lesen und löschen. Ohne Freigabe von Programme und Benutzerordner sind Aufräumen, Optimieren und Deinstallieren gesperrt.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: About

struct AboutView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var showLicense = false

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
            Text(verbatim: "Swabr").font(.title.bold())
            Text("Version \(Edition.version) · \(Edition.name)").foregroundStyle(.secondary)
            Text("Swabr für den Mac: aufräumen, Apps entfernen, Speicher analysieren und den Zustand im Blick behalten.")
                .multilineTextAlignment(.center).frame(maxWidth: 440).foregroundStyle(.secondary)
            Button("Lizenzhinweise") { showLicense.toggle() }
                .buttonStyle(.link).font(.caption)
                .popover(isPresented: $showLicense) {
                    Text("© 2026 mkmaps. Swabr ist freie Software unter der MIT-Lizenz und wird ohne jede Gewährleistung bereitgestellt.")
                        .frame(width: 320).fixedSize(horizontal: false, vertical: true).padding()
                }
            HStack {
                Button("Hilfe öffnen") { openWindow(id: HelpWindow.id) }
                Button("Datenschutz") { openWindow(id: HelpWindow.id, value: HelpTopic.privacy) }
            }
            if !Edition.isStore {
                Link("Quellcode auf GitHub", destination: Edition.repositoryURL).font(.callout)
            }
            if Edition.isStore {
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("In dieser Version nicht enthalten").font(.headline)
                        Text("Apps aktualisieren, Anmeldeobjekte verwalten, Optimierungen mit Administratorrechten und Verschlanken brauchen Rechte, die Apps aus dem App Store nicht erhalten.")
                            .font(.callout).foregroundStyle(.secondary)
                        Link("Direct-Version und Quellcode auf GitHub", destination: Edition.repositoryURL)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: 480)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

/// Sets up or removes the privileged helper, so administrator steps no longer ask for the password.
private struct HelperSettingsSection: View {
    @State private var state = PrivilegedHelper.state
    @State private var error: String?

    var body: some View {
        Section {
            HStack {
                switch state {
                case .enabled:
                    Label("Eingerichtet: kein Passwort mehr nötig", systemImage: "checkmark.shield").foregroundStyle(.green)
                    Spacer()
                    Button("Entfernen") { change { try PrivilegedHelper.uninstall() } }
                case .needsApproval:
                    Label("Wartet auf deine Erlaubnis in den Systemeinstellungen", systemImage: "hand.raised").foregroundStyle(.orange)
                    Spacer()
                    SettingsGearButton(String(localized: "Systemeinstellungen → Anmeldeobjekte öffnen")) { PrivilegedHelper.openApproval() }
                    Button("Entfernen") { change { try PrivilegedHelper.uninstall() } }
                case .notInstalled, .unavailable:
                    Text("Nicht eingerichtet: macOS fragt jedes Mal nach dem Passwort")
                    Spacer()
                    Button("Einrichten …") { change { try PrivilegedHelper.install() } }
                }
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        } header: {
            HStack {
                Text("Administratorrechte")
                Spacer()
                HelpButton(topic: .adminHelper)
            }
        } footer: {
            Text("Ein Hilfsdienst von Swabr führt Schritte mit Administratorrechten aus (Deinstallieren, Optimieren, Startobjekte), ohne jedes Mal nach dem Passwort zu fragen. Du erlaubst ihn einmal unter Systemeinstellungen → Allgemein → Anmeldeobjekte. Er nimmt nur Aufträge von Swabr an. Danach laufen diese Schritte ohne Rückfrage.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state = PrivilegedHelper.state
        }
    }

    private func change(_ work: () throws -> Void) {
        do {
            try work()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        state = PrivilegedHelper.state
    }
}
