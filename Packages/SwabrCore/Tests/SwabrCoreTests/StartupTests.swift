import Darwin
import Foundation
import Testing
@testable import SwabrCore

/// Records launchctl calls instead of running them.
private final class FakeLaunchctl: @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [[String]] = []
    var calls: [[String]] { lock.withLock { _calls } }
    let answer: @Sendable ([String]) -> (status: Int32, output: String)?

    init(answer: @escaping @Sendable ([String]) -> (status: Int32, output: String)? = { _ in (0, "") }) {
        self.answer = answer
    }

    var run: StartupItems.Runner {
        { [self] args in
            lock.withLock { _calls.append(args) }
            return answer(args)
        }
    }
}

private func writePlist(_ dict: [String: Any], to path: String) throws {
    try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0).write(to: URL(fileURLWithPath: path))
}

private func agent(_ label: String, kind: StartupItem.Kind = .userAgent, program: String? = "/bin/sh",
                   path: String? = nil, protected: String? = nil) -> StartupItem {
    StartupItem(label: label, path: path ?? "/tmp/\(label).plist", kind: kind, program: program,
                appPath: program.flatMap(StartupItems.owningApp), disabled: false, loaded: false, protectedReason: protected)
}

@Test func plistVariantsAreRead() throws {
    let h = try FakeHome()
    let dir = h.path + "/Library/LaunchAgents"
    try writePlist(["Label": "com.acme.program", "Program": "/Applications/Acme.app/Contents/MacOS/acme", "Disabled": true],
                   to: dir + "/com.acme.program.plist")
    try writePlist(["Label": "com.acme.args", "ProgramArguments": ["/usr/local/bin/tool", "--flag"]], to: dir + "/com.acme.args.plist")
    try writePlist(["Program": "/bin/ls"], to: dir + "/org.nolabel.plist")
    try Data("not a plist".utf8).write(to: URL(fileURLWithPath: dir + "/com.broken.plist"))
    try writePlist(["Label": "com.apple.thing", "Program": "/bin/ls"], to: dir + "/com.apple.thing.plist")
    try writePlist(["Label": "com.vendor.disguised.apple"], to: dir + "/x.plist")
    try Data("ignored".utf8).write(to: URL(fileURLWithPath: dir + "/readme.txt"))

    #expect(StartupItems.readJob(dir + "/com.acme.program.plist")
            == .init(label: "com.acme.program", program: "/Applications/Acme.app/Contents/MacOS/acme", disabled: true))
    #expect(StartupItems.readJob(dir + "/com.acme.args.plist")?.program == "/usr/local/bin/tool")
    #expect(StartupItems.readJob(dir + "/org.nolabel.plist")?.label == "org.nolabel")
    #expect(StartupItems.readJob(dir + "/com.broken.plist") == nil)

    let launchctl = FakeLaunchctl { args in
        switch args.first {
        case "print-disabled": (0, "disabled services = {\n\t\"com.acme.program\" => enabled\n\t\"com.acme.args\" => disabled\n}\n")
        case "list": (0, "PID\tStatus\tLabel\n123\t0\tcom.acme.args\n-\t0\torg.other\n")
        default: (1, "")
        }
    }
    let items = StartupItems.list(sources: [(dir, .userAgent)], protection: nil, uid: 501, run: launchctl.run)
    #expect(items.map(\.label).sorted() == ["com.acme.args", "com.acme.program", "com.vendor.disguised.apple", "org.nolabel"])
    let program = try #require(items.first { $0.label == "com.acme.program" })
    #expect(program.appPath == "/Applications/Acme.app")
    #expect(program.displayName == "Acme")
    #expect(!program.disabled)                       // the launchd override wins over the plist
    let args = try #require(items.first { $0.label == "com.acme.args" })
    #expect(args.disabled && args.loaded)
    #expect(args.displayName == "com.acme.args")
    #expect(Set(launchctl.calls.map { $0.first ?? "" }) == ["print-disabled", "list"])
    #expect(launchctl.calls.contains(["print-disabled", "gui/501"]))
    #expect(launchctl.calls.count == 2)              // asked once per listing
}

@Test func systemItemsUseOnlyThePlistAndNeverAskLaunchctl() throws {
    let h = try FakeHome()
    try writePlist(["Label": "com.acme.daemon", "Program": "/nope/daemon", "Disabled": true], to: h.path + "/D/com.acme.daemon.plist")
    let launchctl = FakeLaunchctl { _ in Issue.record("no launchctl for system items"); return nil }
    let items = StartupItems.list(sources: [(h.path + "/D", .daemon)], protection: nil, run: launchctl.run)
    #expect(items.count == 1)
    #expect(items.first?.disabled == true && items.first?.loaded == false)
    #expect(items.first?.isBroken == true && items.first?.policy == .settings)
}

