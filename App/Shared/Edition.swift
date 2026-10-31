import AppKit
import SwabrCore
import SwiftUI

/// Which build this is. Set per target through `SWIFT_ACTIVE_COMPILATION_CONDITIONS`.
enum Edition {
    #if SWABR_STORE
    static let isStore = true
    #else
    static let isStore = false
    #endif

    static var name: String { isStore ? String(localized: "App Store") : "Direct" }

    /// Short mark in the app name, so both editions can be told apart when they are installed side by side.
    static let tag = isStore ? "ST" : "OP"
    static let appName = "Swabr \(tag)"

    /// Source code and the Direct edition. Shown under "Über" in both editions, worded neutrally: App Review
    /// does not like apps that advertise other ways to get software, so there is no banner or prompt elsewhere.
    static let repositoryURL = URL(string: "https://github.com/mkmaps/swabr")!

    static var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
    }
}

extension Module {
    /// The sandboxed App Store edition only offers modules that work on folders the user picks.
    var inStoreEdition: Bool {
        switch self {
        // Clean, uninstall and the home-folder part of optimize work once the user granted the folders (AccessGate).
        case .overview, .analyze, .status, .purge, .installer, .history, .clean, .uninstall, .optimize: true
        // Rewrites other apps' code (guideline 2.5.2): direct edition only.
        case .slim: false
        }
    }

    static var available: [Module] { allCases.filter { !Edition.isStore || $0.inStoreEdition } }
    static var initial: Module { .overview }

    /// Folders the App Store edition needs the user to grant before the module can work.
    var requiredAccess: [String] {
        guard Edition.isStore else { return [] }
        switch self {
        case .clean, .optimize: return [UserHome.path]
        case .uninstall: return ["/Applications", UserHome.path]
        default: return []
        }
    }
}

/// Light, dark or following the system, for every window and the menu bar popover.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: Self { self }
    static let key = "appearance"

    var title: String {
        switch self {
        case .system: String(localized: "Wie System")
        case .light: String(localized: "Hell")
        case .dark: String(localized: "Dunkel")
        }
    }

    static var current: Appearance { Appearance(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .system }

    @MainActor static func apply(_ a: Appearance = current) {
        NSApp.appearance = switch a {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

/// Keeps access to folders the user picked across launches (App Store sandbox), a no-op cost in the direct edition.
@MainActor
enum FolderAccess {
    private static let key = "folderBookmarks"
    private static var active: [String: URL] = [:]
    private static var restored = false

    /// Asks for folders; returns their paths with access granted.
    static func choose(prompt: String, multiple: Bool = true) -> [String] {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = multiple
        panel.prompt = prompt
        guard panel.runModal() == .OK else { return [] }
        var stored = UserDefaults.standard.dictionary(forKey: key) as? [String: Data] ?? [:]
        for url in panel.urls {
            if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                stored[url.path] = data
            }
            if url.startAccessingSecurityScopedResource() { active[url.path] = url }
        }
        UserDefaults.standard.set(stored, forKey: key)
        return panel.urls.map(\.path)
    }

    /// Re-opens every remembered folder. Runs before the first access check, because SwiftUI can draw the
    /// window (and ask `covers`) before the app delegate has finished launching.
    static func restore() {
        restored = true
        let stored = UserDefaults.standard.dictionary(forKey: key) as? [String: Data] ?? [:]
        for (path, data) in stored where active[path] == nil {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale),
                  url.startAccessingSecurityScopedResource() else { continue }
            active[path] = url
        }
    }

    static var paths: [String] {
        if !restored { restore() }
        return Array(active.keys).sorted()
    }

    /// Whether a granted folder contains `path` (always true outside the sandbox).
    static func covers(_ path: String) -> Bool {
        guard Edition.isStore else { return true }
        if !restored { restore() }
        return active.keys.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    /// Opens the panel already pointing at `path`, so granting is one click.
    @discardableResult
    static func grant(_ path: String, message: String) -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: path)
        panel.message = message
        panel.prompt = String(localized: "Zugriff erlauben")
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        var stored = UserDefaults.standard.dictionary(forKey: key) as? [String: Data] ?? [:]
        if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            stored[url.path] = data
        }
        UserDefaults.standard.set(stored, forKey: key)
        if url.startAccessingSecurityScopedResource() { active[url.path] = url }
        return covers(path)
    }

    static func forget(_ path: String) {
        active.removeValue(forKey: path)?.stopAccessingSecurityScopedResource()
        var stored = UserDefaults.standard.dictionary(forKey: key) as? [String: Data] ?? [:]
        stored.removeValue(forKey: path)
        UserDefaults.standard.set(stored, forKey: key)
    }
}

/// In the App Store edition, shows a one-time "grant access" screen until the module's folders are granted.
struct AccessGate<Content: View>: View {
    let module: Module
    @ViewBuilder let content: Content
    @State private var refresh = 0

    private var missing: [String] {
        _ = refresh
        return module.requiredAccess.filter { !FolderAccess.covers($0) }
    }

    var body: some View {
        if missing.isEmpty {
            content
        } else {
            VStack(spacing: 18) {
                Image(systemName: "lock.open.display").font(.system(size: 44)).foregroundStyle(.tint)
                Text("Zugriff erlauben").font(.title2.bold())
                Text("Die App-Store-Version von Swabr darf nur Ordner lesen und ändern, die du freigibst. Für „\(module.title)“ braucht sie einmalig:")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 460)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(module.requiredAccess, id: \.self) { path in
                        HStack {
                            Image(systemName: FolderAccess.covers(path) ? "checkmark.circle.fill" : "folder")
                                .foregroundStyle(FolderAccess.covers(path) ? .green : .secondary)
                            Text(path == UserHome.path ? String(localized: "Benutzerordner (\(path))") : String(localized: "Programme (\(path))"))
                            Spacer()
                            if !FolderAccess.covers(path) {
                                Button("Freigeben …") {
                                    FolderAccess.grant(path, message: String(localized: "Bitte „\((path as NSString).lastPathComponent)“ auswählen und auf „Zugriff erlauben“ klicken. Swabr merkt sich die Freigabe."))
                                    refresh += 1
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .frame(width: 440)
                    }
                }
                Text("Die Freigabe lässt sich jederzeit in den Einstellungen widerrufen.").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
