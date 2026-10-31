import Foundation
import Testing
@testable import SwabrCore

@Test func versionComparisonIsNumeric() {
    #expect(Version.isNewer("1.10", than: "1.9"))
    #expect(Version.isNewer("2.0", than: "1.99.9"))
    #expect(!Version.isNewer("1.2", than: "1.2.0"))
    #expect(!Version.isNewer("1.2.0", than: "1.3"))
    #expect(Version.isNewer("25.1.3,abc123", than: "25.1.2"))
    #expect(!Version.isNewer("latest", than: "1.0"))
}

@Test func appcastPicksHighestVersion() {
    let xml = """
    <rss><channel>
      <item><enclosure sparkle:version="210" sparkle:shortVersionString="2.1.0" url="x"/></item>
      <item><enclosure sparkle:version="300" sparkle:shortVersionString="3.0.1" url="y"/></item>
      <item><sparkle:shortVersionString>2.9</sparkle:shortVersionString></item>
    </channel></rss>
    """
    #expect(AppUpdateChecker.parseAppcast(xml) == "3.0.1")
}

@Test func brewOutdatedJsonIsParsed() {
    let json = #"{"formulae":[],"casks":[{"name":"anki","installed_versions":["25.02"],"current_version":"25.07.5"}]}"#
    let o = AppUpdateChecker.parseBrewOutdated(json)
    #expect(o.first?.token == "anki" && o.first?.current == "25.07.5" && o.first?.installed == "25.02")
}

@Test func disabledLaunchdLabelsAreParsed() {
    let text = """
    disabled services = {
        "com.vendor.agent" => disabled
        "com.vendor.on" => enabled
        "org.old.style" => true
    }
    """
    #expect(StartupItems.parseDisabled(text) == ["com.vendor.agent", "org.old.style"])
}

@Test func startupItemsKnowTheirApp() {
    #expect(StartupItems.owningApp("/Applications/Foo Bar.app/Contents/MacOS/helper") == "/Applications/Foo Bar.app")
    #expect(StartupItems.owningApp("/usr/local/bin/tool") == nil)
    #expect(!StartupItems.validLabel("com.x; rm -rf"))
    #expect(StartupItems.validLabel("com.google.keystone.agent"))
}

@Test func appcastGivesNewestFullDownload() {
    let xml = """
    <rss><channel>
      <item><enclosure sparkle:shortVersionString="2.1.0" url="https://x.example/App-2.1.0.zip"/></item>
      <item><enclosure sparkle:shortVersionString="3.0.1" url="https://x.example/App-3.0.1.dmg" length="1"/>
        <sparkle:deltas><enclosure url="https://x.example/delta.delta"/></sparkle:deltas></item>
    </channel></rss>
    """
    let best = AppUpdateChecker.parseAppcastItem(xml)
    #expect(best?.version == "3.0.1")
    #expect(best?.url?.absoluteString == "https://x.example/App-3.0.1.dmg")
}

@Test func installerRecognisesFormatsAndChecksums() throws {
    let h = try FakeHome()
    let zip = URL(fileURLWithPath: h.path + "/a.zip")
    try Data([0x50, 0x4B, 0x03, 0x04, 0, 0]).write(to: zip)
    #expect(try AppInstaller.detect(zip) == .zip)
    let pkg = URL(fileURLWithPath: h.path + "/download")
    try Data("xar!....".utf8).write(to: pkg)
    #expect(try AppInstaller.detect(pkg) == .pkg)
    let txt = URL(fileURLWithPath: h.path + "/x.txt")
    try Data("abc".utf8).write(to: txt)
    #expect(try AppInstaller.sha256(of: txt) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
}

@Test func installerFindsAppByBundleIDInNestedFolder() throws {
    let h = try FakeHome()
    let app = try fakeApp(h, name: "Tool", id: "com.acme.tool")
    let info: [String: Any] = ["CFBundleIdentifier": "com.acme.tool", "CFBundleShortVersionString": "2.0"]
    try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        .write(to: URL(fileURLWithPath: app.path + "/Contents/Info.plist"))
    try FileManager.default.createDirectory(atPath: h.path + "/Applications/Other.app/Contents", withIntermediateDirectories: true)
    #expect(AppInstaller.findApp(in: URL(fileURLWithPath: h.path), bundleID: "com.acme.tool")?.lastPathComponent == "Tool.app")
    #expect(AppInstaller.findApp(in: URL(fileURLWithPath: h.path), bundleID: "com.other") == nil)
}

@Test func signatureCheckRejectsOtherDevelopers() throws {
    // Two real, differently signed apps that exist on every Mac.
    let a = "/System/Applications/Calculator.app", b = "/System/Applications/TextEdit.app"
    #expect(AppInstaller.signature(a) != nil)
    #expect(throws: Never.self) { try AppInstaller.verifySameDeveloper(new: a, installed: b) }
    let h = try FakeHome()
    let unsigned = try fakeApp(h, name: "Unsigned", id: "com.x.unsigned")
    #expect(AppInstaller.signature(unsigned.path) == nil)
    #expect(throws: AppInstaller.Failure.self) { try AppInstaller.verifySameDeveloper(new: unsigned.path, installed: a) }
}

@Test func orphanedSystemItemsAreRemovableOnlyWhenTheirProgramIsGone() {
    let gone = StartupItem(label: "com.gone.helper", path: "/Library/LaunchDaemons/com.gone.helper.plist", kind: .daemon,
                           program: "/Library/PrivilegedHelperTools/com.gone.helper-does-not-exist", appPath: nil, disabled: false, loaded: false)
    let alive = StartupItem(label: "com.alive.helper", path: "/Library/LaunchDaemons/com.alive.helper.plist", kind: .daemon,
                            program: "/bin/ls", appPath: nil, disabled: false, loaded: false)
    #expect(gone.canRemove)
    #expect(!alive.canRemove)
    // A healthy system item is refused without ever asking for a password.
    let failures = StartupItems.removeSystem([alive], runPrivileged: { _ in Issue.record("must not escalate"); return nil })
    #expect(failures[alive.path] != nil)
}
