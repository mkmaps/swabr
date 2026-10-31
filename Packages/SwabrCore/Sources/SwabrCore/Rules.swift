import Foundation

/// What kind of data a rule removes. Decides the explanation shown to the user and the default rating.
public enum RuleKind: String, Codable, Sendable, Hashable {
    case cache, browserCache, log, crash, temp, packages, build, derivedData, deviceSupport,
         updates, state, trash, mailDownloads, models, recentItems, history, suggestions, aerials, worktrees

    /// Regenerable data is pre-selected; everything that may still be wanted is not.
    public var defaultSafety: Safety {
        switch self {
        case .cache, .browserCache, .log, .crash, .temp, .packages, .build, .derivedData: .safe
        case .deviceSupport, .updates, .state, .trash, .mailDownloads, .models, .recentItems, .history, .suggestions,
             .aerials, .worktrees: .review
        }
    }

    /// What removing this kind of data means, in plain words.
    public var impact: String {
        switch self {
        case .cache: String(localized: "Wird bei Bedarf neu erstellt. Betroffene Apps starten beim nächsten Mal eventuell etwas langsamer.", bundle: .module)
        case .browserCache: String(localized: "Browser-Cache. Seiten laden beim ersten Besuch etwas langsamer. Anmeldungen, Verlauf und Lesezeichen bleiben.", bundle: .module)
        case .log: String(localized: "Nur Protokolle. Hilft bei Fehlersuche, wird sonst nicht benötigt.", bundle: .module)
        case .crash: String(localized: "Absturzberichte. Ältere Abstürze lassen sich danach nicht mehr analysieren.", bundle: .module)
        case .temp: String(localized: "Temporäre Dateien, die Apps nach Gebrauch nicht aufgeräumt haben.", bundle: .module)
        case .packages: String(localized: "Heruntergeladene Pakete. Werden bei der nächsten Installation erneut geladen (Internet nötig).", bundle: .module)
        case .build: String(localized: "Build-Ergebnisse. Werden beim nächsten Build neu erzeugt.", bundle: .module)
        case .derivedData: String(localized: "Xcode baut Projekte beim nächsten Mal vollständig neu und indiziert sie erneut.", bundle: .module)
        case .deviceSupport: String(localized: "Wird beim nächsten Anschließen des Geräts erneut von Xcode erstellt (dauert einige Minuten).", bundle: .module)
        case .updates: String(localized: "Heruntergeladene Updates. Ein laufendes Update muss erneut geladen werden.", bundle: .module)
        case .state: String(localized: "Apps öffnen beim nächsten Start ihre zuletzt offenen Fenster nicht wieder.", bundle: .module)
        case .trash: String(localized: "Der Papierkorb wird endgültig geleert. Diese Dateien lassen sich danach nicht wiederherstellen.", bundle: .module)
        case .mailDownloads: String(localized: "Kopien geöffneter Mail-Anhänge. Die Anhänge selbst bleiben in Mail erhalten.", bundle: .module)
        case .models: String(localized: "Lokale KI- oder Optimierungsmodelle. Werden bei Bedarf erneut heruntergeladen.", bundle: .module)
        case .recentItems: String(localized: "Die Listen „Zuletzt benutzt“ im Apple-Menü und in Apps werden geleert.", bundle: .module)
        case .history: String(localized: "Der Eingabeverlauf dieses Programms wird gelöscht.", bundle: .module)
        case .suggestions: String(localized: "Siri-Vorschläge und Spotlight lernen deine Gewohnheiten neu. Kontakte, Nachrichten und Mails bleiben erhalten.", bundle: .module)
        case .aerials: String(localized: "Von macOS geladene Luftaufnahmen, die weder als Hintergrundbild noch als Bildschirmschoner genutzt werden. Sie werden bei erneuter Auswahl wieder geladen.", bundle: .module)
        case .worktrees: String(localized: "Arbeitskopien, die KI-Agenten für einzelne Aufgaben angelegt haben. Nicht übernommene Änderungen darin gehen verloren.", bundle: .module)
        }
    }
}

