import Darwin
import Foundation
import Synchronization

/// Totals of one measurement.
public struct WalkResult: Sendable {
    /// Allocated bytes (space actually used on disk).
    public var bytes: Int64
    /// Files, symlinks and other non-folders; a hard-linked file counts once.
    public var files: Int
    /// Something was left out: an unreadable folder, a stop or a timeout.
    public var partial: Bool
    public var largeFiles: LargeFiles
    /// Allocated bytes of every subfolder down to the requested depth, keyed by path.
    public var folders: [String: Int64]

    public init(bytes: Int64 = 0, files: Int = 0, partial: Bool = false,
                largeFiles: LargeFiles = LargeFiles(), folders: [String: Int64] = [:]) {
        self.bytes = bytes
        self.files = files
        self.partial = partial
        self.largeFiles = largeFiles
        self.folders = folders
    }
}

public struct LargeFile: Sendable, Hashable {
    public let path: String
    public let bytes: Int64
}

/// The largest files seen so far, biggest first.
public struct LargeFiles: Sendable {
    public static let limit = 20
    /// Smaller files are never kept (1 MB, as the size formatter counts).
    public static let minimum: Int64 = 1_000_000

    public private(set) var files: [LargeFile] = []

    public init() {}

    /// A file must be at least this big to be kept: the smallest kept size once the list is full.
    public var threshold: Int64 {
        files.count >= Self.limit ? files[files.count - 1].bytes : Self.minimum
    }

    public mutating func offer(_ path: String, _ bytes: Int64) {
        guard bytes >= Self.minimum, files.count < Self.limit || bytes > files[files.count - 1].bytes else { return }
        if files.contains(where: { $0.path == path }) { return }
        var low = 0, high = files.count
        while low < high {
            let mid = (low + high) / 2
            if files[mid].bytes >= bytes { low = mid + 1 } else { high = mid }
        }
        files.insert(LargeFile(path: path, bytes: bytes), at: low)
        if files.count > Self.limit { files.removeLast() }
    }

    public mutating func merge(_ other: LargeFiles) {
        for f in other.files { offer(f.path, f.bytes) }
    }
}

/// Running totals of a measurement, readable while it runs, and its stop switch. Safe from any thread.
public final class WalkCounter: Sendable {
    private let stopped = Atomic<Bool>(false)
    private let byteCount = Atomic<Int64>(0)
    private let fileCount = Atomic<Int>(0)

    public init() {}

    public func add(bytes: Int64, files: Int) {
        byteCount.wrappingAdd(bytes, ordering: .relaxed)
        fileCount.wrappingAdd(files, ordering: .relaxed)
    }

    /// Asks every measurement using this counter to finish early; their results are partial.
    public func stop() { stopped.store(true, ordering: .relaxed) }

    public var isStopped: Bool { stopped.load(ordering: .relaxed) }
    public var bytes: Int64 { byteCount.load(ordering: .relaxed) }
    public var files: Int { fileCount.load(ordering: .relaxed) }

    /// What has been counted so far, marked as partial.
    var soFar: WalkResult { WalkResult(bytes: bytes, files: files, partial: true) }
}

