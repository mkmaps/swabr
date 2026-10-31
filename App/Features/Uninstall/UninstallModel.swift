import AppKit
import SwabrCore
import Observation

@MainActor @Observable
final class UninstallModel {
    enum Phase {
        case loading
        case ready
        case removing
        case done(UninstallReport)
    }

    var phase = Phase.loading
    var apps: [InstalledApp] = []
    /// Apps ticked for removal.
    var checked: Set<String> = []
    /// App shown in the detail pane.
    var focused: String?
    /// Leftovers per app path, filled on demand.
    var leftovers: [String: [Leftover]] = [:]
    /// Ticked leftover paths.
    var chosenLeftovers: Set<String> = []
    /// Developer, description and links per app path; local facts first, online ones added later.
    var infos: [String: AppInfo] = [:]
    var loadingInfo: Set<String> = []
    var search = ""
    var sort = ListOrder(rawValue: UserDefaults.standard.string(forKey: "appsOrder") ?? "") ?? .name {
        didSet { UserDefaults.standard.set(sort.rawValue, forKey: "appsOrder") }
    }
    var currentStep = ""
    var errorMessage: String?
    /// App whose data the user wants to remove while keeping the app ("reset").
    var resetCandidate: InstalledApp?

    var visibleApps: [InstalledApp] {
        let filtered = search.isEmpty ? apps : apps.filter { $0.name.localizedCaseInsensitiveContains(search) }
        switch sort {
        case .name, .natural: return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .size: return filtered.sorted { $0.bytes > $1.bytes }
        case .newest, .oldest: return sort.byDate(filtered, \.lastUsed)
        }
    }

    var checkedApps: [InstalledApp] { apps.filter { checked.contains($0.path) } }
    var focusedApp: InstalledApp? { apps.first { $0.path == focused } }

    var plans: [UninstallPlan] {
        checkedApps.map { app in
            UninstallPlan(app: app, leftovers: (leftovers[app.path] ?? []).filter { chosenLeftovers.contains($0.path) })
        }
    }

    var totalBytes: Int64 {
        plans.reduce(0) { $0 + $1.app.bytes + $1.leftovers.reduce(0) { $0 + $1.bytes } }
    }

    func load() async {
        phase = .loading
        do {
            let protection = try RuleStore.protection()
            apps = await AppCatalog.installedApps(protection: protection)
            checked = checked.filter { p in apps.contains { $0.path == p } }
            if focused == nil { focused = apps.first(where: \.isRemovable)?.path }
            if let f = focusedApp {
                Task { await ensureInfo(for: f) }
                await ensureLeftovers(for: f)
            }
            phase = .ready
        } catch {
            errorMessage = error.localizedDescription
            phase = .ready
        }
    }

    /// System-owned apps are removable in both editions: the direct one asks Finder, the App Store one
    /// the system Trash service, and each shows the password dialog.
    func canRemove(_ app: InstalledApp) -> Bool { app.isRemovable }

    func toggle(_ app: InstalledApp) {
        guard canRemove(app) else { return }
        if checked.contains(app.path) {
            checked.remove(app.path)
        } else {
            checked.insert(app.path)
            Task { await ensureLeftovers(for: app) }
        }
    }

    func focus(_ path: String?) {
        focused = path
        if let app = focusedApp {
            Task { await ensureLeftovers(for: app) }
            Task { await ensureInfo(for: app) }
        }
    }

    func ensureInfo(for app: InstalledApp) async {
        guard infos[app.path] == nil else { return }
        let local = await Task.detached { AppInfoLocal.read(app) }.value
        infos[app.path] = local
        loadingInfo.insert(app.path)
        if Prefs.onlineInfo { infos[app.path] = await AppInfoService.shared.enrich(app, local) }
        loadingInfo.remove(app.path)
    }

    /// Finds leftovers once per app; caches, logs and agents start ticked, personal data does not.
    /// App Store edition: grant /Library, then search the focused app's leftovers again to include system files.
    func grantLibrary() {
        guard FolderAccess.grant("/Library", message: String(localized: "Bitte „Library“ auswählen und auf „Zugriff erlauben“ klicken, damit Swabr Systemdateien von Apps findet.")) else { return }
        leftovers = [:]
        if let app = focusedApp { Task { await ensureLeftovers(for: app) } }
    }

    func ensureLeftovers(for app: InstalledApp) async {
        guard leftovers[app.path] == nil else { return }
        let all = apps
        var found = await Task.detached { LeftoverFinder.find(for: app, otherApps: all) }.value
        // App Store edition: /Library files only once the user granted /Library.
        if Edition.isStore && !FolderAccess.covers("/Library") { found.removeAll { $0.kind == .system } }
        leftovers[app.path] = found
        chosenLeftovers.formUnion(found.filter { l in
            l.preselected || (l.kind == .personal && Prefs.uninstallPersonalData) || (l.kind == .system && l.evidence == .identity && Prefs.uninstallSystemFiles)
        }.map(\.path))
    }

