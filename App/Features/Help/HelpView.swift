import AppKit
import SwiftUI

/// Topics of the built-in help. Each has a Markdown file per language in `Help/<lang>/<rawValue>.md`.
enum HelpTopic: String, CaseIterable, Identifiable, Codable, Hashable {
    case start, editions, fullDiskAccess, adminHelper, safety, clean, protectedData, analyze, uninstall, updates, startup,
         optimize, projects, installer, slim, status, history, settings, privacy, troubleshooting
    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .start: "Erste Schritte"
        case .editions: "Direct- und App-Store-Version"
        case .fullDiskAccess: "Festplattenvollzugriff"
        case .adminHelper: "Administratorrechte (Hilfsdienst)"
        case .safety: "Sicherheit: Papierkorb, Löschen, Protokoll"
        case .clean: "Aufräumen"
        case .protectedData: "Geschützte Daten (Whitelist)"
        case .analyze: "Speicher"
        case .uninstall: "Apps deinstallieren"
        case .updates: "App-Updates"
        case .startup: "Start: Anmeldeobjekte und Dienste"
        case .optimize: "Optimieren"
        case .projects: "Projekte"
        case .installer: "Installer"
        case .slim: "Verschlanken"
        case .status: "Status und Menüleiste"
        case .history: "Verlauf"
        case .settings: "Einstellungen"
        case .privacy: "Datenschutz"
        case .troubleshooting: "Probleme lösen"
        }
    }

    var symbol: String {
        switch self {
        case .start: "flag"
        case .editions: "square.on.square"
        case .fullDiskAccess: "lock.shield"
        case .adminHelper: "key"
        case .safety: "checkmark.shield"
        case .clean: "sparkles"
        case .protectedData: "shield.lefthalf.filled"
        case .analyze: "chart.pie"
        case .uninstall: "trash"
        case .updates: "arrow.down.circle"
        case .startup: "power"
        case .optimize: "wrench.and.screwdriver"
        case .projects: "hammer"
        case .installer: "shippingbox"
        case .slim: "scissors"
        case .status: "gauge.with.dots.needle.67percent"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        case .privacy: "hand.raised"
        case .troubleshooting: "lifepreserver"
        }
    }

    /// The topic for a sidebar module.
    static func of(_ module: Module) -> HelpTopic {
        switch module {
        case .overview: .start
        case .clean: .clean
        case .uninstall: .uninstall
        case .optimize: .optimize
        case .analyze: .analyze
        case .status: .status
        case .purge: .projects
        case .installer: .installer
        case .slim: .slim
        case .history: .history
        }
    }

    /// Markdown in the app's current language; languages without their own help fall back to English, then German.
    var markdown: String {
        let lang = Bundle.main.preferredLocalizations.first ?? "de"
        for l in [lang, "en", "de"] {
            if let url = Bundle.main.url(forResource: rawValue, withExtension: "md", subdirectory: "Help/\(l)"),
               let text = try? String(contentsOf: url, encoding: .utf8) {
                return text
            }
        }
        return ""
    }
}

enum HelpWindow {
    static let id = "help"
}

/// "?" button that opens the help at a topic.
struct HelpButton: View {
    let topic: HelpTopic
    @Environment(\.openWindow) private var openWindow
    @State private var hover = false

