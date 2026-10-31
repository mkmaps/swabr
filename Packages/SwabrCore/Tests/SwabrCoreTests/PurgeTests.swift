import Foundation
import Testing
@testable import SwabrCore

@Test func purgeFindsArtifactsOnlyInsideProjects() async throws {
    let h = try FakeHome()
    try h.file("dev/web/package.json", bytes: 10)
    try h.file("dev/web/node_modules/lib/index.js", bytes: 50_000)
    try h.file("dev/web/node_modules/lib/deep/node_modules/x.js", bytes: 10)   // nested: counted with the outer one
    try h.file("dev/rust/Cargo.toml", bytes: 10)
    try h.file("dev/rust/target/debug/bin", bytes: 80_000)
    try h.file("dev/notes/build/keep.txt", bytes: 10)       // no project file: left alone
    try h.file("dev/tools/package.json", bytes: 10)
    try h.file("dev/tools/bin/script.sh", bytes: 10)          // bin without .NET project: protected
    try h.file("dev/keys/package.json", bytes: 10)
    try h.file("dev/keys/dist/deploy-keypair.json", bytes: 10) // deployment key: protected
    let found = await ProjectPurge.scan(roots: [h.path + "/dev"], home: h.path)
    let rel = Set(found.map { String($0.path.dropFirst(h.path.count + 1)) })
    #expect(rel == ["dev/web/node_modules", "dev/rust/target"])
    #expect(found.first { $0.name == "node_modules" }?.impact.contains("npm install") == true)
}

@Test func recentArtifactsAreNotPreselected() {
    let fresh = ProjectArtifact(path: "/x/node_modules", project: "/x", name: "node_modules", bytes: 1, lastActivity: Date())
    let old = ProjectArtifact(path: "/y/target", project: "/y", name: "target", bytes: 1,
                              lastActivity: Date().addingTimeInterval(-30 * 86_400))
    #expect(fresh.recent && !old.recent)
}

@Test func purgeRootsComeFromConfigFile() throws {
    let h = try FakeHome()
    try FileManager.default.createDirectory(atPath: h.path + "/Projects", withIntermediateDirectories: true)
    try FileManager.default.createDirectory(atPath: h.path + "/Work/Client", withIntermediateDirectories: true)
    #expect(ProjectPurge.roots(home: h.path) == [h.path + "/Projects"])
    try ProjectPurge.saveRoots([h.path + "/Work/Client"], home: h.path)
    #expect(ProjectPurge.roots(home: h.path) == [h.path + "/Work/Client"])
    #expect(try String(contentsOf: ProjectPurge.configURL(home: h.path), encoding: .utf8) == "~/Work/Client\n")
}

@Test func installerFinderPicksInstallersAndAppZipsOnly() throws {
    let h = try FakeHome()
    try h.file("Downloads/Tool.dmg", bytes: 30_000)
    try h.file("Downloads/sub/Setup.pkg", bytes: 20_000)
    try h.file("Downloads/photos.zip", bytes: 10_000)
    try h.file("Desktop/notes.txt", bytes: 10)
    // A zip that contains an app counts as installer.
    try h.file("stage/My.app/Contents/Info.plist", bytes: 10)
    let zip = h.path + "/Downloads/MyApp.zip"
    #expect(Shell.run("/usr/bin/ditto", ["-c", "-k", "--keepParent", h.path + "/stage/My.app", zip]).status == 0)
    let found = InstallerFinder.scan(home: h.path)
    #expect(Set(found.map(\.name)) == ["Tool.dmg", "Setup.pkg", "MyApp.zip"])
    #expect(found.first { $0.name == "Tool.dmg" }?.source == "Downloads")
}

@Test func ownWorkingDirectoryCountsAsInUse() {
    let cwds = Processes.workingDirectories()
    // The test runner itself has a working directory, so the list is never empty.
    #expect(!cwds.isEmpty)
    #expect(Processes.isInUse("/Users/x/app", workingDirectories: ["/Users/x/app/server"]))
    #expect(!Processes.isInUse("/Users/x/app", workingDirectories: ["/Users/x/application"]))
}
