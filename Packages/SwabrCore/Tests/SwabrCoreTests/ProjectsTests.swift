import Foundation
import Testing
@testable import SwabrCore

private func rel(_ found: [ProjectArtifact], _ h: FakeHome) -> Set<String> {
    Set(found.map { String($0.path.dropFirst(h.path.count + 1)) })
}

private func markerFile(_ marker: String) -> String {
    marker.hasPrefix("*.") ? "main" + marker.dropFirst() : marker
}

@discardableResult
private func git(_ args: [String], in dir: String) throws -> Int32 {
    let exe = try #require(ProjectPurge.gitExecutable)
    guard case .exited(let status, _) = ToolRun.run(exe, ["-C", dir] + args, timeout: 60) else { return -1 }
    return status
}

/// Folders keep their name as the top entry; a single file is stored as it is.
private func zip(_ source: String, to zip: String) {
    let keepParent = DirectoryScanner.isDirectory(source) ? ["--keepParent"] : []
    if case .exited(let status, _) = ToolRun.run("/usr/bin/ditto", ["-c", "-k"] + keepParent + [source, zip], timeout: 60) {
        #expect(status == 0)
    } else {
        Issue.record("ditto did not run")
    }
}

// MARK: - Marker table

@Test func everyKindNeedsItsOwnProjectFile() async throws {
    let h = try FakeHome()
    var expected = Set<String>()
    for (i, (name, kind)) in ProjectPurge.kinds.sorted(by: { $0.key < $1.key }).enumerated() {
        for (j, marker) in kind.markers.enumerated() {
            try h.file("dev/p\(i)_\(j)/\(markerFile(marker))", bytes: 10)
            try h.file("dev/p\(i)_\(j)/\(name)/payload.txt", bytes: 100)
            expected.insert("dev/p\(i)_\(j)/\(name)")
        }
        // Same folder without a matching project file.
        try h.file("dev/n\(i)/README.md", bytes: 10)
        try h.file("dev/n\(i)/\(name)/payload.txt", bytes: 100)
    }
    let found = await ProjectPurge.scan(roots: [h.path + "/dev"], home: h.path)
    #expect(rel(found, h) == expected)
    #expect(found.allSatisfy { !$0.impact.isEmpty && $0.project == ($0.path as NSString).deletingLastPathComponent })
}

@Test func vendorAndBinNeedTheirOwnTool() async throws {
    let h = try FakeHome()
    try h.file("dev/goapp/go.mod", bytes: 10)
    try h.file("dev/goapp/vendor/github.com/x/y.go", bytes: 10)        // Go vendor is source
    try h.file("dev/rubyapp/Gemfile", bytes: 10)
    try h.file("dev/rubyapp/vendor/bundle/x.rb", bytes: 10)
    try h.file("dev/tool/package.json", bytes: 10)
    try h.file("dev/tool/bin/run.sh", bytes: 10)                        // scripts, not .NET output
    try h.file("dev/php/composer.json", bytes: 10)
    try h.file("dev/php/vendor/autoload.php", bytes: 10)
    try h.file("dev/net/App.csproj", bytes: 10)
    try h.file("dev/net/bin/Debug/App.dll", bytes: 10)
    try h.file("dev/net/obj/project.assets.json", bytes: 10)
    let found = await ProjectPurge.scan(roots: [h.path + "/dev"], home: h.path)
    #expect(rel(found, h) == ["dev/php/vendor", "dev/net/bin", "dev/net/obj"])
}

@Test func artifactsAreNotEnteredAndHiddenFoldersOnlyChecked() async throws {
    let h = try FakeHome()
    try h.file("dev/web/package.json", bytes: 10)
    try h.file("dev/web/node_modules/pkg/package.json", bytes: 10)
    try h.file("dev/web/node_modules/pkg/node_modules/inner.js", bytes: 10)
    try h.file("dev/.hidden/app/package.json", bytes: 10)                // hidden folders are not entered
    try h.file("dev/.hidden/app/node_modules/x.js", bytes: 10)
    try h.file("dev/a/b/c/d/e/f/package.json", bytes: 10)                // deeper than maxDepth
    try h.file("dev/a/b/c/d/e/f/node_modules/x.js", bytes: 10)
    let found = await ProjectPurge.scan(roots: [h.path + "/dev"], home: h.path)
    #expect(rel(found, h) == ["dev/web/node_modules"])
}

// MARK: - Protection