    var body: some View {
        Button { openWindow(id: HelpWindow.id, value: topic) } label: {
            Label("Hilfe", systemImage: "book.closed")
                .labelStyle(.titleAndIcon)
                .font(.callout)
                .foregroundStyle(hover ? .primary : .secondary)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(hover ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(.clear), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help("Hilfe zu diesem Bereich")
        .accessibilityLabel(Text("Hilfe zu diesem Bereich"))
    }
}

struct HelpView: View {
    @Binding var topic: HelpTopic
    @State private var search = ""

    private var topics: [HelpTopic] {
        guard !search.isEmpty else { return HelpTopic.allCases }
        return HelpTopic.allCases.filter { $0.markdown.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationSplitView {
            List(topics, selection: Binding(get: { Optional(topic) }, set: { if let t = $0 { topic = t } })) { t in
                Label(t.title, systemImage: t.symbol).tag(t)
            }
            .searchable(text: $search, placement: .sidebar, prompt: "Hilfe durchsuchen")
            .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } detail: {
            ScrollView {
                MarkdownView(text: topic.markdown, highlight: search)
                    .padding(28)
                    .frame(maxWidth: 720, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 820, minHeight: 560)
    }
}

/// Small block renderer for the help files: headings, lists, notes and paragraphs with inline Markdown.
struct MarkdownView: View {
    let text: String
    var highlight = ""

    enum Block: Hashable {
        case h1(String), h2(String), h3(String), bullet(String), note(String), paragraph(String), table([[String]])
        /// `![](images/name.png)`: a picture from the bundle's Help/images folder.
        case image(String)
    }

    var blocks: [Block] {
        var out: [Block] = []
        var paragraph: [String] = []
        var table: [[String]] = []
        func flush() {
            if !paragraph.isEmpty { out.append(.paragraph(paragraph.joined(separator: " "))); paragraph = [] }
            if !table.isEmpty { out.append(.table(table)); table = [] }
        }
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("|") {
                if !paragraph.isEmpty { out.append(.paragraph(paragraph.joined(separator: " "))); paragraph = [] }
                let cells = line.trimmingCharacters(in: CharacterSet(charactersIn: "|")).components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                if !cells.allSatisfy({ $0.allSatisfy { "-: ".contains($0) } }) { table.append(cells) }
                continue
            }
            if line.isEmpty { flush(); continue }
            if line.hasPrefix("!["), let open = line.firstIndex(of: "("), line.hasSuffix(")") {
                flush()
                out.append(.image(String(line[line.index(after: open)..<line.index(before: line.endIndex)])))
                continue
            }
            if line.hasPrefix("### ") { flush(); out.append(.h3(String(line.dropFirst(4)))) }
            else if line.hasPrefix("## ") { flush(); out.append(.h2(String(line.dropFirst(3)))) }
            else if line.hasPrefix("# ") { flush(); out.append(.h1(String(line.dropFirst(2)))) }
            else if line.hasPrefix("- ") { flush(); out.append(.bullet(String(line.dropFirst(2)))) }
            else if line.hasPrefix("> ") { flush(); out.append(.note(String(line.dropFirst(2)))) }
            else { paragraph.append(line) }
        }
        flush()
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .h1(let s): Text(inline(s)).font(.largeTitle.bold()).padding(.bottom, 4)
                case .h2(let s): Text(inline(s)).font(.title2.bold()).padding(.top, 10)
                case .h3(let s): Text(inline(s)).font(.headline).padding(.top, 4)
                case .bullet(let s):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: "•").foregroundStyle(.secondary)
                        Text(inline(s)).fixedSize(horizontal: false, vertical: true)
                    }
                case .note(let s):
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill").foregroundStyle(.tint)
                        Text(inline(s)).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.1), in: .rect(cornerRadius: 8))
                case .paragraph(let s): Text(inline(s)).fixedSize(horizontal: false, vertical: true)
                case .image(let path): HelpImage(path: path)
                case .table(let rows):
                    Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 6) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                            GridRow {
                                ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                    Text(inline(cell)).fontWeight(i == 0 ? .semibold : .regular)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            if i == 0 { Divider() }
                        }
                    }
                    .padding(12)
                    .background(.background.secondary, in: .rect(cornerRadius: 8))
                }
            }
        }
        .textSelection(.enabled)
    }

    private func inline(_ s: String) -> AttributedString {
        var a = (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s)
        if !highlight.isEmpty {
            var range = a.startIndex..<a.endIndex
            while let found = a[range].range(of: highlight, options: .caseInsensitive) {
                a[found].backgroundColor = .yellow.opacity(0.4)
                range = found.upperBound..<a.endIndex
            }
        }
        return a
    }
}

/// A screenshot in the help, at its natural size or narrower, with a light frame.
struct HelpImage: View {
    let path: String

    var body: some View {
        let name = (path as NSString).deletingPathExtension
        if let url = Bundle.main.url(forResource: (name as NSString).lastPathComponent, withExtension: (path as NSString).pathExtension,
                                     subdirectory: "Help/" + (name as NSString).deletingLastPathComponent),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: min(image.size.width, 640))
                .clipShape(.rect(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.separator, lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                .padding(.vertical, 4)
        }
    }
}
