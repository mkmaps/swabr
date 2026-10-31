import SwabrCore
import SwiftUI

/// Swabr's look on top of the macOS system colors: a blue-to-purple brand gradient for the main
/// action, one color per area, and soft cards on the window background. Light and dark come from the system.
enum Brand {
    static let blue = Color(hex: 0x0A6CFF)
    static let purple = Color(hex: 0x8E44EC)
    static let teal = Color(hex: 0x12B5B0)
    static let pink = Color(hex: 0xE8457A)

    static let gradient = LinearGradient(colors: [blue, purple], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let danger = LinearGradient(colors: [Color(hex: 0xFF5A4F), Color(hex: 0xE5372C)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let success = LinearGradient(colors: [Color(hex: 0x5EE07C), Color(hex: 0x1AA865)], startPoint: .topLeading, endPoint: .bottomTrailing)
    /// Colors along the ring of the overview and the status page.
    static let ring = AngularGradient(colors: [teal, blue, purple, pink], center: .center, startAngle: .degrees(-90), endAngle: .degrees(270))
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

extension Module {
    /// Two tones of the area's color, light to dark.
    var colors: (Color, Color) {
        switch self {
        case .overview: (Color(hex: 0x2ED3CC), Color(hex: 0x0A6CFF))
        case .clean: (Color(hex: 0x3D8BFF), Color(hex: 0x0A6CFF))
        case .uninstall: (Color(hex: 0x2ED3CC), Color(hex: 0x12B5B0))
        case .optimize: (Color(hex: 0xFFB347), Color(hex: 0xF08A00))
        case .analyze: (Color(hex: 0xB07CFF), Color(hex: 0x8E44EC))
        case .status: (Color(hex: 0x7F8CFF), Color(hex: 0x4B5BDC))
        case .purge: (Color(hex: 0xFF7AA5), Color(hex: 0xE8457A))
        case .installer: (Color(hex: 0x5EE07C), Color(hex: 0x2FB350))
        case .slim: (Color(hex: 0xFF7A70), Color(hex: 0xE5372C))
        case .history: (Color(hex: 0x8D93A8), Color(hex: 0x5D6377))
        }
    }

    var tint: Color { colors.1 }
    var gradient: LinearGradient { LinearGradient(colors: [colors.0, colors.1], startPoint: .topLeading, endPoint: .bottomTrailing) }
}

/// A rounded square in an area's color with a white symbol, like an app icon in miniature.
struct IconTile: View {
    let symbol: String
    let gradient: LinearGradient
    var size: CGFloat = 36

    init(_ symbol: String, gradient: LinearGradient, size: CGFloat = 36) {
        self.symbol = symbol
        self.gradient = gradient
        self.size = size
    }

    init(module: Module, size: CGFloat = 36) {
        self.init(module.symbol, gradient: module.gradient, size: size)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
            .fill(gradient)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.47, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
    }
}

/// Soft container on the window background.
struct CardBackground: ViewModifier {
    var padding: CGFloat? = 18
    var radius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding ?? 0)
            .background(.fill.quaternary, in: .rect(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func card(padding: CGFloat? = 18, radius: CGFloat = 18) -> some View {
        modifier(CardBackground(padding: padding, radius: radius))
    }
}

/// Title row of every page: large title, one line of context, controls on the right.
struct PageHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 26, weight: .bold)).tracking(-0.4)
                if let subtitle {
                    Text(subtitle).font(.callout).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 12)
            trailing
        }
    }
}

/// The page's main action: a capsule in the brand gradient (or red for removing apps).
struct ProminentButtonStyle: ButtonStyle {
    var gradient: LinearGradient = Brand.gradient
    var glow: Color = Brand.blue
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18).padding(.vertical, 8)
            .background(gradient, in: .capsule)
            .shadow(color: glow.opacity(isEnabled ? 0.35 : 0), radius: 10, y: 4)
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .contentShape(.capsule)
    }
}

/// Secondary actions next to the main one.
struct SoftButtonStyle: ButtonStyle {
    var compact = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? .callout.weight(.medium) : .body.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, compact ? 12 : 16).padding(.vertical, compact ? 5 : 8)
            .background(.fill.tertiary, in: .capsule)
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .contentShape(.capsule)
    }
}

extension ButtonStyle where Self == ProminentButtonStyle {
    static var prominent: ProminentButtonStyle { ProminentButtonStyle() }
    static var destructiveProminent: ProminentButtonStyle { ProminentButtonStyle(gradient: Brand.danger, glow: .red) }
}

extension ButtonStyle where Self == SoftButtonStyle {
    static var soft: SoftButtonStyle { SoftButtonStyle() }
    static var softCompact: SoftButtonStyle { SoftButtonStyle(compact: true) }
}

/// Bar at the bottom of a list: what is selected on the left, the actions on the right.
struct ActionBar<Leading: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            leading
            Spacer(minLength: 12)
            trailing
        }
        .font(.callout)
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(.fill.tertiary)
    }
}

/// Amount plus a line below it, for action bars.
struct AmountLabel: View {
    let amount: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(amount).font(.system(size: 20, weight: .semibold, design: .rounded)).monospacedDigit()
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Ring in the brand colors; `segments` are fractions of the whole circle with their colors.
struct GradientRing<Center: View>: View {
    var value: Double?
    var segments: [(Double, Color)] = []
    var lineWidth: CGFloat = 14
    @ViewBuilder var center: Center

