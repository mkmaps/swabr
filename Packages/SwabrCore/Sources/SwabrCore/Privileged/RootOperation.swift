import Foundation

// This file is also compiled into the privileged helper (see project.yml), so it uses Foundation only and
// nothing else from SwabrCore.

/// One step that needs root. The helper accepts these and nothing else: there is no way to hand it a shell
/// script. Every path is checked again by the helper itself (`RootExecutor`), whatever the app checked before.
public enum RootOperation: Codable, Sendable, Hashable {
    /// Moves `source` into the requesting user's Trash, as `target`, and hands it to that user.
    case trash(source: String, target: String)
    /// `launchctl bootout system <plist>` for a daemon in /Library/LaunchDaemons.
    case stopDaemon(plist: String)
    /// `launchctl bootout gui/<uid> <plist>` for an agent in /Library/LaunchAgents.
    case stopAgent(plist: String)
    /// Runs `then` only when `first` succeeded (an app's system files go only once the app went).
    indirect case group(first: RootOperation, then: [RootOperation])
    /// Slimming: the original app into the Trash, the slimmed copy into its place with the original's owner,
    /// the original put back when the copy cannot be moved.
    case replaceApp(original: String, replacement: String, trash: String)
    /// A fixed maintenance command.
    case command(RootCommand)
}

/// The maintenance commands the helper knows. Each one runs a fixed program with fixed arguments.
public enum RootCommand: Codable, Sendable, Hashable {
    /// dscacheutil -flushcache, then SIGHUP to mDNSResponder.
    case flushDNS
    /// route -n flush, then `ipconfig set <if> DHCP` for each interface.
    case flushRoutes(interfaces: [String])
    /// diskutil resetUserPermissions / <uid of the requesting user>.
    case resetUserPermissions
    /// mdutil -E /
    case rebuildSpotlightIndex
    /// The Spotlight volume configuration as XML (readable by root only).
    case readSpotlightConfiguration
    /// periodic daily|weekly|monthly
    case periodic(names: [String])
    /// sfltool dumpbtm (Background Task Management records).
    case listBackgroundItems
}

public struct RootResult: Codable, Sendable, Hashable {
    public var status: Int32
    public var output: String

    public init(status: Int32, output: String) {
        self.status = status
        self.output = output
    }

    public var ok: Bool { status == 0 }
    static func refused(_ why: String) -> RootResult { RootResult(status: 77, output: "refused: " + why) }
}

/// What the app hands to the helper, and what it gets back.
public struct RootRequest: Codable, Sendable {
    public var operations: [RootOperation]
    public init(_ operations: [RootOperation]) { self.operations = operations }
}

/// Runs root steps: through the helper, after a password prompt, or (in tests) as the user.
/// Nil when nothing ran (no helper, prompt declined); otherwise one result per operation.
public typealias RootRunner = @Sendable ([RootOperation]) -> [RootResult]?

/// Carries out `RootOperation`s. Runs as root in the helper; the tests run it as the user on a fake home.
public struct RootExecutor: Sendable {
    /// The user the work is done for: items go to this user's Trash and are handed to this user.
    public let uid: uid_t
    public let gid: gid_t
    public let home: String
    /// Folders below which `trash` may take something (never a root itself).
    public var sourceRoots: [String]
    /// Folders below which an app may be replaced.
    public var appRoots: [String]
    /// Folders in which a slimmed copy may lie.
    public var replacementRoots: [String]
    /// Upper limit for each program the helper starts.
    public var timeout: TimeInterval

    /// `/Library` folders whose entries may go with administrator rights (REGELWERK S7).
    public static let systemRoots: [String] = [
        "/Library/Application Support/", "/Library/Caches/", "/Library/Logs/", "/Library/Preferences/",
        "/Library/LaunchAgents/", "/Library/LaunchDaemons/", "/Library/PrivilegedHelperTools/", "/Library/Receipts/",
        "/Library/Frameworks/", "/Library/Internet Plug-Ins/", "/Library/Input Methods/",
        "/Library/Audio/Plug-Ins/HAL/", "/Library/Audio/Plug-Ins/Components/", "/Library/Audio/Plug-Ins/VST/",
        "/Library/Audio/Plug-Ins/VST3/", "/Library/QuickLook/", "/Library/PreferencePanes/", "/Library/Screen Savers/",
        "/Library/Extensions/", "/Library/StartupItems/",
    ]

    public static let spotlightConfigurations = [
        "/System/Volumes/Data/.Spotlight-V100/VolumeConfiguration.plist", "/.Spotlight-V100/VolumeConfiguration.plist",
    ]

    public init(uid: uid_t, gid: gid_t, home: String, timeout: TimeInterval = 900) {
        self.uid = uid
        self.gid = gid
        self.home = home
        let apps = ["/Applications/", home + "/Applications/"]
        // The home (project folders, caches), the app folders, /Library's app folders and external volumes.
        sourceRoots = Self.systemRoots + apps + [home + "/", "/Volumes/"]
        appRoots = apps
        replacementRoots = ["/private/var/folders/", "/var/folders/", home + "/"]
        self.timeout = timeout
    }

