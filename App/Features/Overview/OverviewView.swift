import AppKit
import Observation
import SwabrCore
import SwiftUI

/// Runs the scans of the areas whose finds can be removed, one after another, for the overview.
@MainActor @Observable
final class OverviewModel {
    static let shared = OverviewModel()

    var running = false
    var step = ""
    /// Apps not opened for half a year, the overview's suggestion.
    var unusedApps: [InstalledApp] = []
    /// Every installed app, for the search on the overview.
    var apps: [InstalledApp] = []
    var recent: [HistorySession] = []
    private var appsLoaded = false

    func scanAll() async {
        guard !running else { return }
        running = true
        defer { running = false }
        let models = AppModels.shared
        if Module.clean.isAvailable, Module.clean.requiredAccess.allSatisfy(FolderAccess.covers) {
            step = String(localized: "Caches, Logs und Reste")
            await models.clean.scan()
        }
        if Module.purge.isAvailable, !models.projects.roots.isEmpty {
            step = String(localized: "Build-Ordner in Projekten")
            await models.projects.scan()
        }
        if Module.installer.isAvailable {
            step = String(localized: "Installer-Dateien")
            await models.installer.scan()
        }
        if Module.slim.isAvailable, AppSlimmer.isAppleSilicon {
            step = String(localized: "Intel-Code in Universal-Apps")
            await models.slim.scan()
        }
        step = ""
        refreshRecent()
    }

    func refreshRecent() {
        recent = Array(History.sessions(History.load()).prefix(3))
    }

    func loadUnusedApps() async {
        guard !appsLoaded, let protection = try? RuleStore.protection() else { return }
        appsLoaded = true
        let limit = Date().addingTimeInterval(-180 * 86_400)
        let apps = await AppCatalog.installedApps(protection: protection)
        self.apps = apps.filter { !$0.isIOSApp }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        unusedApps = apps.filter { $0.isRemovable && !$0.isIOSApp && ($0.lastUsed.map { $0 < limit } ?? false) }
            .sorted { $0.bytes > $1.bytes }
    }
}

