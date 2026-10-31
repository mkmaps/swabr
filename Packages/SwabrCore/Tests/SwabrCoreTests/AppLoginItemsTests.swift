import Foundation
import Testing
@testable import SwabrCore

private let dump = """
========================
 Records for UID 0 : FFFFEEEE-DDDD-CCCC-BBBB-AAAA00000000
========================

 Items:

 #1:
                 UUID: 1
                 Name: Root Helper
                 Type: login item (0x4)
          Disposition: [enabled, allowed, notified] (0xb)
           Identifier: 4.com.example.root
                  URL: /Library/Root.app

========================
 Records for UID 501 : 39066032-610A-48A1-AFC5-336499CB03CF
========================

 Items:

 #1:
                 UUID: A
                 Name: DeepL GmbH
                 Type: app (0x2)
          Disposition: [disabled, allowed, not notified] (0x2)
           Identifier: 2.com.linguee.DeepLCopyTranslator
                  URL: file:///Applications/DeepL.app/
  Embedded Item Identifiers:
    #1: 4.com.linguee.DeepLLauncher

 #2:
                 UUID: B
                 Name: DeepLLauncher
                 Type: login item (0x4)
          Disposition: [enabled, allowed, notified] (0xb)
           Identifier: 4.com.linguee.DeepLLauncher
                  URL: Contents/Library/LoginItems/DeepLLauncher.app
    Parent Identifier: 2.com.linguee.DeepLCopyTranslator

 #3:
                 UUID: C
                 Name: Spotify
                 Type: app (0x2)
          Disposition: [disabled, allowed, not notified] (0x2)
           Identifier: 2.com.spotify.client
                  URL: file:///Applications/Spotify.app/

 #4:
                 UUID: D
                 Name: StartUpHelper
                 Type: login item (0x4)
          Disposition: [enabled, disallowed, notified] (0x9)
           Identifier: 4.com.spotify.client.startuphelper
                  URL: Contents/Library/LoginItems/StartUpHelper.app
    Parent Identifier: 2.com.spotify.client

 #5:
                 UUID: E
                 Name: WireGuard
                 Type: login item (0x4)
          Disposition: [disabled, disallowed, notified] (0x8)
           Identifier: 4.com.wireguard.macos.login-item-helper
                  URL: Contents/Library/LoginItems/WireGuardLoginItemHelper.app

 #6:
                 UUID: F
                 Name: Notes Plus
                 Type: app (0x2)
          Disposition: [enabled, allowed, notified] (0xb)
           Identifier: 2.com.example.notes
                  URL: file:///Applications/Notes%20Plus.app/

 #7:
                 UUID: G
                 Name: Updater
                 Type: legacy agent (0x10008)
          Disposition: [enabled, allowed, notified] (0xb)
           Identifier: 8.com.example.updater
                  URL: file:///Users/test/Library/LaunchAgents/com.example.updater.plist
"""

@Test func appLoginItemsReadsTheUsersRegisteredItems() {
    let items = AppLoginItems.parse(dump, uid: 501)
    #expect(items.map(\.appPath) == ["/Applications/DeepL.app", "/Applications/Notes Plus.app", "/Applications/Spotify.app"])
    #expect(items.map(\.name) == ["DeepL", "Notes Plus", "Spotify"])
    // Spotify registered its helper, but it is switched off in System Settings.
    #expect(items.map(\.starts) == [true, true, false])
}

@Test func appLoginItemsIgnoreOtherUsersAndUnparsableText() {
    #expect(AppLoginItems.parse(dump, uid: 502).isEmpty)
    #expect(AppLoginItems.parse("sfltool: error", uid: 501).isEmpty)
    #expect(AppLoginItems.parse(dump, uid: 0).map(\.appPath) == ["/Library/Root.app"])
}
