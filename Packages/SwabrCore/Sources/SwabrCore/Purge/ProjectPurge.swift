import Darwin
import Foundation

/// A folder inside a development project that the project's own tools can recreate.
public struct ProjectArtifact: Identifiable, Sendable, Hashable {
    public var id: String { path }
    public let path: String
    /// The folder holding the project file the artifact belongs to (its parent).
    public let project: String
    public let name: String
    public let bytes: Int64
    /// Newest change of the project's own files, outside its artifacts.
    public let lastActivity: Date?
    /// A process works inside the project.
    public var inUse: Bool

    public init(path: String, project: String, name: String, bytes: Int64, lastActivity: Date?, inUse: Bool = false) {
        self.path = path
        self.project = project
        self.name = name
        self.bytes = bytes
        self.lastActivity = lastActivity
        self.inUse = inUse
    }

    /// Worked on within `ProjectPurge.recentDays`; without a date we cannot tell, so it counts as recent.
    public var recent: Bool {
        guard let lastActivity else { return true }
        return lastActivity > Date().addingTimeInterval(-Double(ProjectPurge.recentDays) * 86_400)
    }

    /// How the folder comes back.
    public var impact: String { (ProjectPurge.kinds[name]?.restore ?? .build).text }
}

/// Finds and removes regenerable folders (dependencies, build output, tool caches) in development projects.
public enum ProjectPurge {
    /// Projects changed within this many days are not preselected.
    nonisolated(unsafe) public static var recentDays = 7
    /// How deep below a search location artifacts are looked for.
    nonisolated(unsafe) public static var maxDepth = 6
    /// Longest wait for `git ls-files`; a slower answer counts as "tracked".
    static let gitTimeout: TimeInterval = 20
    /// Mount point of external volumes.
    static let volumes = "/Volumes"

    /// One kind of artifact: the project files one of which must sit next to it (`*.ext` matches by
    /// extension), what it holds and how it is recreated.
    struct Kind: Sendable {
        enum Role: Sendable {
            /// Installed packages from a registry. They often ship sample keys and CA bundles,
            /// so key files only count at the folder's first level.
            case dependencies
            case output
            case cache
        }

        let markers: [String]
        let role: Role
        let restore: Restore
    }

    enum Restore: Sendable {
        case npm, cargoMaven, build, output, venv, pods, swiftPM, composer, dotnet, pycache, cache, testEnvs, pub, zig,
             terraform, terragrunt

        var text: String {
            switch self {
            case .npm: String(localized: "Mit npm install / pnpm install / yarn wieder herstellen.", bundle: .module)
            case .cargoMaven: String(localized: "Wird von cargo build bzw. mvn package neu gebaut.", bundle: .module)
            case .build: String(localized: "Wird beim nächsten Build neu erzeugt.", bundle: .module)
            case .output: String(localized: "Build-Ergebnisse. Werden beim nächsten Build neu erzeugt.", bundle: .module)
            case .venv: String(localized: "Virtuelle Python-Umgebung: mit uv sync oder pip install neu anlegen.", bundle: .module)
            case .pods: String(localized: "Mit pod install wieder herstellen.", bundle: .module)
            case .swiftPM: String(localized: "Swift-Build-Ordner: swift build erzeugt ihn neu.", bundle: .module)
            case .composer: String(localized: "Mit composer install wieder herstellen.", bundle: .module)
            case .dotnet: String(localized: "Wird von dotnet build neu erzeugt.", bundle: .module)
            case .pycache: String(localized: "Python erzeugt die Dateien beim nächsten Start neu.", bundle: .module)
            case .cache: String(localized: "Cache. Wird bei Bedarf neu erstellt.", bundle: .module)
            case .testEnvs: String(localized: "Testumgebungen von tox bzw. nox: werden beim nächsten Lauf neu angelegt.", bundle: .module)
            case .pub: String(localized: "Mit dart pub get bzw. flutter pub get wieder herstellen.", bundle: .module)
            case .zig: String(localized: "Wird von zig build neu erzeugt.", bundle: .module)
            case .terraform: String(localized: "Mit terraform init wieder herstellen.", bundle: .module)
            case .terragrunt: String(localized: "Terragrunt lädt den Inhalt beim nächsten Lauf neu.", bundle: .module)
            }
        }
    }

