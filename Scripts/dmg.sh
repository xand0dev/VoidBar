#!/bin/bash
# Packs a freshly built VoidBar.app into a drag-to-Applications disk image and
# writes a SHA-256 checksum next to it.
#
# Output (the architecture is the one the host toolchain built for):
#   build/VoidBar-<version>-<arch>.dmg
#   build/VoidBar-<version>-<arch>.dmg.sha256
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/VoidBar.app"
VERSION="$(sed -n 's/^VERSION=//p' "$ROOT/Scripts/version")"
if [ -z "$VERSION" ]; then
    echo "Scripts/version does not define VERSION" >&2
    exit 1
fi

# Always rebuild. Packing whatever was left in build/ would ship an app whose
# version silently differs from the one in the file name.
"$ROOT/Scripts/bundle.sh" release

ARCH="$(lipo -archs "$APP/Contents/MacOS/VoidBar" | tr ' ' '-')"
NAME="VoidBar-$VERSION-$ARCH"
DMG="$ROOT/build/$NAME.dmg"
SUM="$DMG.sha256"

INSIDE="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
if [ "$INSIDE" != "$VERSION" ]; then
    echo "Bundle version $INSIDE does not match Scripts/version $VERSION" >&2
    exit 1
fi

echo "==> staging disk image"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
# ditto keeps the signature, extended attributes, and symlinks intact.
ditto "$APP" "$STAGE/VoidBar.app"
ln -s /Applications "$STAGE/Applications"

echo "==> creating $NAME.dmg"
rm -f "$DMG" "$SUM"
hdiutil create \
    -volname "VoidBar $VERSION" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDZO \
    -imagekey zlib-level=9 \
    -quiet \
    "$DMG"

# The checksum file names the image without a directory, so it verifies with
# `shasum -a 256 -c` from wherever both files were downloaded to.
(cd "$(dirname "$DMG")" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$SUM")")

"$ROOT/Scripts/verify-release.sh" "$DMG"

SIZE="$(du -h "$DMG" | cut -f1 | tr -d ' ')"
echo "==> done: $DMG ($SIZE)"
echo "    $(cat "$SUM")"

if ! spctl --assess --type execute "$APP" >/dev/null 2>&1; then
    cat <<'NOTE'

    This build is ad-hoc signed, not signed with a Developer ID, and not
    notarized. Gatekeeper blocks its first launch on other Macs until the user
    chooses System Settings → Privacy & Security → Open Anyway.
NOTE
fi
