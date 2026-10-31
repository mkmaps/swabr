import Foundation

/// One line of the operation log.
public struct HistoryEntry: Identifiable, Sendable, Hashable {
    /// Position in the file, counted from the first valid line.
    public let id: Int
    public let date: Date
    public let action: String
    public let bytes: Int64
    /// As written to the log (German keys for the module prefixes).
    public let label: String
    public let path: String

    public var actionTitle: String {
        switch action {
        case "TRASH": String(localized: "In den Papierkorb", bundle: .module)
        case "REMOVE": String(localized: "Gelöscht", bundle: .module)
        default: action
        }
    }

    public var module: String {
        if let hit = LabelArea.split(label) { return hit.0.title }
        return LabelArea.standalone(label).title
    }

    public var displayLabel: String {
        if let hit = LabelArea.split(label) { return hit.0.title + ": " + hit.1 }
        return String(localized: String.LocalizationValue(label), bundle: .module)
    }
}

/// Entries that happened close together, i.e. one run of a feature.
public struct HistorySession: Identifiable, Sendable {
    public var id: Int
    /// Newest first.
    public let entries: [HistoryEntry]

    public var start: Date { entries.map(\.date).min() ?? .distantPast }
    public var bytes: Int64 { entries.reduce(0) { $0 + $1.bytes } }
    public var modules: [String] { Array(Set(entries.map(\.module))).sorted() }

    public init(id: Int, entries: [HistoryEntry]) {
        self.id = id
        self.entries = entries
    }
}

public enum History {
    /// All logged operations, newest first. A missing or unreadable log yields an empty list.
    public static func load(_ log: OperationLog = OperationLog()) -> [HistoryEntry] {
        guard let data = try? Data(contentsOf: log.url) else { return [] }
        return parse(data)
    }

    /// Groups entries whose neighbours are at most `gap` seconds apart. Newest session first.
    public static func sessions(_ entries: [HistoryEntry], gap: TimeInterval = 300) -> [HistorySession] {
        var groups: [[HistoryEntry]] = []
        for entry in entries.sorted(by: newestFirst) {
            if let last = groups.last?.last, last.date.timeIntervalSince(entry.date) <= gap {
                groups[groups.count - 1].append(entry)
            } else {
                groups.append([entry])
            }
        }
        // The oldest entry of a run keeps its id while the run grows, so the UI's expansion state survives reloads.
        return groups.map { HistorySession(id: $0.last!.id, entries: $0) }
    }

    static func parse(_ text: String) -> [HistoryEntry] {
        parse(Data(text.utf8))
    }

    static func parse(_ data: Data) -> [HistoryEntry] {
        var entries: [HistoryEntry] = []
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard var cursor = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            let stop = cursor + raw.count
            while cursor < stop {
                let newline = memchr(cursor, 0x0A, stop - cursor).map { UnsafePointer($0.assumingMemoryBound(to: UInt8.self)) } ?? stop
                var end = newline
                if end > cursor && end[-1] == 0x0D { end -= 1 }
                if let e = entry(cursor, end, id: entries.count) { entries.append(e) }
                cursor = newline + 1
            }
        }
        // The log is appended to, so it is normally oldest first already and only needs reversing.
        entries.reverse()
        if zip(entries, entries.dropFirst()).contains(where: { !newestFirst($0, $1) }) {
            entries.sort(by: newestFirst)
        }
        return entries
    }

    private static func newestFirst(_ a: HistoryEntry, _ b: HistoryEntry) -> Bool {
        a.date != b.date ? a.date > b.date : a.id > b.id
    }

    /// Splits at the first four tabs; the path is everything after the fourth and may contain tabs itself.
    private static func entry(_ start: UnsafePointer<UInt8>, _ end: UnsafePointer<UInt8>, id: Int) -> HistoryEntry? {
        func nextTab(_ from: UnsafePointer<UInt8>) -> UnsafePointer<UInt8>? {
            guard from < end, let hit = memchr(from, 0x09, end - from) else { return nil }
            return UnsafePointer(hit.assumingMemoryBound(to: UInt8.self))
        }
        func text(_ from: UnsafePointer<UInt8>, _ to: UnsafePointer<UInt8>) -> String {
            String(decoding: UnsafeBufferPointer(start: from, count: to - from), as: UTF8.self)
        }
        guard let t1 = nextTab(start), let t2 = nextTab(t1 + 1), let t3 = nextTab(t2 + 1), let t4 = nextTab(t3 + 1),
              let date = Timestamp.parse(UnsafeBufferPointer(start: start, count: t1 - start)),
              let bytes = integer(t2 + 1, t3)
        else { return nil }
        return HistoryEntry(id: id, date: date, action: text(t1 + 1, t2), bytes: bytes,
                            label: text(t3 + 1, t4), path: text(t4 + 1, end))
    }

    /// Non-negative decimal byte count; anything else marks the line as broken.
    private static func integer(_ from: UnsafePointer<UInt8>, _ to: UnsafePointer<UInt8>) -> Int64? {
        guard from < to, to - from <= 18 else { return nil }
        var value: Int64 = 0
        var p = from
        while p < to {
            let digit = Int64(p.pointee) - 0x30
            guard digit >= 0 && digit <= 9 else { return nil }
            value = value * 10 + digit
            p += 1
        }
        return value
    }
}