    private static let gradleFiles = ["build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts"]
    private static let pythonProject = ["pyproject.toml", "requirements.txt", "setup.py", "setup.cfg", "Pipfile",
                                        "uv.lock", "poetry.lock"]
    private static let dotnetProject = ["*.csproj", "*.fsproj", "*.vbproj"]
    private static let nextConfig = ["next.config.js", "next.config.mjs", "next.config.ts"]
    private static let nuxtConfig = ["nuxt.config.ts", "nuxt.config.js", "nuxt.config.mjs"]

    /// Folder name → kind. Each entry names the documentation that says where the tool writes it.
    static let kinds: [String: Kind] = [
        // npm docs, "folders": local installs go to ./node_modules next to package.json.
        "node_modules": Kind(markers: ["package.json"], role: .dependencies, restore: .npm),
        // Cargo Book, "Build Cache" (target/ at the package or workspace root); Maven,
        // "Introduction to the Standard Directory Layout" (target/ next to pom.xml).
        "target": Kind(markers: ["Cargo.toml", "pom.xml"], role: .output, restore: .cargoMaven),
        // Gradle "Build directory" (layout.buildDirectory = build/); cmake(1) `cmake -B build`;
        // Flutter `flutter build` writes build/; setuptools builds into build/; JS bundlers (CRA,
        // SvelteKit adapter-static) default to build/ next to package.json.
        "build": Kind(markers: gradleFiles + ["CMakeLists.txt", "pubspec.yaml", "setup.py", "setup.cfg", "package.json"],
                      role: .output, restore: .build),
        // Gradle "Project cache directory": .gradle in the root project.
        ".gradle": Kind(markers: gradleFiles + ["gradlew"], role: .cache, restore: .build),
        // Kotlin Gradle plugin 2.x: project-level .kotlin directory (session and error files).
        ".kotlin": Kind(markers: gradleFiles, role: .cache, restore: .build),
        // Vite/Angular/Astro outDir dist/; Python Packaging User Guide: `python -m build`, Poetry,
        // uv and Hatch write sdists and wheels to dist/.
        "dist": Kind(markers: ["package.json", "pyproject.toml", "setup.py"], role: .output, restore: .output),
        // Next.js "Static Exports": `output: 'export'` writes out/.
        "out": Kind(markers: nextConfig, role: .output, restore: .output),
        // Next.js `distDir`, default .next.
        ".next": Kind(markers: nextConfig + ["package.json"], role: .output, restore: .build),
        // Nuxt "Directory Structure": .nuxt (generated app) and .output (production build, Nitro).
        ".nuxt": Kind(markers: nuxtConfig + ["package.json"], role: .output, restore: .build),
        ".output": Kind(markers: nuxtConfig + ["nitro.config.ts", "nitro.config.js"], role: .output, restore: .build),
        // Angular CLI `cli.cache.path`, default .angular/cache.
        ".angular": Kind(markers: ["angular.json"], role: .cache, restore: .cache),
        // SvelteKit "Project structure": generated .svelte-kit.
        ".svelte-kit": Kind(markers: ["svelte.config.js", "svelte.config.ts"], role: .output, restore: .build),
        // Astro "Project structure": generated .astro (types, content cache).
        ".astro": Kind(markers: ["astro.config.mjs", "astro.config.js", "astro.config.ts", "astro.config.mts", "astro.config.cjs"],
                       role: .cache, restore: .build),
        // Turborepo "Caching": local cache in .turbo.
        ".turbo": Kind(markers: ["turbo.json"], role: .cache, restore: .cache),
        // Parcel "Caching": .parcel-cache next to package.json.
        ".parcel-cache": Kind(markers: ["package.json"], role: .cache, restore: .cache),
        // Zig build system: cache in .zig-cache (zig-cache before 0.13), install prefix zig-out.
        ".zig-cache": Kind(markers: ["build.zig"], role: .cache, restore: .zig),
        "zig-cache": Kind(markers: ["build.zig"], role: .cache, restore: .zig),
        "zig-out": Kind(markers: ["build.zig"], role: .output, restore: .zig),
        // Terraform `terraform init`: providers and modules in .terraform.
        ".terraform": Kind(markers: ["*.tf", "*.tf.json"], role: .dependencies, restore: .terraform),
        // Terragrunt: downloaded sources in .terragrunt-cache.
        ".terragrunt-cache": Kind(markers: ["terragrunt.hcl"], role: .dependencies, restore: .terragrunt),
        // Python `venv` docs (.venv convention), uv "Project environment" (.venv), Poetry
        // `virtualenvs.in-project` (.venv), pip requirements files.
        ".venv": Kind(markers: pythonProject, role: .dependencies, restore: .venv),
        "venv": Kind(markers: pythonProject, role: .dependencies, restore: .venv),
        // tox `work_dir` (.tox) and nox `envdir` (.nox) hold virtual environments.
        ".tox": Kind(markers: ["tox.ini", "pyproject.toml", "setup.cfg"], role: .dependencies, restore: .testEnvs),
        ".nox": Kind(markers: ["noxfile.py"], role: .dependencies, restore: .testEnvs),
        // PEP 3147: bytecode in __pycache__ next to the source files.
        "__pycache__": Kind(markers: ["*.py"], role: .cache, restore: .pycache),
        // pytest cache plugin (rootdir/.pytest_cache), mypy `cache_dir`, Ruff `cache-dir`.
        ".pytest_cache": Kind(markers: ["pytest.ini", "pyproject.toml", "tox.ini", "setup.cfg", "conftest.py", "*.py"],
                              role: .cache, restore: .cache),
        ".mypy_cache": Kind(markers: ["mypy.ini", ".mypy.ini", "pyproject.toml", "setup.cfg", "*.py"], role: .cache, restore: .cache),
        ".ruff_cache": Kind(markers: ["pyproject.toml", "ruff.toml", ".ruff.toml", "*.py"], role: .cache, restore: .cache),
        // CocoaPods "Using CocoaPods": `pod install` creates Pods/ next to the Podfile.
        "Pods": Kind(markers: ["Podfile"], role: .dependencies, restore: .pods),
        // Swift Package Manager: build directory .build (checkouts, artifacts, products).
        ".build": Kind(markers: ["Package.swift"], role: .dependencies, restore: .swiftPM),
        // Composer `vendor-dir`, default vendor. Go and Ruby keep sources in vendor/, so only composer.json counts.
        "vendor": Kind(markers: ["composer.json"], role: .dependencies, restore: .composer),
        // .NET SDK: OutputPath bin/, BaseIntermediateOutputPath obj/. Anything else named bin is kept.
        "bin": Kind(markers: dotnetProject, role: .output, restore: .dotnet),
        "obj": Kind(markers: dotnetProject, role: .output, restore: .dotnet),
        // Dart `dart pub get` writes .dart_tool/package_config.json (also used by Flutter).
        ".dart_tool": Kind(markers: ["pubspec.yaml"], role: .cache, restore: .pub),
    ]