struct OverviewView: View {
    private let model = OverviewModel.shared
    private let summary = ScanSummary.shared
    private let status = StatusModel.shared
    private let nav = Navigator.shared
    @State private var search = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(String(localized: "Übersicht"), subtitle: subtitle)
                if !query.isEmpty {
                    SearchResults(query: query, apps: model.apps) { search = "" }
                } else {
                    dashboard
                }
            }
            .padding(.horizontal, 28).padding(.top, 8).padding(.bottom, 24)
        }
        .navigationTitle("Übersicht")
        .searchable(text: $search, placement: .toolbarPrincipal, prompt: "In Swabr suchen")
        .onAppear {
            status.acquire()
            model.refreshRecent()
        }
        .onDisappear { status.release() }
        .task { await model.loadUnusedApps() }
    }

    private var query: String { search.trimmingCharacters(in: .whitespaces) }

    @ViewBuilder private var dashboard: some View {
                HStack(alignment: .top, spacing: 14) {
                    hero
                    VStack(spacing: 12) {
                        LiveCard(snapshot: status.snapshot)
                        ProtectionCard()
                    }
                    .frame(width: 290)
                }
                Text("Bereiche").font(.headline).foregroundStyle(.secondary).padding(.top, 4)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 12)], spacing: 12) {
                    ForEach(tiles, id: \.module) { tile in
                        Button { nav.open(tile.module) } label: { ModuleTile(module: tile.module, caption: tile.caption, value: tile.value) }
                            .buttonStyle(.plain)
                    }
                }
                HStack(alignment: .top, spacing: 12) {
                    RecentCard(sessions: model.recent) { nav.open(.history) }
                    if !model.unusedApps.isEmpty {
                        SuggestionCard(apps: model.unusedApps) { nav.open(.uninstall) }
                    }
                }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let hw = status.snapshot?.hardware { parts.append("\(hw.model) · \(hw.chip)") }
        if model.running {
            parts.append(String(localized: "wird geprüft …"))
        } else if let date = summary.lastChecked {
            parts.append(String(localized: "zuletzt geprüft \(date.formatted(.relative(presentation: .named)))"))
        } else {
            parts.append(String(localized: "noch nicht geprüft"))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Hero

    private var total: Int64 { summary.reclaimableBytes }

    private var segments: [(Double, Color)] {
        guard total > 0 else { return [] }
        return ScanSummary.cleanup.filter(\.isAvailable).compactMap { m in
            guard let b = summary.entry(m)?.foundBytes, b > 0 else { return nil }
            return (Double(b) / Double(total), m.tint)
        }
    }

    private var hero: some View {
        HStack(spacing: 26) {
            GradientRing(value: nil, segments: segments, lineWidth: 14) {
                VStack(spacing: 0) {
                    if model.running {
                        ProgressView().controlSize(.regular)
                    } else if summary.hasAny {
                        let parts = DiskSize.format(total).split(separator: " ", maxSplits: 1).map(String.init)
                        Text(parts.first ?? "").font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
                        Text(String(localized: "\(parts.count > 1 ? parts[1] : "") freigebbar")).font(.caption).foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "questionmark").font(.system(size: 30, weight: .semibold)).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 150, height: 150)
            VStack(alignment: .leading, spacing: 8) {
                Text(heroKicker).font(.caption.weight(.semibold)).tracking(0.6).foregroundStyle(Brand.purple)
                Text(heroTitle).font(.system(size: 26, weight: .bold)).tracking(-0.4)
                Text(heroText).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    if model.running {
                        Button {} label: { Label("Prüfe …", systemImage: "hourglass") }.buttonStyle(.prominent).disabled(true)
                    } else if summary.hasAny, total >= 100_000_000 {
                        Button { nav.open(largestArea) } label: { Label("Prüfen & aufräumen", systemImage: "sparkles") }
                            .buttonStyle(.prominent)
                        Button("Neu prüfen") { Task { await model.scanAll() } }.buttonStyle(.soft)
                    } else {
                        Button { Task { await model.scanAll() } } label: { Label(summary.hasAny ? String(localized: "Neu prüfen") : String(localized: "Alles prüfen"), systemImage: "magnifyingglass") }
                            .buttonStyle(.prominent)
                        Button("Speicher ansehen") { nav.open(.analyze) }.buttonStyle(.soft)
                    }
                }
                .padding(.top, 6)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 26).padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Brand.blue.opacity(0.10), Brand.purple.opacity(0.10)], startPoint: .leading, endPoint: .trailing),
            in: .rect(cornerRadius: 20, style: .continuous))
    }

    private var heroKicker: String {
        if model.running { return String(localized: "PRÜFE …") }
        if !summary.hasAny { return String(localized: "NOCH NICHT GEPRÜFT") }
        return total >= 100_000_000 ? String(localized: "BEREIT") : String(localized: "ALLES IN ORDNUNG")
    }

    private var heroTitle: String {
        if model.running { return model.step }
        if !summary.hasAny { return String(localized: "Wie viel Platz kann weg?") }
        return total >= 100_000_000 ? String(localized: "Dein Mac kann aufatmen.") : String(localized: "Dein Mac ist aufgeräumt.")
    }

    private var heroText: String {
        if model.running || !summary.hasAny {
            return String(localized: "Swabr sucht in Caches, Build-Ordnern, Installern und Universal-Apps. Gelöscht wird erst, nachdem du die Liste geprüft hast.")
        }
        return total >= 100_000_000
            ? String(localized: "\(DiskSize.format(total)) in Caches, Build-Ordnern und Installer-Resten gefunden. Gelöscht wird erst, nachdem du die Liste geprüft hast.")
            : String(localized: "Gerade gibt es nichts Nennenswertes aufzuräumen.")
    }

    /// The clean-up area with the most found, where "Prüfen & aufräumen" leads (Clean Up when in doubt).
    private var largestArea: Module {
        let areas = ScanSummary.cleanup.filter(\.isAvailable)
        return areas.max { (summary.entry($0)?.foundBytes ?? 0) < (summary.entry($1)?.foundBytes ?? 0) } ?? .clean
    }

    // MARK: Tiles

    private struct Tile {
        let module: Module
        let caption: String
        let value: String
    }

    private var tiles: [Tile] {
        let s = status.snapshot
        let all: [Tile] = [
            Tile(module: .clean, caption: String(localized: "Caches, Logs und Reste"), value: bytes(.clean)),
            Tile(module: .uninstall, caption: String(localized: "Deinstallieren, Updates, Start"),
                 value: summary.entry(.uninstall).map { String(localized: "\($0.count) Updates") } ?? "›"),
            Tile(module: .optimize, caption: String(localized: "Caches und Dienste auffrischen"), value: "›"),
            Tile(module: .analyze, caption: s.map { String(localized: "\(DiskSize.format($0.disk.free)) frei") } ?? String(localized: "Belegung erkunden"),
                 value: s.map { "\(Int($0.disk.usedPercent.rounded())) %" } ?? "›"),
            Tile(module: .purge, caption: String(localized: "Build-Ordner in Projekten"), value: bytes(.purge)),
            Tile(module: .installer, caption: String(localized: ".dmg- und .pkg-Dateien"), value: bytes(.installer)),
            Tile(module: .slim, caption: String(localized: "Intel-Code aus Universal-Apps"), value: bytes(.slim)),
            Tile(module: .status, caption: s.map { String(localized: "Zustand: \($0.health.label)") } ?? String(localized: "CPU, Speicher, Netz live"),
                 value: s.map { "\($0.health.score)" } ?? "›"),
        ]
        return all.filter { $0.module.isAvailable }
    }

    /// What the last scan found in an area (ticked or not); the area's own page decides what goes.
    private func bytes(_ m: Module) -> String {
        guard let e = summary.entry(m) else { return "–" }
        return e.foundBytes > 0 ? DiskSize.format(e.foundBytes) : "0"
    }
}

