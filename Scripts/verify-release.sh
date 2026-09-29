#!/bin/bash
# Verifies a release disk image the way a downloader receives it: checksum,
# image integrity, layout, bundle version, localizations, and code signature.
#
# Usage: Scripts/verify-release.sh build/VoidBar-<version>-<arch>.dmg
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DMG="${1:?usage: verify-release.sh <path-to-dmg>}"
SUM="$DMG.sha256"
VERSION="$(sed -n 's/^VERSION=//p' "$ROOT/Scripts/version")"

fail() {
    echo "!!! $*" >&2
    exit 1
}

[ -f "$DMG" ] || fail "missing disk image: $DMG"
[ -f "$SUM" ] || fail "missing checksum file: $SUM"

echo "==> checksum"
(cd "$(dirname "$DMG")" && shasum -a 256 -c "$(basename "$SUM")")

echo "==> image integrity"
hdiutil verify -quiet "$DMG"

echo "==> mounting"
MOUNT="$(mktemp -d)"
cleanup() {
    hdiutil detach -quiet "$MOUNT" 2>/dev/null || hdiutil detach -quiet -force "$MOUNT" 2>/dev/null || true
    rmdir "$MOUNT" 2>/dev/null || true
}
trap cleanup EXIT
hdiutil attach -quiet -nobrowse -readonly -noautoopen -mountpoint "$MOUNT" "$DMG"

APP="$MOUNT/VoidBar.app"
[ -d "$APP" ] || fail "VoidBar.app is not at the root of the image"
[ -L "$MOUNT/Applications" ] || fail "Applications link is missing"
[ "$(readlink "$MOUNT/Applications")" = "/Applications" ] || fail "Applications link points elsewhere"
[ -x "$APP/Contents/MacOS/VoidBar" ] || fail "executable is missing"
[ -f "$APP/Contents/Resources/libvoidmedia.dylib" ] || fail "media helper is missing"
[ -f "$APP/Contents/Resources/AppIcon.icns" ] || fail "app icon is missing"

echo "==> bundle metadata"
PLIST="$APP/Contents/Info.plist"
SHORT="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$PLIST")"
[ "$SHORT" = "$VERSION" ] || fail "CFBundleShortVersionString $SHORT != Scripts/version $VERSION"
[ "$BUILD" = "$VERSION" ] || fail "CFBundleVersion $BUILD != Scripts/version $VERSION"
echo "    version $SHORT"
echo "    minimum macOS $(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' "$PLIST")"
echo "    architectures $(lipo -archs "$APP/Contents/MacOS/VoidBar")"

echo "==> localizations"
for lang in en uk; do
    [ -f "$APP/Contents/Resources/$lang.lproj/Localizable.strings" ] || fail "$lang.lproj is missing"
    plutil -lint -s "$APP/Contents/Resources/$lang.lproj/Localizable.strings" || fail "$lang.lproj does not parse"
    echo "    $lang"
done
EXTRA="$(find "$APP/Contents/Resources" -maxdepth 1 -name '*.lproj' ! -name en.lproj ! -name uk.lproj)"
[ -z "$EXTRA" ] || fail "unexpected localizations: $EXTRA"

echo "==> code signature"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dv "$APP" 2>&1 | grep -E '^(Signature|TeamIdentifier|Identifier)=' | sed 's/^/    /'

# Informational only: an ad-hoc signed build is expected to be rejected here.
echo "==> Gatekeeper assessment (informational)"
spctl --assess --type execute --verbose=2 "$APP" 2>&1 | sed 's/^/    /' || true

echo "==> verified: $(basename "$DMG")"
