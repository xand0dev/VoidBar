#!/bin/bash
# Builds VoidBar.app without Xcode: SwiftPM produces the binary, this script
# assembles the bundle around it and ad-hoc signs it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-release}"
APP="$ROOT/build/VoidBar.app"
VERSION="$(sed -n 's/^VERSION=//p' "$ROOT/Scripts/version" 2>/dev/null || echo 0.1.0)"

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

# Таблицы строк кладутся прямо в бандл, а не через ресурсы SwiftPM: бандл здесь
# собирается вручную, и .lproj рядом с исполняемым файлом — то, где их ищет сама
# macOS. Язык она выбирает потом сама, по списку предпочитаемых у пользователя.
echo "==> локализации"
for lproj in "$ROOT"/Resources/*.lproj; do
    [ -d "$lproj" ] || continue
    cp -R "$lproj" "$APP/Contents/Resources/"
    echo "    $(basename "$lproj")"
done

echo "==> ad-hoc signing"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || \
    echo "    (codesign failed — the app still runs, but TCC prompts may repeat)"

echo "==> done: $APP"
