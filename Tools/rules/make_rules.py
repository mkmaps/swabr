# Swabr's own clean-up catalogue. Writes Packages/SwabrCore/Sources/SwabrCore/Resources/clean_rules.json.
#   python3 -I Tools/rules/make_rules.py
#
# Sources: the folder conventions macOS documents for apps (Library/Caches is purgeable, Logs, Saved Application
# State, sandbox containers), the cache layout of Chromium and Firefox, and the cache locations the tools
# below document themselves (Xcode, Homebrew, pip, Yarn, Cargo, Gradle, Composer …), checked against an
# inventory of a real home folder. Order matters: the first rule that matches a path owns it, so specific
# rules come before the broad ones at the end.
import json, os

rules = []

def rule(section, label, kind, paths, **extra):
    r = {"section": section, "label": label, "kind": kind, "paths": paths}
    r.update(extra)
    rules.append(r)

# Folder names Chromium (and every Electron app) uses for data it rebuilds on its own.
CHROMIUM_PROFILE = "{Cache,Code Cache,GPUCache,DawnCache,DawnGraphiteCache,DawnWebGPUCache,Service Worker/CacheStorage,Service Worker/ScriptCache}"
CHROMIUM_ROOT = "{ShaderCache,GrShaderCache,GraphiteDawnCache,component_crx_cache}"

def chromium_browser(name, support, caches, process):
    """A Chromium browser: profile caches (Default, Profile 1 …), shared shader caches and ~/Library/Caches."""
    paths = [f"~/Library/Application Support/{support}/*/{CHROMIUM_PROFILE}/*",
             f"~/Library/Application Support/{support}/{CHROMIUM_ROOT}/*"]
    paths += [f"~/Library/Caches/{c}/*" for c in caches]
    rule("browsers", name, "browserCache", paths, skipIfRunning=process)

# --- macOS (user level) -------------------------------------------------------------------------
rule("system", "Papierkorb", "trash", ["~/.Trash/*"])
rule("system", "Absturzberichte", "crash", [
    "~/Library/Logs/DiagnosticReports/*",
    "~/Library/Application Support/CrashReporter/*",
    "~/Library/Application Support/*/Crashpad/completed/*",
    "~/Library/Application Support/*/sentry/*",       # crash events an app has not sent yet
    "~/Library/Application Support/*/crash-reports/*",
])
rule("system", "Mail-Anhänge", "mailDownloads",
     ["~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads/*"], skipIfRunning="com.apple.mail")
rule("system", "Fensterzustände", "state", ["~/Library/Saved Application State/*"])
rule("system", "Zuletzt benutzt", "recentItems",
     ["~/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.Recent*",
      "~/Library/Preferences/com.apple.recentitems.plist"])
# Deliberately not cleaned: ~/Library/Suggestions (databases suggestd keeps open) and ~/Library/IdentityCaches
# (identity services behind iMessage and FaceTime); little space, real risk of follow-up problems.
rule("system", "Kontakte", "cache", ["~/Library/Application Support/AddressBook/Sources/*/Photos.cache"],
     skipIfRunning="com.apple.AddressBook", safety="review")
rule("system", "iPhone- und iPad-Software", "updates",
     ["~/Library/iTunes/iPhone Software Updates/*", "~/Library/iTunes/iPad Software Updates/*",
      "~/Library/iTunes/iPod Software Updates/*"])

# --- Browsers ------------------------------------------------------------------------------------
rule("browsers", "Safari", "browserCache",
     ["~/Library/Containers/com.apple.Safari/Data/Library/Caches/*", "~/Library/Caches/com.apple.Safari/*"],
     skipIfRunning="com.apple.Safari")
# Safari web apps ("Add to Dock") keep one container each inside the shared WebApp container. The inner
# container is named after the web app's bundle id, so CleanScanner.owners finds the running web app.
rule("browsers", "Safari-Web-Apps", "browserCache",
     ["~/Library/Containers/com.apple.Safari.WebApp/Data/Library/Containers/com.apple.Safari.WebApp.*/Library/Caches/*"],
     skipRunningOwner=True)
