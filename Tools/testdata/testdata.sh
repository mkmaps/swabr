#!/bin/sh
# Test data for trying out Swabr by hand. Every item carries "swabr-test" or "SwabrTest" in its
# name, so it is easy to recognise in the app, in the Trash and in History.
#   sh Tools/testdata/testdata.sh create   lays out the data (about 500 MB)
#   sh Tools/testdata/testdata.sh status   shows what is still there
#   sh Tools/testdata/testdata.sh remove   deletes what is left (also from the Trash)
set -eu
H="$HOME"
ID_APP="com.example.swabr-test-app"          # installed test app (Apps → Deinstallieren)
ID_GONE="com.example.swabr-test-geloescht"   # app that no longer exists (Aufräumen → Reste entfernter Apps)
OLD=202608010000                                  # 1 Aug 2026: older than 30 days (leftovers) and 7 days (projects)

PATHS="
$H/Library/Caches/SwabrTest-Cache
$H/Library/Logs/SwabrTest
$H/Library/Caches/$ID_GONE
$H/Library/Application Support/$ID_GONE
$H/SwabrTest
$H/Downloads/SwabrTest-Installer.dmg
$H/Downloads/SwabrTest-Setup.pkg
$H/Applications/SwabrTest.app
$H/Library/Application Support/$ID_APP
$H/Library/Caches/$ID_APP
$H/Library/Preferences/$ID_APP.plist
$H/Library/Saved Application State/$ID_APP.savedState
"

# Writes a file of $2 megabytes with real (not sparse) blocks.
blob() { mkdir -p "$(dirname "$1")"; dd if=/dev/zero of="$1" bs=1048576 count="$2" 2>/dev/null; }

create() {
    # Aufräumen: an app cache (general rule ~/Library/Caches) and logs.
    blob "$H/Library/Caches/SwabrTest-Cache/data/swabr-test-1.bin" 80
    blob "$H/Library/Caches/SwabrTest-Cache/data/swabr-test-2.bin" 40
    blob "$H/Library/Logs/SwabrTest/swabr-test-1.log" 15
    blob "$H/Library/Logs/SwabrTest/swabr-test-2.log" 5

    # Aufräumen → Reste entfernter Apps: data of an app that is not installed, untouched for months.
    blob "$H/Library/Caches/$ID_GONE/swabr-test-cache.db" 30
    blob "$H/Library/Application Support/$ID_GONE/swabr-test-state.bin" 10
    touch -t $OLD "$H/Library/Caches/$ID_GONE/swabr-test-cache.db" "$H/Library/Caches/$ID_GONE" \
        "$H/Library/Application Support/$ID_GONE/swabr-test-state.bin" "$H/Library/Application Support/$ID_GONE"

    # Projekte: a Node project and a Rust project, last worked on in August (so they start ticked).
    P="$H/SwabrTest"
    mkdir -p "$P/node-projekt/src" "$P/rust-projekt/src"
    printf '{ "name": "swabr-test", "version": "1.0.0" }\n' > "$P/node-projekt/package.json"
    printf 'console.log("test")\n' > "$P/node-projekt/src/index.js"
    blob "$P/node-projekt/node_modules/test-paket/swabr-test-lib.js" 90
    blob "$P/node-projekt/dist/swabr-test-bundle.js" 20
    printf '[package]\nname = "swabr-test"\nversion = "0.1.0"\n' > "$P/rust-projekt/Cargo.toml"
    printf 'fn main() {}\n' > "$P/rust-projekt/src/main.rs"
    blob "$P/rust-projekt/target/debug/swabr-test-bin" 70
    find "$P" -exec touch -t $OLD {} +
    printf 'Testdaten von Swabr (Tools/testdata/testdata.sh). Kann gelöscht werden.\n' > "$P/LIESMICH.txt"

    # Installer: a disk image and a package in Downloads.
    blob "$H/Downloads/SwabrTest-Installer.dmg" 50
    blob "$H/Downloads/SwabrTest-Setup.pkg" 25

    # Apps → Deinstallieren: a tiny app in ~/Applications with settings, caches and saved state.
    A="$H/Applications/SwabrTest.app/Contents"
    mkdir -p "$A/MacOS" "$A/Resources"
    cat > "$A/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$ID_APP</string>
<key>CFBundleName</key><string>SwabrTest</string>
<key>CFBundleExecutable</key><string>SwabrTest</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
</dict></plist>
EOF
    printf '#!/bin/sh\nexit 0\n' > "$A/MacOS/SwabrTest"
    chmod +x "$A/MacOS/SwabrTest"
    blob "$A/Resources/swabr-test-daten.bin" 10
    blob "$H/Library/Application Support/$ID_APP/swabr-test-datenbank.sqlite" 20
    blob "$H/Library/Caches/$ID_APP/swabr-test-cache.bin" 15
    defaults write "$ID_APP" SwabrTest -bool true
    blob "$H/Library/Saved Application State/$ID_APP.savedState/swabr-test.data" 1

    echo "Testdaten angelegt."
    status
}

status() {
    echo "$PATHS" | while IFS= read -r p; do
        [ -n "$p" ] || continue
        if [ -e "$p" ]; then printf '  vorhanden  %6s  %s\n' "$(du -sh "$p" | cut -f1)" "${p#$H/}"
        else printf '  entfernt           %s\n' "${p#$H/}"; fi
    done
    n=0
    for t in "$H/.Trash/"* "$H/.Trash/".[!.]*; do
        [ -e "$t" ] || continue
        find "$t" -maxdepth 6 \( -iname '*swabr-test*' -o -iname '*SwabrTest*' \) -print -quit 2>/dev/null | grep -q . && n=$((n + 1))
    done
    echo "  im Papierkorb: $n Objekte mit Testnamen"
}

remove() {
    echo "$PATHS" | while IFS= read -r p; do
        if [ -n "$p" ]; then rm -rf "$p"; fi
    done
    defaults delete "$ID_APP" 2>/dev/null || true
    # Test items Swabr moved to the Trash: their name or a file inside carries the test marker.
    for t in "$H/.Trash/"* "$H/.Trash/".[!.]*; do
        [ -e "$t" ] || continue
        if find "$t" -maxdepth 6 \( -iname '*swabr-test*' -o -iname '*SwabrTest*' \) -print -quit 2>/dev/null | grep -q .; then
            rm -rf "$t"
        fi
    done
    echo "Testdaten entfernt."
    status
}

case "${1:-}" in
    create) create ;;
    status) status ;;
    remove) remove ;;
    *) echo "Aufruf: sh $0 create|status|remove"; exit 1 ;;
esac