/// One cleanup rule from Swabr's own catalogue (`clean_rules.json`) or built at run time (`DynamicRules`).
public struct CleanRule: Codable, Sendable, Hashable {
    /// Section id, see `RuleStore.sectionOrder`.
    public var section: String
    /// Product name, or a German key that is localized when the catalogue is loaded.
    public var label: String
    public var kind: RuleKind
    /// Overrides `kind.defaultSafety` where a rule is more delicate than its kind.
    public var safety: Safety?
    /// Glob patterns; a leading `~` is the user's home directory.
    public var paths: [String]
    /// Matches of these patterns are left to later rules (fnmatch, `*` crosses `/`).
    public var exclude: [String]?
    /// App name; the rule is skipped while a matching app is running.
    public var skipIfRunning: String?
    /// Skip each match whose owning app (the folder right below Caches, Application Support or
    /// Containers, a name or bundle id) is running. For rules that cover many apps at once.
    public var skipRunningOwner: Bool?
    /// Only matches next to Chromium's own `Code Cache` or `GPUCache` folders (in the same folder or up
    /// to two levels above), so a folder named `Cache` is known to be a web cache and not app content.
    public var chromiumOnly: Bool?
    /// Matches that must never be removed themselves (only their children).
    public var keep: [String]?
    /// Only matches not modified for this many days (temporary files of finished jobs, stale worktrees).
    public var minAgeDays: Int?

    public init(section: String, label: String, kind: RuleKind, safety: Safety? = nil, paths: [String],
                exclude: [String]? = nil, skipIfRunning: String? = nil, skipRunningOwner: Bool? = nil,
                chromiumOnly: Bool? = nil, keep: [String]? = nil, minAgeDays: Int? = nil) {
        self.section = section
        self.label = label
        self.kind = kind
        self.safety = safety
        self.paths = paths
        self.exclude = exclude
        self.skipIfRunning = skipIfRunning
        self.skipRunningOwner = skipRunningOwner
        self.chromiumOnly = chromiumOnly
        self.keep = keep
        self.minAgeDays = minAgeDays
    }

    public var effectiveSafety: Safety { safety ?? kind.defaultSafety }
}

public struct WhitelistOption: Codable, Sendable, Hashable, Identifiable {
    public var label: String
    public var pattern: String
    public var category: String
    public var id: String { pattern }
}

public struct ProtectionData: Codable, Sendable {
    /// Optional defaults, replaced entirely by a user whitelist file.
    public var defaultWhitelist: [String]
    /// Hard safety patterns that always apply.
    public var safetyWhitelist: [String]
    public var systemCriticalBundles: [String]
    /// Bundle id globs whose data is never treated as a leftover of a removed app
    /// (passwords, keys, wallets, VPN and security tools).
    public var sensitiveBundles: [String]
    /// Apple apps that may be uninstalled although they match a system pattern.
    public var appleUninstallableApps: [String] = []
    /// Security/MDM software that must be removed with the vendor's own uninstaller.
    public var officialUninstallerRules: [OfficialUninstallerRule] = []
    public var whitelistOptions: [WhitelistOption]
}

public struct OfficialUninstallerRule: Codable, Sendable, Hashable {
    public var vendor: String
    public var bundlePrefixes: [String]
    public var nameFragments: [String]
}

public enum RuleStore {
    /// Display order of the clean sections (ids used in the rules).
    public static let sectionOrder = ["system", "browsers", "apps", "developer", "app_caches", "leftovers"]

    /// The bundled catalogue; generic labels are German keys and come back localized.
    public static func cleanRules() throws -> [CleanRule] {
        try load("clean_rules", as: [CleanRule].self).map { rule in
            var r = rule
            r.label = String(localized: String.LocalizationValue(rule.label), bundle: .module)
            return r
        }
    }

    /// Protection data; switch names that are German keys come back localized.
    public static func protection() throws -> ProtectionData {
        var p = try load("protection", as: ProtectionData.self)
        p.whitelistOptions = p.whitelistOptions.map { o in
            var o = o
            o.label = String(localized: String.LocalizationValue(o.label), bundle: .module)
            return o
        }
        return p
    }

    private static func load<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}