chromium_browser("Google Chrome", "Google/Chrome", ["Google/Chrome"], "Google Chrome")
# Chrome's on-device AI and optimisation models: big, downloaded again when Chrome needs them.
rule("browsers", "Chrome-KI-Modelle", "models",
     ["~/Library/Application Support/Google/Chrome/{OptGuideOnDeviceModel,OptGuideOnDeviceClassifierModel,OptimizationGuidePredictionModels,optimization_guide_model_store}/*"],
     skipIfRunning="Google Chrome")
rule("browsers", "Google Updater", "updates", ["~/Library/Application Support/Google/GoogleUpdater/crx_cache/*",
                                                "~/Library/Application Support/Google/GoogleUpdater/*.old"])
chromium_browser("Google Chrome Canary", "Google/Chrome Canary", ["Google/Chrome Canary"], "Google Chrome Canary")
chromium_browser("Chromium", "Chromium", ["Chromium"], "Chromium")
chromium_browser("Microsoft Edge", "Microsoft Edge", ["Microsoft Edge"], "Microsoft Edge")
chromium_browser("Brave", "BraveSoftware/Brave-Browser", ["BraveSoftware/Brave-Browser"], "Brave Browser")
chromium_browser("Vivaldi", "Vivaldi", ["Vivaldi"], "Vivaldi")
chromium_browser("Opera", "com.operasoftware.Opera", ["com.operasoftware.Opera"], "Opera")
chromium_browser("Arc", "Arc/User Data", ["company.thebrowser.Browser"], "Arc")
for name, folder in (("Firefox", "Firefox"), ("Zen", "zen"), ("LibreWolf", "librewolf")):
    rule("browsers", name, "browserCache",
         [f"~/Library/Caches/{folder}/Profiles/*/{{cache2,startupCache,thumbnails}}/*",
          f"~/Library/Application Support/{folder}/Profiles/*/{{cache2,startupCache}}/*"], skipIfRunning=name)

# --- Apps whose caches lie deeper than the broad rules reach -------------------------------------
rule("apps", "Nachrichten", "cache", ["~/Library/Messages/Caches/Previews/*", "~/Library/Messages/StickerCache/*"],
     skipIfRunning="com.apple.MobileSMS")
rule("apps", "VirtualBox", "cache", ["~/VirtualBox VMs/.cache"], skipIfRunning="VirtualBox")
rule("apps", "Steam", "cache",
     ["~/Library/Application Support/Steam/{appcache,depotcache,htmlcache,steamapps/shadercache}/*"], skipIfRunning="Steam")
rule("apps", "Steam-Protokolle", "log", ["~/Library/Application Support/Steam/logs/*"])
rule("apps", "Adobe", "cache",
     ["~/Library/Application Support/Adobe/Common/{Media Cache Files,Media Cache,Peak Files}/*"])
rule("apps", "Dropbox", "cache", ["~/Dropbox/.dropbox.cache/*"], skipIfRunning="Dropbox")
# DaVinci Resolve's render cache lives next to the user's videos; rebuilt by rendering again.
rule("apps", "DaVinci Resolve", "build", ["~/Movies/CacheClip/*"], skipIfRunning="DaVinci Resolve", safety="review")
rule("apps", "Docker Desktop", "log", ["~/Library/Containers/com.docker.docker/Data/log/*"])
# Offline copies of note attachments; downloaded again, but only with a connection.
rule("apps", "Evernote", "cache", ["~/Library/Application Support/Evernote/resource-cache/*"],
     skipIfRunning="Evernote", safety="review")
# May still hold files waiting to be uploaded.
rule("apps", "pCloud Drive", "temp", ["~/.pcloud/temp/*"], skipIfRunning="pCloud Drive", safety="review")
rule("apps", "ONLYOFFICE", "cache", ["~/Library/Application Support/asc.onlyoffice.ONLYOFFICE/data/cache/*"],
     skipIfRunning="ONLYOFFICE")