/// Measures folder trees by allocated size, without following links, leaving the volume or
/// downloading cloud files.
public enum DiskWalker {
    /// Lets reads of iCloud placeholders (and listings of placeholder folders) fail instead of
    /// downloading them. Process-wide; see `setiopolicy_np(3)`.
    public static let disableCloudMaterialization: Void = {
        _ = setiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_PROCESS, IOPOL_MATERIALIZE_DATALESS_FILES_OFF)
    }()

    /// `st_flags` bit of a cloud placeholder whose content is not on disk (`SF_DATALESS`, sys/stat.h).
    public static let datalessFlag = UInt32(SF_DATALESS)

    /// Seconds one entry of a listing may take before its partial total is shown (set from the settings).
    nonisolated(unsafe) public static var timeout: TimeInterval = 30

    /// Folders that are never entered: volume bookkeeping and backup stores whose content is not the
    /// user's files, or which appear a second time somewhere else.
    public static let skipDirNames: Set<String> = [
        ".Spotlight-V100",          // Spotlight index of a volume (mdutil(1))
        ".fseventsd",               // FSEvents log of a volume (File System Events Programming Guide)
        ".DocumentRevisions-V100",  // saved document versions of a volume (NSFileVersion)
        ".MobileBackups",           // Time Machine local snapshots of OS X 10.7–10.12
        "Backups.backupdb",         // Time Machine backups on an HFS+ disk (tmutil(8))
        ".timemachine",             // mount point of Time Machine backups on APFS disks (tmutil(8))
        "com.apple.TimeMachine.localsnapshots", // mount point of local APFS snapshots (tmutil(8))
        ".Trashes",                 // per-user Trash folders on other volumes (Finder)
        ".TemporaryItems",          // per-volume temporary items (FileManager.itemReplacementDirectory)
        ".vol",                     // volfs: every file once more by volume and file ID
        "OrbStack",                 // ~/OrbStack shows the files inside OrbStack's Linux machines (OrbStack docs, "File sharing")
    ]

    /// Folders measured as one block: their files are managed by a tool and never listed as large files.
    public static let foldDirNames: Set<String> = [
        "node_modules",       // npm, "folders" in the npm docs
        "bower_components",   // Bower install folder
        ".git",               // git repository data (gitrepository-layout(5))
        ".hg",                // Mercurial repository data
        ".svn",               // Subversion working copy data
        "DerivedData",        // Xcode build output (Xcode build settings, "Derived Data")
        ".build",             // Swift Package Manager build folder
        "Pods",               // CocoaPods install folder
        "venv", ".venv",      // Python virtual environments (venv module docs)
        "__pycache__",        // Python bytecode cache (PEP 3147)
        ".tox", ".nox",       // tox and nox test environments
        ".gradle",            // Gradle project cache
        ".dart_tool",         // Dart and Flutter tool data
        ".next", ".nuxt", ".svelte-kit", ".angular", ".turbo", // web framework build caches (their docs)
        ".zig-cache",         // Zig build cache
        ".terraform",         // Terraform providers and modules (terraform init)
    ]

    /// On the startup disk the data volume is also reached through firmlinks (/Users, /Applications …),
    /// so its own mount point is not entered.
    static let dataVolumeMount = "/System/Volumes/Data"

    public static func walk(_ path: String, skipNames: Set<String> = skipDirNames, trackLargeFiles: Bool = true,
                            folderDepth: Int = 0, counter: WalkCounter? = nil) -> WalkResult {
        walk(path, skipNames: skipNames, trackLargeFiles: trackLargeFiles, folderDepth: folderDepth, excluding: [], counter: counter)
    }

    /// `excluding`: folders left out by path, for measurements that list them separately.
    static func walk(_ path: String, skipNames: Set<String> = skipDirNames, trackLargeFiles: Bool = true,
                     folderDepth: Int = 0, excluding: Set<String>, counter: WalkCounter? = nil) -> WalkResult {
        _ = disableCloudMaterialization
        var st = stat()
        guard lstat(path, &st) == 0 else { return WalkResult(partial: errno != ENOENT) }
        let walker = Walker(skipNames: skipNames, trackLargeFiles: trackLargeFiles, folderDepth: folderDepth,
                            excluding: excluding, counter: counter, device: st.st_dev)
        let bytes: Int64
        if (st.st_mode & S_IFMT) == S_IFDIR {
            bytes = walker.directory(path, st, depth: 0, folded: false)
        } else {
            bytes = Walker.allocated(st)
            walker.files = 1
            if trackLargeFiles, (st.st_mode & S_IFMT) == S_IFREG { walker.large.offer(path, bytes) }
            counter?.add(bytes: bytes, files: 1)
        }
        return WalkResult(bytes: bytes, files: walker.files, partial: walker.partial || (counter?.isStopped ?? false),
                          largeFiles: walker.large, folders: walker.folders)
    }

    /// Runs `body` on its own thread. If it has not finished after `seconds`, its counter is stopped and
    /// the total so far is returned as partial, even when the thread hangs in the kernel (a stalled
    /// network volume). Cancelling the calling task stops the counter as well.
    public static func withTimeout(_ seconds: TimeInterval, _ body: @escaping @Sendable (WalkCounter) -> WalkResult) async -> WalkResult {
        await run(seconds, body).result
    }

    /// Upper limit for a stopped walk to hand in its own result; the wait ends as soon as it does. Kept
    /// short enough that a walk hung in the kernel is given up quickly.
    static let stopWait: TimeInterval = 1.0

    /// Like `withTimeout`, and tells whether the measurement was cut short.
    static func run(_ seconds: TimeInterval, _ body: @escaping @Sendable (WalkCounter) -> WalkResult) async -> (result: WalkResult, cut: Bool) {
        let counter = WalkCounter()
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<WalkResult, Never>) in
                let once = ResumeOnce(continuation)
                let thread = Thread {
                    var r = body(counter)
                    if counter.isStopped { r.partial = true }
                    once.resume(r)
                }
                thread.stackSize = 8 << 20   // deep trees recurse
                thread.start()
                // A stopped walk returns on its own with its large files, and `once` takes that result the moment
                // it arrives. Only a walk still stuck `stopWait` after the stop gets the counter's totals instead.
                DispatchQueue.global().asyncAfter(deadline: .now() + max(seconds, 0)) {
                    counter.stop()
                    DispatchQueue.global().asyncAfter(deadline: .now() + DiskWalker.stopWait) { once.resume(counter.soFar) }
                }
            }
        } onCancel: {
            counter.stop()
        }
        return (result, counter.isStopped)
    }
}

