#!/bin/bash
# Builds VoidBar.app without Xcode: SwiftPM produces the binary, this script
# assembles the bundle around it and ad-hoc signs it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-release}"
APP="$ROOT/build/VoidBar.app"
VERSION="$(sed -n 's/^VERSION=//p' "$ROOT/Scripts/version")"
if [ -z "$VERSION" ]; then
    echo "Scripts/version does not define VERSION" >&2
    exit 1
fi

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG" --package-path "$ROOT"
BIN="$(swift build -c "$CONFIG" --package-path "$ROOT" --show-bin-path)/VoidBar"

echo "==> assembling $APP"
case "$APP" in
  "$ROOT"/build/*) ;;
  *)
    echo "Unsafe build directory: $APP" >&2
    exit 1
    ;;
esac
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/VoidBar"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>VoidBar</string>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key>
    <array><string>en</string><string>uk</string></array>
    <key>CFBundleDisplayName</key><string>VoidBar</string>
    <key>CFBundleIdentifier</key><string>dev.xand0.VoidBar</string>
    <key>CFBundleExecutable</key><string>VoidBar</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSSupportsAutomaticTermination</key><false/>
    <key>NSSupportsSuddenTermination</key><false/>
    <key>NSAppleEventsUsageDescription</key>
    <string>VoidBar reads the current track name and controls playback in Apple Music and Spotify.</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>VoidBar shows upcoming meetings and a button to join them.</string>
    <key>NSCalendarsUsageDescription</key>
    <string>VoidBar shows upcoming meetings and a button to join them.</string>
    <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
PLIST

if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

echo "==> compiling media helper"
clang -fobjc-arc -dynamiclib -o "$APP/Contents/Resources/libvoidmedia.dylib" \
      "$ROOT/Sources/VoidBarMediaHelper/helper.m"

# String tables go straight into the bundle rather than through SwiftPM
# resources: the bundle is assembled by hand here, and .lproj folders in
# Contents/Resources are where macOS itself looks for them. It then picks the
# language from the user's preferred list on its own.
echo "==> localizations"
for lproj in "$ROOT"/Resources/*.lproj; do
    [ -d "$lproj" ] || continue
    cp -R "$lproj" "$APP/Contents/Resources/"
    echo "    $(basename "$lproj")"
done

# Ad-hoc: no Developer ID is involved, so Gatekeeper still asks on other Macs.
# A failed signature is fatal — an unsigned bundle does not launch on Apple
# Silicon and re-prompts for every privacy permission.
echo "==> ad-hoc signing"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

echo "==> done: $APP"