# --- Developer tools -----------------------------------------------------------------------------
rule("developer", "Xcode DerivedData", "derivedData", ["~/Library/Developer/Xcode/DerivedData/*"], skipIfRunning="com.apple.dt.Xcode")
rule("developer", "Xcode Products", "build", ["~/Library/Developer/Xcode/Products/*"], skipIfRunning="com.apple.dt.Xcode")
rule("developer", "Xcode DocumentationCache", "cache", ["~/Library/Developer/Xcode/DocumentationCache/*"], skipIfRunning="com.apple.dt.Xcode")
rule("developer", "Xcode Device Support", "deviceSupport",
     ["~/Library/Developer/Xcode/{iOS,watchOS,tvOS,visionOS} DeviceSupport/*"])
rule("developer", "Simulator", "cache", ["~/Library/Developer/CoreSimulator/Caches/*"], skipIfRunning="com.apple.iphonesimulator")
rule("developer", "Simulator", "temp", ["~/Library/Developer/CoreSimulator/Devices/*/data/tmp/*"],
     skipIfRunning="com.apple.iphonesimulator")
rule("developer", "Homebrew", "packages", ["~/Library/Caches/Homebrew/*"])
rule("developer", "pip", "packages", ["~/Library/Caches/pip/*"])
rule("developer", "Poetry", "packages", ["~/Library/Caches/pypoetry/*"])
rule("developer", "Yarn", "packages", ["~/Library/Caches/Yarn/*"])
rule("developer", "pnpm", "packages", ["~/Library/Caches/pnpm/*"])
rule("developer", "node-gyp", "packages", ["~/Library/Caches/node-gyp/*"])
rule("developer", "Deno", "packages", ["~/Library/Caches/deno/*"])
rule("developer", "CocoaPods", "packages", ["~/Library/Caches/CocoaPods/*"])
rule("developer", "Swift Package Manager", "packages", ["~/Library/Caches/org.swift.swiftpm/*"])
rule("developer", "Go", "build", ["~/Library/Caches/go-build/*"])
rule("developer", "Cargo", "packages",
     ["~/.cargo/registry/cache/*", "~/.cargo/registry/src/*", "~/.cargo/git/checkouts/*", "~/.cargo/git/db/*",
      "~/.cargo/registry/index/*/.cache/*"])
