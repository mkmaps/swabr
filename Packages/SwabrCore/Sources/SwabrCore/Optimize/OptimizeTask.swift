import AppKit
import Darwin
import Foundation

/// What a maintenance task did. Every task ends in exactly one of these states.
public enum OptimizeOutcome: Equatable, Sendable {
    case applied(String)
    case unchanged(String)
    case skipped(String)
    case attention(String)
    case failed(String)
    case unavailable(String)

    public var message: String {
        switch self {
        case .applied(let m), .unchanged(let m), .skipped(let m), .attention(let m), .failed(let m), .unavailable(let m): m
        }
    }
}

/// A shell command that needs root. All steps of a run share one password prompt; `interpret` turns the
/// step's exit status and output into the task's outcome.
public struct AdminStep: Sendable {
    public let command: RootCommand
    public let interpret: @Sendable (Int32, String) -> OptimizeOutcome

    public init(command: RootCommand, interpret: @escaping @Sendable (Int32, String) -> OptimizeOutcome) {
        self.command = command
        self.interpret = interpret
    }
}

public struct OptimizeTask: Identifiable, Sendable {
    /// Result of the check: either the task is finished, or it still needs a root step.
    public enum Plan: Sendable {
        case done(OptimizeOutcome)
        case admin(AdminStep)
    }

    public let id: String
    public let title: String
    public let summary: String
    public let impact: String
    public let needsAdmin: Bool
    /// The user notices a side effect (connection drops, index rebuilds …).
    public let noticeable: Bool
    /// Checks whether there is anything to do and does all the work that needs no root.
    public let prepare: @Sendable (OptimizeContext) -> Plan

    public init(id: String, title: String, summary: String, impact: String, needsAdmin: Bool, noticeable: Bool,
                prepare: @escaping @Sendable (OptimizeContext) -> Plan) {
        self.id = id
        self.title = title
        self.summary = summary
        self.impact = impact
        self.needsAdmin = needsAdmin
        self.noticeable = noticeable
        self.prepare = prepare
    }
}

/// Everything a task may touch. The internal members exist so tests can replace commands, the Trash
/// and system locations.
public struct OptimizeContext: Sendable {
    /// Runs a tool with arguments and a timeout; status -1 when it could not start or timed out.
    typealias Command = @Sendable (_ tool: String, _ arguments: [String], _ timeout: TimeInterval) -> (status: Int32, output: String)

    public let home: String
    /// Asked with app names and bundle ids.
    public let isAppRunning: @Sendable (String) -> Bool
    public let log: OperationLog

    var run: Command = { Shell.run($0, $1, timeout: $2) }
    /// Moves a file to the Trash; nil on success, otherwise the reason.
    var trash: @Sendable (String) -> String? = OptimizeContext.systemTrash
    /// Names an installed app with this bundle id runs under, for the running-app check.
    var appNames: @Sendable (String) -> [String] = OptimizeContext.installedAppNames
    var now = Date()
    var uid: uid_t = getuid()
    var systemLaunchFolders: [(String, StartupItem.Kind)] = [("/Library/LaunchAgents", .systemAgent), ("/Library/LaunchDaemons", .daemon)]
    /// Spotlight keeps its per-volume settings, including the privacy exclusions, in this file (root only).
    var spotlightConfigs = ["/System/Volumes/Data/.Spotlight-V100/VolumeConfiguration.plist", "/.Spotlight-V100/VolumeConfiguration.plist"]
    var periodicTool = "/usr/sbin/periodic"
    /// periodic(8) writes `daily.out`, `weekly.out` and `monthly.out` here.
    var periodicLogs = "/var/log"
    var databaseSizeLimit = SQLiteMaintenance.sizeLimit
    var busyTimeout = SQLiteMaintenance.busyTimeout

    public init(home: String = UserHome.path, isAppRunning: @escaping @Sendable (String) -> Bool,
                log: OperationLog = OperationLog()) {
        self.home = home
        self.isAppRunning = isAppRunning
        self.log = log
    }

    func command(_ tool: String, _ arguments: [String], timeout: TimeInterval = 60) -> (status: Int32, output: String) {
        run(tool, arguments, timeout)
    }

    /// True when the app with this bundle id (or one of the given names) is running.
    func isRunning(bundleID: String, names: [String] = []) -> Bool {
        ([bundleID] + names + appNames(bundleID)).contains(where: isAppRunning)
    }

    /// `~/…` for messages.
    func tilde(_ path: String) -> String {
        path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
    }

    static let systemTrash: @Sendable (String) -> String? = { path in
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    static let installedAppNames: @Sendable (String) -> [String] = { bundleID in
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return [] }
        var names = [url.deletingPathExtension().lastPathComponent]
        if let info = Bundle(url: url)?.infoDictionary {
            for key in ["CFBundleDisplayName", "CFBundleName"] {
                if let n = info[key] as? String, !n.isEmpty, !names.contains(n) { names.append(n) }
            }
        }
        return names
    }
}

public enum Optimizer {
    /// Checks every task, then runs all root steps in one privileged run (at most one password prompt).
    /// Without `runPrivileged` (App Store edition) tasks that need root are not run.
    public static func run(_ tasks: [OptimizeTask], context: OptimizeContext,
                           runPrivileged: RootRunner? = nil,
                           progress: @escaping @Sendable (String) -> Void = { _ in }) -> [String: OptimizeOutcome] {
        var results: [String: OptimizeOutcome] = [:]
        var pending: [(id: String, step: AdminStep)] = []
        let noAdmin = String(localized: "braucht Administratorrechte", bundle: .module)
        for task in tasks where results[task.id] == nil && !pending.contains(where: { $0.id == task.id }) {
            if task.needsAdmin && runPrivileged == nil {
                results[task.id] = .unavailable(noAdmin)
                continue
            }
            progress(task.title)
            switch task.prepare(context) {
            case .done(let outcome): results[task.id] = outcome
            case .admin(let step):
                if runPrivileged == nil { results[task.id] = .unavailable(noAdmin) } else { pending.append((task.id, step)) }
            }
        }
        guard !pending.isEmpty, let runPrivileged else { return results }

        progress(String(localized: "Aufgaben mit Administratorrechten", bundle: .module))
        guard let finished = runPrivileged(pending.map { .command($0.step.command) }) else {
            let declined = String(localized: "Administratorrechte nicht erteilt", bundle: .module)
            for p in pending { results[p.id] = .skipped(declined) }
            return results
        }
        for (n, p) in pending.enumerated() {
            if n < finished.count {
                let r = finished[n]
                results[p.id] = p.step.interpret(r.status, r.output.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                results[p.id] = .failed(String(localized: "Ergebnis nicht erkannt", bundle: .module))
            }
        }
        return results
    }
}