@Test func gitTrackedContentIsProtected() async throws {
    let h = try FakeHome()
    let project = h.path + "/dev/app"
    try h.file("dev/app/package.json", bytes: 10)
    try h.file("dev/app/dist/app.js", bytes: 100)          // committed build output
    try h.file("dev/app/build/out.js", bytes: 100)         // ignored build output
    #expect(try git(["init", "-q"], in: project) == 0)
    #expect(try git(["add", "package.json", "dist/app.js"], in: project) == 0)
    #expect(ProjectPurge.gitState(of: project + "/dist") == .tracked)
    #expect(ProjectPurge.gitState(of: project + "/build") == .untracked)
    let found = await ProjectPurge.scan(roots: [h.path + "/dev"], home: h.path)
    #expect(rel(found, h) == ["dev/app/build"])
}

@Test func slowOrMissingGitCountsAsProtected() async throws {
    let h = try FakeHome()
    try h.file("dev/app/package.json", bytes: 10)
    try h.file("dev/app/dist/app.js", bytes: 100)
    try FileManager.default.createDirectory(atPath: h.path + "/dev/app/.git", withIntermediateDirectories: true)
    let hanging = h.path + "/hanging-git"
    try "#!/bin/sh\nexec /bin/sleep 30\n".write(toFile: hanging, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hanging)

    let dist = h.path + "/dev/app/dist"
    #expect(ProjectPurge.gitState(of: dist, git: hanging, timeout: 0.2) == .timedOut)
    #expect(ProjectPurge.gitState(of: dist, git: nil) == .failed)
    #expect(ProjectPurge.gitState(of: dist, git: "/usr/bin/false") == .failed)
    let kind = try #require(ProjectPurge.kinds["dist"])
    #expect(ProjectPurge.protection(of: dist, kind: kind, home: h.path, git: hanging, gitTimeout: 0.2).refusal == .gitTimedOut)
    let found = await ProjectPurge.scan(roots: [h.path + "/dev"], home: h.path, volumes: "/Volumes", git: hanging, gitTimeout: 0.2)
    #expect(found.isEmpty)
}

@Test func nestedRepositoriesAndKeyFilesAreProtected() async throws {
    let h = try FakeHome()
    try h.file("dev/a/package.json", bytes: 10)
    try h.file("dev/a/node_modules/forked/.git/HEAD", bytes: 10)        // a clone the user works in
    try h.file("dev/b/package.json", bytes: 10)
    try h.file("dev/b/dist/certs/server.pem", bytes: 10)
    try h.file("dev/c/build.gradle", bytes: 10)
    try h.file("dev/c/build/resources/release.p12", bytes: 10)
    try h.file("dev/d/package.json", bytes: 10)
    try h.file("dev/d/build/.env.production", bytes: 10)
    try h.file("dev/e/pyproject.toml", bytes: 10)
    try h.file("dev/e/.venv/.env", bytes: 10)                            // top level of a dependency folder
    try h.file("dev/f/Cargo.toml", bytes: 10)
    try h.file("dev/f/target/deploy/program-keypair.json", bytes: 10)
    // Package payload deep inside dependencies does not count: pip and requests ship certifi's CA bundle.
    try h.file("dev/g/requirements.txt", bytes: 10)
    try h.file("dev/g/.venv/lib/python3.13/site-packages/certifi/cacert.pem", bytes: 10)
    // SwiftPM's own clones of dependencies.
    try h.file("dev/h/Package.swift", bytes: 10)
    try h.file("dev/h/.build/checkouts/dep/.git/HEAD", bytes: 10)
    try h.file("dev/i/Package.swift", bytes: 10)
    try h.file("dev/i/.build/debug/mine/.git/HEAD", bytes: 10)
    let found = await ProjectPurge.scan(roots: [h.path + "/dev"], home: h.path)
    #expect(rel(found, h) == ["dev/g/.venv", "dev/h/.build"])
}

@Test func globalDerivedDataIsProtected() throws {
    let h = try FakeHome()
    try h.file("Library/Developer/Xcode/DerivedData/App-abc/Build/x", bytes: 10)
    let kind = try #require(ProjectPurge.kinds["build"])
    let derived = h.path + "/Library/Developer/Xcode/DerivedData"
    #expect(ProjectPurge.protection(of: derived, kind: kind, home: h.path).refusal == .derivedData)
    #expect(ProjectPurge.protection(of: derived + "/App-abc", kind: kind, home: h.path).refusal == .derivedData)
}

// MARK: - Processes

