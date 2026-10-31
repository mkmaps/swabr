import SwiftUI

@main
struct SwabrApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        WindowGroup(id: WindowOpener.mainID) {
            RootView()
                .frame(minWidth: 900, minHeight: 600)
                .captureWindowOpener()
        }
        .windowToolbarStyle(.unified)

        Settings {
            SettingsView()
        }

        WindowGroup("Swabr-Hilfe", id: HelpWindow.id, for: HelpTopic.self) { $topic in
            HelpView(topic: $topic)
        } defaultValue: {
            .start
        }
        .commands {
            CommandGroup(replacing: .help) {
                HelpMenuButton()
            }
        }
    }
}

/// Help menu entry (⌘?) opening the help window.
struct HelpMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Swabr-Hilfe") { openWindow(id: HelpWindow.id, value: HelpTopic.start) }
            .keyboardShortcut("?", modifiers: .command)
    }
}

enum Module: String, CaseIterable, Identifiable {
    case overview, clean, uninstall, optimize, analyze, status, purge, installer, slim, history
    var id: Self { self }

    var title: String {
        switch self {
        case .overview: String(localized: "Übersicht")
        case .clean: String(localized: "Aufräumen")
        case .uninstall: String(localized: "Apps")
        case .optimize: String(localized: "Optimieren")
        case .analyze: String(localized: "Speicher")
        case .status: String(localized: "Status")
        case .purge: String(localized: "Projekte")
        case .installer: String(localized: "Installer")
        case .slim: String(localized: "Verschlanken")
        case .history: String(localized: "Verlauf")
        }
    }

    var symbol: String {
        switch self {
        case .overview: "house"
        case .clean: "sparkles"
        case .uninstall: "square.grid.2x2"
        case .optimize: "wrench.and.screwdriver"
        case .analyze: "chart.pie"
        case .status: "gauge.with.dots.needle.67percent"
        case .purge: "hammer"
        case .installer: "shippingbox"
        case .slim: "scissors"
        case .history: "clock.arrow.circlepath"
        }
    }

    var summary: String {
        switch self {
        case .overview: String(localized: "Zustand und freigebbarer Speicher auf einen Blick")
        case .clean: String(localized: "Caches, Logs und Reste entfernen")
        case .uninstall: String(localized: "Deinstallieren, Updates und Startobjekte")
        case .optimize: String(localized: "Caches und Dienste auffrischen")
        case .analyze: String(localized: "Speicherbelegung erkunden")
        case .status: String(localized: "CPU, Speicher, Netz live")
        case .purge: String(localized: "Build-Artefakte in Projekten")
        case .installer: String(localized: "Installer-Dateien finden")
        case .slim: String(localized: "Intel-Code aus Universal-Apps entfernen")
        case .history: String(localized: "Was Swabr entfernt hat")
        }
    }
}

struct RootView: View {
    @Bindable private var nav = Navigator.shared
    private let summary = ScanSummary.shared
    @State private var startHint: StartHint?
    @State private var shownHints: Set<StartHint> = []

    private static let main: [Module] = [.overview, .clean, .uninstall, .optimize, .analyze, .status]
    private static let tools: [Module] = [.purge, .installer, .slim]

    var body: some View {
        NavigationSplitView {
            List(selection: $nav.selection) {
                Section {
                    ForEach(Self.main.filter(\.isAvailable)) { row($0) }
                }
                Section("Werkzeuge") {
                    ForEach(Self.tools.filter(\.isAvailable)) { row($0) }
                }
                Section(Edition.appName) {
                    row(.history)
                    SettingsLink {
                        Label("Einstellungen", systemImage: "gearshape")
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            VStack(spacing: 0) {
                if !Edition.isStore { FullDiskAccessBanner() }
                switch nav.selection ?? .initial {
                case .overview: OverviewView()
                case .clean: AccessGate(module: .clean) { CleanView() }
                case .analyze: AnalyzeView()
                case .uninstall: AccessGate(module: .uninstall) { AppsView() }
                case .status: StatusView()
                case .optimize: AccessGate(module: .optimize) { OptimizeView() }
                case .purge: ProjectsView()
                case .installer: InstallerView()
                case .slim: SlimView()
                case .history: HistoryView()
                }
            }
            // Notices for missing rights at start, one after the other; each can be switched off in itself.
            // `-showFullDiskAccessIntro YES` shows the first regardless (for screenshots and testing).
            .sheet(item: $startHint, onDismiss: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { startHint = StartHint.next(after: shownHints) }
            }) { hint in
                switch hint {
                case .fullDiskAccess: FullDiskAccessIntro().onAppear { shownHints.insert(.fullDiskAccess) }
                case .adminHelper: AdminHelperIntro().onAppear { shownHints.insert(.adminHelper) }
                }
            }
            .onAppear {
                if shownHints.isEmpty { startHint = StartHint.next() }
            }
            .toolbar(removing: .title)
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
            .toolbar {
                // A sidebar module's own help topic; Apps shows its segment's topic in the view itself.
                ToolbarSpacer(.flexible)
                if nav.selection != .uninstall {
                    ToolbarItem { HelpButton(topic: .of(nav.selection ?? .initial)) }
                        .sharedBackgroundVisibility(.hidden)
                }
            }
        }
    }

    private func row(_ module: Module) -> some View {
        Label(module.title, systemImage: module.symbol)
            .badge(summary.badge(module).map { Text($0) })
            .tag(module)
    }
}