    /// Subfolders where a tool keeps its own git clones; a `.git` there is the tool's, not the user's.
    /// SwiftPM clones dependencies into .build/checkouts from mirrors in .build/repositories.
    static let toolClones: [String: [String]] = [".build": ["checkouts", "repositories"]]

    public static let targets: Set<String> = Set(kinds.keys)

    /// Usual project folders below the home folder. Only existing ones are used.
    public static let defaultRoots = [
        "Developer",          // Finder gives ~/Developer its own icon (Xcode convention)
        "Projects", "Code", "src", "Repos", "Workspace", "dev",
        "GitHub",
        "Documents/GitHub",   // GitHub Desktop's default clone location
        ".codex/worktrees",   // Codex agent worktrees
        ".claude/worktrees",  // Claude Code agent worktrees
    ]

    // MARK: - Search locations

    public static func configURL(home: String = UserHome.path) -> URL {
        URL(fileURLWithPath: home).appending(path: ".config/swabr/purge_paths")
    }

    /// The saved locations (one path per line, `~` allowed) or, without a config file, the existing defaults.
    public static func roots(home: String = UserHome.path) -> [String] {
        let url = configURL(home: home)
        var seen = Set<String>()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return defaultRoots.map { home + "/" + $0 }
                .filter { DirectoryScanner.isDirectory($0) && seen.insert(resolved($0)).inserted }
        }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .map { PathGlob.expandTilde($0, home: home) }
            .filter { seen.insert($0).inserted }
    }

    public static func saveRoots(_ roots: [String], home: String = UserHome.path) throws {
        let url = configURL(home: home)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let lines = roots.map { $0.hasPrefix(home + "/") ? "~" + $0.dropFirst(home.count) : $0 }
        try (lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    struct Root: Sendable, Hashable {
        let path: String
        /// On an external volume below `/Volumes`.
        let external: Bool
    }

    /// A location we may search: below the home folder, or explicitly listed on an external volume
    /// with no link anywhere from the volume down.
    static func usableRoot(_ raw: String, home: String, volumes: String = volumes) -> Root? {
        var path = PathGlob.expandTilde(raw.trimmingCharacters(in: .whitespaces), home: home)
        while path.count > 1 && path.hasSuffix("/") { path.removeLast() }
        guard path.hasPrefix("/"), !PathSafety.hasControlCharacters(path) else { return nil }
        let comps = path.split(separator: "/")
        guard !comps.contains("."), !comps.contains("..") else { return nil }
        if path == home || path.hasPrefix(home + "/") { return Root(path: path, external: false) }
        guard path.hasPrefix(volumes + "/"), linkFree(path, down: volumes) else { return nil }
        return Root(path: path, external: true)
    }

    /// True when `path` and every folder above it, up to but excluding `stop`, is a real folder.
    static func linkFree(_ path: String, down stop: String) -> Bool {
        var dir = path
        while dir.count > stop.count {
            var st = stat()
            guard lstat(dir, &st) == 0, (st.st_mode & S_IFMT) == S_IFDIR else { return false }
            dir = (dir as NSString).deletingLastPathComponent
        }
        return dir == stop
    }

    // MARK: - Scan

    struct Candidate: Sendable {
        let path: String
        let name: String
        let kind: Kind
        let root: Root
        var project: String { (path as NSString).deletingLastPathComponent }
    }

    public static func scan(roots: [String], home: String = UserHome.path) async -> [ProjectArtifact] {
        await scan(roots: roots, home: home, volumes: volumes)
    }

    static func scan(roots: [String], home: String, volumes: String, git: String? = gitExecutable,
                     gitTimeout: TimeInterval = gitTimeout) async -> [ProjectArtifact] {
        let usable = Array(Set(roots.compactMap { usableRoot($0, home: home, volumes: volumes) }))
        // A location inside another one would be searched twice.
        let tops = usable.filter { r in !usable.contains { $0 != r && r.path.hasPrefix($0.path + "/") } }
        let depth = max(1, maxDepth)
        var candidates: [Candidate] = []
        for root in tops.sorted(by: { $0.path < $1.path }) {
            candidates += collect(in: root, home: home, depth: depth)
        }
        let cwds = Processes.workingDirectories()

        let found = await parallel(candidates) { c -> (Candidate, Int64)? in
            if refusal(forPath: c.path, root: c.root, home: home, volumes: volumes) != nil { return nil }
            let check = protection(of: c.path, kind: c.kind, home: home, git: git, gitTimeout: gitTimeout)
            return check.refusal == nil ? (c, check.bytes) : nil
        }.compactMap { $0 }

        let projects = Array(Set(found.map(\.0.project)))
        let activity = await parallel(projects) { lastActivity(of: $0) }
        let dates = Dictionary(uniqueKeysWithValues: zip(projects, activity))

        return found.map { c, bytes in
            ProjectArtifact(path: c.path, project: c.project, name: c.name, bytes: bytes,
                            lastActivity: dates[c.project] ?? nil,
                            inUse: inUse(project: c.project, root: c.root.path, workingDirectories: cwds))
        }
        .sorted { $0.bytes != $1.bytes ? $0.bytes > $1.bytes : $0.path < $1.path }
    }

    /// Folder names whose content never holds projects worth searching.
    private static let opaqueSuffixes = [".app", ".bundle", ".framework", ".xcodeproj", ".xcworkspace", ".xcarchive",
                                         ".photoslibrary", ".musiclibrary"]

    /// Walks `root` and returns folders whose name and neighbouring project file match a kind.
    /// Hidden folders are only looked at as candidates, never entered; found artifacts are not entered either.
    static func collect(in root: Root, home: String, depth: Int) -> [Candidate] {
        guard DirectoryScanner.isDirectory(root.path) else { return [] }
        var out: [Candidate] = []
        var pending = [(root.path, 0)]
        while let (dir, level) = pending.popLast() {
            if Task.isCancelled { break }
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for name in names.sorted() {
                let path = dir + "/" + name
                guard DirectoryScanner.isDirectory(path) else { continue }
                if let kind = kinds[name], hasMarker(kind.markers, among: names) {
                    out.append(Candidate(path: path, name: name, kind: kind, root: root))
                    continue
                }
                if name.hasPrefix(".") || opaqueSuffixes.contains(where: name.hasSuffix) { continue }
                if path == home + "/Library" { continue }
                if level + 1 < depth { pending.append((path, level + 1)) }
            }
        }
        return out
    }

    static func hasMarker(_ markers: [String], among names: [String]) -> Bool {
        markers.contains { marker in
            marker.hasPrefix("*.") ? names.contains { $0.hasSuffix(marker.dropFirst()) && $0.count > marker.count - 1 }
                : names.contains(marker)
        }
    }

    // MARK: - Protection

    enum Refusal: Equatable, Sendable {
        case path(String)
        case outsideRoots
        case derivedData
        case nestedRepository
        case keyFile
        case trackedByGit
        case gitTimedOut
        case gitFailed

        var reason: String {
            switch self {
            case .path(let why): why
            case .outsideRoots: String(localized: "außerhalb der Suchorte", bundle: .module)
            case .derivedData: String(localized: "geschützter Ordner", bundle: .module)
            case .nestedRepository: String(localized: "enthält ein eigenes git-Repository", bundle: .module)
            case .keyFile: String(localized: "enthält Schlüsseldateien", bundle: .module)
            case .trackedByGit: String(localized: "enthält von git verfolgte Dateien", bundle: .module)
            case .gitTimedOut: String(localized: "Zeitüberschreitung", bundle: .module)
            case .gitFailed: String(localized: "git-Prüfung fehlgeschlagen", bundle: .module)
            }
        }
    }

    /// Path rules: inside the home folder `PathSafety`, on an external volume the same checks without the
    /// home folder (absolute, no control characters, no relative parts, no link below the volume).
    static func refusal(forPath path: String, root: Root, home: String, volumes: String) -> Refusal? {
        guard path.hasPrefix(root.path + "/") else { return .outsideRoots }
        if !root.external {
            if case .refused(let why) = PathSafety.check(path, home: home) { return .path(why) }
            return nil
        }
        if PathSafety.hasControlCharacters(path) { return .path(String(localized: "Pfad enthält Steuerzeichen", bundle: .module)) }
        let comps = path.split(separator: "/")
        if comps.contains("..") || comps.contains(".") { return .path(String(localized: "relativer Pfadbestandteil", bundle: .module)) }
        guard path.hasPrefix(volumes + "/"), linkFree((path as NSString).deletingLastPathComponent, down: volumes) else {
            return .path(String(localized: "Symlink im Pfad", bundle: .module))
        }
        return nil
    }

    /// The content rules, measured in the same walk: size, nested repositories, key files, git-tracked files.
    static func protection(of path: String, kind: Kind, home: String, git: String? = gitExecutable,
                           gitTimeout: TimeInterval = gitTimeout) -> (bytes: Int64, refusal: Refusal?) {
        let derived = home + "/Library/Developer/Xcode/DerivedData"
        if path == derived || path.hasPrefix(derived + "/") { return (0, .derivedData) }

        var st = stat()
        guard lstat(path, &st) == 0 else { return (0, .path(String(localized: "nicht mehr vorhanden oder verändert", bundle: .module))) }
        var bytes = Int64(st.st_blocks) * 512
        let name = (path as NSString).lastPathComponent
        let clones = (toolClones[name] ?? []).map { path + "/" + $0 + "/" }
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey]
        if let walk = FileManager.default.enumerator(at: URL(fileURLWithPath: path, isDirectory: true),
                                                     includingPropertiesForKeys: keys, options: [], errorHandler: { _, _ in true }) {
            for case let child as URL in walk {
                let entry = child.lastPathComponent
                if entry == ".git" {
                    let p = child.path
                    if !clones.contains(where: { p.hasPrefix($0) }) { return (bytes, .nestedRepository) }
                } else if isKeyFile(entry), kind.role != .dependencies || walk.level == 1 {
                    return (bytes, .keyFile)
                }
                bytes += Int64((try? child.resourceValues(forKeys: Set(keys)))?.totalFileAllocatedSize ?? 0)
            }
        }

        switch gitState(of: path, git: git, timeout: gitTimeout) {
        case .untracked: return (bytes, nil)
        case .tracked: return (bytes, .trackedByGit)
        case .timedOut: return (bytes, .gitTimedOut)
        case .failed: return (bytes, .gitFailed)
        }
    }

    /// Deployment keys and secrets: `*-keypair.json` (e.g. Solana CLI), PEM and PKCS#12 files, dotenv files.
    static func isKeyFile(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasSuffix("-keypair.json") || lower.hasSuffix(".pem") || lower.hasSuffix(".p12") || lower.hasPrefix(".env")
    }

    enum GitState: Equatable, Sendable { case untracked, tracked, timedOut, failed }

    /// Whether git tracks anything inside `path`. Outside a work tree git is not asked at all.
    static func gitState(of path: String, git: String? = gitExecutable, timeout: TimeInterval = gitTimeout) -> GitState {
        let project = (path as NSString).deletingLastPathComponent
        guard insideWorkTree(project) else { return .untracked }
        guard let git else { return .failed }
        // Nothing from our own environment may point git at another repository.
        var env = ProcessInfo.processInfo.environment.filter { !$0.key.hasPrefix("GIT_") }
        env["GIT_TERMINAL_PROMPT"] = "0"
        env["GIT_OPTIONAL_LOCKS"] = "0"
        let name = (path as NSString).lastPathComponent
        switch ToolRun.run(git, ["-C", project, "ls-files", "-z", "--", name], timeout: timeout, environment: env) {
        case .exited(0, let output): return output.isEmpty ? .untracked : .tracked
        case .exited: return .failed
        case .timedOut: return .timedOut
        case .failed: return .failed
        }
    }

    /// A `.git` folder or file (worktrees, submodules) in `dir` or above.
    static func insideWorkTree(_ dir: String) -> Bool {
        var d = dir
        while !d.isEmpty {
            var st = stat()
            if lstat(d == "/" ? "/.git" : d + "/.git", &st) == 0 { return true }
            if d == "/" { break }
            d = (d as NSString).deletingLastPathComponent
        }
        return false
    }

    /// git from the Command Line Tools, the selected Xcode or Homebrew. `/usr/bin/git` alone is avoided:
    /// without developer tools it is a stub that asks to install them.
    static let gitExecutable: String? = {
        let fm = FileManager.default
        var candidates = ["/Library/Developer/CommandLineTools/usr/bin/git"]
        if let dev = try? fm.destinationOfSymbolicLink(atPath: "/var/db/xcode_select_link") { candidates.append(dev + "/usr/bin/git") }
        candidates += ["/Applications/Xcode.app/Contents/Developer/usr/bin/git", "/opt/homebrew/bin/git", "/usr/local/bin/git"]
        return candidates.first { fm.isExecutableFile(atPath: $0) }
    }()

    // MARK: - Activity

    /// Newest modification of a regular file in the project, skipping hidden folders and artifacts.
    /// Looks at most `limit` files up to `depth` levels down.
    static func lastActivity(of project: String, limit: Int = 2_000, depth: Int = 3) -> Date? {
        var newest: Date?
        var seen = 0
        var pending = [(project, 0)]
        while let (dir, level) = pending.popLast(), seen < limit {
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for name in names {
                let path = dir + "/" + name
                var st = stat()
                guard lstat(path, &st) == 0 else { continue }
                switch st.st_mode & S_IFMT {
                case S_IFDIR:
                    if level + 1 < depth, !name.hasPrefix("."), kinds[name] == nil { pending.append((path, level + 1)) }
                case S_IFREG:
                    seen += 1
                    let date = DirectoryScanner.date(st)
                    if newest.map({ date > $0 }) ?? true { newest = date }
                default:
                    break
                }
                if seen >= limit { break }
            }
        }
        return newest
    }

    /// A process works in the project, or in a folder above it that still lies below the search location
    /// (a dev server started at a monorepo's top uses the packages' dependencies too).
    static func inUse(project: String, root: String, workingDirectories cwds: [String]) -> Bool {
        if Processes.isInUse(project, workingDirectories: cwds) { return true }
        let real = resolved(project)
        if real != project, Processes.isInUse(real, workingDirectories: cwds) { return true }
        return cwds.contains { cwd in cwd.hasPrefix(root + "/") && project.hasPrefix(cwd + "/") }
    }

    static func resolved(_ path: String) -> String {
        guard let r = realpath(path, nil) else { return path }
        defer { free(r) }
        return String(cString: r)
    }

    // MARK: - Delete

    /// Removes the artifacts. Each one is checked again right before: still a real folder with a known name next
    /// to its project file, inside a search location, not protected, and no process in its project.
    /// `runPrivileged` removes artifacts the user may not delete (they belong to root, e.g. made by Docker).
    public static func delete(_ artifacts: [ProjectArtifact], roots: [String], home: String = UserHome.path,
                              toTrash: Bool = false, log: OperationLog = OperationLog(),
                              runPrivileged: (@Sendable (String) -> String?)? = nil) -> CleanReport {
        delete(artifacts, roots: roots, home: home, toTrash: toTrash, log: log, volumes: volumes, runPrivileged: runPrivileged)
    }

    static func delete(_ artifacts: [ProjectArtifact], roots: [String], home: String, toTrash: Bool, log: OperationLog,
                       volumes: String, git: String? = gitExecutable, gitTimeout: TimeInterval = gitTimeout,
                       runPrivileged: (@Sendable (String) -> String?)? = nil) -> CleanReport {
        let usable = roots.compactMap { usableRoot($0, home: home, volumes: volumes) }
        var report = CleanReport()
        var needRoot: [(path: String, name: String, bytes: Int64, error: ProtectedPath)] = []
        for artifact in artifacts {
            let path = artifact.path
            func refuse(_ why: String, _ kind: ProtectedPath.Kind = .protectedPath) {
                report.failures.append(.init(path: path, reason: why, kind: kind))
            }
            guard let root = usable.first(where: { path.hasPrefix($0.path + "/") }) else {
                refuse(Refusal.outsideRoots.reason)
                continue
            }
            if let r = refusal(forPath: path, root: root, home: home, volumes: volumes) {
                refuse(r.reason)
                continue
            }
            guard DirectoryScanner.isDirectory(path) else {
                refuse(String(localized: "nicht mehr vorhanden oder verändert", bundle: .module))
                continue
            }
            let name = (path as NSString).lastPathComponent
            guard let kind = kinds[name] else {
                refuse(String(localized: "kein bekannter Build-Ordner", bundle: .module))
                continue
            }
            let project = (path as NSString).deletingLastPathComponent
            guard let siblings = try? FileManager.default.contentsOfDirectory(atPath: project),
                  hasMarker(kind.markers, among: siblings) else {
                refuse(String(localized: "kein passendes Projektkennzeichen", bundle: .module))
                continue
            }
            let check = protection(of: path, kind: kind, home: home, git: git, gitTimeout: gitTimeout)
            if let r = check.refusal {
                refuse(r.reason)
                continue
            }
            if inUse(project: project, root: root.path, workingDirectories: Processes.workingDirectories()) {
                refuse(String(localized: "ein Prozess läuft im Projekt", bundle: .module), .running)
                continue
            }
            do {
                if toTrash {
                    try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
                } else {
                    try FileManager.default.removeItem(atPath: path)
                }
                report.removedBytes += check.bytes
                report.removedCount += 1
                log.record(action: toTrash ? "TRASH" : "REMOVE", path: path, bytes: check.bytes, label: "Projekte: \(name)")
            } catch {
                let failure = ProtectedPath(path: path, error: error)
                if failure.kind == .permission, runPrivileged != nil {
                    needRoot.append((path, name, check.bytes, failure))
                } else {
                    report.failures.append(failure)
                }
            }
        }
        guard let runPrivileged, !needRoot.isEmpty else { return report }

        // Every artifact passed all checks above; root only moves it into the Trash and hands it back.
        let allowed = usable.map { $0.path + "/" }
        let moved = RootTrash.move(needRoot.map(\.path), home: home, allowedRoots: allowed, runPrivileged: runPrivileged)
        for item in needRoot {
            guard let target = moved[item.path] else {
                report.failures.append(item.error)
                continue
            }
            if !toTrash { try? FileManager.default.removeItem(atPath: target) }
            report.removedBytes += item.bytes
            report.removedCount += 1
            log.record(action: toTrash ? "TRASH" : "REMOVE", path: item.path, bytes: item.bytes, label: "Projekte: \(item.name)")
        }
        return report
    }

    // MARK: - Helpers

    /// Runs `body` for every element, a few at a time, keeping the order.
    static func parallel<T: Sendable, R: Sendable>(_ items: [T], _ body: @escaping @Sendable (T) -> R) async -> [R] {
        guard !items.isEmpty else { return [] }
        var results = [R?](repeating: nil, count: items.count)
        await withTaskGroup(of: (Int, R).self) { group in
            let width = max(2, ProcessInfo.processInfo.activeProcessorCount)
            var next = 0
            while next < min(width, items.count) {
                let i = next
                group.addTask { (i, body(items[i])) }
                next += 1
            }
            for await (i, r) in group {
                results[i] = r
                if next < items.count {
                    let j = next
                    group.addTask { (j, body(items[j])) }
                    next += 1
                }
            }
        }
        return results.map { $0! }
    }
}

