import AppKit
import SwabrCore
import Observation

@MainActor @Observable
final class OptimizeModel {
    enum Phase {
        case ready, running, done
    }

    static let disabledKey = "optimizeDisabledTasks"
    static let lastRunKey = "optimizeLastRun"

    /// When each task last ran, for sorting by newest and oldest.
    var lastRun: [String: Date] = (UserDefaults.standard.dictionary(forKey: lastRunKey) as? [String: Date]) ?? [:] {
        didSet { UserDefaults.standard.set(lastRun, forKey: Self.lastRunKey) }
    }

    /// The App Store edition offers only the tasks that need no administrator rights (guideline 2.4.5 v).
    let tasks = Edition.isStore ? OptimizeCatalog.all.filter { OptimizeCatalog.sandboxSafeIDs.contains($0.id) } : OptimizeCatalog.all
    var phase = Phase.ready
    var results: [String: OptimizeOutcome] = [:]
    var currentStep = ""
    /// Unticked tasks are remembered and stay off in later runs.
    var selected: Set<String> {
        didSet { UserDefaults.standard.set(tasks.map(\.id).filter { !selected.contains($0) }, forKey: Self.disabledKey) }
    }

    init() {
        let disabled = Set(UserDefaults.standard.stringArray(forKey: Self.disabledKey) ?? [])
        selected = Set(OptimizeCatalog.all.map(\.id).filter { !disabled.contains($0) })
    }

    var chosen: [OptimizeTask] { tasks.filter { selected.contains($0.id) } }
    var adminCount: Int { chosen.filter(\.needsAdmin).count }

    func toggle(_ id: String) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    var reviewLines: [ReviewLine] {
        chosen.map { t in
            ReviewLine(id: t.id, title: t.title + (t.needsAdmin ? String(localized: " (Passwort)") : ""), iconPath: nil, bytes: 0,
                       impact: t.impact, warning: t.noticeable)
        }
    }

    func run() async {
        let tasks = chosen
        phase = .running
        results = [:]
        // Names and bundle ids: tasks ask by bundle id (saved states, preferences) as well as by app name.
        let ctx = OptimizeContext(isAppRunning: RunningApps.snapshot())
        let report: @Sendable (String) -> Void = { [weak self] step in
            Task { @MainActor in self?.currentStep = step }
        }
        let out = await Task.detached {
            // The sandboxed edition has no root shell; its catalogue holds no admin tasks anyway.
            Optimizer.run(tasks, context: ctx, runPrivileged: Edition.isStore ? nil : Privileged.run, progress: report)
        }.value
        results = out
        let now = Date()
        for id in out.keys { lastRun[id] = now }
        phase = .done
    }

    var summary: String {
        var applied = 0, unchanged = 0, skipped = 0, other = 0
        for r in results.values {
            switch r {
            case .applied: applied += 1
            case .unchanged: unchanged += 1
            case .skipped: skipped += 1
            default: other += 1
            }
        }
        return String(localized: "\(applied) angewendet · \(unchanged) unverändert · \(skipped) übersprungen") + (other > 0 ? String(localized: " · \(other) Hinweise/nicht verfügbar") : "")
    }
}
