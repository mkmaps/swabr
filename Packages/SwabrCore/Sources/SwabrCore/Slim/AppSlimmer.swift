import Darwin
import Foundation
import Security

/// A universal app whose Intel code can go.
public struct SlimCandidate: Identifiable, Sendable, Hashable {
    public let app: InstalledApp
    /// Team identifier of the signature; empty for an ad-hoc signature.
    public let team: String
    /// Binary path relative to the bundle → bytes of its x86_64 slice.
    public let plan: [String: Int64]

    public var intelBytes: Int64 { plan.values.reduce(0, +) }
    public var id: String { app.id }

    public init(app: InstalledApp, team: String, plan: [String: Int64]) {
        self.app = app
        self.team = team
        self.plan = plan
    }
}

/// An app that is left as it is, and why.
public struct SlimSkip: Identifiable, Sendable, Hashable {
    public let app: InstalledApp
    public let reason: String

    public var id: String { app.id }

    public init(app: InstalledApp, reason: String) {
        self.app = app
        self.reason = reason
    }
}

/// Removes the x86_64 code from universal apps on Apple silicon. All work happens on a clone of the bundle;
/// the original is only replaced (and kept in the Trash) once the clone verifies and launches.
public enum AppSlimmer {
    public struct Outcome: Sendable, Hashable {
        public let ok: Bool
        public let message: String

        public init(ok: Bool, message: String) {
            self.ok = ok
            self.message = message
        }
    }

    /// Below this saving an app is not worth the risk.
    static let minimumSavings: Int64 = 1_000_000

