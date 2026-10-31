import Foundation

/// One reading of the machine's live state, as shown in the Status view and the menu bar.
public struct StatusSnapshot: Sendable {
    public struct Hardware: Sendable {
        /// Readable model name ("MacBook Air"), or the raw identifier until that is known.
        public var model: String
        public var modelIdentifier: String
        public var chip: String
        public var memoryBytes: UInt64
        public var osVersion: String
        public var uptime: TimeInterval
    }

    public struct CPU: Sendable {
        /// Total usage in percent of all cores.
        public var usage: Double
        public var perCore: [Double]
        /// Load average over 1, 5 and 15 minutes.
        public var load: (Double, Double, Double)
        /// Mean usage of the samples taken during the last minute.
        public var minuteAverage: Double
    }

    public struct Memory: Sendable {
        public enum Pressure: Sendable, Equatable {
            case normal, warn, critical

            /// Maps `kern.memorystatus_vm_pressure_level` (1 normal, 2 warning, 4 critical).
            public init(level: Int) {
                switch level {
                case 4...: self = .critical
                case 2...: self = .warn
                default: self = .normal
                }
            }
        }

        public var total: UInt64
        /// Active + wired + compressed.
        public var used: UInt64
        public var available: UInt64
        public var wired: UInt64
        public var compressed: UInt64
        /// Inactive, speculative and file-backed pages macOS can hand out again.
        public var cached: UInt64
        public var swapUsed: UInt64
        public var swapTotal: UInt64
        public var pressure: Pressure

        public var usedPercent: Double { total > 0 ? Double(used) / Double(total) * 100 : 0 }
    }

    public struct Disk: Sendable {
        public var total: Int64
        /// Space available for important use (includes purgeable space).
        public var free: Int64
        /// Bytes per second.
        public var readRate: Double
        public var writeRate: Double

        public var used: Int64 { max(0, total - free) }
        public var usedPercent: Double { total > 0 ? Double(used) / Double(total) * 100 : 0 }
        public var freePercent: Double { total > 0 ? Double(free) / Double(total) * 100 : 0 }
    }

    public struct Battery: Sendable {
        public var level: Int
        public var isCharging: Bool
        public var onACPower: Bool
        public var isCharged: Bool
        public var minutesRemaining: Int?
        public var cycles: Int
        /// Full-charge capacity relative to design capacity, 0 when unknown.
        public var healthPercent: Int
        /// Degrees Celsius.
        public var temperature: Double?

        public var statusText: String {
            if isCharging { return String(localized: "Lädt", bundle: .module) }
            if onACPower { return isCharged ? String(localized: "Geladen", bundle: .module) : String(localized: "Angeschlossen, lädt nicht", bundle: .module) }
            return String(localized: "Akkubetrieb", bundle: .module)
        }

        public var health: (label: String, severity: HealthScore.Severity) {
            HealthScore.batteryHealth(cycles: cycles, capacity: healthPercent)
        }
    }

    public struct Network: Sendable {
        public var interface: String?
        public var address: String?
        /// Bytes per second, smoothed.
        public var downRate: Double
        public var upRate: Double
        public var proxy: String?
    }

    public struct Processes: Sendable {
        public struct Process: Sendable, Identifiable, Hashable {
            public var pid: Int32
            public var name: String
            /// Percent of one core; a busy multi-threaded process can exceed 100.
            public var cpu: Double
            public var memory: UInt64

            public var id: Int32 { pid }

            public init(pid: Int32, name: String, cpu: Double, memory: UInt64) {
                self.pid = pid
                self.name = name
                self.cpu = cpu
                self.memory = memory
            }
        }

        public var count: Int
        public var top: [Process]
        public var zombies: [Process]

        public init(count: Int, top: [Process], zombies: [Process]) {
            self.count = count
            self.top = top
            self.zombies = zombies
        }
    }

    public struct Health: Sendable, Equatable {
        public var score: Int
        public var label: String
        public var issues: [String]

        public init(score: Int, label: String, issues: [String]) {
            self.score = score
            self.label = label
            self.issues = issues
        }
    }