rule("developer", "Composer", "packages", ["~/.composer/cache/*", "~/Library/Caches/composer/*"])
rule("developer", "Bundler", "packages", ["~/.bundle/cache/*"])
rule("developer", "Dart/Flutter", "packages", ["~/.pub-cache/hosted/*"])
rule("developer", "Android", "cache", ["~/.android/cache/*", "~/.android/build-cache/*"])
rule("developer", "Expo", "packages", ["~/.expo/*-cache/*", "~/.expo/expo-go/*"])
rule("developer", "Yarn", "packages", ["~/.yarn/cache/*", "~/.yarn/berry/cache/*"])
rule("developer", "node-gyp", "packages", ["~/.node-gyp/*"])
rule("developer", "Turborepo", "build", ["~/.turbo/cache/*"])
rule("developer", "pyenv", "packages", ["~/.pyenv/cache/*"])
rule("developer", "rbenv", "packages", ["~/.rbenv/cache/*"])
rule("developer", "RubyGems", "packages", ["~/.gem/specs/*", "~/.gem/ruby/*/cache/*.gem"])
rule("developer", "Hex (Elixir)", "packages", ["~/.hex/cache/*"])
rule("developer", "opam (OCaml)", "packages", ["~/.opam/download-cache/*"])
rule("developer", "Docker Buildx", "build", ["~/.docker/buildx/cache/*"])
rule("developer", "kubectl", "cache", ["~/.kube/cache/*", "~/.kube/http-cache/*"])
rule("developer", "Google Cloud CLI", "log", ["~/.config/gcloud/logs/*"])
rule("developer", "Azure CLI", "log", ["~/.azure/logs/*"])
rule("developer", "SonarScanner", "cache", ["~/.sonar/*"])
rule("developer", "tnpm", "packages", ["~/.tnpm/_cacache/*"])
rule("developer", "tnpm", "log", ["~/.tnpm/_logs/*"])
rule("developer", "pytest", "cache", ["~/.pytest_cache/*"])
rule("developer", "Vite", "cache", ["~/.vite/cache/*"])
rule("developer", "Parcel", "cache", ["~/.parcel-cache/*"])
rule("developer", "CPAN", "build", ["~/.cpan/build/*"])
rule("developer", "Podman", "temp", ["~/.local/share/containers/storage/tmp/*"])
rule("developer", "Grafana", "cache", ["~/.grafana/cache/*"])
rule("developer", "CI-Werkzeuge", "cache", ["~/.github/cache/*", "~/.circleci/cache/*"])
rule("developer", "Jenkins", "build", ["~/.jenkins/workspace/*/target/*"], safety="review")
rule("developer", "Cacher", "log", ["~/.cacher/logs/*"])
rule("developer", "Kite", "log", ["~/.kite/logs/*"])
# Running notebooks keep their kernel connection files here; reviewed.
rule("developer", "Jupyter", "temp", ["~/.jupyter/runtime/*"], safety="review")
# Short-lived AWS sign-in tokens: after removal the CLI asks to sign in again.
rule("developer", "AWS CLI", "cache", ["~/.aws/cli/cache/*"], safety="review")
rule("developer", "Zsh", "cache", ["~/.zcompdump*"])
rule("developer", "less", "history", ["~/.lesshst"])
rule("developer", "Vim", "temp", ["~/.viminfo.tmp"])
rule("developer", "wget", "cache", ["~/.wget-hsts"], safety="review")
rule("developer", "Vagrant", "temp", ["~/.vagrant.d/tmp/*"])
rule("developer", "Oh My Zsh", "cache", ["~/.oh-my-zsh/cache/*"])
# Big downloads that take long to fetch again: listed, never pre-selected.
rule("developer", "Gradle", "packages", ["~/.gradle/caches/*"], safety="review")
rule("developer", "Gradle-Protokolle", "log", ["~/.gradle/daemon/*/*.log"])
rule("developer", "Playwright", "packages", ["~/Library/Caches/ms-playwright/*"], safety="review")
rule("developer", "Cypress", "packages", ["~/Library/Caches/Cypress/*"], safety="review")
rule("developer", "Hugging Face", "models", ["~/.cache/huggingface/*"])
# AI coding agents. Their sessions, history and memories are never touched; only what a finished job left.
rule("developer", "Claude Code", "temp", ["~/.claude/shell-snapshots/*", "~/.claude/paste-cache/*"], minAgeDays=7)
rule("developer", "Claude Code", "log", ["~/.claude/telemetry/*"], minAgeDays=7)
rule("developer", "Codex", "log", ["~/.codex/log/*"], minAgeDays=7)
rule("developer", "Codex", "cache", ["~/.codex/cache/*", "~/.codex/plugins/cache/*"], skipIfRunning="Codex")
rule("developer", "KI-Arbeitskopien", "worktrees", ["~/.codex/worktrees/*"], minAgeDays=3)
rule("developer", "Kommandozeilen-Caches (~/.cache)", "cache", ["~/.cache/*"], safety="review")

# --- Broad rules: every app, by macOS convention -------------------------------------------------
# Chromium's own cache folders in every Electron app and Chromium browser (Slack, Discord, VS Code, Notion,
# Obsidian, Teams, Dia …), in the app folder or in a profile up to two levels below it. A plain "Cache"
# folder counts only next to Chromium's Code Cache/GPUCache; elsewhere it is reviewed further down.
CHROMIUM_DIRS = ("{Cache,Code Cache,GPUCache,GPUPersistentCache,DawnCache,DawnGraphiteCache,DawnWebGPUCache,GrShaderCache,"
                 "ShaderCache,GraphiteDawnCache,CachedData,component_crx_cache,extensions_crx_cache,Application Cache}")
