import Darwin
import Foundation

/// The maintenance tasks. Each one checks first whether there is anything to do and reports exactly what
/// it did; none of them promises a faster Mac. Commands and locations come from the man pages named at
/// each task and from looking at a current macOS installation.
public enum OptimizeCatalog {
    public static let all: [OptimizeTask] = [
        quickLook, savedStates, brokenPreferences, dnsFlush, networkRoutes, dsStore, legacyDefaults,
        homePermissions, spotlightCheck, spotlightOrphans, periodic, sharedFileLists, verifyVolume,
        loginItems, quarantineHistory, orphanedAgents, oldNotifications, compactDatabases,
    ]

    /// Tasks that work inside the App Store sandbox: no root, only the user's own files.
    public static let sandboxSafeIDs: Set<String> = ["state.old", "prefs.broken", "finder.sfl", "quarantine.history", "agents.orphans"]

    static func text(_ key: String.LocalizationValue) -> String { String(localized: key, bundle: .module) }

    /// `"Reason: first line of the tool's output"`.
    static func failure(_ reason: String, _ output: String) -> String {
        let line = output.split(whereSeparator: \.isNewline).lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty }
        return line.map { reason + ": " + $0 } ?? reason
    }

    static let days30: TimeInterval = 30 * 86_400

    // MARK: Finder

    /// qlmanage(1): `-r` resets the Quick Look server and its generators, `-r cache` the thumbnail disk cache.
    static let quickLook = OptimizeTask(
        id: "finder.quicklook",
        title: text("QuickLook-Vorschauen neu aufbauen"),
        summary: text("Vorschaubilder-Cache von QuickLook zurücksetzen."),
        impact: text("Behebt falsche oder fehlende Vorschaubilder und Symbole. Der Finder zeigt sie kurz verzögert neu an."),
        needsAdmin: false, noticeable: false
    ) { ctx in
        let server = ctx.command("/usr/bin/qlmanage", ["-r"], timeout: 30)
        let cache = ctx.command("/usr/bin/qlmanage", ["-r", "cache"], timeout: 30)
        guard server.status == 0, cache.status == 0 else {
            return .done(.failed(failure(text("QuickLook konnte nicht neu gestartet werden"), server.status == 0 ? cache.output : server.output)))
        }
        return .done(.applied(text("QuickLook zurückgesetzt, Vorschauen werden neu erzeugt")))
    }

    /// Settings domain of the Finder's desktop services; documented by Apple Support for SMB browsing.
    static let dsStoreKeys = ["DSDontWriteNetworkStores", "DSDontWriteUSBStores"]

    static let dsStore = OptimizeTask(
        id: "finder.dsstore",
        title: text("Keine .DS_Store auf Netz- und USB-Laufwerken"),
        summary: text("Finder legt dort keine .DS_Store-Dateien mehr an."),
        impact: text("Keine versteckten Finder-Dateien mehr auf NAS, Freigaben und USB-Sticks. Ordneransichten dort merkt sich der Finder dann nicht mehr."),
        needsAdmin: false, noticeable: false
    ) { ctx in
        let missing = dsStoreKeys.filter { !isTrue(ctx.command("/usr/bin/defaults", ["read", "com.apple.desktopservices", $0], timeout: 10)) }
        guard !missing.isEmpty else { return .done(.unchanged(text("Bereits eingestellt"))) }
        for key in missing {
            let r = ctx.command("/usr/bin/defaults", ["write", "com.apple.desktopservices", key, "-bool", "true"], timeout: 10)
            guard r.status == 0 else { return .done(.failed(failure(text("Einstellung konnte nicht gesetzt werden"), r.output))) }
        }
        return .done(.applied(text("Finder schreibt keine .DS_Store mehr auf Netz- und USB-Laufwerke")))
    }

    /// `defaults read` prints booleans as 1 or 0.
    static func isTrue(_ r: (status: Int32, output: String)) -> Bool {
        r.status == 0 && ["1", "true", "yes"].contains(r.output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    /// Readable lists of the sidebar, "Recent Items" and server lists (`.sfl`, `.sfl2` … `.sfl4`).
    static let sharedFileLists = OptimizeTask(
        id: "finder.sfl",
        title: text("Defekte Seitenleisten- und Verlaufslisten"),
        summary: text("Beschädigte Listen für Seitenleiste und „Zuletzt benutzt“ finden."),
        impact: text("Nur beschädigte Listen werden entfernt. macOS legt sie leer neu an, betroffene Favoriten musst du neu hinzufügen."),
        needsAdmin: false, noticeable: false
    ) { ctx in
        let root = ctx.home + "/Library/Application Support/com.apple.sharedfilelist"
        let lists: [String]
        switch listing(root, ctx: ctx) {
        case .missing: return .done(.unchanged(text("Keine Listen gefunden")))
        case .denied(let why): return .done(.unavailable(why))
        case .names:
            lists = sharedFileListFiles(in: root)
        }
        guard !lists.isEmpty else { return .done(.unchanged(text("Keine Listen gefunden"))) }
        let broken = lists.filter { !isReadableArchive($0) }
        guard !broken.isEmpty else { return .done(.unchanged(text("Alle Listen sind lesbar"))) }
        let report = moveToTrash(broken, label: "Optimieren: Seitenleisten- und Verlaufslisten", ctx: ctx)
        guard report.moved > 0 else { return .done(.failed(report.failureText)) }
        // The list daemon caches the lists in memory; launchd restarts it on demand.
        _ = ctx.command("/usr/bin/killall", ["sharedfilelistd"], timeout: 10)
        let done = text("\(report.moved) beschädigte Listen entfernt")
        return .done(report.problems.isEmpty ? .applied(done) : .attention(done + " · " + report.failureText))
    }

    static func sharedFileListFiles(in root: String) -> [String] {
        guard let walker = FileManager.default.enumerator(atPath: root) else { return [] }
        var out: [String] = []
        while let rel = walker.nextObject() as? String {
            let ext = (rel as NSString).pathExtension.lowercased()
            guard ext.hasPrefix("sfl"), ext.dropFirst(3).allSatisfy(\.isNumber) else { continue }
            if walker.fileAttributes?[.type] as? FileAttributeType == .typeRegular { out.append(root + "/" + rel) }
        }
        return out.sorted()
    }

    /// The lists are keyed archives; one the unarchiver rejects cannot be read by macOS either.
    static func isReadableArchive(_ path: String) -> Bool {
        guard let data = FileManager.default.contents(atPath: path),
              let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return false }
        unarchiver.finishDecoding()
        return true
    }

    // MARK: Saved state and preferences

    static let savedStates = OptimizeTask(
        id: "state.old",
        title: text("Alte Fensterzustände entfernen"),
        summary: text("Gespeicherte Fensterzustände, die älter als 30 Tage sind."),
        impact: text("Apps, die du über einen Monat nicht benutzt hast, öffnen ihre alten Fenster beim nächsten Start nicht wieder."),
        needsAdmin: false, noticeable: false
    ) { ctx in
        let root = ctx.home + "/Library/Saved Application State"
        let names: [String]
        switch listing(root, ctx: ctx) {
        case .missing: return .done(.unchanged(text("Keine alten Fensterzustände")))
        case .denied(let why): return .done(.unavailable(why))
        case .names(let n): names = n
        }
        let cutoff = ctx.now.addingTimeInterval(-days30)
        var removed = 0
        var problems: [String] = []
        for name in names where name.hasSuffix(".savedState") {
            let path = root + "/" + name
            guard let changed = newestChange(path), changed < cutoff else { continue }
            let bundleID = String(name.dropLast(".savedState".count))
            if ctx.isRunning(bundleID: bundleID) { continue }
            if case .refused(let why) = PathSafety.check(path, home: ctx.home) {
                problems.append(name + ": " + why)
                continue
            }
            let bytes = DiskSize.allocatedSize(of: path)
            do {
                try FileManager.default.removeItem(atPath: path)
                removed += 1
                ctx.log.record(action: "REMOVE", path: path, bytes: bytes, label: "Optimieren: Fensterzustände")
            } catch {
                problems.append(name + ": " + error.localizedDescription)
            }
        }
        if removed == 0 && problems.isEmpty { return .done(.unchanged(text("Keine alten Fensterzustände"))) }
        if removed == 0 { return .done(.failed(problems.joined(separator: "; "))) }
        let done = text("\(removed) alte Fensterzustände entfernt")
        return .done(problems.isEmpty ? .applied(done) : .attention(done + " · " + problems.joined(separator: "; ")))
    }

    /// The later of the folder's own date and that of its direct entries: apps rewrite the files inside
    /// without touching the folder.
    static func newestChange(_ folder: String) -> Date? {
        let fm = FileManager.default
        guard var newest = (try? fm.attributesOfItem(atPath: folder))?[.modificationDate] as? Date else { return nil }
        for name in (try? fm.contentsOfDirectory(atPath: folder)) ?? [] {
            if let d = (try? fm.attributesOfItem(atPath: folder + "/" + name))?[.modificationDate] as? Date, d > newest { newest = d }
        }
        return newest
    }

    static let brokenPreferences = OptimizeTask(
        id: "prefs.broken",
        title: text("Defekte Einstellungsdateien reparieren"),
        summary: text("Beschädigte Einstellungsdateien von Drittanbieter-Apps finden."),
        impact: text("Betroffene Apps starten mit Standardeinstellungen statt abzustürzen. Die Dateien landen im Papierkorb. Apple-Einstellungen bleiben unberührt."),
        needsAdmin: false, noticeable: false
    ) { ctx in
        let folder = ctx.home + "/Library/Preferences"
        switch listing(folder, ctx: ctx) {
        case .missing: return .done(.unchanged(text("Keine defekten Einstellungsdateien")))
        case .denied(let why): return .done(.unavailable(why))
        case .names: break
        }
        let broken = brokenPreferenceFiles(in: folder, ctx: ctx)
        guard !broken.isEmpty else { return .done(.unchanged(text("Keine defekten Einstellungsdateien"))) }
        var busy: [String] = []
        var eligible: [String] = []
        for path in broken {
            let bundleID = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
            if ctx.isRunning(bundleID: bundleID) { busy.append(bundleID) } else { eligible.append(path) }
        }
        let waiting = busy.isEmpty ? nil : text("Bitte zuerst schließen: \(busy.joined(separator: ", "))")
        guard !eligible.isEmpty else { return .done(.attention(waiting ?? "")) }
        let report = moveToTrash(eligible, label: "Optimieren: Einstellungsdateien", ctx: ctx)
        guard report.moved > 0 else { return .done(.failed([report.failureText, waiting].compactMap { $0 }.joined(separator: " · "))) }
        let done = text("\(report.moved) beschädigte Einstellungsdateien in den Papierkorb gelegt")
        let notes = [report.problems.isEmpty ? nil : report.failureText, waiting].compactMap { $0 }
        return .done(notes.isEmpty ? .applied(done) : .attention(([done] + notes).joined(separator: " · ")))
    }

    /// Top-level `*.plist` of third-party apps that `plutil -lint` rejects. Apple's own files are never
    /// candidates: they start with `com.apple.`, belong to an Apple group container or are named after a
    /// system daemon without a reverse-DNS name (`loginwindow.plist`, `pbs.plist` …).
    static func brokenPreferenceFiles(in folder: String, ctx: OptimizeContext) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
        return names.sorted().compactMap { name -> String? in
            guard isThirdPartyPreference(name) else { return nil }
            let path = folder + "/" + name
            var st = stat()
            // Regular files with content only; an empty file is treated by macOS as no settings at all.
            guard lstat(path, &st) == 0, (st.st_mode & S_IFMT) == S_IFREG, st.st_size > 0,
                  FileManager.default.isReadableFile(atPath: path) else { return nil }
            if let data = FileManager.default.contents(atPath: path),
               (try? PropertyListSerialization.propertyList(from: data, format: nil)) != nil { return nil }
            let lint = ctx.command("/usr/bin/plutil", ["-lint", "-s", path], timeout: 10)
            return lint.status > 0 ? path : nil
        }
    }

    static func isThirdPartyPreference(_ name: String) -> Bool {
        let lower = name.lowercased()
        guard lower.hasSuffix(".plist"), !lower.hasPrefix(".") else { return false }
        let base = String(lower.dropLast(".plist".count))
        guard base.contains("."), !base.hasPrefix("com.apple."), !base.contains(".com.apple.") else { return false }
        return !PathSafety.hasControlCharacters(name)
    }

    // MARK: Network (root)

    /// Interface of the default route, or nil when offline (route(8): `route -n get default`).
    static func defaultInterface(_ ctx: OptimizeContext) -> String? {
        let r = ctx.command("/sbin/route", ["-n", "get", "default"], timeout: 10)
        guard r.status == 0 else { return nil }
        for line in r.output.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, parts[0] == "interface", isInterfaceName(parts[1]) { return parts[1] }
        }
        return nil
    }

    /// Tunnel interfaces carry VPN traffic; flushing under them would drop the tunnel.
    static func isTunnel(_ interface: String) -> Bool {
        ["utun", "ppp", "ipsec", "tun", "tap"].contains { interface.hasPrefix($0) }
    }

    static func isInterfaceName(_ s: String) -> Bool {
        !s.isEmpty && s.count < 16 && s.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    static let dnsFlush = OptimizeTask(
        id: "dns.flush",
        title: text("DNS-Cache leeren"),
        summary: text("Zwischengespeicherte Namensauflösungen verwerfen."),
        impact: text("Hilft, wenn Webseiten nach einer Netzwerk- oder DNS-Änderung nicht erreichbar sind. Erste Seitenaufrufe dauern minimal länger."),
        needsAdmin: true, noticeable: false
    ) { ctx in
        guard let interface = defaultInterface(ctx) else { return .done(.unchanged(text("Keine Standardroute, offline"))) }
        if isTunnel(interface) { return .done(.skipped(text("VPN aktiv (\(interface)), DNS bleibt unverändert"))) }
        // dscacheutil(1) -flushcache, then mDNSResponder re-reads its configuration on SIGHUP.
        return .admin(AdminStep(command: "/usr/bin/dscacheutil -flushcache && /usr/bin/killall -HUP mDNSResponder") { status, output in
            status == 0 ? .applied(text("DNS-Cache geleert")) : .failed(failure(text("DNS-Cache konnte nicht aufgefrischt werden"), output))
        })
    }

    static let networkRoutes = OptimizeTask(
        id: "net.routes",
        title: text("Netzwerk-Routen auffrischen"),
        summary: text("Routing-Tabelle leeren und die Adresse der aktiven Schnittstellen neu per DHCP holen."),
        impact: text("Löst hängende Verbindungen nach Netzwechseln. Die Verbindung ist dabei wenige Sekunden unterbrochen, laufende Downloads können abbrechen."),
        needsAdmin: true, noticeable: true
    ) { ctx in
        guard let primary = defaultInterface(ctx) else { return .done(.unchanged(text("Keine Standardroute, offline"))) }
        if isTunnel(primary) { return .done(.skipped(text("VPN aktiv (\(primary)), Routen bleiben unverändert"))) }
        let active = activeInterfaces(ctx)
        if let tunnel = active.first(where: isTunnel) { return .done(.skipped(text("VPN aktiv (\(tunnel)), Routen bleiben unverändert"))) }
        let interfaces = active.contains(primary) ? active : [primary] + active
        // ipconfig(8) `set <if> DHCP` would replace a manual setup by DHCP, so every interface must use DHCP already.
        if let manual = interfaces.first(where: { !usesDHCP($0, ctx) }) {
            return .done(.skipped(text("Schnittstelle \(manual) ist manuell eingerichtet, Routen bleiben unverändert")))
        }
        let renew = interfaces.map { "/usr/sbin/ipconfig set \($0) DHCP" }.joined(separator: " && ")
        return .admin(AdminStep(command: "/sbin/route -n flush >/dev/null && " + renew) { status, output in
            status == 0 ? .applied(text("Routen geleert, Adressen neu angefordert")) : .failed(failure(text("Netzwerk-Routen konnten nicht geleert werden"), output))
        })
    }

    /// The interfaces `scutil --nwi` lists as reachable (`Network interfaces: en0 en1`).
    static func activeInterfaces(_ ctx: OptimizeContext) -> [String] {
        let r = ctx.command("/usr/sbin/scutil", ["--nwi"], timeout: 10)
        guard r.status == 0 else { return [] }
        for line in r.output.split(whereSeparator: \.isNewline) where line.hasPrefix("Network interfaces:") {
            return line.dropFirst("Network interfaces:".count).split(separator: " ").map(String.init).filter(isInterfaceName)
        }
        return []
    }

    /// `ipconfig getpacket` prints the accepted DHCP packet, and nothing for other configurations.
    static func usesDHCP(_ interface: String, _ ctx: OptimizeContext) -> Bool {
        let r = ctx.command("/usr/sbin/ipconfig", ["getpacket", interface], timeout: 10)
        return r.status == 0 && !r.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Old tuning switches

    /// Switches that tuning tools set and that only do harm on current macOS. Each is removed only when
    /// it is set to true; removing restores the system default.
    static let legacySwitches: [(domain: String, key: String)] = [
        // App Nap off for every app; Apple's Energy Efficiency Guide for Mac Apps names this key for testing only.
        ("-g", "NSAppSleepDisabled"),
        // hdiutil(1), "-[no]verify" and "-[no]ignorebadchecksums": preference keys in com.apple.frameworks.diskimages
        // that skip the checksum verification of disk images or accept bad checksums.
        ("com.apple.frameworks.diskimages", "skip-verify"),
        ("com.apple.frameworks.diskimages", "skip-verify-locked"),
        ("com.apple.frameworks.diskimages", "skip-verify-remote"),
        ("com.apple.frameworks.diskimages", "ignore-bad-checksums"),
    ]

    static let legacyDefaults = OptimizeTask(
        id: "defaults.legacy",
        title: text("Veraltete Tuning-Einstellungen entfernen"),
        summary: text("Versteckte Schalter alter Tuning-Tools (App Nap aus, Image-Prüfung aus)."),
        impact: text("macOS nutzt wieder seine Standardwerte: Apps im Hintergrund sparen Energie, Festplattenimages werden geprüft."),
        needsAdmin: false, noticeable: false
    ) { ctx in
        let set = legacySwitches.filter { isTrue(ctx.command("/usr/bin/defaults", ["read", $0.domain, $0.key], timeout: 10)) }
        guard !set.isEmpty else { return .done(.unchanged(text("Keine alten Schalter gefunden"))) }
        var removed = 0
        var problems: [String] = []
        for s in set {
            let r = ctx.command("/usr/bin/defaults", ["delete", s.domain, s.key], timeout: 10)
            if r.status == 0 { removed += 1 } else { problems.append(s.key) }
        }
        let done = text("\(removed) alte Schalter entfernt")
        if problems.isEmpty { return .done(.applied(done)) }
        let why = text("Einstellung konnte nicht gesetzt werden") + ": " + problems.joined(separator: ", ")
        return .done(removed == 0 ? .failed(why) : .attention(done + " · " + why))
    }

    // MARK: Home folder permissions (root)

    static let homePermissions = OptimizeTask(
        id: "home.permissions",
        title: text("Zugriffsrechte im Benutzerordner reparieren"),
        summary: text("diskutil resetUserPermissions für deinen Benutzer."),
        impact: text("Behebt „Keine Berechtigung“-Fehler in deinem Benutzerordner. Dauert je nach Datenmenge einige Minuten."),
        needsAdmin: true, noticeable: true
    ) { ctx in
        guard hasPermissionProblems(home: ctx.home, uid: ctx.uid) else { return .done(.unchanged(text("Zugriffsrechte sind in Ordnung"))) }
        // diskutil(8): resetUserPermissions <mount point> <uid>, root only.
        return .admin(AdminStep(command: "/usr/sbin/diskutil resetUserPermissions / \(ctx.uid)") { status, output in
            status == 0 ? .applied(text("Zugriffsrechte zurückgesetzt")) : .failed(failure(text("Zugriffsrechte konnten nicht zurückgesetzt werden"), output))
        })
    }

    /// Looks at the home folder and two levels below it (without following links) for entries owned by
    /// someone else or folders the owner cannot write. The Trash keeps what other users deleted, so it is left out.
    static func hasPermissionProblems(home: String, uid: uid_t, depth: Int = 2) -> Bool {
        func bad(_ path: String) -> (Bool, isDir: Bool) {
            var st = stat()
            guard lstat(path, &st) == 0 else { return (false, false) }
            let type = st.st_mode & S_IFMT
            if type == S_IFLNK { return (false, false) }
            let isDir = type == S_IFDIR
            return (st.st_uid != uid || (isDir && st.st_mode & S_IWUSR == 0), isDir)
        }
        var level = [home]
        if bad(home).0 { return true }
        for _ in 0..<depth {
            var next: [String] = []
            for dir in level {
                for name in (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? [] where !(dir == home && name == ".Trash") {
                    let path = dir + "/" + name
                    let (isBad, isDir) = bad(path)
                    if isBad { return true }
                    if isDir { next.append(path) }
                }
            }
            level = next
        }
        return false
    }

    // MARK: Spotlight

    static let spotlightCheck = OptimizeTask(
        id: "spotlight.check",
        title: text("Spotlight-Index prüfen"),
        summary: text("Status des Index mit mdutil prüfen, nur bei Fehler oder ausgeschaltetem Index neu aufbauen."),
        impact: text("Falls neu aufgebaut wird: Spotlight findet für einige Stunden nicht alles und der Mac arbeitet im Hintergrund mehr."),
        needsAdmin: true, noticeable: true
    ) { ctx in
        // mdutil(1) -s prints "Indexing enabled." for a healthy volume.
        let status = ctx.command("/usr/bin/mdutil", ["-s", "/"], timeout: 30)
        if status.status == 0, status.output.localizedCaseInsensitiveContains("indexing enabled") {
            return .done(.unchanged(text("Spotlight-Index ist eingeschaltet")))
        }
        // -E erases the store; Spotlight rebuilds it.
        return .admin(AdminStep(command: "/usr/bin/mdutil -E /") { code, output in
            code == 0 ? .applied(text("Spotlight-Index wird neu aufgebaut")) : .failed(failure(text("Neuaufbau konnte nicht gestartet werden"), output))
        })
    }

    static let spotlightOrphans = OptimizeTask(
        id: "spotlight.orphans",
        title: text("Spotlight-Ausschlüsse entfernter Orte"),
        summary: text("Ausschlüsse in den Spotlight-Einstellungen finden, deren Ort nicht mehr existiert (nur Bericht)."),
        impact: text("Ändert nichts. Entfernen kannst du sie in Systemeinstellungen → Spotlight → Suchdatenschutz."),
        needsAdmin: true, noticeable: false
    ) { ctx in
        if let exclusions = spotlightExclusions(ctx.spotlightConfigs) {
            return .done(spotlightReport(exclusions, ctx))
        }
        // The volume configuration is readable by root only: read it in the admin step, change nothing.
        let tries = ctx.spotlightConfigs.map { path in
            let q = Uninstaller.quote(path)
            return "if [ -r \(q) ]; then /usr/bin/plutil -convert xml1 -o - \(q); exit $?; fi"
        }
        return .admin(AdminStep(command: "(" + tries.joined(separator: "; ") + "; exit 1)") { status, output in
            guard status == 0,
                  let plist = try? PropertyListSerialization.propertyList(from: Data(output.utf8), format: nil) as? [String: Any]
            else { return .unavailable(text("Spotlight-Einstellungen nicht lesbar")) }
            return spotlightReport(plist["Exclusions"] as? [String] ?? [], ctx)
        })
    }

    /// Exclusions whose place is gone; a place on a disk that is not connected does not count as gone.
    static func spotlightReport(_ exclusions: [String], _ ctx: OptimizeContext) -> OptimizeOutcome {
        let gone = exclusions.filter { path in
            guard path.hasPrefix("/") else { return false }
            let parts = path.split(separator: "/")
            if parts.first == "Volumes", parts.count > 1, !FileManager.default.fileExists(atPath: "/Volumes/" + parts[1]) { return false }
            return !FileManager.default.fileExists(atPath: path)
        }
        guard !gone.isEmpty else { return .unchanged(text("Alle Spotlight-Ausschlüsse sind vorhanden")) }
        return .attention(text("\(gone.count) Ausschlüsse ohne Ort: ") + gone.map(ctx.tilde).joined(separator: ", "))
    }

    /// `Exclusions` of the first readable volume configuration; nil when none can be read.
    static func spotlightExclusions(_ configs: [String]) -> [String]? {
        for path in configs {
            guard let data = FileManager.default.contents(atPath: path),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { continue }
            return plist["Exclusions"] as? [String] ?? []
        }
        return nil
    }

    // MARK: System maintenance

    /// periodic(8) and the last run of each period, from its output files; only due periods run.
    static let periodic = OptimizeTask(
        id: "system.periodic",
        title: text("Periodische macOS-Wartung"),
        summary: text("Tägliche, wöchentliche und monatliche Wartungsskripte ausführen."),
        impact: text("Rotiert alte Systemprotokolle und räumt temporäre Systemdateien auf."),
        needsAdmin: true, noticeable: false
    ) { ctx in
        guard FileManager.default.isExecutableFile(atPath: ctx.periodicTool) else {
            return .done(.unavailable(text("Gibt es seit macOS 26 nicht mehr, das System erledigt das selbst")))
        }
        let periods: [(String, TimeInterval)] = [("daily", 1), ("weekly", 7), ("monthly", 31)]
        let due = periods.filter { name, days in
            let attrs = try? FileManager.default.attributesOfItem(atPath: ctx.periodicLogs + "/\(name).out")
            guard let last = attrs?[.modificationDate] as? Date else { return true }
            return ctx.now.timeIntervalSince(last) > days * 86_400
        }.map(\.0)
        guard !due.isEmpty else { return .done(.unchanged(text("Wartung ist auf dem aktuellen Stand"))) }
        return .admin(AdminStep(command: ctx.periodicTool + " " + due.joined(separator: " ")) { status, output in
            status == 0 ? .applied(text("Wartungsskripte ausgeführt")) : .failed(failure(text("Fehlgeschlagen"), output))
        })
    }

    static let verifyVolume = OptimizeTask(
        id: "disk.verify",
        title: text("Startvolume prüfen"),
        summary: text("Dateisystem des Startvolumes auf Fehler prüfen (nur lesen)."),
        impact: text("Ändert nichts. Der Mac kann während der Prüfung für einige Sekunden langsamer reagieren."),
        needsAdmin: false, noticeable: false
    ) { ctx in
        // diskutil(8) verifyVolume only reads; it supports a live check of the boot volume.
        let r = ctx.command("/usr/sbin/diskutil", ["verifyVolume", "/"], timeout: 900)
        if r.status == 0 { return .done(.unchanged(text("Keine Fehler gefunden"))) }
        if r.status == -1 { return .done(.failed(text("Prüfung dauerte zu lange und wurde abgebrochen"))) }
        let lower = r.output.lowercased()
        if ["must be run as root", "permission denied", "not permitted", "ownership of the affected disk"].contains(where: lower.contains) {
            return .done(.unavailable(text("braucht Administratorrechte")))
        }
        return .done(.attention(text("Fehler gefunden: im Festplattendienstprogramm „Erste Hilfe“ ausführen")))
    }

    // MARK: Reports

    /// Asks System Events for the paths of the login items (System Settings → General → Login Items).
    static let loginItemScript = [
        "set out to \"\"",
        "tell application \"System Events\" to set itemPaths to path of every login item",
        "repeat with p in itemPaths",
        "set out to out & p & linefeed",
        "end repeat",
        "return out",
    ]

    static let loginItems = OptimizeTask(
        id: "login.audit",
        title: text("Anmeldeobjekte prüfen"),
        summary: text("Anmeldeobjekte suchen, deren Programm nicht mehr existiert (nur Bericht)."),
        impact: text("Ändert nichts, listet nur defekte Einträge. Entfernen kannst du sie im Bereich „Start“."),
        needsAdmin: false, noticeable: false
    ) { ctx in
        let r = ctx.command("/usr/bin/osascript", loginItemScript.flatMap { ["-e", $0] }, timeout: 30)
        guard r.status == 0 else {
            // -1743: the user has not allowed Swabr to control System Events.
            if r.output.contains("-1743") || r.output.localizedCaseInsensitiveContains("not authorized") {
                return .done(.skipped(text("Kein Zugriff auf System Events (Systemeinstellungen → Datenschutz & Sicherheit → Automation)")))
            }
            return .done(.failed(failure(text("System Events hat nicht geantwortet"), r.output)))
        }
        let missing = r.output.split(whereSeparator: \.isNewline).map(String.init)
            .filter { $0.hasPrefix("/") && !FileManager.default.fileExists(atPath: $0) }
        guard !missing.isEmpty else { return .done(.unchanged(text("Alle Anmeldeobjekte sind vorhanden"))) }
        return .done(.attention(text("Programm fehlt: \(missing.map { ($0 as NSString).lastPathComponent }.joined(separator: ", "))")))
    }

    static let orphanedAgents = OptimizeTask(
        id: "agents.orphans",
        title: text("Verwaiste Hintergrunddienste finden"),
        summary: text("LaunchAgents, deren Programm nicht mehr existiert (nur Bericht)."),
        impact: text("Ändert nichts. Gefundene Einträge kannst du im Finder prüfen und entfernen."),
        needsAdmin: false, noticeable: false
    ) { ctx in
        let own = ctx.home + "/Library/LaunchAgents"
        if case .denied(let why) = listing(own, ctx: ctx) { return .done(.unavailable(why)) }
        let launchctl: StartupItems.Runner = { args in
            let r = ctx.command("/bin/launchctl", args, timeout: 15)
            return r.status == -1 ? nil : r
        }
        let items = StartupItems.list(sources: [(own, .userAgent)] + ctx.systemLaunchFolders,
                                      protection: try? RuleStore.protection(), uid: ctx.uid, run: launchctl)
        let broken = items.filter(\.isBroken)
        guard !broken.isEmpty else { return .done(.unchanged(text("Alle Hintergrunddienste zeigen auf vorhandene Programme"))) }
        return .done(.attention(text("\(broken.count) mit fehlendem Programm: ") + broken.map(\.label).joined(separator: ", ")))
    }

    // MARK: Databases

    /// Gatekeeper's record of downloaded files (Launch Services quarantine events).
    static let quarantineHistory = OptimizeTask(
        id: "quarantine.history",
        title: text("Download-Verlauf von Gatekeeper leeren"),
        summary: text("Liste aller jemals heruntergeladenen Dateien (Quarantäne-Datenbank)."),
        impact: text("Datenschutz: macOS vergisst, welche Dateien woher geladen wurden. Bereits geprüfte Apps bleiben freigegeben."),
        needsAdmin: false, noticeable: false
    ) { ctx in
        let path = ctx.home + "/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2"
        if case .denied(let why) = listing(ctx.home + "/Library/Preferences", ctx: ctx) { return .done(.unavailable(why)) }
        guard FileManager.default.fileExists(atPath: path) else { return .done(.unchanged(text("Kein Download-Verlauf vorhanden"))) }
        let db: SQLiteDatabase
        switch SQLiteDatabase.open(path, timeoutMs: ctx.busyTimeout) {
        case .success(let opened): db = opened
        case .failure(let f): return .done(databaseFailure(f))
        }
        let before = SQLiteMaintenance.footprint(path)
        let deleted: Int64
        do throws(SQLiteDatabase.Failure) {
            guard try db.integer("SELECT count(*) FROM LSQuarantineEvent") > 0 else {
                return .done(.unchanged(text("Download-Verlauf ist leer")))
            }
            try db.execute("DELETE FROM LSQuarantineEvent")
            deleted = db.changes
            try db.execute("VACUUM")
        } catch {
            return .done(databaseFailure(error))
        }
        db.close()
        ctx.log.record(action: "REMOVE", path: path, bytes: max(0, before - SQLiteMaintenance.footprint(path)),
                       label: "Optimieren: Download-Verlauf")
        return .done(.applied(text("\(Int(deleted)) Einträge gelöscht")))
    }

    static func databaseFailure(_ f: SQLiteDatabase.Failure) -> OptimizeOutcome {
        switch f {
        case .locked: .skipped(text("Datenbank war gesperrt"))
        case .damaged: .attention(text("\(text("Datenbank")) beschädigt, nicht angefasst"))
        case .unreadable: .unavailable(text("Datenbank nicht lesbar (Festplattenvollzugriff?)"))
        case .other(let m): .failed(failure(text("Fehlgeschlagen"), m))
        }
    }

    /// Delivered notifications live in usernoted's database: under `getconf DARWIN_USER_DIR` up to
    /// macOS 14, in its group container since. `delivered_date` counts seconds since 2001-01-01.
    static func notificationDatabase(_ ctx: OptimizeContext) -> String? {
        var candidates = [ctx.home + "/Library/Group Containers/group.com.apple.usernoted/db2/db"]
        let dir = ctx.command("/usr/bin/getconf", ["DARWIN_USER_DIR"], timeout: 10)
        let userDir = dir.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if dir.status == 0, userDir.hasPrefix("/") {
            candidates.append((userDir.hasSuffix("/") ? userDir : userDir + "/") + "com.apple.notificationcenter/db2/db")
        }
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    static let oldNotifications = OptimizeTask(
        id: "notifications.old",
        title: text("Alte Mitteilungen aufräumen"),
        summary: text("Zugestellte Mitteilungen, die älter als 30 Tage sind."),
        impact: text("Ältere Einträge verschwinden aus der Mitteilungszentrale. Die Mitteilungsanzeige startet kurz neu."),
        needsAdmin: false, noticeable: false
    ) { ctx in
        guard let path = notificationDatabase(ctx) else { return .done(.unavailable(text("Mitteilungs-Datenbank nicht gefunden"))) }
        let cutoff = ctx.now.addingTimeInterval(-days30).timeIntervalSinceReferenceDate
        let old = "FROM record WHERE delivered_date IS NOT NULL AND delivered_date < \(cutoff)"

        // Check a copy first: it tells whether there is anything to do without touching usernoted's file.
        switch countOnCopy(path, query: "SELECT count(*) " + old, ctx: ctx) {
        case .failure(let f): return .done(databaseFailure(f))
        case .success(0): return .done(.unchanged(text("Keine alten Mitteilungen")))
        case .success: break
        }
        let db: SQLiteDatabase
        switch SQLiteDatabase.open(path, timeoutMs: ctx.busyTimeout) {
        case .success(let opened): db = opened
        case .failure(let f): return .done(databaseFailure(f))
        }
        let deleted: Int64
        do throws(SQLiteDatabase.Failure) {
            // IMMEDIATE takes the write lock up front, so a busy usernoted is detected before anything changes.
            try db.execute("BEGIN IMMEDIATE")
            try db.execute("DELETE " + old)
            deleted = db.changes
            try db.execute("COMMIT")
        } catch {
            try? db.execute("ROLLBACK")
            return .done(databaseFailure(error))
        }
        db.close()
        ctx.log.record(action: "REMOVE", path: path, bytes: 0, label: "Optimieren: Mitteilungen")
        // usernoted reads the database again when launchd restarts it.
        _ = ctx.command("/usr/bin/killall", ["usernoted"], timeout: 10)
        return .done(.applied(text("\(Int(deleted)) alte Einträge gelöscht")))
    }

    /// Copies the database with its log into a temporary folder, checks it and runs a count there.
    static func countOnCopy(_ path: String, query: String, ctx: OptimizeContext) -> Result<Int64, SQLiteDatabase.Failure> {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appending(path: "swabr-db-\(UUID().uuidString)").path
        defer { try? fm.removeItem(atPath: dir) }
        do {
            try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
            for suffix in ["", "-wal", "-shm"] where fm.fileExists(atPath: path + suffix) {
                try fm.copyItem(atPath: path + suffix, toPath: dir + "/db" + suffix)
            }
        } catch {
            return .failure(.unreadable(error.localizedDescription))
        }
        switch SQLiteDatabase.open(dir + "/db", timeoutMs: ctx.busyTimeout) {
        case .failure(let f): return .failure(f)
        case .success(let copy):
            do {
                guard try copy.isIntact() else { return .failure(.damaged("integrity_check")) }
                return .success(try copy.integer(query))
            } catch {
                return .failure(error)
            }
        }
    }

    /// The databases of Mail, Safari and Messages with the names their apps run under.
    static func appDatabases(home: String) -> [(app: String, names: [String], bundleID: String, paths: [String])] {
        let mail = PathGlob.expand("~/Library/Mail/V*/MailData/Envelope Index", home: home)
        let safari = [home + "/Library/Safari/History.db", home + "/Library/Containers/com.apple.Safari/Data/Library/Safari/History.db"]
        return [
            ("Mail", ["Mail"], "com.apple.mail", mail),
            ("Safari", ["Safari"], "com.apple.Safari", safari),
            (text("Nachrichten"), ["Messages", "Nachrichten"], "com.apple.MobileSMS", [home + "/Library/Messages/chat.db"]),
        ]
    }

    static let compactDatabases = OptimizeTask(
        id: "sqlite.compact",
        title: text("Mail-, Safari- und Nachrichten-Datenbanken komprimieren"),
        summary: text("Leerraum in den Datenbanken freigeben (nur wenn die Apps geschlossen sind)."),
        impact: text("Ändert keine Inhalte. Beschädigte oder über 100 MB große Datenbanken bleiben unberührt."),
        needsAdmin: false, noticeable: false
    ) { ctx in
        var compacted = 0
        var saved: Int64 = 0
        var found = 0
        var serious: [String] = []
        var held: [String] = []
        for db in appDatabases(home: ctx.home) {
            let present = db.paths.filter { FileManager.default.fileExists(atPath: $0) }
            guard !present.isEmpty else { continue }
            found += present.count
            if ctx.isRunning(bundleID: db.bundleID, names: db.names) {
                held.append(text("\(db.app) läuft"))
                continue
            }
            for path in present {
                switch SQLiteMaintenance.compact(path, sizeLimit: ctx.databaseSizeLimit, timeoutMs: ctx.busyTimeout) {
                case .compacted(let bytes):
                    compacted += 1
                    saved += bytes
                case .alreadyCompact, .missing: break
                case .tooLarge: serious.append(text("\(db.app) zu groß (> 100 MB)"))
                case .damaged: serious.append(text("\(db.app) beschädigt, nicht angefasst"))
                case .locked: held.append(text("\(db.app) gesperrt"))
                case .unreadable: serious.append(db.app + ": " + text("Datenbank nicht lesbar (Festplattenvollzugriff?)"))
                }
            }
        }
        let done = compacted > 0 ? text("\(compacted) Datenbanken komprimiert, \(DiskSize.format(saved)) frei") : nil
        let parts = ([done] + (serious + held).map(Optional.some)).compactMap { $0 }.joined(separator: " · ")
        if !serious.isEmpty { return .done(.attention(parts)) }
        if compacted > 0 { return .done(.applied(parts)) }
        if !held.isEmpty { return .done(.skipped(parts)) }
        return .done(.unchanged(found == 0 ? text("Keine Datenbanken gefunden") : text("Alle Datenbanken sind bereits kompakt")))
    }

    // MARK: Helpers

    enum Listing {
        case names([String])
        case missing
        /// Not readable, e.g. outside the folders granted to the sandbox.
        case denied(String)
    }

    static func listing(_ folder: String, ctx: OptimizeContext) -> Listing {
        do {
            return .names(try FileManager.default.contentsOfDirectory(atPath: folder))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return .missing
        } catch {
            if !FileManager.default.fileExists(atPath: folder) { return .missing }
            return .denied(text("Kein Zugriff auf \(ctx.tilde(folder))"))
        }
    }

    struct TrashReport {
        var moved = 0
        var problems: [String] = []
        var failureText: String { problems.joined(separator: "; ") }
    }

    /// Each file is checked against the path rules right before it goes to the Trash.
    static func moveToTrash(_ paths: [String], label: String, ctx: OptimizeContext) -> TrashReport {
        var report = TrashReport()
        for path in paths {
            let name = (path as NSString).lastPathComponent
            if case .refused(let why) = PathSafety.check(path, home: ctx.home) {
                report.problems.append(name + ": " + why)
                continue
            }
            let bytes = DiskSize.allocatedSize(of: path)
            if let why = ctx.trash(path) {
                report.problems.append(name + ": " + why)
            } else {
                report.moved += 1
                ctx.log.record(action: "TRASH", path: path, bytes: bytes, label: label)
            }
        }
        return report
    }
}