// MARK: - Installers

/// A leftover installation file.
public struct InstallerFile: Identifiable, Sendable, Hashable {
    public var id: String { path }
    public let path: String
    public let bytes: Int64
    /// Readable name of the place it was found.
    public let source: String
    public let modified: Date?
    public var name: String { (path as NSString).lastPathComponent }

    public init(path: String, bytes: Int64, source: String, modified: Date?) {
        self.path = path
        self.bytes = bytes
        self.source = source
        self.modified = modified
    }
}

public enum InstallerFinder {
    /// Disk images, installer packages, Xcode archives and ISO images. Zip files only count when they hold an installer.
    static let installerExtensions: Set<String> = ["dmg", "pkg", "mpkg", "xip", "iso"]
    static let zipContent = [".app", ".pkg", ".mpkg", ".dmg"]

    /// Places searched: the folder and one level of subfolders. App folders come first, so a file there keeps
    /// the app's name as source.
    static func locations(home: String) -> [(path: String, source: String)] {
        [
            // Apple Mail keeps opened attachments in "Mail Downloads" (sandboxed container, older Mail below ~/Library).
            (home + "/Library/Containers/com.apple.mail/Data/Library/Mail Downloads", "Mail"),
            (home + "/Library/Mail Downloads", "Mail"),
            // Telegram Desktop's default download path.
            (home + "/Downloads/Telegram Desktop", "Telegram"),
            (home + "/Downloads", String(localized: "Downloads", bundle: .module)),
            (home + "/Desktop", String(localized: "Schreibtisch", bundle: .module)),
            (home + "/Documents", String(localized: "Dokumente", bundle: .module)),
        ]
    }