    public var date: Date
    public var hardware: Hardware
    public var cpu: CPU
    public var memory: Memory
    public var disk: Disk
    public var battery: Battery?
    public var network: Network
    public var processes: Processes
    public var health: Health
}

/// Swabr's own health weighting: start at 100, subtract per finding, clamp to 0...100.
public enum HealthScore {
    public enum Severity: Sendable, Equatable {
        case ok, warn, danger, unknown
    }

    private static let gigabyte: Int64 = 1_000_000_000
    private static let gibibyte: UInt64 = 1 << 30
    private static let day: TimeInterval = 86_400

    /// Every parameter defaults to "nothing to report", so callers pass only what they measured.
    public static func compute(
        diskFree: Int64? = nil,
        diskTotal: Int64? = nil,
        pressure: StatusSnapshot.Memory.Pressure = .normal,
        swapUsed: UInt64 = 0,
        cpuMinuteAverage: Double = 0,
        battery: Severity = .unknown,
        uptime: TimeInterval = 0,
        zombies: Int = 0
    ) -> StatusSnapshot.Health {
        var deductions: [(points: Int, issue: String)] = []
        func t(_ key: String.LocalizationValue) -> String { String(localized: key, bundle: .module) }

        if let free = diskFree, let total = diskTotal, total > 0 {
            let percent = Double(free) / Double(total) * 100
            if percent < 5 || free < 10 * gigabyte {
                deductions.append((25, t("Festplatte fast voll")))
            } else if percent < 10 {
                deductions.append((15, t("Festplatte fast voll")))
            } else if percent < 20 {
                deductions.append((5, t("Wenig freier Speicherplatz")))
            }
        }

        switch pressure {
        case .critical: deductions.append((25, t("Kritischer Speicherdruck")))
        case .warn: deductions.append((15, t("Erhöhter Speicherdruck")))
        case .normal: break
        }

        if swapUsed > 8 * gibibyte {
            deductions.append((15, t("Viel Speicher ausgelagert")))
        } else if swapUsed > 2 * gibibyte {
            deductions.append((5, t("Viel Speicher ausgelagert")))
        }

        if cpuMinuteAverage > 90 {
            deductions.append((15, t("Hohe CPU-Last")))
        } else if cpuMinuteAverage > 70 {
            deductions.append((5, t("Hohe CPU-Last")))
        }

        switch battery {
        case .danger: deductions.append((15, t("Akku bald austauschen")))
        case .warn: deductions.append((5, t("Akku lässt nach")))
        case .ok, .unknown: break
        }

        if uptime > 30 * day {
            deductions.append((15, t("Neustart empfohlen")))
        } else if uptime > 14 * day {
            deductions.append((5, t("Neustart empfohlen")))
        }

        if zombies >= 10 {
            deductions.append((15, t("Zombie-Prozesse vorhanden")))
        } else if zombies >= 1 {
            deductions.append((5, t("Zombie-Prozesse vorhanden")))
        }

        let score = min(100, max(0, 100 - deductions.reduce(0) { $0 + $1.points }))
        return .init(score: score, label: label(for: score), issues: deductions.map(\.issue))
    }

    public static func label(for score: Int) -> String {
        switch score {
        case 90...: String(localized: "Ausgezeichnet", bundle: .module)
        case 75...: String(localized: "Gut", bundle: .module)
        case 50...: String(localized: "Mittel", bundle: .module)
        default: String(localized: "Kritisch", bundle: .module)
        }
    }

    /// `capacity` is the full-charge capacity in percent of design capacity; 0 or less means unknown.
    public static func batteryHealth(cycles: Int, capacity: Int) -> (label: String, severity: Severity) {
        let severity: Severity
        if capacity > 0 {
            if capacity < 70 { severity = .danger }
            else if capacity < 80 || cycles >= 1000 { severity = .warn }
            else { severity = .ok }
        } else {
            severity = cycles >= 1000 ? .warn : .unknown
        }
        let label = switch severity {
        case .ok: String(localized: "Gut", bundle: .module)
        case .warn: String(localized: "Braucht Aufmerksamkeit", bundle: .module)
        case .danger: String(localized: "Bald austauschen", bundle: .module)
        case .unknown: ""
        }
        return (label, severity)
    }
}
