import Foundation
import SwabrCore

/// Everything the user can tune, in one place.
enum Prefs {
    enum Key {
        static let onlineInfo = "onlineInfo"
        static let cleanEmptyTrash = "cleanEmptyTrash"
        static let cleanPreselect = "cleanPreselect"
        static let orphanAgeDays = "orphanAgeDays"
        static let largeDataMinMB = "largeDataMinMB"
        static let uninstallPersonalData = "uninstallPersonalData"
        static let uninstallSystemFiles = "uninstallSystemFiles"
        static let uninstallConfirm = "uninstallConfirm"
        static let purgeRecentDays = "purgeRecentDays"
        static let purgeMaxDepth = "purgeMaxDepth"
        static let analyzeTimeout = "analyzeTimeout"
        static let statusInterval = "statusInterval"
        static let language = "appLanguage"
        static let startHintFullDiskAccess = "startHintFullDiskAccess"
        static let startHintAdminHelper = "startHintAdminHelper"
    }

    private static var d: UserDefaults { .standard }

    private static func bool(_ key: String, _ fallback: Bool) -> Bool { d.object(forKey: key) as? Bool ?? fallback }
    private static func int(_ key: String, _ fallback: Int) -> Int { d.object(forKey: key) as? Int ?? fallback }

    /// Homebrew catalogue, App Store lookups and Sparkle feeds. Off by default in the App Store edition
    /// (guideline 4.2.3 ii: no unannounced downloads; 5.1.1: data minimisation).
    static var onlineInfo: Bool {
        get { bool(Key.onlineInfo, !Edition.isStore) }
        set { d.set(newValue, forKey: Key.onlineInfo) }
    }

    static var cleanEmptyTrash: Bool { bool(Key.cleanEmptyTrash, true) }
    /// What every page ticks after a scan. Nothing by default: the user decides what goes (REGELWERK G2).
    static var preselect: Preselect {
        Preselect(rawValue: d.string(forKey: Key.cleanPreselect) ?? "") ?? .none
    }
    static var orphanAgeDays: Int { int(Key.orphanAgeDays, DynamicRules.defaultOrphanAgeDays) }
    static var largeDataMinMB: Int { int(Key.largeDataMinMB, 500) }
    static var uninstallPersonalData: Bool { bool(Key.uninstallPersonalData, false) }
    static var uninstallSystemFiles: Bool { bool(Key.uninstallSystemFiles, false) }
    /// Shows the review sheet before uninstalling; running apps are always confirmed before they are quit.
    static var uninstallConfirm: Bool { bool(Key.uninstallConfirm, true) }
    static var purgeRecentDays: Int { int(Key.purgeRecentDays, 7) }
    static var purgeMaxDepth: Int { int(Key.purgeMaxDepth, 6) }
    static var analyzeTimeout: Int { int(Key.analyzeTimeout, 30) }
    static var statusInterval: Double { d.object(forKey: Key.statusInterval) as? Double ?? 2 }

    /// Pushes the values the core library reads directly.
    static func applyToCore() {
        ProjectPurge.recentDays = purgeRecentDays
        ProjectPurge.maxDepth = purgeMaxDepth
        DiskWalker.timeout = TimeInterval(analyzeTimeout)
    }

    /// The language setting this process started with, to tell whether a restart is pending.
    static let languageAtLaunch = UserDefaults.standard.string(forKey: Key.language) ?? "system"

    /// Languages the app ships, with their own names for the picker.
    static let languages: [(code: String, name: String)] = [
        ("de", "Deutsch"), ("en", "English"), ("fr", "Français"), ("es", "Español"), ("it", "Italiano"),
        ("pt-PT", "Português"), ("cs", "Čeština"), ("sk", "Slovenčina"), ("hu", "Magyar"), ("ro", "Română"),
        ("hr", "Hrvatski"), ("el", "Ελληνικά"),
    ]

    /// "system" or a code from `languages`; takes effect at the next launch, like every macOS app language.
    static var language: String {
        get { d.string(forKey: Key.language) ?? "system" }
        set {
            d.set(newValue, forKey: Key.language)
            if newValue == "system" { d.removeObject(forKey: "AppleLanguages") } else { d.set([newValue], forKey: "AppleLanguages") }
        }
    }
}

/// What the pages tick after a scan: Clean Up, Projects, Installers and Optimize.
enum Preselect: String, CaseIterable, Identifiable {
    case none, recommended, all
    var id: Self { self }

    var title: String {
        switch self {
        case .none: String(localized: "Nichts")
        case .recommended: String(localized: "Empfohlen")
        case .all: String(localized: "Alle")
        }
    }
}
