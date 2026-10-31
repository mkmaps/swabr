import SwiftUI

/// "Apps" section: uninstall, updates and startup items, switched with a segmented control.
/// In the App Store edition updates are report-only and startup items limited to the user's own agents.
struct AppsView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case uninstall, updates, startup
        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .uninstall: "Deinstallieren"
            case .updates: "Updates"
            case .startup: "Start"
            }
        }

        var symbol: String {
            switch self {
            case .uninstall: "trash"
            case .updates: "arrow.down.circle"
            case .startup: "power"
            }
        }
    }

    @AppStorage("appsSegment") private var segment = Segment.uninstall

    private var subtitle: String {
        switch segment {
        case .uninstall: String(localized: "Apps samt Resten entfernen")
        case .updates: ScanSummary.shared.entry(.uninstall).map { String(localized: "\($0.count) Updates verfügbar") } ?? String(localized: "Nach Updates suchen")
        case .startup: String(localized: "Was beim Anmelden startet")
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                PageHeader(String(localized: "Apps"), subtitle: subtitle)
                    .fixedSize()
                Picker("Bereich", selection: $segment) {
                    ForEach(Segment.allCases) { s in
                        Label(s.title, systemImage: s.symbol).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                Spacer()
                HelpButton(topic: segment == .uninstall ? .uninstall : segment == .updates ? .updates : .startup)
            }
            Group {
                switch segment {
                case .uninstall: UninstallView()
                case .updates: UpdatesView().pagePanel()
                case .startup: StartupView().pagePanel()
                }
            }
        }
        .pagePadding()
        .navigationTitle("Apps")
    }
}
