import Darwin
import Foundation

/// One row of the storage view: a folder or file with its measured size.
public struct DiskEntry: Identifiable, Sendable, Hashable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let bytes: Int64
    public let files: Int
    public let isDirectory: Bool
    public let modified: Date?
    /// Can be recreated by the project's tools (see `Cleanable`).
    public let isCleanable: Bool
    /// Some content could not be measured; the size is a lower bound.
    public let partial: Bool
    /// Short hint for special places (iCloud, Photos library, the app behind a container).
    public let note: String?

    public init(name: String, path: String, bytes: Int64, files: Int = 1, isDirectory: Bool, modified: Date? = nil,
                isCleanable: Bool = false, partial: Bool = false, note: String? = nil) {
        self.name = name
        self.path = path
        self.bytes = bytes
        self.files = files
        self.isDirectory = isDirectory
        self.modified = modified
        self.isCleanable = isCleanable
        self.partial = partial
        self.note = note
    }
}

/// The content of one location in the storage view, largest first.
public struct DirectoryListing: Sendable {
    /// Empty for the overview.
    public var path: String
    public var entries: [DiskEntry]
    public var largeFiles: [DiskEntry]
    public var partial: Bool
    /// Overview only: what grew since the last day's measurement.
    public var growth: GrowthReport?

    public init(path: String = "", entries: [DiskEntry] = [], largeFiles: [DiskEntry] = [], partial: Bool = false,
                growth: GrowthReport? = nil) {
        self.path = path
        self.entries = entries
        self.largeFiles = largeFiles
        self.partial = partial
        self.growth = growth
    }

    public var totalBytes: Int64 { entries.reduce(0) { $0 + $1.bytes } }
}

public enum DirectoryScanner {
    public typealias Progress = @Sendable (_ done: Int, _ total: Int) -> Void

    /// The direct children of `path` with their sizes, and the largest files below it.
    public static func list(_ path: String, home: String = UserHome.path, progress: @escaping Progress = { _, _ in }) async -> DirectoryListing {
        _ = DiskWalker.disableCloudMaterialization
        var listing = DirectoryListing(path: path)
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            listing.partial = true
            return listing
        }
        let prefix = path.hasSuffix("/") ? path : path + "/"
        var large = LargeFiles()
        var entries: [DiskEntry] = []
        var folders: [String] = []
        for name in names {
            let child = prefix + name
            var st = stat()
            guard lstat(child, &st) == 0 else { continue }
            if (st.st_mode & S_IFMT) == S_IFDIR {
                if !DiskWalker.skipDirNames.contains(name) { folders.append(child) }
                continue
            }
            let bytes = st.st_flags & DiskWalker.datalessFlag != 0 ? 0 : Int64(st.st_blocks) * 512
            if (st.st_mode & S_IFMT) == S_IFREG { large.offer(child, bytes) }
            entries.append(DiskEntry(name: name, path: child, bytes: bytes, isDirectory: false,
                                     modified: date(st), note: note(for: child, home: home)))
        }