// MARK: Cards

private struct ModuleTile: View {
    let module: Module
    let caption: String
    let value: String
    @State private var hover = false

    var body: some View {
        HStack(spacing: 12) {
            IconTile(module: module, size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(module.title).font(.headline)
                Text(caption).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 6)
            Text(value).font(.headline).monospacedDigit().lineLimit(1)
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .background(hover ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(.fill.quaternary), in: .rect(cornerRadius: 16, style: .continuous))
        .contentShape(.rect)
        .onHover { hover = $0 }
    }
}

private struct LiveCard: View {
    let snapshot: StatusSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live").font(.headline)
            if let s = snapshot {
                metric("CPU", value: String(format: "%.0f %%", s.cpu.usage), fraction: s.cpu.usage / 100, color: Brand.blue)
                metric("RAM", value: "\(Rate.memory(s.memory.used)) / \(Rate.memory(s.memory.total))", fraction: s.memory.usedPercent / 100, color: Brand.purple)
                metric(String(localized: "Festplatte"), value: String(localized: "\(DiskSize.format(s.disk.free)) frei"), fraction: s.disk.usedPercent / 100, color: Brand.teal)
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 90)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 18)
    }

    private func metric(_ label: String, value: String, fraction: Double, color: Color) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(label).font(.callout).foregroundStyle(.secondary)
                Spacer()
                Text(value).font(.callout.weight(.semibold)).monospacedDigit()
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.fill.tertiary)
                    Capsule().fill(color).frame(width: g.size.width * max(0, min(fraction, 1)))
                }
            }
            .frame(height: 5)
        }
    }
}