@Test func printDisabledOutputIsParsed() {
    let text = """
    \tdisabled services = {
    \t\t"com.vendor.off" => disabled
    \t\t"com.vendor.on" => enabled
    \t\t"org.legacy" => true
    \t\t"org.legacy.on" => false
    \t\tgarbage line
    \t}
    """
    #expect(StartupItems.parseOverrides(text) == ["com.vendor.off": true, "com.vendor.on": false, "org.legacy": true, "org.legacy.on": false])
    #expect(StartupItems.parseDisabled(text) == ["com.vendor.off", "org.legacy"])
    #expect(StartupItems.parseList("PID\tStatus\tLabel\n-\t0\tcom.a\n42\t-9\tcom.b\n") == ["com.a", "com.b"])
}

@Test func protectionCases() throws {
    let p = try RuleStore.protection()
    func reason(_ label: String, program: String? = nil) -> String? {
        StartupItems.protectionReason(label: label, path: "/Users/x/Library/LaunchAgents/\(label).plist", program: program, protection: p)
    }
    #expect(reason("io.github.mkmaps.swabr.helper") == String(localized: "Dienst von Swabr", bundle: .module))
    #expect(reason("com.other.x", program: "/Applications/Swabr.app/Contents/Library/io.github.mkmaps.swabr.agent") != nil)
    #expect(reason("com.crowdstrike.falcon.UserAgent")?.contains("CrowdStrike") == true)
    #expect(reason("com.vendor.agent", program: "/Applications/Cisco Secure Client.app/Contents/MacOS/x")?.contains("Cisco") == true)
    #expect(reason("com.tailscale.ipn.macsys.login-item-helper") == String(localized: "Passwort-, Schlüssel- oder Netzwerkprogramm", bundle: .module))
    #expect(reason("com.1password.browser-helper") != nil)
    #expect(reason("com.example.resetdns") == nil)
    #expect(reason("com.google.keystone.agent") == nil)
    #expect(StartupItems.containsWord("eset", in: "com.eset.proxy"))
    #expect(!StartupItems.containsWord("eset", in: "com.example.resetdns"))
}

@Test func canRemoveTable() {
    let gone = "/nonexistent-\(UUID().uuidString)/bin"
    // (kind, program exists, protected) → removable
    let cases: [(StartupItem.Kind, Bool, Bool, Bool)] = [
        (.userAgent, true, false, true),
        (.userAgent, false, false, true),
        (.userAgent, true, true, false),
        (.userAgent, false, true, true),
        (.systemAgent, true, false, false),
        (.systemAgent, false, false, true),
        (.daemon, true, true, false),
        (.daemon, false, true, true),
        (.loginItem, true, false, false),
        (.loginItem, false, false, false),
        (.loginItem, false, true, false),
    ]
    for (kind, exists, protected, expected) in cases {
        let item = agent("com.x.y", kind: kind, program: exists ? "/bin/sh" : gone, protected: protected ? "p" : nil)
        #expect(item.canRemove == expected, "\(kind) exists=\(exists) protected=\(protected)")
    }
    // A program without an absolute path is never treated as missing.
    #expect(!agent("com.x.y", kind: .daemon, program: "relative-tool").isBroken)
    #expect(!agent("com.x.y", kind: .daemon, program: nil).isBroken)
}

@Test func blockWithoutConfirmationTouchesNothing() {
    let launchctl = FakeLaunchctl()
    let item = agent("com.tailscale.ipn", protected: "VPN")
    #expect(StartupItems.block(item, confirmed: false, uid: 501, run: launchctl.run) == "VPN")
    #expect(launchctl.calls.isEmpty)

    #expect(StartupItems.block(item, confirmed: true, uid: 501, run: launchctl.run) == nil)
    #expect(launchctl.calls == [["bootout", "gui/501", item.path], ["disable", "gui/501/com.tailscale.ipn"]])
}

@Test func blockAndAllowOnlyManageValidUserAgents() {
    let launchctl = FakeLaunchctl()
    #expect(StartupItems.block(agent("com.x; rm -rf"), confirmed: false, uid: 501, run: launchctl.run) != nil)
    #expect(StartupItems.block(agent("com.sys", kind: .daemon), confirmed: true, uid: 501, run: launchctl.run) != nil)
    #expect(StartupItems.allow(agent("com.sys", kind: .systemAgent), uid: 501, run: launchctl.run) != nil)
    #expect(launchctl.calls.isEmpty)

    let ok = agent("com.acme.agent")
    #expect(StartupItems.allow(ok, uid: 501, run: launchctl.run) == nil)
    #expect(launchctl.calls == [["enable", "gui/501/com.acme.agent"], ["bootstrap", "gui/501", ok.path]])

    let orphan = FakeLaunchctl()
    #expect(StartupItems.allow(agent("com.acme.gone", program: "/nonexistent-\(UUID().uuidString)"), uid: 501, run: orphan.run) == nil)
    #expect(orphan.calls == [["enable", "gui/501/com.acme.gone"]])

    let failing = FakeLaunchctl { _ in (5, "") }
    #expect(StartupItems.block(ok, confirmed: false, uid: 501, run: failing.run) == String(localized: "Blockieren fehlgeschlagen", bundle: .module))
    #expect(StartupItems.allow(ok, uid: 501, run: failing.run) == String(localized: "Erlauben fehlgeschlagen", bundle: .module))
}