    public static var isAppleSilicon: Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("hw.optional.arm64", &value, &size, nil, 0) == 0 && value == 1
    }

    // MARK: Outside world

    /// Everything that reaches beyond the bundle being examined; tests replace the parts that would launch
    /// apps, use the real Trash or depend on notarization.
    struct Environment: Sendable {
        var appleSilicon: @Sendable () -> Bool
        /// Executable paths of the running processes.
        var runningExecutables: @Sendable () -> [String]
        /// `codesign --verify --deep --strict` passes.
        var verify: @Sendable (String) -> Bool
        var isNotarized: @Sendable (String) -> Bool
        /// Ad-hoc signature over the whole bundle.
        var resign: @Sendable (String) -> Bool
        /// Starts the bundle, checks it stays up, then ends it again.
        var launchProbe: @Sendable (String) -> Bool
        /// Moves the item to the Trash and returns where it went.
        var trash: @Sendable (URL) throws -> URL
        /// A fresh empty folder on the volume of the given path.
        var workFolder: @Sendable (String) -> String?
        /// lipo, or nil to cut the slice out directly.
        var lipo: String?
        /// Root step for apps the user may not replace (they belong to root); nil skips those apps.
        var runPrivileged: RootRunner? = nil

        static let live = Environment(
            appleSilicon: { AppSlimmer.isAppleSilicon },
            runningExecutables: { AppSlimmer.runningExecutables() },
            verify: { Shell.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", $0], timeout: 600).status == 0 },
            isNotarized: { AppSlimmer.isNotarized($0) },
            resign: { AppSlimmer.adHocSign($0) },
            launchProbe: { AppSlimmer.launchProbe($0) },
            trash: { url in
                var result: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &result)
                guard let result else { throw CocoaError(.fileWriteUnknown) }
                return result as URL
            },
            workFolder: { AppSlimmer.workFolder(near: $0) },
            lipo: AppSlimmer.installedLipo())
    }

    // MARK: Scan

    /// `home` is part of the caller's interface; the checks here only look at the bundles themselves.
    public static func scan(_ apps: [InstalledApp], home: String = UserHome.path,
                            runPrivileged: RootRunner? = nil) async
        -> (candidates: [SlimCandidate], skipped: [SlimSkip]) {
        var env = Environment.live
        env.runPrivileged = runPrivileged
        return await scan(apps, home: home, env: env)
    }

    static func scan(_ apps: [InstalledApp], home: String, env: Environment) async
        -> (candidates: [SlimCandidate], skipped: [SlimSkip]) {
        guard env.appleSilicon() else { return ([], []) }
        let running = env.runningExecutables()
        var candidates: [SlimCandidate] = []
        var skipped: [SlimSkip] = []
        // codesign runs per app; a few at a time, each on a thread of its own.
        var index = 0
        while index < apps.count {
            let batch = apps[index..<min(index + 4, apps.count)]
            index += batch.count
            await withTaskGroup(of: Result<SlimCandidate, SkipReason>.self) { group in
                for app in batch {
                    group.addTask { await onOwnThread { evaluate(app, running: running, env: env) } }
                }
                for await result in group {
                    switch result {
                    case .success(let c): candidates.append(c)
                    case .failure(let s): skipped.append(SlimSkip(app: s.app, reason: s.reason))
                    }
                }
            }
        }
        candidates.sort { $0.intelBytes > $1.intelBytes }
        skipped.sort { $0.app.name.localizedStandardCompare($1.app.name) == .orderedAscending }
        return (candidates, skipped)
    }

    struct SkipReason: Error {
        let app: InstalledApp
        let reason: String
    }

    /// Cheap checks first; signature checks only for apps that would actually be slimmed.
    static func evaluate(_ app: InstalledApp, running: [String], env: Environment) -> Result<SlimCandidate, SkipReason> {
        func skip(_ reason: String) -> Result<SlimCandidate, SkipReason> { .failure(SkipReason(app: app, reason: reason)) }
        // Changing the binaries invalidates the store receipt's signature check.
        if app.fromAppStore || app.isIOSApp || AppBundle.isFromAppStore(app.path) {
            return skip(String(localized: "aus dem App Store", bundle: .module))
        }
        if AppBundle.isSystemProtected(app.path) {
            return skip(String(localized: "Systemkomponente von macOS", bundle: .module))
        }
        if app.bundleID.lowercased().hasPrefix("com.apple.") {
            return skip(String(localized: "Apple-App", bundle: .module))
        }
        // An app that belongs to root can still be slimmed when the swap may run as root.
        if (app.needsAdmin || !AppCatalog.canMove(app.path)) && env.runPrivileged == nil {
            return skip(String(localized: "braucht Administratorrechte", bundle: .module))
        }
        if isRunning(app.path, executables: running) {
            return skip(String(localized: "läuft gerade", bundle: .module))
        }
        guard let main = mainExecutable(app.path), hasArm64(main) else {
            return skip(String(localized: "Hauptprogramm enthält keinen Apple-Silicon-Code", bundle: .module))
        }
        let plan = plan(for: app.path)
        guard plan.values.reduce(0, +) >= minimumSavings else {
            return skip(String(localized: "enthält keinen entfernbaren Intel-Code", bundle: .module))
        }
        guard env.verify(app.path), let signing = signingInfo(app.path) else {
            return skip(String(localized: "Code-Signatur ist bereits ungültig", bundle: .module))
        }
        // Only an app that is not notarized may ever be re-signed, and an ad-hoc signature would drop
        // these exceptions; for notarized apps the slim aborts instead of re-signing.
        if signing.runtimeExceptions, !env.isNotarized(app.path) {
            return skip(String(localized: "nutzt Ausnahmen der Hardened Runtime, die beim Neusignieren verloren gingen", bundle: .module))
        }
        return .success(SlimCandidate(app: app, team: signing.team ?? "", plan: plan))
    }

    // MARK: Slim

    public static func slim(_ c: SlimCandidate, home: String = UserHome.path, log: OperationLog = OperationLog(),
                            runPrivileged: RootRunner? = nil) -> Outcome {
        var env = Environment.live
        env.runPrivileged = runPrivileged
        return slim(c, home: home, log: log, env: env)
    }

    static func slim(_ c: SlimCandidate, home: String, log: OperationLog, env: Environment) -> Outcome {
        func fail(_ message: String) -> Outcome { Outcome(ok: false, message: message) }
        let app = c.app
        let fm = FileManager.default
        guard env.appleSilicon() else { return fail(String(localized: "Nur auf Apple-Silicon-Macs möglich", bundle: .module)) }
        guard !c.plan.isEmpty, c.plan.keys.allSatisfy(isSafeRelativePath) else {
            return fail(String(localized: "enthält keinen entfernbaren Intel-Code", bundle: .module))
        }
        if isRunning(app.path, executables: env.runningExecutables()) {
            return fail(String(localized: "\(app.name) läuft", bundle: .module))
        }

        // 1. Clone on the same volume: instant and without extra space.
        guard let work = env.workFolder(app.path), sameVolume(work, app.path) else {
            return fail(String(localized: "Kein temporärer Ordner auf demselben Volume", bundle: .module))
        }
        defer { try? fm.removeItem(atPath: work) }
        let copy = work + "/" + (app.path as NSString).lastPathComponent
        guard clonefile(app.path, copy, 0) == 0 else {
            return fail(String(localized: "Kopieren fehlgeschlagen", bundle: .module))
        }

        // 2. Thin each planned binary in the clone.
        var saved: Int64 = 0
        for rel in c.plan.keys.sorted() {
            let file = copy + "/" + rel
            guard !isSymlink(file), removableIntelBytes(file) != nil else {
                return fail(String(localized: "nicht mehr vorhanden oder verändert", bundle: .module))
            }
            let before = fileSize(file)
            guard removeIntel(file, lipo: env.lipo) else {
                return fail(String(localized: "Intel-Code ließ sich aus \((rel as NSString).lastPathComponent) nicht entfernen", bundle: .module))
            }
            saved += max(0, before - fileSize(file))
        }
        guard let main = mainExecutable(copy), hasArm64(main) else {
            return fail(String(localized: "Hauptprogramm enthält keinen Apple-Silicon-Code", bundle: .module))
        }

        // 3. Signature. A notarized app is never re-signed: the ad-hoc signature would replace its developer's.
        var resigned = false
        if !env.verify(copy) {
            if env.isNotarized(app.path) {
                return fail(String(localized: "Notarisierte App wäre danach nicht mehr gültig signiert, nichts verändert", bundle: .module))
            }
            if signingInfo(app.path)?.runtimeExceptions ?? true {
                return fail(String(localized: "nutzt Ausnahmen der Hardened Runtime, die beim Neusignieren verloren gingen", bundle: .module))
            }
            guard env.resign(copy), env.verify(copy) else {
                return fail(String(localized: "Code-Signatur-Prüfung fehlgeschlagen", bundle: .module))
            }
            resigned = true
        }
        if !resigned, (signingInfo(copy)?.team ?? "") != c.team {
            return fail(String(localized: "Entwickler-Signatur hat sich geändert", bundle: .module))
        }

        // 4. The clone must start and stay up.
        guard env.launchProbe(copy) else {
            return fail(String(localized: "Verschlankte Kopie ließ sich nicht starten, nichts verändert", bundle: .module))
        }
        if isRunning(app.path, executables: env.runningExecutables()) {
            return fail(String(localized: "\(app.name) läuft", bundle: .module))
        }

        // 5. Swap: original to the Trash, clone into its place. An app the user may not move swaps as root.
        if !AppCatalog.canMove(app.path) {
            guard let runPrivileged = env.runPrivileged else {
                return fail(String(localized: "braucht Administratorrechte", bundle: .module))
            }
            return rootSwap(app: app, copy: copy, home: home, saved: saved, log: log, runPrivileged: runPrivileged)
        }
        let trashed: URL
        do { trashed = try env.trash(URL(fileURLWithPath: app.path)) } catch {
            return fail(String(localized: "Original ließ sich nicht in den Papierkorb legen", bundle: .module))
        }
        do {
            try fm.moveItem(atPath: copy, toPath: app.path)
        } catch {
            if (try? fm.moveItem(at: trashed, to: URL(fileURLWithPath: app.path))) != nil {
                return fail(String(localized: "Kopieren fehlgeschlagen", bundle: .module))
            }
            return fail(String(localized: "Das Original liegt im Papierkorb. Bitte nach \(app.path) zurücklegen.", bundle: .module))
        }
        log.record(action: "TRASH", path: app.path, bytes: saved, label: "Verschlanken: \(app.name)")
        return Outcome(ok: true, message: String(localized: "\(DiskSize.format(saved)) Intel-Code entfernt", bundle: .module))
    }

    /// The swap as one root step: the original into the user's Trash (checked by the helper), the slimmed copy into
    /// its place with the original's owner, and the original put back if the copy cannot be moved.
    static func rootSwap(app: InstalledApp, copy: String, home: String, saved: Int64, log: OperationLog,
                         runPrivileged: RootRunner) -> Outcome {
        var st = stat()
        guard lstat(app.path, &st) == 0, !PathSafety.hasControlCharacters(copy) else {
            return Outcome(ok: false, message: String(localized: "nicht mehr vorhanden oder verändert", bundle: .module))
        }
        let trash = "\(home)/.Trash/\((app.path as NSString).lastPathComponent) \(Int(Date().timeIntervalSince1970))"
        _ = runPrivileged([.replaceApp(original: app.path, replacement: copy, trash: trash)])
        let fm = FileManager.default
        if fm.fileExists(atPath: app.path), !fm.fileExists(atPath: copy) {
            log.record(action: "TRASH", path: app.path, bytes: saved, label: "Verschlanken: \(app.name)")
            return Outcome(ok: true, message: String(localized: "\(DiskSize.format(saved)) Intel-Code entfernt", bundle: .module))
        }
        if fm.fileExists(atPath: app.path) {
            return Outcome(ok: false, message: String(localized: "Original ließ sich nicht in den Papierkorb legen", bundle: .module))
        }
        return Outcome(ok: false, message: String(localized: "Das Original liegt im Papierkorb. Bitte nach \(app.path) zurücklegen.", bundle: .module))
    }

    // MARK: Mach-O

    /// One architecture entry of a fat header (<mach-o/fat.h>).
    struct Slice: Equatable {
        let cpuType: UInt32
        /// Capability bits (high byte) already masked off.
        let cpuSubtype: UInt32
        let offset: UInt64
        let size: UInt64
    }

    // Values from <mach-o/fat.h>, <mach-o/loader.h> and <mach/machine.h>.
    static let fatMagic: UInt32 = 0xCAFE_BABE
    static let fatMagic64: UInt32 = 0xCAFE_BABF
    static let machMagic64: UInt32 = 0xFEED_FACF
    static let cpuX86_64: UInt32 = 0x0100_0007
    static let cpuARM64: UInt32 = 0x0100_000C
    static let subtypeX86_64All: UInt32 = 3
    /// arm64 proper; arm64e (2) is a different ABI and not counted.
    static let subtypesARM64: Set<UInt32> = [0, 1]

    /// The fat header's entries, or nil when the file is no fat Mach-O. Java class files share the magic,
    /// so every entry must lie inside the file.
    static func slices(_ path: String) -> [Slice]? {
        guard let fd = openForReading(path) else { return nil }
        defer { close(fd) }
        var st = stat()
        guard fstat(fd, &st) == 0, (st.st_mode & S_IFMT) == S_IFREG, let head = read(fd, at: 0, count: 8) else { return nil }
        let magic = bigEndian32(head, 0)
        guard magic == fatMagic || magic == fatMagic64 else { return nil }
        let count = Int(bigEndian32(head, 4))
        guard (1...32).contains(count) else { return nil }
        let wide = magic == fatMagic64
        let entrySize = wide ? 32 : 20
        guard let table = read(fd, at: 8, count: count * entrySize) else { return nil }
        var out: [Slice] = []
        for i in 0..<count {
            let b = i * entrySize
            let offset = wide ? bigEndian64(table, b + 8) : UInt64(bigEndian32(table, b + 8))
            let size = wide ? bigEndian64(table, b + 16) : UInt64(bigEndian32(table, b + 12))
            guard size > 0, offset >= UInt64(8 + count * entrySize), offset + size <= UInt64(st.st_size) else { return nil }
            out.append(Slice(cpuType: bigEndian32(table, b), cpuSubtype: bigEndian32(table, b + 4) & 0x00FF_FFFF,
                             offset: offset, size: size))
        }
        return out
    }

    /// Size of the x86_64 slice when the file is fat with both x86_64 and a real arm64 Mach-O slice; else nil.
    static func removableIntelBytes(_ path: String) -> Int64? {
        guard let all = slices(path),
              let intel = all.first(where: { $0.cpuType == cpuX86_64 && $0.cpuSubtype == subtypeX86_64All }),
              let arm = armSlice(all), startsWithMachHeader(path, at: arm.offset) else { return nil }
        return Int64(intel.size)
    }

    static func armSlice(_ all: [Slice]) -> Slice? {
        all.first { $0.cpuType == cpuARM64 && subtypesARM64.contains($0.cpuSubtype) }
    }

    /// Thin arm64, or fat with an arm64 slice.
    static func hasArm64(_ path: String) -> Bool {
        if let all = slices(path) { return armSlice(all) != nil }
        guard let fd = openForReading(path) else { return false }
        defer { close(fd) }
        guard let h = read(fd, at: 0, count: 12), littleEndian32(h, 0) == machMagic64 else { return false }
        return littleEndian32(h, 4) == cpuARM64 && subtypesARM64.contains(littleEndian32(h, 8) & 0x00FF_FFFF)
    }

    static func startsWithMachHeader(_ path: String, at offset: UInt64) -> Bool {
        guard let fd = openForReading(path) else { return false }
        defer { close(fd) }
        guard let h = read(fd, at: off_t(offset), count: 4) else { return false }
        return littleEndian32(h, 0) == machMagic64
    }

    /// Replaces the file by a version without its x86_64 slice: `lipo -remove x86_64` when lipo is available,
    /// otherwise the arm64 slice is cut out as a thin file (what `lipo -thin arm64` writes).
    static func removeIntel(_ path: String, lipo: String?) -> Bool {
        let tmp = path + ".slim-\(UUID().uuidString.prefix(8))"
        defer { unlink(tmp) }
        if let lipo {
            guard Shell.run(lipo, [path, "-remove", "x86_64", "-output", tmp], timeout: 120).status == 0 else { return false }
        } else {
            guard let all = slices(path), let arm = armSlice(all), extract(arm, from: path, to: tmp) else { return false }
        }
        guard hasArm64(tmp), removableIntelBytes(tmp) == nil,
              slices(tmp)?.contains(where: { $0.cpuType == cpuX86_64 && $0.cpuSubtype == subtypeX86_64All }) != true
        else { return false }
        var st = stat()
        guard stat(path, &st) == 0, chmod(tmp, st.st_mode & 0o7777) == 0 else { return false }
        return rename(tmp, path) == 0
    }

    static func extract(_ slice: Slice, from path: String, to dest: String) -> Bool {
        guard let fd = openForReading(path) else { return false }
        defer { close(fd) }
        guard let data = read(fd, at: off_t(slice.offset), count: Int(slice.size)) else { return false }
        return FileManager.default.createFile(atPath: dest, contents: Data(data))
    }

    private static func openForReading(_ path: String) -> Int32? {
        let fd = open(path, O_RDONLY | O_NOFOLLOW)
        return fd >= 0 ? fd : nil
    }

    private static func read(_ fd: Int32, at offset: off_t, count: Int) -> [UInt8]? {
        var buffer = [UInt8](repeating: 0, count: count)
        let got = buffer.withUnsafeMutableBytes { pread(fd, $0.baseAddress, count, offset) }
        return got == count ? buffer : nil
    }

    private static func bigEndian32(_ b: [UInt8], _ i: Int) -> UInt32 {
        UInt32(b[i]) << 24 | UInt32(b[i + 1]) << 16 | UInt32(b[i + 2]) << 8 | UInt32(b[i + 3])
    }

    private static func bigEndian64(_ b: [UInt8], _ i: Int) -> UInt64 {
        UInt64(bigEndian32(b, i)) << 32 | UInt64(bigEndian32(b, i + 4))
    }

    private static func littleEndian32(_ b: [UInt8], _ i: Int) -> UInt32 {
        UInt32(b[i]) | UInt32(b[i + 1]) << 8 | UInt32(b[i + 2]) << 16 | UInt32(b[i + 3]) << 24
    }

    // MARK: Plan

    /// Every fat binary in the bundle with removable Intel code, found by its header. Binaries that a bundle's
    /// seal tracks by content hash are left out: changing them would break the developer's signature.
    static func plan(for bundle: String) -> [String: Int64] {
        var out: [String: Int64] = [:]
        var seals: [String: [String: Any]] = [:]
        let root = URL(fileURLWithPath: bundle)
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys) else { return [:] }
        for case let url as URL in walker {
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true,
                  (values.fileSize ?? 0) >= 4096 else { continue }
            let path = url.path
            guard let bytes = removableIntelBytes(path), !sealedByHash(path, bundle: bundle, cache: &seals) else { continue }
            out[String(path.dropFirst(bundle.count + 1))] = bytes
        }
        return out
    }

    /// True when the nearest enclosing seal (`_CodeSignature/CodeResources`) lists the file as a plain
    /// resource (`hash2`) rather than as nested code (`cdhash`) or not at all (the bundle's own executable).
    static func sealedByHash(_ path: String, bundle: String, cache: inout [String: [String: Any]]) -> Bool {
        var dir = (path as NSString).deletingLastPathComponent
        while dir.count >= bundle.count {
            let seal = dir + "/_CodeSignature/CodeResources"
            if FileManager.default.fileExists(atPath: seal) {
                if cache[dir] == nil { cache[dir] = sealedFiles(seal) }
                let entry = cache[dir]?[String(path.dropFirst(dir.count + 1))]
                if let entry = entry as? [String: Any] { return entry["cdhash"] == nil }
                return entry is Data
            }
            let parent = (dir as NSString).deletingLastPathComponent
            if parent == dir { break }
            dir = parent
        }
        return false
    }

    /// The `files2` table of a CodeResources file.
    static func sealedFiles(_ path: String) -> [String: Any] {
        guard let data = FileManager.default.contents(atPath: path),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [:] }
        return plist["files2"] as? [String: Any] ?? [:]
    }

    static func mainExecutable(_ bundle: String) -> String? {
        guard let name = AppBundle.info(bundle)["CFBundleExecutable"] as? String, !name.isEmpty, !name.contains("/") else { return nil }
        return bundle + "/Contents/MacOS/" + name
    }

    static func isSafeRelativePath(_ rel: String) -> Bool {
        !rel.isEmpty && !rel.hasPrefix("/") && !rel.split(separator: "/").contains("..")
    }

    // MARK: Signature

    struct SigningInfo {
        let team: String?
        /// Holds a `com.apple.security.cs.*` entitlement (JIT, unsigned memory, library validation off …).
        let runtimeExceptions: Bool
    }

    /// Team and entitlements of the bundle's signature (the same facts `codesign -dv --entitlements -` prints).
    static func signingInfo(_ path: String) -> SigningInfo? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &code) == errSecSuccess, let code else { return nil }
        var dict: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &dict) == errSecSuccess,
              let info = dict as? [String: Any] else { return nil }
        let entitlements = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any] ?? [:]
        let exceptions = entitlements.contains { key, value in
            key.hasPrefix("com.apple.security.cs.") && (value as? Bool ?? true)
        }
        return SigningInfo(team: info[kSecCodeInfoTeamIdentifier as String] as? String, runtimeExceptions: exceptions)
    }

    /// Notarized unless shown otherwise: a stapled ticket (stapler writes it to `Contents/CodeResources`) or
    /// Gatekeeper naming a notarized/App Store/Apple source counts as yes; only a finished assessment without
    /// any of these counts as no. `stapler` itself is left out because it needs the developer tools.
    static func isNotarized(_ path: String) -> Bool {
        if FileManager.default.fileExists(atPath: path + "/Contents/CodeResources") { return true }
        let r = Shell.run("/usr/sbin/spctl", ["--assess", "-vv", "--type", "execute", path], timeout: 60)
        guard r.status >= 0 else { return true }
        return ["source=Notarized", "source=Mac App Store", "source=Apple"].contains { r.output.contains($0) }
    }

    static func adHocSign(_ path: String) -> Bool {
        Shell.run("/usr/bin/codesign", ["--force", "--deep", "--sign", "-", "--preserve-metadata=entitlements", path],
                  timeout: 600).status == 0
    }

    /// /usr/bin/lipo is a stub that asks to install the developer tools when they are missing.
    static func installedLipo() -> String? {
        Shell.run("/usr/bin/xcode-select", ["-p"], timeout: 10).status == 0 ? "/usr/bin/lipo" : nil
    }

    // MARK: Processes

    /// Every process this user may inspect, with its executable path.
    static func processList() -> [(pid: pid_t, path: String)] {
        let all = UInt32(PROC_ALL_PIDS)
        let needed = proc_listpids(all, 0, nil, 0)
        guard needed > 0 else { return [] }
        // Some room for processes started between the two calls.
        var pids = [pid_t](repeating: 0, count: Int(needed) / MemoryLayout<pid_t>.stride + 64)
        let filled = pids.withUnsafeMutableBytes { proc_listpids(all, 0, $0.baseAddress, Int32($0.count)) }
        guard filled > 0 else { return [] }
        return pids.prefix(Int(filled) / MemoryLayout<pid_t>.stride).compactMap { pid in
            guard pid > 0 else { return nil }
            var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
            guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
            return (pid, String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self))
        }
    }

    static func runningExecutables() -> [String] { processList().map(\.path) }

    static func isRunning(_ bundle: String, executables: [String]) -> Bool {
        executables.contains { $0.hasPrefix(bundle + "/") }
    }

    /// Processes started from the bundle; a quarantined copy may run translocated, so that location
    /// is matched by bundle name and executable.
    static func processes(of bundle: String) -> [pid_t] {
        let name = (bundle as NSString).lastPathComponent
        let exe = mainExecutable(bundle).map { "/" + name + "/Contents/MacOS/" + ($0 as NSString).lastPathComponent }
        return processList().filter { p in
            p.path.hasPrefix(bundle + "/") || (exe.map { p.path.contains("/AppTranslocation/") && p.path.hasSuffix($0) } ?? false)
        }.map(\.pid)
    }

    /// `open -g -j -n` (background, hidden, new instance); the app must still run after 5 s. It is ended either way.
    static func launchProbe(_ bundle: String) -> Bool {
        guard Shell.run("/usr/bin/open", ["-g", "-j", "-n", bundle], timeout: 30).status == 0 else { return false }
        Thread.sleep(forTimeInterval: 5)
        let alive = processes(of: bundle)
        stop(alive + processes(of: bundle))
        return !alive.isEmpty
    }

    static func stop(_ pids: [pid_t]) {
        let unique = Set(pids)
        guard !unique.isEmpty else { return }
        for pid in unique { kill(pid, SIGTERM) }
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, unique.contains(where: { kill($0, 0) == 0 }) {
            Thread.sleep(forTimeInterval: 0.2)
        }
        for pid in unique where kill(pid, 0) == 0 { kill(pid, SIGKILL) }
    }

    // MARK: Files

    /// A temporary folder that macOS keeps on the same volume as `path` (for safe replacement).
    static func workFolder(near path: String) -> String? {
        let parent = URL(fileURLWithPath: (path as NSString).deletingLastPathComponent)
        guard let url = try? FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                     appropriateFor: parent, create: true) else { return nil }
        return url.path
    }

    static func sameVolume(_ a: String, _ b: String) -> Bool {
        var sa = stat(), sb = stat()
        return stat(a, &sa) == 0 && stat(b, &sb) == 0 && sa.st_dev == sb.st_dev
    }

    static func isSymlink(_ path: String) -> Bool {
        var st = stat()
        return lstat(path, &st) == 0 && (st.st_mode & S_IFMT) == S_IFLNK
    }

    static func fileSize(_ path: String) -> Int64 {
        var st = stat()
        return stat(path, &st) == 0 ? Int64(st.st_size) : 0
    }
}

/// Runs blocking work (subprocesses, file walks) on a dedicated thread, keeping the shared pool free.
private func onOwnThread<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
    await withCheckedContinuation { continuation in
        Thread.detachNewThread { continuation.resume(returning: work()) }
    }
}