private struct ProtectionCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 18)).foregroundStyle(.green)
                .frame(width: 34, height: 34)
                .background(.green.opacity(0.15), in: .rect(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("Schutz aktiv").font(.headline)
                Text("System, laufende Apps und deine Ausnahmen bleiben unangetastet.").font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
    }
}

private struct RecentCard: View {
    let sessions: [HistorySession]
    let open: () -> Void
    private let colors = [Brand.blue, Brand.pink, Brand.teal]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Zuletzt").font(.headline)
                Spacer()
                Button("Verlauf", action: open).buttonStyle(.softCompact)
            }
            if sessions.isEmpty {
                Text("Noch nichts entfernt.").font(.callout).foregroundStyle(.secondary)
            }
            ForEach(Array(sessions.enumerated()), id: \.element.id) { i, s in
                HStack(spacing: 8) {
                    Circle().fill(colors[i % colors.count]).frame(width: 7, height: 7)
                    Text("\(s.modules.joined(separator: ", ")) · \(s.start.formatted(date: .abbreviated, time: .omitted))")
                        .font(.callout).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Text(DiskSize.format(s.bytes)).font(.callout.weight(.semibold)).monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 18)
    }
}

private struct SuggestionCard: View {
    let apps: [InstalledApp]
    let open: () -> Void

    var body: some View {
        let bytes = apps.reduce(Int64(0)) { $0 + $1.bytes }
        HStack(spacing: 14) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 18)).foregroundStyle(.orange)
                .frame(width: 40, height: 40)
                .background(.orange.opacity(0.15), in: .rect(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("VORSCHLAG").font(.caption.weight(.semibold)).tracking(0.6).foregroundStyle(.orange)
                Text(String(localized: "\(apps.count) Apps seit über 6 Monaten nicht geöffnet")).font(.headline)
                Text("\(apps.prefix(3).map(\.name).joined(separator: ", ")): \(DiskSize.format(bytes))")
                    .font(.callout).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            Button("Ansehen", action: open).buttonStyle(.softCompact)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 18)
    }
}

/// Results of the overview's search: matching areas and installed apps.
private struct SearchResults: View {
    let query: String
    let apps: [InstalledApp]
    let done: () -> Void

    private var areas: [Module] {
        Module.available.filter { $0 != .overview && ($0.title.localizedCaseInsensitiveContains(query) || $0.summary.localizedCaseInsensitiveContains(query)) }
    }

    private var appHits: [InstalledApp] {
        Array(apps.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.bundleID.localizedCaseInsensitiveContains(query) }.prefix(12))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if areas.isEmpty && appHits.isEmpty {
                ContentUnavailableView.search(text: query).frame(maxWidth: .infinity, minHeight: 240)
            }
            if !areas.isEmpty {
                Text("Bereiche").font(.headline).foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(areas) { m in
                        row {
                            IconTile(module: m, size: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.title).font(.headline)
                                Text(m.summary).font(.caption).foregroundStyle(.secondary)
                            }
                        } action: {
                            Navigator.shared.open(m)
                            done()
                        }
                    }
                }
                .card(padding: 6)
            }
            if !appHits.isEmpty {
                Text("Apps").font(.headline).foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(appHits) { app in
                        row {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path)).resizable().frame(width: 30, height: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(app.name).font(.headline)
                                Text(app.lastUsed.map { String(localized: "zuletzt geöffnet \($0.formatted(.relative(presentation: .named)))") } ?? app.bundleID)
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Text(DiskSize.format(app.bytes)).font(.callout).monospacedDigit().foregroundStyle(.secondary)
                        } action: {
                            UserDefaults.standard.set("uninstall", forKey: "appsSegment")
                            let apps = AppModels.shared.uninstall
                            apps.search = app.name
                            apps.focus(app.path)
                            Navigator.shared.open(.uninstall)
                            done()
                        }
                    }
                }
                .card(padding: 6)
            }
        }
    }

    private func row<Content: View>(@ViewBuilder _ content: () -> Content, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                content()
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