@Test func processInProjectBlocksDeletion() async throws {
    let h = try FakeHome()
    try h.file("dev/web/package.json", bytes: 10)
    try h.file("dev/web/node_modules/x.js", bytes: 1_000)
    let root = h.path + "/dev"
    let log = OperationLog(home: h.path)

    let server = Process()
    server.executableURL = URL(fileURLWithPath: "/bin/sleep")
    server.arguments = ["60"]
    server.currentDirectoryURL = URL(fileURLWithPath: h.path + "/dev/web")
    // A termination handler, not waitUntilExit: that can miss the exit on a test thread and hang forever.
    let exited = DispatchSemaphore(value: 0)
    server.terminationHandler = { _ in exited.signal() }
    try server.run()
    defer { if server.isRunning { server.terminate() } }

    let found = await ProjectPurge.scan(roots: [root], home: h.path)
    #expect(found.count == 1 && found[0].inUse)
    let blocked = ProjectPurge.delete(found, roots: [root], home: h.path, log: log)
    #expect(blocked.removedCount == 0)
    #expect(blocked.failures.map(\.kind) == [.running])
    #expect(h.exists("dev/web/node_modules"))

    server.terminate()
    let gone = await withCheckedContinuation { c in
        DispatchQueue.global().async { c.resume(returning: exited.wait(timeout: .now() + 10) == .success) }
    }
    #expect(gone)
    let done = ProjectPurge.delete(found, roots: [root], home: h.path, log: log)
    #expect(done.removedCount == 1 && done.failures.isEmpty && done.removedBytes > 0)
    #expect(!h.exists("dev/web/node_modules"))
    let text = try String(contentsOf: log.url, encoding: .utf8)
    #expect(text.contains("\tREMOVE\t") && text.contains("\tProjekte: node_modules\t"))
}

@Test func processAboveTheProjectCountsInsideTheSearchLocation() {
    let cwds = ["/r/mono", "/r"]
    #expect(ProjectPurge.inUse(project: "/r/mono/packages/a", root: "/r", workingDirectories: ["/r/mono"]))
    #expect(!ProjectPurge.inUse(project: "/r/mono/packages/a", root: "/r", workingDirectories: ["/r"]))
    #expect(!ProjectPurge.inUse(project: "/r/other", root: "/r", workingDirectories: cwds))
    #expect(Processes.isInUse("/r/mono", workingDirectories: ["/r/mono"]))
    #expect(Processes.isInUse("/r/mono/", workingDirectories: ["/r/mono/x"]))
    #expect(!Processes.isInUse("/r/mono", workingDirectories: ["/r/monorepo", "/r"]))
}

// MARK: - Delete

