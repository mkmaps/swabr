import Foundation
import Testing
@testable import SwabrCore

/// Stand-in for root: first lifts the lock the user could not get past, then carries out the operations.
private func rootStandIn(unlocking folder: String, calls: Calls, home: String, roots: [String] = []) -> RootRunner {
    { ops in
        calls.count += 1
        chmod(folder, 0o755)
        return rootAsUser(home: home, roots: roots)(ops)
    }
}

private final class Calls: @unchecked Sendable { var count = 0 }

private func lockedFolder(_ h: FakeHome, _ rel: String, file: String) throws -> String {
    try h.file(rel + "/" + file, bytes: 8192)
    let folder = h.path + "/" + rel
    chmod(folder, 0o555)
    return folder
}

@Test func cleanerHandsRootOwnedItemsToTheRootStep() async throws {
    for mode in [Cleaner.Mode.trash, .permanent] {
        let h = try FakeHome()
        try FileManager.default.createDirectory(atPath: h.path + "/.Trash", withIntermediateDirectories: true)
        let folder = try lockedFolder(h, "Library/Caches/com.acme.locked", file: "blob")
        defer { chmod(folder, 0o755) }
        let rules = [CleanRule(section: "app_caches", label: "App-Caches", kind: .cache, paths: ["~/Library/Caches/*/*"])]
        let items = await CleanScanner(rules: rules, whitelist: whitelist(h), home: h.path).scan()
        let calls = Calls()

        // Without a root step (App Store edition) the permission error is reported.
        var report = await Cleaner(home: h.path, whitelist: whitelist(h), mode: mode, log: OperationLog(home: h.path)).clean(items)
        #expect(report.removedCount == 0 && report.failures.map(\.kind) == [.permission])

        report = await Cleaner(home: h.path, whitelist: whitelist(h), mode: mode, log: OperationLog(home: h.path),
                               runPrivileged: rootStandIn(unlocking: folder, calls: calls, home: h.path)).clean(items)
        #expect(calls.count == 1)
        #expect(report.removedCount == 1 && report.failures.isEmpty)
        #expect(!h.exists("Library/Caches/com.acme.locked/blob"))
        let trashed = try FileManager.default.contentsOfDirectory(atPath: h.path + "/.Trash").filter { $0.hasPrefix("blob ") }
        // Trash mode keeps it in the Trash; permanent mode deletes it there as the user.
        #expect(trashed.count == (mode == .trash ? 1 : 0))
    }
}

@Test func projectArtifactsOwnedByRootGoThroughTheRootStep() throws {
    let h = try FakeHome()
    try FileManager.default.createDirectory(atPath: h.path + "/.Trash", withIntermediateDirectories: true)
    try h.file("dev/web/package.json")
    let locked = try lockedFolder(h, "dev/web/node_modules/pkg", file: "index.js")
    defer { chmod(locked, 0o755) }
    let artifact = ProjectArtifact(path: h.path + "/dev/web/node_modules", project: "web", name: "node_modules",
                                   bytes: 8192, lastActivity: nil)
    let calls = Calls()
    let report = ProjectPurge.delete([artifact], roots: [h.path + "/dev"], home: h.path, toTrash: false,
                                     log: OperationLog(home: h.path), volumes: "/Volumes",
                                     runPrivileged: rootStandIn(unlocking: locked, calls: calls, home: h.path))
    #expect(calls.count == 1)
    #expect(report.removedCount == 1 && report.failures.isEmpty)
    #expect(!h.exists("dev/web/node_modules"))
    #expect(try FileManager.default.contentsOfDirectory(atPath: h.path + "/.Trash").isEmpty)
}

@Test func slimSwapsRootOwnedAppsAsRoot() throws {
    let h = try FakeHome()
    try FileManager.default.createDirectory(atPath: h.path + "/.Trash", withIntermediateDirectories: true)
    try h.file("Applications/Tool.app/Contents/MacOS/Tool", bytes: 20_000)
    try h.file("work/Tool.app/Contents/MacOS/Tool", bytes: 10_000)
    let app = InstalledApp(name: "Tool", path: h.path + "/Applications/Tool.app", bundleID: "com.acme.tool", version: nil,
                           bytes: 20_000, lastUsed: nil, fromAppStore: false, protection: nil)
    let calls = Calls()
    let outcome = AppSlimmer.rootSwap(app: app, copy: h.path + "/work/Tool.app", home: h.path, saved: 10_000,
                                      log: OperationLog(home: h.path), runPrivileged: { ops in
        calls.count += 1
        return rootAsUser(home: h.path)(ops)
    })
    #expect(outcome.ok)
    #expect(calls.count == 1)
    #expect(!h.exists("work/Tool.app"))
    let size = (try FileManager.default.attributesOfItem(atPath: app.path + "/Contents/MacOS/Tool")[.size] as? Int) ?? 0
    #expect(size == 10_000)   // the slimmed copy now sits in the app's place
    #expect(try FileManager.default.contentsOfDirectory(atPath: h.path + "/.Trash").contains { $0.hasPrefix("Tool.app ") })

    // Declined password: nothing moves, the original stays.
    try h.file("work/Tool.app/Contents/MacOS/Tool", bytes: 5_000)
    let declined = AppSlimmer.rootSwap(app: app, copy: h.path + "/work/Tool.app", home: h.path, saved: 5_000,
                                       log: OperationLog(home: h.path), runPrivileged: { _ in nil })
    #expect(!declined.ok)
    #expect(h.exists("Applications/Tool.app/Contents/MacOS/Tool"))
}