    /// The executor for a user account, or nil for an unknown account or root itself.
    public static func forUser(_ uid: uid_t) -> RootExecutor? {
        guard uid != 0, let pw = getpwuid(uid), let dir = pw.pointee.pw_dir else { return nil }
        let home = String(cString: dir)
        guard home.hasPrefix("/Users/") || home.hasPrefix("/Volumes/") else { return nil }
        return RootExecutor(uid: uid, gid: pw.pointee.pw_gid, home: home)
    }

    public func perform(_ operations: [RootOperation]) -> [RootResult] {
        operations.map(run)
    }

    func run(_ op: RootOperation) -> RootResult {
        switch op {
        case .trash(let source, let target):
            return trash(source, to: target)
        case .stopDaemon(let plist):
            guard Self.isLaunchPlist(plist, in: "/Library/LaunchDaemons/") else { return .refused(plist) }
            return Self.launch("/bin/launchctl", ["bootout", "system", plist], timeout: 60)
        case .stopAgent(let plist):
            guard Self.isLaunchPlist(plist, in: "/Library/LaunchAgents/") else { return .refused(plist) }
            return Self.launch("/bin/launchctl", ["bootout", "gui/\(uid)", plist], timeout: 60)
        case .group(let first, let then):
            let head = run(first)
            guard head.ok else { return head }
            let rest = then.map(run)
            return RootResult(status: 0, output: ([head] + rest).map(\.output).filter { !$0.isEmpty }.joined(separator: "\n"))
        case .replaceApp(let original, let replacement, let trash):
            return replaceApp(original, with: replacement, trash: trash)
        case .command(let command):
            return run(command)
        }
    }

    // MARK: Moves