@Test func deleteChecksEveryArtifactAgain() async throws {
    let h = try FakeHome()
    for p in ["a", "b", "c", "d"] {
        try h.file("dev/\(p)/package.json", bytes: 10)
        try h.file("dev/\(p)/node_modules/x.js", bytes: 10)
    }
    let root = h.path + "/dev"
    let found = await ProjectPurge.scan(roots: [root], home: h.path).sorted { $0.path < $1.path }
    #expect(found.count == 4)
    let fm = FileManager.default
    // a: replaced by a link; b: project file gone; c: now tracked by git; d: outside the given roots.
    try fm.removeItem(atPath: h.path + "/dev/a/node_modules")
    try fm.createSymbolicLink(atPath: h.path + "/dev/a/node_modules", withDestinationPath: h.path + "/dev/b/node_modules")
    try fm.removeItem(atPath: h.path + "/dev/b/package.json")
    #expect(try git(["init", "-q"], in: h.path + "/dev/c") == 0)
    #expect(try git(["add", "-f", "node_modules/x.js"], in: h.path + "/dev/c") == 0)
    let fake = ProjectArtifact(path: h.path + "/dev/d/stuff", project: h.path + "/dev/d", name: "stuff", bytes: 1, lastActivity: nil)
    try h.file("dev/d/stuff/x", bytes: 10)

    let report = ProjectPurge.delete(found.dropLast() + [fake], roots: [root], home: h.path, log: OperationLog(home: h.path))
    #expect(report.removedCount == 0)
    #expect(report.failures.count == 4 && report.failures.allSatisfy { $0.kind == .protectedPath })
    let outside = ProjectPurge.delete([found[3]], roots: [h.path + "/elsewhere"], home: h.path, log: OperationLog(home: h.path))
    #expect(outside.removedCount == 0 && outside.failures.map(\.kind) == [.protectedPath])
    for p in ["dev/b/node_modules", "dev/c/node_modules", "dev/d/node_modules", "dev/d/stuff"] { #expect(h.exists(p)) }
}

// MARK: - External volumes

@Test func externalVolumesOnlyBelowAListedLocation() async throws {
    let disk = try FakeHome()
    let home = try FakeHome()
    let volumes = disk.path + "/Volumes"
    try disk.file("Volumes/Ext/dev/web/package.json", bytes: 10)
    try disk.file("Volumes/Ext/dev/web/node_modules/x.js", bytes: 1_000)
    try FileManager.default.createSymbolicLink(atPath: volumes + "/Link", withDestinationPath: volumes + "/Ext")
    let listed = volumes + "/Ext/dev"

    #expect(ProjectPurge.usableRoot(listed, home: home.path, volumes: volumes)?.external == true)
    #expect(ProjectPurge.usableRoot(volumes + "/Link/dev", home: home.path, volumes: volumes) == nil)
    #expect(ProjectPurge.usableRoot(volumes + "/Ext/de\u{1B}v", home: home.path, volumes: volumes) == nil)
    #expect(ProjectPurge.usableRoot(volumes + "/Ext/../Ext/dev", home: home.path, volumes: volumes) == nil)
    // Not below the home folder and not below the volumes folder.
    #expect(await ProjectPurge.scan(roots: [listed], home: home.path).isEmpty)
    #expect(await ProjectPurge.scan(roots: [volumes + "/Link/dev"], home: home.path, volumes: volumes).isEmpty)

    let found = await ProjectPurge.scan(roots: [listed], home: home.path, volumes: volumes)
    #expect(found.map(\.name) == ["node_modules"])
    let log = OperationLog(home: home.path)
    let unlisted = ProjectPurge.delete(found, roots: [home.path], home: home.path, toTrash: false, log: log, volumes: volumes)
    #expect(unlisted.removedCount == 0 && unlisted.failures.map(\.kind) == [.protectedPath])
    #expect(disk.exists("Volumes/Ext/dev/web/node_modules"))
    let done = ProjectPurge.delete(found, roots: [listed], home: home.path, toTrash: false, log: log, volumes: volumes)
    #expect(done.removedCount == 1)
    #expect(!disk.exists("Volumes/Ext/dev/web/node_modules"))
}

@Test func defaultRootsAndConfiguredRoots() throws {
    let h = try FakeHome()
    try FileManager.default.createDirectory(atPath: h.path + "/.claude/worktrees", withIntermediateDirectories: true)
    try FileManager.default.createDirectory(atPath: h.path + "/Code", withIntermediateDirectories: true)
    #expect(ProjectPurge.roots(home: h.path) == [h.path + "/Code", h.path + "/.claude/worktrees"])
    try ProjectPurge.saveRoots([], home: h.path)
    #expect(ProjectPurge.roots(home: h.path).isEmpty)
    try Data("# mine\n~/Code\n\n/Volumes/Ext/dev\n~/Code\n".utf8).write(to: ProjectPurge.configURL(home: h.path))
    #expect(ProjectPurge.roots(home: h.path) == [h.path + "/Code", "/Volumes/Ext/dev"])
}

// MARK: - Installers

@Test func zipCountsOnlyWithAnInstallerAtTheTop() throws {
    let h = try FakeHome()
    try h.file("stage/Setup.pkg", bytes: 1_000)
    try h.file("stage/Folder/Deep.app/Contents/Info.plist", bytes: 10)
    try h.file("stage/Photos/a.jpg", bytes: 1_000)
    try h.file("stage/Tool.app/Contents/Info.plist", bytes: 10)
    try FileManager.default.createDirectory(atPath: h.path + "/Downloads", withIntermediateDirectories: true)
    zip(h.path + "/stage/Setup.pkg", to: h.path + "/Downloads/Setup.zip")
    zip(h.path + "/stage/Tool.app", to: h.path + "/Downloads/Tool.zip")
    zip(h.path + "/stage/Folder", to: h.path + "/Downloads/Nested.zip")
    zip(h.path + "/stage/Photos", to: h.path + "/Downloads/Photos.zip")
    try h.file("Downloads/broken.zip", bytes: 100)
    try h.file("Desktop/Image.iso", bytes: 3_000)
    try h.file("Documents/Xcode.xip", bytes: 2_000)
    try h.file("Documents/deep/er/Old.dmg", bytes: 10)                  // two levels down: not searched
    try h.file("Library/Containers/com.apple.mail/Data/Library/Mail Downloads/0A1B/Invoice.pkg", bytes: 500)
    try h.file("Downloads/.hidden.dmg", bytes: 10)

    let found = InstallerFinder.scan(home: h.path)
    #expect(Set(found.map(\.name)) == ["Setup.zip", "Tool.zip", "Image.iso", "Xcode.xip", "Invoice.pkg"])
    #expect(found.map(\.bytes) == found.map(\.bytes).sorted(by: >))
    #expect(found.first { $0.name == "Invoice.pkg" }?.source == "Mail")
    #expect(found.first { $0.name == "Image.iso" }?.modified != nil)
}