/// The feature a log label belongs to.
private enum LabelArea: CaseIterable {
    case clean, uninstall, reset, projects, installer, optimize, slim, storage, startup

    var title: String {
        switch self {
        case .clean: String(localized: "Aufräumen", bundle: .module)
        case .uninstall: String(localized: "Deinstallieren", bundle: .module)
        case .reset: String(localized: "Zurücksetzen", bundle: .module)
        case .projects: String(localized: "Projekte", bundle: .module)
        case .installer: String(localized: "Installer", bundle: .module)
        case .optimize: String(localized: "Optimieren", bundle: .module)
        case .slim: String(localized: "Verschlanken", bundle: .module)
        case .storage: String(localized: "Speicher", bundle: .module)
        case .startup: String(localized: "Start", bundle: .module)
        }
    }

    /// German prefix written before `": "` in the log.
    var prefix: String? {
        switch self {
        case .uninstall: "Deinstallieren"
        case .reset: "Zurücksetzen"
        case .projects: "Projekte"
        case .optimize: "Optimieren"
        case .slim: "Verschlanken"
        case .clean, .installer, .storage, .startup: nil
        }
    }

    /// Splits `"Prefix: rest"` when the prefix names a known area. Some callers log an already
    /// localized label, so the prefix's translation is accepted as well.
    static func split(_ label: String) -> (LabelArea, String)? {
        guard let sep = label.range(of: ": ") else { return nil }
        let head = label[..<sep.lowerBound]
        for area in allCases {
            guard let key = area.prefix else { continue }
            let translated = String(localized: String.LocalizationValue(key), bundle: .module)
            if head == key || head.caseInsensitiveCompare(translated) == .orderedSame {
                return (area, String(label[sep.upperBound...]))
            }
        }
        return nil
    }

    /// Area for a label without a module prefix; rule names belong to cleaning.
    static func standalone(_ label: String) -> LabelArea {
        switch label {
        case "Speicheranalyse": .storage
        case "Installer": .installer
        case "Startobjekt", "Startobjekt (System)": .startup
        default: .clean
        }
    }
}

/// ISO-8601 timestamps as written by `OperationLog`.
private enum Timestamp {
    /// `Date.ISO8601Format()` writes `yyyy-MM-ddTHH:mm:ssZ`; that shape is decoded by hand because
    /// the general parser is too slow for large logs. Anything else goes through Foundation.
    static func parse(_ s: UnsafeBufferPointer<UInt8>) -> Date? {
        if s.count == 20, s[4] == 0x2D, s[7] == 0x2D, s[10] == 0x54, s[13] == 0x3A, s[16] == 0x3A, s[19] == 0x5A,
           let y = number(s, 0, 4), let month = number(s, 5, 2), let d = number(s, 8, 2),
           let h = number(s, 11, 2), let mi = number(s, 14, 2), let sec = number(s, 17, 2),
           (1...12).contains(month), (1...daysIn(month: month, year: y)).contains(d),
           h < 24, mi < 60, sec < 61 {
            let days = daysSinceEpoch(year: y, month: month, day: d)
            return Date(timeIntervalSince1970: TimeInterval(((days * 24 + h) * 60 + mi) * 60 + sec))
        }
        let text = String(decoding: s, as: UTF8.self)
        if let date = try? Date.ISO8601FormatStyle().parse(text) { return date }
        return try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text)
    }

    private static func number(_ s: UnsafeBufferPointer<UInt8>, _ from: Int, _ count: Int) -> Int? {
        var value = 0
        for i in from..<(from + count) {
            let digit = Int(s[i]) - 0x30
            guard (0...9).contains(digit) else { return nil }
            value = value * 10 + digit
        }
        return value
    }

    private static func daysIn(month: Int, year: Int) -> Int {
        switch month {
        case 2: (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    /// Proleptic Gregorian day count relative to 1970-01-01, using March-based years so leap days come last.
    private static func daysSinceEpoch(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }
}
