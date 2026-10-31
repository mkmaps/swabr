# Swabr's own protection data. Writes Packages/SwabrCore/Sources/SwabrCore/Resources/protection.json.
#   python3 -I Tools/rules/make_protection.py
import json, os

# Always protected, whatever the user sets: Apple caches that hold sync state, credentials, fonts or
# downloads still in flight, and Swabr's own cache. Rebuilding them is slow or loses data.
safety = [
    "~/Library/Caches/CloudKit*",                 # iCloud sync state of every app
    "~/Library/Caches/com.apple.bird*",           # iCloud Drive
    "~/Library/Caches/com.apple.cloudd*",
    "~/Library/Caches/com.apple.CloudDocs*",
    "~/Library/Caches/com.apple.akd*",            # Apple account authentication
    "~/Library/Caches/com.apple.passd*",          # Wallet
    "~/Library/Caches/com.apple.HomeKit*",
    "~/Library/Caches/com.apple.FontRegistry*",
    "~/Library/Caches/com.apple.spotlight*",
    "~/Library/Caches/com.apple.Spotlight*",
    "~/Library/Caches/com.apple.nsurlsessiond*",  # background downloads in progress
    "~/Library/Caches/com.apple.containermanagerd*",
    "~/Library/Caches/de.knieriem.swabr*",
]

# Switches under Settings → Protected Data, named after the product (category and path give the context);
# German names are localized on load. Default-on entries are big downloads that take long to fetch again.
options = []
def opt(category, label, pattern):
    options.append({"label": label, "pattern": pattern, "category": category})

opt("system_cache", "Apple Music", "~/Library/Caches/com.apple.Music/*")
opt("system_cache", "Fotos und Medienanalyse", "~/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches/*")
opt("system_cache", "Karten", "~/Library/Containers/com.apple.geod/Data/Library/Caches/*")
opt("system_cache", "Mail-Anhänge", "~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads/*")
opt("system_cache", "Fensterzustände", "~/Library/Saved Application State/*")
opt("system_cache", "Absturzberichte", "~/Library/Logs/DiagnosticReports/*")
opt("browser_cache", "Safari", "~/Library/Containers/com.apple.Safari/Data/Library/Caches/*")
opt("browser_cache", "Google Chrome", "~/Library/Application Support/Google/Chrome/*")
opt("browser_cache", "Microsoft Edge", "~/Library/Application Support/Microsoft Edge/*")
opt("browser_cache", "Brave", "~/Library/Application Support/BraveSoftware/Brave-Browser/*")
opt("browser_cache", "Arc", "~/Library/Application Support/Arc/User Data/*")
opt("browser_cache", "Firefox", "~/Library/Caches/Firefox/*")
opt("ide_cache", "Xcode DerivedData", "~/Library/Developer/Xcode/DerivedData/*")
opt("ide_cache", "Xcode Device Support", "~/Library/Developer/Xcode/iOS DeviceSupport/*")
opt("ide_cache", "Simulator", "~/Library/Developer/CoreSimulator/Caches/*")
opt("ide_cache", "JetBrains", "~/Library/Caches/JetBrains/*")
opt("ide_cache", "Visual Studio Code", "~/Library/Application Support/Code/*")
opt("ide_cache", "Cursor", "~/Library/Application Support/Cursor/*")
opt("compiler_cache", "Go", "~/Library/Caches/go-build/*")
opt("compiler_cache", "Swift Package Manager", "~/Library/Caches/org.swift.swiftpm/*")
opt("compiler_cache", "Cargo", "~/.cargo/registry/*")
opt("package_manager", "Homebrew", "~/Library/Caches/Homebrew/*")
opt("package_manager", "npm", "~/.npm/*")
opt("package_manager", "pip", "~/Library/Caches/pip/*")
opt("package_manager", "uv", "~/.cache/uv/*")
opt("package_manager", "Yarn", "~/Library/Caches/Yarn/*")
opt("package_manager", "pnpm", "~/Library/Caches/pnpm/*")
opt("package_manager", "Bun", "~/.bun/install/cache/*")
opt("package_manager", "CocoaPods", "~/Library/Caches/CocoaPods/*")
opt("package_manager", "Composer", "~/.composer/cache/*")
opt("package_manager", "Gradle", "~/.gradle/caches/*")
opt("package_manager", "Playwright", "~/Library/Caches/ms-playwright/*")
opt("package_manager", "Cypress", "~/Library/Caches/Cypress/*")
opt("package_manager", "Dart/Flutter", "~/.pub-cache/*")
opt("ai_ml_cache", "Hugging Face", "~/.cache/huggingface/*")
opt("ai_ml_cache", "PyTorch", "~/.cache/torch/*")
opt("container_cache", "Docker Desktop", "~/Library/Containers/com.docker.docker/Data/log/*")
opt("apps", "Spotify", "~/Library/Caches/com.spotify.client/*")
opt("apps", "Slack", "~/Library/Application Support/Slack/*")
opt("apps", "Discord", "~/Library/Application Support/discord/*")
opt("apps", "Microsoft Teams", "~/Library/Application Support/Microsoft/Teams/*")
opt("apps", "Steam", "~/Library/Application Support/Steam/*")
opt("apps", "Adobe", "~/Library/Application Support/Adobe/Common/*")
opt("apps", "Dropbox", "~/Dropbox/.dropbox.cache/*")

