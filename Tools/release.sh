#!/bin/bash
# Builds a release of Swabr.
#
#   Tools/release.sh direct   Release build, signed, notarized when possible, packed into a DMG
#   Tools/release.sh store    Archive for App Store Connect (needs an "Apple Distribution" certificate)
#   Tools/release.sh all      both, one after the other
#
# Notarization needs a "Developer ID Application" certificate and stored notarytool credentials:
#   xcrun notarytool store-credentials swabr-notary --apple-id <mail> --team-id Y94QZAZZ45
# Without them the script still builds a signed DMG and says what is missing.
set -euo pipefail

EDITION="${1:-direct}"
if [[ "$EDITION" == "all" ]]; then
    "$0" direct
    "$0" store || echo "Store-Paket übersprungen (siehe Hinweis oben)."
    exit 0
fi
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/dist"
BUILD="$ROOT/build/release"
PROFILE="${NOTARY_PROFILE:-swabr-notary}"
VERSION="$(awk -F'"' '/MARKETING_VERSION/ {print $2; exit}' "$ROOT/project.yml")"

mkdir -p "$OUT"
cd "$ROOT"
xcodegen generate >/dev/null

has_identity() { security find-identity -v -p codesigning | grep -q "$1"; }

if [[ "$EDITION" == "store" ]]; then
    has_identity "Apple Distribution" || { echo "Kein „Apple Distribution“-Zertifikat: in Xcode unter Settings → Accounts → Manage Certificates anlegen."; exit 1; }
    xcodebuild -project Swabr.xcodeproj -scheme SwabrStore -configuration Release \
        -archivePath "$BUILD/SwabrStore.xcarchive" -allowProvisioningUpdates archive | tail -1
    xcodebuild -exportArchive -archivePath "$BUILD/SwabrStore.xcarchive" -exportPath "$OUT/store" \
        -exportOptionsPlist Tools/ExportStore.plist -allowProvisioningUpdates | tail -1
    echo "App-Store-Paket: $OUT/store (mit Transporter oder Xcode Organizer hochladen)"
    exit 0
fi

echo "== Release-Build SwabrDirect $VERSION"
xcodebuild -project Swabr.xcodeproj -scheme SwabrDirect -configuration Release \
    -archivePath "$BUILD/Swabr.xcarchive" -allowProvisioningUpdates archive | tail -1

APP="$BUILD/export/Swabr OP.app"
rm -rf "$BUILD/export"
NOTARIZE=false
if has_identity "Developer ID Application"; then
    xcodebuild -exportArchive -archivePath "$BUILD/Swabr.xcarchive" -exportPath "$BUILD/export" \
        -exportOptionsPlist Tools/ExportDirect.plist -allowProvisioningUpdates | tail -1
    if xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
        NOTARIZE=true
    else
        echo "Hinweis: keine notarytool-Zugangsdaten „${PROFILE}“, App wird nicht notarisiert."
    fi
else
    echo "Hinweis: kein „Developer ID Application“-Zertifikat. Die App wird mit dem Entwicklungszertifikat"
    echo "         signiert und läuft auf diesem Mac, auf anderen Macs blockiert Gatekeeper sie."
    mkdir -p "$BUILD/export"
    ditto "$BUILD/Swabr.xcarchive/Products/Applications/Swabr OP.app" "$APP"
fi

if [[ "$NOTARIZE" == true ]]; then
    echo "== Notarisiere App"
    ditto -c -k --keepParent "$APP" "$BUILD/Swabr.zip"
    xcrun notarytool submit "$BUILD/Swabr.zip" --keychain-profile "$PROFILE" --wait
    xcrun stapler staple "$APP"
fi

echo "== Erzeuge DMG"
DMG="$OUT/Swabr-$VERSION.dmg"
STAGE="$BUILD/dmg"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Swabr OP.app"
ln -s /Applications "$STAGE/Programme"
hdiutil create -volname "Swabr $VERSION" -srcfolder "$STAGE" -fs APFS -format ULFO -ov "$DMG" >/dev/null
SIGNER="$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/ {print $2; exit}')"
[[ -n "$SIGNER" ]] && codesign --sign "$SIGNER" --timestamp "$DMG"

if [[ "$NOTARIZE" == true ]]; then
    echo "== Notarisiere DMG"
    xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
    xcrun stapler staple "$DMG"
fi

codesign --verify --deep --strict "$APP" && echo "Signatur der App: gültig"
spctl --assess --type execute "$APP" 2>/dev/null && echo "Gatekeeper: akzeptiert" || echo "Gatekeeper: nicht akzeptiert (ohne Developer ID und Notarisierung erwartet)"
echo "Fertig: $DMG ($(du -h "$DMG" | cut -f1))"