rule("app_caches", "Chromium-Caches von Apps", "cache",
     [f"~/Library/Application Support/{depth}{CHROMIUM_DIRS}" for depth in ("*/", "*/*/", "*/*/*/")]
     + [f"~/Library/Application Support/{depth}Service Worker/{{CacheStorage,ScriptCache}}" for depth in ("*/", "*/*/", "*/*/*/")],
     exclude=["~/Library/Application Support/com.apple.*"], skipRunningOwner=True, chromiumOnly=True)
# Downloaded extension packages of VS Code and its forks (Cursor, Windsurf …).
rule("app_caches", "Chromium-Caches von Apps", "cache", ["~/Library/Application Support/*/CachedExtensionVSIXs/*"],
     skipRunningOwner=True)
rule("app_caches", "Chromium-Caches von Apps", "cache", ["~/Library/Application Support/*/WebStorage/*/CacheStorage/*"],
     exclude=["~/Library/Application Support/com.apple.*"], skipRunningOwner=True, chromiumOnly=True)
rule("app_caches", "App-Protokolle", "log",
     ["~/Library/Application Support/*/{log,logs,Logs}/*", "~/Library/Application Support/*/*/{log,logs,Logs}/*"],
     exclude=["~/Library/Application Support/com.apple.*"])
rule("app_caches", "Weitere Cache-Ordner von Apps", "cache",
     ["~/Library/Application Support/*/{Cache,Caches,cache,caches}/*"],
     exclude=["~/Library/Application Support/com.apple.*", "~/Library/Application Support/MobileSync*"],
     skipRunningOwner=True, safety="review")
# Library/Caches is where macOS expects purgeable data; the system itself empties it when space runs low.
rule("app_caches", "App-Caches", "cache", ["~/Library/Caches/*/*"],
     exclude=["~/Library/Caches/com.apple.*"], skipRunningOwner=True)
rule("app_caches", "Caches in App-Containern", "cache", ["~/Library/Containers/*/Data/Library/Caches/*"],
     exclude=["~/Library/Containers/com.apple.*"], skipRunningOwner=True)
rule("app_caches", "App-Protokolle", "log", ["~/Library/Containers/*/Data/Library/Logs/*"])
# Temporary files of sandboxed apps. Background services keep some open, so they are reviewed.
rule("app_caches", "Temporäre Dateien in App-Containern", "temp", ["~/Library/Containers/*/Data/tmp/*"],
     skipRunningOwner=True, safety="review")
rule("app_caches", "Caches in Gruppen-Containern", "cache", ["~/Library/Group Containers/*/Library/Caches/*"],
     safety="review")
rule("app_caches", "App-Protokolle", "log",
     ["~/Library/Group Containers/*/Library/{Logs,Application Support/Logs,Application Support/logs}/*"],
     exclude=["~/Library/Group Containers/group.com.apple.*", "~/Library/Group Containers/*.com.apple.*"])
rule("app_caches", "App-Protokolle", "log", ["~/Library/Logs/*"])
# Apple's own caches are rebuilt too, but some (media analysis, maps) take long; reviewed, not pre-selected.
rule("system", "macOS-Caches", "cache",
     ["~/Library/Caches/com.apple.*/*", "~/Library/Containers/com.apple.*/Data/Library/Caches/*"],
     skipRunningOwner=True, safety="review")

out = os.path.join(os.path.dirname(__file__), "../../Packages/SwabrCore/Sources/SwabrCore/Resources/clean_rules.json")
with open(out, "w", encoding="utf-8") as f:
    json.dump(rules, f, ensure_ascii=False, indent=1)
print(len(rules), "rules")