defaults = ["~/.gradle/caches/*", "~/Library/Caches/ms-playwright/*", "~/.cache/huggingface/*"]

# Uninstall: Apple's own apps are part of macOS, except the ones Apple ships separately. Anything from the
# App Store is never treated as part of macOS (AppCatalog checks the receipt), and Safari web apps
# ("Add to Dock") carry Apple ids although the user made them.
# The real test is macOS's own protection flag (AppBundle.isSystemProtected); this list is a backstop only.
system_critical = ["com.apple.Safari"]
apple_uninstallable = ["com.apple.Safari.WebApp.*", "com.apple.pixelmator*", "com.apple.iWork.*", "com.apple.iMovieApp", "com.apple.garageband*", "com.apple.dt.*",
                       "com.apple.FinalCut*", "com.apple.logic*", "com.apple.motionapp", "com.apple.Compressor",
                       "com.apple.mainstage*", "com.apple.configurator.*", "com.apple.TransporterApp"]

# Never treated as leftovers of a removed app: secrets, wallets, network and security tools, input methods.
sensitive = ["com.1password.*", "com.agilebits.*", "com.bitwarden.*", "*.bitwarden.*", "org.keepassxc.*",
             "com.dashlane.*", "com.lastpass.*", "in.sinew.Enpass*", "me.proton.pass*", "com.yubico.*",
             "com.authy.*", "com.ledger.*", "org.electrum.*", "com.exodus.*", "*.wireguard.*", "net.tunnelblick.*",
             "com.sparklabs.*", "com.tailscale.*", "io.tailscale.*", "net.mullvad.*", "com.nordvpn.*",
             "ch.protonvpn.*", "com.cisco.*", "com.paloaltonetworks.*", "*.inputmethod.*", "*inputmethod*",
             "*ssh*", "*gpg*", "*keychain*", "*password*", "*wallet*"]

# Endpoint security and device management: their own uninstaller removes kernel/system extensions and
# deregisters the device; deleting the app bundle would leave a broken agent behind.
def vendor(name, prefixes, fragments):
    return {"vendor": name, "bundlePrefixes": prefixes, "nameFragments": fragments}
official = [
    vendor("CrowdStrike", ["com.crowdstrike."], ["crowdstrike"]),
    vendor("SentinelOne", ["com.sentinelone."], ["sentinelone"]),
    vendor("Sophos", ["com.sophos."], ["sophos"]),
    vendor("ESET", ["com.eset."], ["eset"]),
    vendor("Microsoft Defender", ["com.microsoft.wdav"], ["microsoft defender"]),
    vendor("Jamf", ["com.jamf.", "com.jamfsoftware."], ["jamf"]),
    vendor("Kandji", ["io.kandji."], ["kandji"]),
    vendor("Trend Micro", ["com.trendmicro."], ["trend micro"]),
    vendor("Bitdefender", ["com.bitdefender."], ["bitdefender"]),
    vendor("Kaspersky", ["com.kaspersky."], ["kaspersky"]),
    vendor("Zscaler", ["com.zscaler."], ["zscaler"]),
    vendor("Palo Alto GlobalProtect", ["com.paloaltonetworks."], ["globalprotect"]),
    vendor("Cisco Secure Client", ["com.cisco.anyconnect", "com.cisco.secureclient"], ["anyconnect", "cisco secure client"]),
]

data = {"defaultWhitelist": defaults, "safetyWhitelist": safety, "systemCriticalBundles": system_critical,
        "sensitiveBundles": sensitive, "appleUninstallableApps": apple_uninstallable,
        "officialUninstallerRules": official, "whitelistOptions": options}
out = os.path.join(os.path.dirname(__file__), "../../Packages/SwabrCore/Sources/SwabrCore/Resources/protection.json")
with open(out, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=1)
print(len(options), "options,", len(safety), "safety patterns")
