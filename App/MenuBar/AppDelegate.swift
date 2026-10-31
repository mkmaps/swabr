import AppKit
import SwabrCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor private var menuBar: MenuBarController?

    /// Both editions share one menu bar slot: a second copy hands over to the running one and quits.
    static let bundleIDs = ["de.knieriem.swabr", "de.knieriem.swabr.store"]

    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        let me = ProcessInfo.processInfo.processIdentifier
        if let other = NSWorkspace.shared.runningApplications.first(where: {
            $0.processIdentifier != me && Self.bundleIDs.contains($0.bundleIdentifier ?? "")
        }) {
            other.activate()
            NSApp.terminate(nil)
            return
        }
        Appearance.apply()
        Prefs.applyToCore()
        FolderAccess.restore()
        menuBar = MenuBarController()
    }

    /// Keep running in the menu bar after the window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !MenuBarSettings.enabled
    }
}

/// Lets AppKit code (the menu bar) open the main window again after it was closed.
@MainActor
final class WindowOpener {
    static let mainID = "main"
    static let shared = WindowOpener()
    var open: OpenWindowAction?
    var settings: OpenSettingsAction?

    /// Opens the settings window, optionally at a tab (`SettingsTab`).
    func openSettings(tab: String? = nil) {
        if let tab { UserDefaults.standard.set(tab, forKey: SettingsTab.key) }
        NSApp.activate()
        if let settings { settings() } else { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }
    }

    func openMain() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix(Self.mainID) == true && $0.isVisible })
            ?? NSApp.windows.first(where: { $0.canBecomeMain && !($0 is NSPanel) && $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            open?(id: Self.mainID)
        }
    }
}

private struct CaptureOpener: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    func body(content: Content) -> some View {
        content.onAppear {
            WindowOpener.shared.open = openWindow
            WindowOpener.shared.settings = openSettings
            // `-openSettings behavior` on the command line opens that settings tab (for screenshots and testing).
            if let tab = UserDefaults.standard.string(forKey: "openSettings") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { WindowOpener.shared.openSettings(tab: tab) }
            }
            // `-openHelp adminHelper` opens that help topic.
            if let topic = UserDefaults.standard.string(forKey: "openHelp").flatMap(HelpTopic.init(rawValue:)) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { openWindow(id: HelpWindow.id, value: topic) }
            }
        }
    }
}

extension View {
    func captureWindowOpener() -> some View { modifier(CaptureOpener()) }
}
