import Foundation

/// How confidently an item can be removed without the user looking at it first.
public enum Safety: String, Codable, Sendable, Hashable {
    /// Regenerable cache, log or temp data; pre-selected.
    case safe
    /// May hold data that is still wanted; never pre-selected.
    case review

    public var title: String { self == .safe ? String(localized: "Sicher", bundle: .module) : String(localized: "Prüfen", bundle: .module) }
    public var help: String {
        self == .safe
            ? String(localized: "Cache, Log oder temporäre Daten, die bei Bedarf neu erstellt werden.", bundle: .module)
            : String(localized: "Nicht vorausgewählt: kann noch benötigte Daten, Einstellungen oder Verläufe enthalten.", bundle: .module)
    }
}

/// What removing an item means for the user, in plain words.
public enum Impact {
    /// Explanation for a file or folder chosen in the disk analyzer.
    public static func analyze(path: String, isDirectory: Bool, isCleanable: Bool, home: String = UserHome.path) -> (text: String, warning: Bool) {
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()
        let rel = path.hasPrefix(home + "/") ? String(path.dropFirst(home.count + 1)) : path

        if isCloudSynced(url) || rel.hasPrefix("Library/Mobile Documents") || rel.hasPrefix("Library/CloudStorage") {
            return (String(localized: "Synchronisierter Ordner: Der Inhalt verschwindet auch auf deinen anderen Geräten.", bundle: .module), true)
        }
        if isCleanable {
            return (String(localized: "Abhängigkeiten oder Build-Ergebnisse. Werden bei Bedarf neu erzeugt (z. B. durch npm install oder einen Build).", bundle: .module), false)
        }
        if ext == "app" {
            return (String(localized: "Entfernt nur das Programm. Einstellungen und Reste bleiben, dafür „Deinstallieren“ verwenden.", bundle: .module), false)
        }
        if ext == "photoslibrary" || ext == "musiclibrary" || rel.hasPrefix("Pictures/Photos Library") {
            return (String(localized: "Mediathek: Fotos oder Musik darin gehen verloren, sofern sie nicht in iCloud oder einem Backup liegen.", bundle: .module), true)
        }
        if rel.hasPrefix("Library/Caches") {
            return (String(localized: "Cache. Wird bei Bedarf neu erstellt.", bundle: .module), false)
        }
        if rel.hasPrefix("Library/Application Support") || rel.hasPrefix("Library/Containers") || rel.hasPrefix("Library/Group Containers") {
            return (String(localized: "App-Daten: Die zugehörige App kann Einstellungen, Konten oder Inhalte verlieren.", bundle: .module), true)
        }
        if rel.hasPrefix("Library/Developer") {
            return (String(localized: "Entwicklerdaten (Xcode, Simulatoren). Werden teilweise neu erstellt, Simulator-Inhalte gehen verloren.", bundle: .module), false)
        }
        if ["dmg", "pkg", "zip", "iso", "xip"].contains(ext) {
            return (String(localized: "Installer oder Archiv. Lässt sich meist erneut herunterladen.", bundle: .module), false)
        }
        if rel.hasPrefix("Library/") {
            return (String(localized: "Teil der Benutzer-Library. Apps können Daten oder Einstellungen verlieren.", bundle: .module), true)
        }
        return (isDirectory ? String(localized: "Persönlicher Ordner mit allen enthaltenen Dateien.", bundle: .module) : String(localized: "Persönliche Datei.", bundle: .module), false)
    }

    static func isCloudSynced(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) == true
    }
}

extension CleanItem {
    public var impact: String { kind.impact }
}