/// Resumes a continuation with the first value only.
private final class ResumeOnce: Sendable {
    private let continuation: Mutex<CheckedContinuation<WalkResult, Never>?>

    init(_ c: CheckedContinuation<WalkResult, Never>) { continuation = Mutex(c) }

    func resume(_ value: WalkResult) {
        let c = continuation.withLock { c -> CheckedContinuation<WalkResult, Never>? in
            defer { c = nil }
            return c
        }
        c?.resume(returning: value)
    }
}

/// State of one walk. Used from one thread only.
private final class Walker {
    struct FileID: Hashable {
        let device: dev_t
        let inode: ino_t
    }

    let skipNames: Set<String>
    let trackLargeFiles: Bool
    let folderDepth: Int
    let excluding: Set<String>
    let counter: WalkCounter?
    let device: dev_t

    var files = 0
    var partial = false
    var large = LargeFiles()
    var folders: [String: Int64] = [:]
    /// Files with more than one hard link that were already counted.
    var linked = Set<FileID>()

    init(skipNames: Set<String>, trackLargeFiles: Bool, folderDepth: Int, excluding: Set<String>,
         counter: WalkCounter?, device: dev_t) {
        self.skipNames = skipNames
        self.trackLargeFiles = trackLargeFiles
        self.folderDepth = folderDepth
        self.excluding = excluding
        self.counter = counter
        self.device = device
    }

    /// Blocks in use (the figure behind `fileAllocatedSize`); a cloud placeholder uses none.
    static func allocated(_ st: stat) -> Int64 {
        st.st_flags & DiskWalker.datalessFlag != 0 ? 0 : Int64(st.st_blocks) * 512
    }

    var stopped: Bool { counter?.isStopped ?? false }

    /// Allocated bytes of `dir` and everything below it. `folded`: inside a fold folder.
    func directory(_ dir: String, _ st: stat, depth: Int, folded: Bool) -> Int64 {
        var total = Self.allocated(st)
        if stopped {
            partial = true
            return total
        }
        // Listing a placeholder folder would fetch it from the cloud.
        if st.st_flags & DiskWalker.datalessFlag != 0 { return total }
        guard let handle = opendir(dir) else {
            if errno != ENOENT { partial = true }
            return total
        }
        let fd = dirfd(handle)
        let prefix = dir.hasSuffix("/") ? dir : dir + "/"
        var subdirs: [(path: String, name: String, st: stat)] = []
        var localBytes: Int64 = 0
        var localFiles = 0
        var seen = 0
        while let entry = readdir(handle) {
            let length = Int(entry.pointee.d_namlen)
            let name = withUnsafeBytes(of: entry.pointee.d_name) { String(decoding: $0.prefix(length), as: UTF8.self) }
            if name == "." || name == ".." { continue }
            seen += 1
            if seen & 1023 == 0, stopped {
                partial = true
                break
            }
            var cst = stat()
            guard fstatat(fd, name, &cst, AT_SYMLINK_NOFOLLOW) == 0 else { continue }
            let type = cst.st_mode & S_IFMT
            if type == S_IFDIR {
                // Another volume mounted here, or a folder that is never entered.
                if cst.st_dev != device || skipNames.contains(name) { continue }
                let path = prefix + name
                if path == DiskWalker.dataVolumeMount || excluding.contains(path) { continue }
                subdirs.append((path, name, cst))
                continue
            }
            if cst.st_nlink > 1, !linked.insert(FileID(device: cst.st_dev, inode: cst.st_ino)).inserted { continue }
            let bytes = Self.allocated(cst)
            localBytes += bytes
            localFiles += 1
            if trackLargeFiles, !folded, type == S_IFREG, bytes >= large.threshold { large.offer(prefix + name, bytes) }
        }
        closedir(handle)
        total += localBytes
        files += localFiles
        counter?.add(bytes: localBytes + Self.allocated(st), files: localFiles)

        for sub in subdirs {
            let inFold = folded || DiskWalker.foldDirNames.contains(sub.name)
            let size = directory(sub.path, sub.st, depth: depth + 1, folded: inFold)
            total += size
            if !folded, depth + 1 <= folderDepth { folders[sub.path] = size }
        }
        return total
    }
}