@Test func removeTrashesOnlyOwnAgentsAndLogsIt() throws {
    let h = try FakeHome()
    let path = h.path + "/Library/LaunchAgents/com.acme.agent.plist"
    try writePlist(["Label": "com.acme.agent", "Program": "/bin/sh"], to: path)
    try FileManager.default.createDirectory(atPath: h.path + "/.Trash", withIntermediateDirectories: true)
    let trash: StartupItems.Trash = { p in
        do { try FileManager.default.moveItem(atPath: p, toPath: h.path + "/.Trash/" + (p as NSString).lastPathComponent); return nil }
        catch { return error.localizedDescription }
    }
    let log = OperationLog(home: h.path)
    let launchctl = FakeLaunchctl()

    // Outside ~/Library/LaunchAgents and protected healthy agents are refused.
    #expect(StartupItems.remove(agent("com.acme.agent", path: "/tmp/com.acme.agent.plist"), home: h.path, log: log,
                                uid: 501, run: launchctl.run, trash: trash) != nil)
    #expect(StartupItems.remove(agent("com.acme.agent", path: path, protected: "x"), home: h.path, log: log,
                                uid: 501, run: launchctl.run, trash: trash) != nil)
    #expect(launchctl.calls.isEmpty)

    #expect(StartupItems.remove(agent("com.acme.agent", path: path), home: h.path, log: log,
                                uid: 501, run: launchctl.run, trash: trash) == nil)
    #expect(launchctl.calls == [["bootout", "gui/501", path]])
    #expect(!h.exists("Library/LaunchAgents/com.acme.agent.plist") && h.exists(".Trash/com.acme.agent.plist"))
    let entry = try #require(History.load(log).first)
    #expect(entry.action == "TRASH" && entry.label == "Startobjekt" && entry.path == path)
}

@Test func systemRemovalRefusesWhatIsNotOrphaned() {
    let gone = "/nonexistent-\(UUID().uuidString)/helper"
    let items = [
        agent("com.alive", kind: .daemon, program: "/bin/ls", path: "/Library/LaunchDaemons/com.alive.plist"),
        agent("com.user", kind: .userAgent, program: gone, path: "/Library/LaunchDaemons/com.user.plist"),
        agent("com.txt", kind: .daemon, program: gone, path: "/Library/LaunchDaemons/com.txt.conf"),
        agent("com.outside", kind: .daemon, program: gone, path: "/tmp/com.outside.plist"),
    ]
    let failures = StartupItems.removeSystem(items, runPrivileged: { _ in Issue.record("must not escalate"); return nil },
                                             privilegedTrash: { _ in Issue.record("must not trash"); return nil })
    #expect(Set(failures.keys) == Set(items.map(\.path)))
}

@Test func systemOperationsStopDaemonsAndMoveIntoFreeTrashNames() throws {
    let h = try FakeHome()
    try FileManager.default.createDirectory(atPath: h.path + "/.Trash", withIntermediateDirectories: true)
    try h.file(".Trash/com.a.helper.plist")
    let gone = "/nonexistent/helper"
    let daemon = agent("com.a.helper", kind: .daemon, program: gone, path: "/Library/LaunchDaemons/com.a.helper.plist")
    let other = agent("com.a.helper", kind: .systemAgent, program: gone, path: "/Library/LaunchAgents/com.a.helper.plist")
    // The existing Trash file and the first move's target are both avoided; agents are not booted out of system.
    #expect(StartupItems.systemOperations(for: [daemon, other], home: h.path) == [
        .stopDaemon(plist: daemon.path),
        .trash(source: daemon.path, target: h.path + "/.Trash/com.a.helper 2.plist"),
        .trash(source: other.path, target: h.path + "/.Trash/com.a.helper 3.plist"),
    ])
}

@Test func storeEditionShowsOnlyAgentsOfGrantedApps() {
    let items = [
        agent("com.a", program: "/Applications/A.app/Contents/MacOS/a"),
        agent("com.b", program: "/usr/local/bin/b"),
        agent("com.c", kind: .daemon, program: "/Applications/C.app/Contents/MacOS/c"),
        agent("com.d", program: "/Users/x/Apps/D.app/Contents/MacOS/d"),
        agent("com.e", program: "/ApplicationsX/E.app/Contents/MacOS/e"),
    ]
    #expect(StartupItems.storeEdition(items, grantedFolders: ["/Applications"]).map(\.label) == ["com.a"])
    #expect(StartupItems.storeEdition(items, grantedFolders: []).isEmpty)
}