    public static func scan(home: String = UserHome.path) -> [InstallerFile] {
        var seen = Set<String>()
        var out: [InstallerFile] = []
        for (dir, source) in locations(home: home) where DirectoryScanner.isDirectory(dir) {
            for path in candidates(in: dir) where seen.insert(path).inserted {
                guard PathSafety.check(path, home: home) == .ok, isInstaller(path) else { continue }
                out.append(InstallerFile(path: path, bytes: DiskSize.allocatedSize(of: path), source: source,
                                         modified: DirectoryScanner.modified(path)))
            }
        }
        return out.sorted { $0.bytes != $1.bytes ? $0.bytes > $1.bytes : $0.path < $1.path }
    }

    /// Files with an installer extension in `dir` and its direct subfolders. Placeholders of files that
    /// only live in iCloud are skipped (reading them would download them).
    static func candidates(in dir: String) -> [String] {
        var out: [String] = []
        func visit(_ folder: String, level: Int) {
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder) else { return }
            for name in names.sorted() where !name.hasPrefix(".") {
                let path = folder + "/" + name
                var st = stat()
                guard lstat(path, &st) == 0, st.st_flags & DiskWalker.datalessFlag == 0 else { continue }
                let ext = (name as NSString).pathExtension.lowercased()
                switch st.st_mode & S_IFMT {
                case S_IFREG where installerExtensions.contains(ext) || ext == "zip":
                    out.append(path)
                case S_IFDIR where ext == "pkg" || ext == "mpkg":
                    out.append(path)   // bundle-style installer package
                case S_IFDIR where level == 0 && !["app", "bundle", "framework", "photoslibrary"].contains(ext):
                    visit(path, level: 1)
                default:
                    break
                }
            }
        }
        visit(dir, level: 0)
        return out
    }

    static func isInstaller(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return ext == "zip" ? zipHoldsInstaller(path) : installerExtensions.contains(ext)
    }

    /// Asks `zipinfo -1` for the entry names; an app, package or disk image at the top level makes it an installer.
    static func zipHoldsInstaller(_ path: String) -> Bool {
        guard case .exited(0, let data) = ToolRun.run("/usr/bin/zipinfo", ["-1", path], timeout: 10) else { return false }
        for line in String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline) {
            guard let top = line.split(separator: "/", omittingEmptySubsequences: false).first?.lowercased(),
                  top != "__macosx" else { continue }
            if zipContent.contains(where: { top.hasSuffix($0) && top.count > $0.count }) { return true }
        }
        return false
    }
}