    var body: some View {
        ZStack {
            Circle().stroke(.fill.tertiary, lineWidth: lineWidth)
            if !segments.isEmpty {
                ForEach(Array(segmentRanges.enumerated()), id: \.offset) { _, s in
                    Circle().trim(from: s.from, to: s.to)
                        .stroke(s.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }
            } else if let value {
                Circle().trim(from: 0, to: max(0, min(value, 1)))
                    .stroke(Brand.ring, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            center
        }
        .animation(.easeInOut(duration: 0.6), value: value)
    }

    private var segmentRanges: [(from: Double, to: Double, color: Color)] {
        var start = 0.0
        let gap = segments.count > 1 ? 0.006 : 0
        return segments.map { fraction, color in
            defer { start += fraction }
            return (start + gap, max(start + gap, start + fraction - gap), color)
        }
    }
}

/// Safety level as a small dot label: green for safe, orange for review, red for blocked.
struct LevelBadge: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(color)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(color.opacity(0.14), in: .capsule)
        .fixedSize()
    }
}

/// Placeholder for a page that has not run yet: tile, explanation and the start button.
struct StartPanel: View {
    let module: Module
    let title: String
    let text: String
    let action: String
    var symbol = "magnifyingglass"
    let start: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            IconTile(module: module, size: 72)
                .shadow(color: module.tint.opacity(0.35), radius: 18, y: 8)
            Text(title).font(.title2.bold())
            Text(text).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 440)
            // Return starts it, like the default button of a dialog.
            Button(action: start) { Label(action, systemImage: symbol) }
                .buttonStyle(.prominent).padding(.top, 4)
                .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Progress while a page scans or removes.
struct WorkingPanel: View {
    let module: Module
    let title: String
    var detail: String = ""

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                ProgressView().controlSize(.large)
            }
            .frame(width: 72, height: 72)
            Text(title).font(.title3.bold())
            if !detail.isEmpty {
                Text(detail).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).frame(maxWidth: 480)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    /// The rounded panel a page's list lives in; lists inside should hide their own background.
    func pagePanel() -> some View {
        background(.fill.quaternary, in: .rect(cornerRadius: 18, style: .continuous))
            .clipShape(.rect(cornerRadius: 18, style: .continuous))
    }

    /// Margins of a page's content below the window toolbar.
    func pagePadding() -> some View {
        padding(.horizontal, 28).padding(.top, 8).padding(.bottom, 20)
    }
}

/// Green check in a glow, at the top of a "done" page; orange exclamation mark when nothing worked.
struct SuccessHero: View {
    var failed = false

    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [(failed ? Color.orange : .green).opacity(0.28), .clear],
                                         center: .center, startRadius: 40, endRadius: 80))
                .frame(width: 150, height: 150)
            Circle().fill(failed ? LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom) : Brand.success)
                .frame(width: 100, height: 100)
                .shadow(color: (failed ? Color.orange : .green).opacity(0.4), radius: 16, y: 8)
            Image(systemName: failed ? "exclamationmark" : "checkmark").font(.system(size: 46, weight: .semibold)).foregroundStyle(.white)
        }
    }
}

/// Order of a list, chosen from the sort menu next to the search field.
enum ListOrder: String, CaseIterable, Identifiable {
    case natural, newest, oldest, size, name
    var id: Self { self }

    var title: String {
        switch self {
        case .natural: String(localized: "Empfohlene Reihenfolge")
        case .newest: String(localized: "Neueste zuerst")
        case .oldest: String(localized: "Älteste zuerst (chronologisch)")
        case .size: String(localized: "Größte zuerst")
        case .name: String(localized: "Name")
        }
    }

    /// Sorts by date; items without a date go last in both directions.
    func byDate<T>(_ list: [T], _ date: (T) -> Date?) -> [T] {
        list.sorted { a, b in
            switch (date(a), date(b)) {
            case let (x?, y?): self == .oldest ? x < y : x > y
            case (_?, nil): true
            default: false
            }
        }
    }
}

/// Sort choices as a row of symbols for the left of the window toolbar; the tooltip names each order.
struct SortMenu: View {
    @Binding var order: ListOrder
    var options: [ListOrder] = [.newest, .oldest, .size, .name]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options) { o in
                Button { order = o } label: {
                    Image(systemName: o.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 26)
                        .foregroundStyle(order == o ? Color.white : Color.primary)
                        .background(order == o ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.clear), in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .help(o.title)
                .accessibilityLabel(Text(o.title))
                .accessibilityAddTraits(order == o ? .isSelected : [])
            }
        }
        .padding(3)
        .background(.fill.tertiary, in: .capsule)
        .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
        .fixedSize()
    }
}

extension ListOrder {
    var symbol: String {
        switch self {
        case .natural: "list.bullet"
        case .newest: "clock.badge"
        case .oldest: "clock.arrow.circlepath"
        case .size: "chart.bar.xaxis"
        case .name: "textformat.abc"
        }
    }
}

/// Opens settings for the item next to it (System Settings or Swabr's own): a gear, its target in the tooltip.
struct SettingsGearButton: View {
    let help: String
    var prominent = false
    let action: () -> Void
    @State private var hover = false

    init(_ help: String, prominent: Bool = false, action: @escaping () -> Void) {
        self.help = help
        self.prominent = prominent
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: prominent ? 15 : 13, weight: .semibold))
                .foregroundStyle(prominent ? Color.white : (hover ? Color.primary : Color.secondary))
                .frame(width: prominent ? 34 : 28, height: prominent ? 34 : 28)
                .background(prominent ? AnyShapeStyle(Brand.gradient) : (hover ? AnyShapeStyle(.fill.secondary) : AnyShapeStyle(.fill.tertiary)), in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(help)
        .accessibilityLabel(Text(help))
    }
}

/// Places in System Settings that Swabr links to.
enum SystemSettingsPane {
    static func open(_ id: String) { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:" + id)!) }
    static let loginItems = "com.apple.LoginItems-Settings.extension"
    static let automation = "com.apple.preference.security?Privacy_Automation"
}
