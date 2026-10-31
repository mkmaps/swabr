import AppKit
import SwabrCore
import SwiftUI

enum FullDiskAccess {
    /// macOS offers no API to ask for Full Disk Access, so Swabr tries to read places that privacy
    /// protection (TCC) keeps closed without it. Missing paths prove nothing and are skipped.
    static let probes = [
        "/Library/Application Support/com.apple.TCC/TCC.db",
        UserHome.path + "/Library/Safari/LocalStorage",
        UserHome.path + "/Library/Mail",
        UserHome.path + "/Library/Messages/chat.db",
    ]

    /// False only when a protected path exists and none of them can be read.
    static var isGranted: Bool {
        var tested = false
        for path in probes {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { continue }
            tested = true
            if isDir.boolValue {
                if (try? FileManager.default.contentsOfDirectory(atPath: path)) != nil { return true }
            } else if let h = FileHandle(forReadingAtPath: path) {
                try? h.close()
                return true
            }
        }
        return !tested
    }

    /// Opens the Full Disk Access list. macOS lists an app there only after it was added once, so a Finder
    /// window with Swabr selected opens alongside: the app can be dragged straight into the list.
    static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
        // The settings window comes to the front after the Finder window, so both stay visible.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { NSWorkspace.shared.open(url) }
    }
}

struct FullDiskAccessBanner: View {
    @State private var granted = FullDiskAccess.isGranted

    var body: some View {
        if !granted {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield").font(.title2).foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Festplattenvollzugriff fehlt").bold()
                    Text("Ohne ihn bleiben Papierkorb, Mail und einige App-Caches unsichtbar.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                HelpButton(topic: .fullDiskAccess)
                Button("Erneut prüfen") { granted = FullDiskAccess.isGranted }
                SettingsGearButton(String(localized: "Systemeinstellungen → Festplattenvollzugriff öffnen"), prominent: true) { FullDiskAccess.openSettings() }
            }
            .padding(12)
            .background(.orange.opacity(0.12))
                // Coming back from System Settings: check again so the banner disappears on its own.
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    granted = FullDiskAccess.isGranted
                }
        }
    }
}

enum RunningApps {
    /// Snapshot taken on the main actor, so the scanner can query it from any thread.
    @MainActor static func snapshot() -> @Sendable (String) -> Bool {
        // Names and bundle ids: broad clean rules know an app only by its cache folder, often the bundle id.
        let apps = NSWorkspace.shared.runningApplications
        let names = Set(apps.compactMap { $0.localizedName?.lowercased() } + apps.compactMap { $0.bundleIdentifier?.lowercased() })
        return { app in
            let a = app.lowercased()
            return names.contains { $0 == a || $0.hasPrefix(a + " ") || $0.hasSuffix(" " + a) }
        }
    }
}

/// Shown once at the first start of the direct edition while Full Disk Access is missing: what it is for,
/// how to grant it, with the picture from the help.
struct FullDiskAccessIntro: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @AppStorage(Prefs.Key.startHintFullDiskAccess) private var askAgain = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                IconTile("lock.shield", gradient: LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom), size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Festplattenvollzugriff erlauben").font(.title2.bold())
                    Text("Einmalig nötig, damit Swabr alles findet").foregroundStyle(.secondary)
                }
            }
            Text("Ohne ihn bleiben Papierkorb, Mail und einige App-Caches unsichtbar. Swabr löscht trotzdem nur, was du im Prüffenster bestätigst.")
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                step(1, String(localized: "Auf das Zahnrad klicken. Es öffnet sich Datenschutz & Sicherheit → Festplattenvollzugriff."))
                step(2, String(localized: "Den Schalter neben „Swabr OP“ einschalten. Fehlt der Eintrag, Swabr aus dem Finder-Fenster, das sich mit öffnet, in die Liste ziehen."))
                step(3, String(localized: "Swabr neu starten, wenn macOS darum bittet."))
            }
            HelpImage(path: "images/festplattenvollzugriff-1-liste.png").frame(maxWidth: .infinity)
            HStack {
                Toggle("Beim nächsten Start wieder fragen", isOn: $askAgain).toggleStyle(.checkbox)
                Spacer()
                Button("Später") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Bebilderte Anleitung") { openWindow(id: HelpWindow.id, value: HelpTopic.fullDiskAccess) }
                    .buttonStyle(.soft)
                SettingsGearButton(String(localized: "Systemeinstellungen → Festplattenvollzugriff öffnen"), prominent: true) {
                    FullDiskAccess.openSettings()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 600)
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(n)").font(.callout.bold()).foregroundStyle(.white)
                .frame(width: 20, height: 20).background(Brand.blue, in: .circle)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Shown at start while the helper for administrator rights is not set up (direct edition).
struct AdminHelperIntro: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @AppStorage(Prefs.Key.startHintAdminHelper) private var askAgain = true
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                IconTile("key.fill", gradient: LinearGradient(colors: [Color(hex: 0x7F8CFF), Color(hex: 0x4B5BDC)], startPoint: .top, endPoint: .bottom), size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Administratorrechte ohne Passwort").font(.title2.bold())
                    Text("Optional: einmal erlauben, dann fragt macOS nicht mehr").foregroundStyle(.secondary)
                }
            }
            Text("Deinstallieren, Optimieren und einige Aufräumschritte brauchen Administratorrechte. Ohne den Hilfsdienst von Swabr fragt macOS dafür jedes Mal nach deinem Passwort, und Apps, die sich selbst beim Anmelden eintragen, bleiben unter Apps → Start unsichtbar.")
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                step(1, String(localized: "„Jetzt einrichten“ klicken. macOS öffnet Allgemein → Anmeldeobjekte."))
                step(2, String(localized: "Unter „App-Hintergrundaktivitäten“ den Eintrag „Swabr OP“ einschalten."))
                step(3, String(localized: "Mit Passwort oder Touch ID bestätigen. Fertig."))
            }
            HelpImage(path: "images/helfer-2-anmeldeobjekte.png").frame(maxWidth: .infinity)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Toggle("Beim nächsten Start wieder fragen", isOn: $askAgain).toggleStyle(.checkbox)
                Spacer()
                Button("Später") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Bebilderte Anleitung") { openWindow(id: HelpWindow.id, value: HelpTopic.adminHelper) }
                    .buttonStyle(.soft)
                Button("Jetzt einrichten") {
                    do {
                        try PrivilegedHelper.install()
                        dismiss()
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
                .buttonStyle(.prominent).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 640)
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(n)").font(.callout.bold()).foregroundStyle(.white)
                .frame(width: 20, height: 20).background(Brand.blue, in: .circle)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Which start notice to show, one after the other.
enum StartHint: Identifiable {
    case fullDiskAccess, adminHelper
    var id: Self { self }

    /// The next notice still due, after `shown`.
    @MainActor static func next(after shown: Set<StartHint> = []) -> StartHint? {
        guard !Edition.isStore else { return nil }
        let d = UserDefaults.standard
        let force = d.bool(forKey: "showFullDiskAccessIntro")
        if !shown.contains(.fullDiskAccess), force || ((d.object(forKey: Prefs.Key.startHintFullDiskAccess) as? Bool ?? true) && !FullDiskAccess.isGranted) {
            return .fullDiskAccess
        }
        if !shown.contains(.adminHelper), (d.object(forKey: Prefs.Key.startHintAdminHelper) as? Bool ?? true), PrivilegedHelper.state != .enabled {
            return .adminHelper
        }
        return nil
    }
}