    /// What "remove data only" takes: caches, logs, window state and settings. The app, its background
    /// services and system files stay (the app still needs them); shared and sensitive data too.
    func resetData(of app: InstalledApp) -> [Leftover] {
        (leftovers[app.path] ?? []).filter { $0.kind == .disposable || $0.kind == .personal }
    }

    func prepareReset(_ app: InstalledApp) async {
        await ensureLeftovers(for: app)
        resetCandidate = app
    }

    /// Quits the app, then moves its data to the Trash; the app itself stays installed.
    func reset(_ app: InstalledApp) async {
        let data = resetData(of: app)
        phase = .removing
        for running in NSWorkspace.shared.runningApplications where running.bundleIdentifier == app.bundleID {
            currentStep = String(localized: "Beende \(running.localizedName ?? "App") …")
            running.terminate()
        }
        for _ in 0..<20 where NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == app.bundleID }) {
            try? await Task.sleep(for: .milliseconds(500))
        }
        var report: UninstallReport
        if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == app.bundleID }) {
            report = UninstallReport()
            report.dataOnly = true
            report.failures.append(.init(path: app.path, reason: String(localized: "App läuft noch und wurde nicht beendet")))
        } else {
            let plan = [UninstallPlan(app: app, leftovers: data)]
            report = await Task.detached { Edition.isStore
                ? Uninstaller.run(plan, privilegedTrash: WorkspaceTrash.move, keepApps: true)
                : Uninstaller.run(plan, privilegedTrash: FinderTrash.move, runPrivileged: Privileged.run, keepApps: true) }.value
        }
        leftovers[app.path] = nil
        resetCandidate = nil
        phase = .done(report)
    }

    func toggleLeftover(_ path: String) {
        if chosenLeftovers.contains(path) { chosenLeftovers.remove(path) } else { chosenLeftovers.insert(path) }
    }

    /// Ticks or unticks every personal (non-sensitive) path of one app.
    func setPersonalData(for app: InstalledApp, _ on: Bool) {
        for l in leftovers[app.path] ?? [] where l.kind == .personal {
            if on { chosenLeftovers.insert(l.path) } else { chosenLeftovers.remove(l.path) }
        }
    }

    var runningCheckedApps: [NSRunningApplication] {
        let ids = Set(checkedApps.map(\.bundleID))
        return NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier.map(ids.contains) ?? false }
    }

    var reviewLines: [ReviewLine] {
        plans.flatMap { plan -> [ReviewLine] in
            let personal = plan.leftovers.filter { $0.kind == .personal || $0.kind == .sensitive || $0.kind == .system }
            var lines = [ReviewLine(
                id: plan.app.path, title: plan.app.name, iconPath: plan.app.path,
                bytes: plan.app.bytes + plan.leftovers.filter { ![.personal, .sensitive, .system].contains($0.kind) }.reduce(0) { $0 + $1.bytes },
                impact: String(localized: "App und \(plan.leftovers.count - personal.count) zugehörige Caches/Dienste.")
                    + (personal.isEmpty ? String(localized: " Persönliche Daten bleiben erhalten.") : ""),
                warning: false)]
            for p in personal {
                lines.append(ReviewLine(
                    id: p.path, title: "\(plan.app.name): \((p.path as NSString).lastPathComponent)", iconPath: nil,
                    bytes: p.bytes, impact: p.impact, warning: true))
            }
            return lines
        }
    }

    /// Quits running apps (waiting up to 10 s), then moves everything to the Trash.
    func uninstall() async {
        let plans = plans
        phase = .removing
        for running in runningCheckedApps {
            currentStep = String(localized: "Beende \(running.localizedName ?? "App") …")
            running.terminate()
        }
        for _ in 0..<20 where !runningCheckedApps.isEmpty {
            try? await Task.sleep(for: .milliseconds(500))
        }
        let stillRunning = Set(runningCheckedApps.compactMap(\.bundleIdentifier))
        let runnable = plans.filter { !stillRunning.contains($0.app.bundleID) }
        var report = await Task.detached { Edition.isStore
            ? Uninstaller.run(runnable, privilegedTrash: WorkspaceTrash.move)
            : Uninstaller.run(runnable, privilegedTrash: FinderTrash.move, runPrivileged: Privileged.run) }.value
        for plan in plans where stillRunning.contains(plan.app.bundleID) {
            report.failures.append(.init(path: plan.app.path, reason: String(localized: "App läuft noch und wurde nicht beendet")))
        }
        // Network filters, drivers and the like keep running until switched off in System Settings.
        if !Edition.isStore {
            let ids = runnable.map(\.app.bundleID)
            report.activeExtensions = await Task.detached { SystemExtensions.stillActive(for: ids) }.value
        }
        checked = []
        leftovers = [:]
        chosenLeftovers = []
        focused = nil
        phase = .done(report)
    }
}