        let measured = await measured(folders, progress: progress) { p, counter in DiskWalker.walk(p, counter: counter) }
        for (p, r, _) in measured {
            large.merge(r.largeFiles)
            if r.partial { listing.partial = true }
            entries.append(DiskEntry(name: (p as NSString).lastPathComponent, path: p, bytes: r.bytes, files: r.files,
                                     isDirectory: true, modified: modified(p), isCleanable: Cleanable.isCleanableDirectory(p),
                                     partial: r.partial, note: note(for: p, home: home)))
        }
        listing.entries = sorted(entries)
        listing.largeFiles = fileEntries(large)
        return listing
    }

    /// The well-known places of the home folder and /Applications, each measured on its own. A place
    /// inside another one (Developer inside Library) is left out of the outer one, so the sizes add up.
    /// Records a growth snapshot when everything could be measured in time.
    public static func overview(home: String = UserHome.path, progress: @escaping Progress = { _, _ in }) async -> DirectoryListing {
        // The shared /Applications belongs to the real user's overview, not to a test home.
        let places = overviewPlaces(home: home).filter { isDirectory($0.path) && ($0.path.hasPrefix(home + "/") || $0.path == home || home == UserHome.path) }
        let paths = places.map(\.path)
        var excluded: [String: Set<String>] = [:]
        for p in paths {
            excluded[p] = Set(paths.filter { $0 != p && $0.hasPrefix(p.hasSuffix("/") ? p : p + "/") })
        }
        let skip = excluded
        let measured = await measured(paths, progress: progress) { p, counter in
            DiskWalker.walk(p, folderDepth: 3, excluding: skip[p] ?? [], counter: counter)
        }

        var listing = DirectoryListing()
        var large = LargeFiles()
        var folders: [String: Int64] = [:]
        var cut = false
        for ((p, r, wasCut), place) in zip(measured, places) {
            large.merge(r.largeFiles)
            folders.merge(r.folders) { a, _ in a }
            folders[p] = r.bytes
            if r.partial { listing.partial = true }
            if wasCut { cut = true }
            let note = excluded[p, default: []].isEmpty ? nil : String(localized: "ohne die einzeln aufgeführten Orte", bundle: .module)
            listing.entries.append(DiskEntry(name: place.name, path: p, bytes: r.bytes, files: r.files, isDirectory: true,
                                             modified: modified(p), partial: r.partial, note: note))
        }
        listing.entries = sorted(listing.entries)
        listing.largeFiles = fileEntries(large)

        // A walk cut short by the timeout would look like shrinking today and growth tomorrow.
        if !cut, !Task.isCancelled, let used = VolumeInfo.usedSpace(at: home) {
            let now = GrowthSnapshot(used: used, folders: folders,
                                     files: Dictionary(large.files.map { ($0.path, $0.bytes) }, uniquingKeysWith: { a, _ in a }))
            if let before = Growth.baseline(home: home, now: now.date) { listing.growth = Growth.compare(before, now) }
            Growth.record(now, home: home)
        }
        return listing
    }

    /// The given folders (the ones the user granted access to in the App Store edition), each measured.
    public static func locations(_ paths: [String], home: String = UserHome.path, progress: @escaping Progress = { _, _ in }) async -> DirectoryListing {
        let existing = paths.filter(isDirectory)
        let measured = await measured(existing, progress: progress) { p, counter in DiskWalker.walk(p, counter: counter) }
        var listing = DirectoryListing()
        var large = LargeFiles()
        for (p, r, _) in measured {
            large.merge(r.largeFiles)
            if r.partial { listing.partial = true }
            listing.entries.append(DiskEntry(name: FileManager.default.displayName(atPath: p), path: p, bytes: r.bytes,
                                             files: r.files, isDirectory: true, modified: modified(p),
                                             isCleanable: Cleanable.isCleanableDirectory(p), partial: r.partial,
                                             note: note(for: p, home: home)))
        }
        listing.entries = sorted(listing.entries)
        listing.largeFiles = fileEntries(large)
        return listing
    }

    /// Measures every path with `body`, a few at a time, each limited to `DiskWalker.timeout`.
    /// Results keep the order of `paths`.
    public static func measure(_ paths: [String], progress: @escaping Progress = { _, _ in },
                               _ body: @escaping @Sendable (String, WalkCounter) -> WalkResult) async -> [(String, WalkResult)] {
        await measured(paths, progress: progress, body).map { ($0.0, $0.1) }
    }

    static func measured(_ paths: [String], progress: @escaping Progress,
                         _ body: @escaping @Sendable (String, WalkCounter) -> WalkResult) async -> [(String, WalkResult, Bool)] {
        let total = paths.count
        let seconds = DiskWalker.timeout
        progress(0, total)
        var results = [(WalkResult, Bool)?](repeating: nil, count: total)
        await withTaskGroup(of: (Int, WalkResult, Bool).self) { group in
            let width = max(2, ProcessInfo.processInfo.activeProcessorCount)
            var next = 0
            var done = 0
            while next < min(width, total) {
                let i = next
                group.addTask { let r = await DiskWalker.run(seconds) { body(paths[i], $0) }; return (i, r.result, r.cut) }
                next += 1
            }
            for await (i, r, cut) in group {
                results[i] = (r, cut)
                done += 1
                progress(done, total)
                if next < total, !Task.isCancelled {
                    let j = next
                    group.addTask { let r = await DiskWalker.run(seconds) { body(paths[j], $0) }; return (j, r.result, r.cut) }
                    next += 1
                }
            }
        }
        return zip(paths, results).map { p, r in (p, r?.0 ?? WalkResult(partial: true), r?.1 ?? true) }
    }

    /// A real folder, not a link to one.
    public static func isDirectory(_ path: String) -> Bool {
        var st = stat()
        return lstat(path, &st) == 0 && (st.st_mode & S_IFMT) == S_IFDIR
    }

    /// Modification date of the item itself (a link is not followed).
    public static func modified(_ path: String) -> Date? {
        var st = stat()
        guard lstat(path, &st) == 0 else { return nil }
        return date(st)
    }

    // MARK: - Helpers

    /// Overview places. Standard folders of the user domain (File System Programming Guide, "macOS Library
    /// Directory Details"), where Finder shows their localized names; the Library parts that usually hold
    /// most data; the user's Trash; and whatever else is in the home folder.
    static func overviewPlaces(home: String) -> [(name: String, path: String)] {
        func standard(_ rel: String) -> (name: String, path: String) {
            let p = home + "/" + rel
            return (FileManager.default.displayName(atPath: p), p)
        }
        return [
            (String(localized: "Programme", bundle: .module), "/Applications"),
            (String(localized: "Programme (Benutzer)", bundle: .module), home + "/Applications"),
            standard("Desktop"),
            standard("Documents"),
            standard("Downloads"),
            standard("Pictures"),
            standard("Movies"),
            standard("Music"),
            (String(localized: "Entwicklerdaten", bundle: .module), home + "/Library/Developer"),
            (String(localized: "App-Container", bundle: .module), home + "/Library/Containers"),
            (String(localized: "Gruppen-Container", bundle: .module), home + "/Library/Group Containers"),
            ("iCloud Drive", home + "/Library/Mobile Documents"),
            (String(localized: "Benutzer-Library", bundle: .module), home + "/Library"),
            (String(localized: "Papierkorb", bundle: .module), home + "/.Trash"),
            (String(localized: "Benutzerordner", bundle: .module), home),
        ]
    }

    static func note(for path: String, home: String) -> String? {
        let icloud = home + "/Library/Mobile Documents"
        if path == icloud || path.hasPrefix(icloud + "/") { return "iCloud" }
        if path.lowercased().hasSuffix(".photoslibrary") { return String(localized: "Fotos-Mediathek", bundle: .module) }
        let parent = (path as NSString).deletingLastPathComponent
        if parent == home + "/Library/Containers" || parent == home + "/Library/Group Containers" {
            // Finder and FileManager show the app's name for its container.
            let shown = FileManager.default.displayName(atPath: path)
            if shown != (path as NSString).lastPathComponent { return shown }
        }
        return nil
    }

    static func sorted(_ entries: [DiskEntry]) -> [DiskEntry] {
        entries.sorted { $0.bytes != $1.bytes ? $0.bytes > $1.bytes : $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func fileEntries(_ large: LargeFiles) -> [DiskEntry] {
        large.files.map {
            DiskEntry(name: ($0.path as NSString).lastPathComponent, path: $0.path, bytes: $0.bytes,
                      isDirectory: false, modified: modified($0.path))
        }
    }

    static func date(_ st: stat) -> Date {
        Date(timeIntervalSince1970: TimeInterval(st.st_mtimespec.tv_sec) + TimeInterval(st.st_mtimespec.tv_nsec) / 1e9)
    }
}

/// Folders a project's tools recreate (dependencies, build output, caches).
public enum Cleanable {
    /// Names that only the tool creates; no project file needed next to them.
    static let ownNames: Set<String> = [
        "node_modules",   // npm, "folders" in the npm docs
        "__pycache__",    // Python bytecode cache (PEP 3147)
        ".pytest_cache",  // pytest cache plugin
        ".mypy_cache",    // mypy incremental cache
        ".ruff_cache",    // Ruff cache
    ]

    /// Folder name → project files, one of which must lie next to it. `*.ext` matches by extension.
    static let markers: [String: [String]] = [
        "target": ["Cargo.toml", "pom.xml", "build.sbt"],                     // Cargo, Maven, sbt output
        "build": ["build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts",
                  "CMakeLists.txt", "pubspec.yaml", "package.json"],           // Gradle, CMake, Flutter, npm scripts
        ".gradle": ["build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts", "gradlew"],
        "dist": ["package.json", "pyproject.toml", "setup.py"],               // bundlers, Python sdist/wheel
        ".build": ["Package.swift"],                                          // Swift Package Manager
        "Pods": ["Podfile"],                                                  // CocoaPods
        "DerivedData": ["*.xcodeproj", "*.xcworkspace"],                      // Xcode, project-relative setting
        "vendor": ["composer.json"],                                          // Composer (Go and Ruby vendor is source)
        "bin": ["*.csproj", "*.fsproj", "*.vbproj"],                          // .NET build output
        "obj": ["*.csproj", "*.fsproj", "*.vbproj"],
        ".venv": ["pyproject.toml", "requirements.txt", "setup.py", "setup.cfg", "Pipfile", "uv.lock", "poetry.lock"],
        "venv": ["pyproject.toml", "requirements.txt", "setup.py", "setup.cfg", "Pipfile", "uv.lock", "poetry.lock"],
        ".tox": ["tox.ini", "pyproject.toml", "setup.cfg"],                   // tox
        ".nox": ["noxfile.py"],                                               // nox
        ".dart_tool": ["pubspec.yaml"],                                       // Dart, Flutter
        ".next": ["package.json"],                                            // Next.js
        ".nuxt": ["package.json"], ".output": ["nuxt.config.ts", "nuxt.config.js"], // Nuxt
        ".angular": ["angular.json"],                                         // Angular CLI cache
        ".svelte-kit": ["svelte.config.js", "svelte.config.ts"],              // SvelteKit
        ".astro": ["astro.config.mjs", "astro.config.ts", "astro.config.js"], // Astro
        ".turbo": ["turbo.json"],                                             // Turborepo
        ".parcel-cache": ["package.json"],                                    // Parcel
        ".zig-cache": ["build.zig"], "zig-out": ["build.zig"],                // Zig
        ".terraform": ["*.tf"],                                               // terraform init
        ".terragrunt-cache": ["terragrunt.hcl"],                              // Terragrunt
    ]

    /// First bytes of a `CACHEDIR.TAG` file (Cache Directory Tagging Specification, bford.org).
    static let cacheTagSignature = Data("Signature: 8a477f597d28d172789f06886806bc55".utf8)

    public static func isCleanableDirectory(_ path: String) -> Bool {
        guard DirectoryScanner.isDirectory(path) else { return false }
        let name = (path as NSString).lastPathComponent
        if ownNames.contains(name) || hasCacheTag(path) { return true }
        // A virtual environment marks itself (venv module docs: pyvenv.cfg).
        if name == ".venv" || name == "venv", FileManager.default.fileExists(atPath: path + "/pyvenv.cfg") { return true }
        guard let wanted = markers[name] else { return false }
        let parent = (path as NSString).deletingLastPathComponent
        guard let siblings = try? FileManager.default.contentsOfDirectory(atPath: parent) else { return false }
        return wanted.contains { marker in
            marker.hasPrefix("*.") ? siblings.contains { $0.hasSuffix(marker.dropFirst()) } : siblings.contains(marker)
        }
    }

    static func hasCacheTag(_ path: String) -> Bool {
        guard let handle = FileHandle(forReadingAtPath: path + "/CACHEDIR.TAG") else { return false }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: cacheTagSignature.count)) == cacheTagSignature
    }
}