    /// Below one of `roots` (not the root itself), absolute, without empty, `.` or `..` parts, without
    /// anything of Apple's and without control characters.
    static func isCleanPath(_ path: String, roots: [String]) -> Bool {
        guard path.hasPrefix("/"), !path.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F }),
              let root = roots.first(where: { path.hasPrefix($0) }), path.count > root.count else { return false }
        for part in path.dropFirst().split(separator: "/", omittingEmptySubsequences: false) {
            if part.isEmpty || part == "." || part == ".." { return false }
            if part.lowercased().hasPrefix("com.apple.") { return false }
        }
        return true
    }

    /// The item exists, is not a link, and its folder is a real folder that resolves to itself.
    static func isPinned(_ path: String) -> Bool {
        var st = stat()
        guard lstat(path, &st) == 0, (st.st_mode & S_IFMT) != S_IFLNK else { return false }
        let parent = (path as NSString).deletingLastPathComponent
        var pst = stat()
        guard lstat(parent, &pst) == 0, (pst.st_mode & S_IFMT) == S_IFDIR else { return false }
        return realPath(parent) == parent
    }

    static func realPath(_ path: String) -> String? {
        guard let p = realpath(path, nil) else { return nil }
        defer { free(p) }
        return String(cString: p)
    }

    /// A free name directly in the user's Trash.
    func isTrashTarget(_ target: String) -> Bool {
        let trash = home + "/.Trash"
        guard target.hasPrefix(trash + "/"), !target.dropFirst(trash.count + 1).contains("/"),
              Self.isCleanPath(target, roots: [trash + "/"]) else { return false }
        var st = stat(), tst = stat()
        guard lstat(target, &st) != 0, lstat(trash, &tst) == 0, (tst.st_mode & S_IFMT) == S_IFDIR else { return false }
        return Self.realPath(trash) == trash
    }

    func trash(_ source: String, to target: String) -> RootResult {
        guard Self.isCleanPath(source, roots: sourceRoots) else { return .refused(source) }
        // On an external volume never the volume itself or its top level: at least one folder below it.
        if source.hasPrefix("/Volumes/"), source.dropFirst("/Volumes/".count).split(separator: "/").count < 3 {
            return .refused(source)
        }
        guard Self.isPinned(source) else { return .refused(source) }
        guard isTrashTarget(target) else { return .refused(target) }
        if let failure = move(source, to: target) { return failure }
        return handOver(target, to: uid, gid)
    }

    /// `rename` relative to the pinned folders, so a folder swapped for a link after the check cannot redirect
    /// it; across volumes `mv` copies.
    func move(_ source: String, to target: String) -> RootResult? {
        let from = (source as NSString).deletingLastPathComponent, leaf = (source as NSString).lastPathComponent
        let to = (target as NSString).deletingLastPathComponent, newLeaf = (target as NSString).lastPathComponent
        let fromFD = open(from, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        let toFD = open(to, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        defer {
            if fromFD >= 0 { close(fromFD) }
            if toFD >= 0 { close(toFD) }
        }
        guard fromFD >= 0, toFD >= 0 else { return .refused(source) }
        if renameatx_np(fromFD, leaf, toFD, newLeaf, UInt32(RENAME_EXCL)) == 0 { return nil }
        let err = errno
        guard err == EXDEV else { return RootResult(status: Int32(err), output: String(cString: strerror(err))) }
        let copied = Self.launch("/bin/mv", [source, target], timeout: timeout)
        return copied.ok ? nil : copied
    }

    func handOver(_ path: String, to owner: uid_t, _ group: gid_t) -> RootResult {
        // chown -R does not follow links (-P is the default).
        let r = Self.launch("/usr/sbin/chown", ["-R", "\(owner):\(group)", path], timeout: timeout)
        return r.ok ? RootResult(status: 0, output: "") : r
    }

    func replaceApp(_ original: String, with replacement: String, trash: String) -> RootResult {
        guard original.hasSuffix(".app"), Self.isCleanPath(original, roots: appRoots), Self.isPinned(original),
              (replacement as NSString).lastPathComponent == (original as NSString).lastPathComponent,
              Self.isCleanPath(replacement, roots: replacementRoots), Self.isPinned(replacement)
        else { return .refused(original) }
        guard isTrashTarget(trash) else { return .refused(trash) }
        var st = stat()
        guard lstat(original, &st) == 0 else { return .refused(original) }
        if let failure = move(original, to: trash) { return failure }
        if let failure = move(replacement, to: original) {
            _ = move(trash, to: original)
            return failure
        }
        _ = handOver(original, to: st.st_uid, st.st_gid)
        return handOver(trash, to: uid, gid)
    }

    static func isLaunchPlist(_ plist: String, in folder: String) -> Bool {
        plist.hasSuffix(".plist") && !plist.dropFirst(folder.count).contains("/") && isCleanPath(plist, roots: [folder])
    }

    // MARK: Commands

    func run(_ command: RootCommand) -> RootResult {
        switch command {
        case .flushDNS:
            let flush = Self.launch("/usr/bin/dscacheutil", ["-flushcache"], timeout: 60)
            guard flush.ok else { return flush }
            return Self.launch("/usr/bin/killall", ["-HUP", "mDNSResponder"], timeout: 30)
        case .flushRoutes(let interfaces):
            guard !interfaces.isEmpty, interfaces.allSatisfy(Self.isInterfaceName) else { return .refused("interface") }
            let flush = Self.launch("/sbin/route", ["-n", "flush"], timeout: 60)
            guard flush.ok else { return flush }
            for name in interfaces {
                let renew = Self.launch("/usr/sbin/ipconfig", ["set", name, "DHCP"], timeout: 60)
                if !renew.ok { return renew }
            }
            return RootResult(status: 0, output: "")
        case .resetUserPermissions:
            return Self.launch("/usr/sbin/diskutil", ["resetUserPermissions", "/", "\(uid)"], timeout: timeout)
        case .rebuildSpotlightIndex:
            return Self.launch("/usr/bin/mdutil", ["-E", "/"], timeout: 120)
        case .readSpotlightConfiguration:
            for path in Self.spotlightConfigurations where access(path, R_OK) == 0 {
                return Self.launch("/usr/bin/plutil", ["-convert", "xml1", "-o", "-", path], timeout: 30)
            }
            return RootResult(status: 1, output: "")
        case .periodic(let names):
            let allowed: Set<String> = ["daily", "weekly", "monthly"]
            guard !names.isEmpty, names.allSatisfy(allowed.contains) else { return .refused("periodic") }
            return Self.launch("/usr/sbin/periodic", names, timeout: timeout)
        case .listBackgroundItems:
            return Self.launch("/usr/bin/sfltool", ["dumpbtm"], timeout: 60, errors: false)
        }
    }

    static func isInterfaceName(_ s: String) -> Bool {
        !s.isEmpty && s.count <= 15 && s.first!.isLetter && s.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    // MARK: Processes

    private final class Box: @unchecked Sendable { var data = Data() }

    /// Runs a program directly (no shell), with a fixed PATH, and stops it after `timeout` seconds.
    static func launch(_ tool: String, _ arguments: [String], timeout: TimeInterval, errors: Bool = true) -> RootResult {
        guard FileManager.default.isExecutableFile(atPath: tool) else { return RootResult(status: 127, output: "\(tool) fehlt") }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "en_US.UTF-8"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errors ? pipe : FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        do { try process.run() } catch { return RootResult(status: 126, output: error.localizedDescription) }
        let box = Box()
        let drained = DispatchSemaphore(value: 0)
        Thread.detachNewThread {
            box.data = pipe.fileHandleForReading.readDataToEndOfFile()
            drained.signal()
        }
        if exited.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            if exited.wait(timeout: .now() + 3) == .timedOut { kill(process.processIdentifier, SIGKILL); _ = exited.wait(timeout: .now() + 3) }
            _ = drained.wait(timeout: .now() + 3)
            return RootResult(status: 124, output: "timeout after \(Int(timeout)) s: \(tool)")
        }
        _ = drained.wait(timeout: .now() + 5)
        return RootResult(status: process.terminationStatus, output: String(decoding: box.data, as: UTF8.self))
    }
}
