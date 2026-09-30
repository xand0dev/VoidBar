#!/bin/bash
# Records the website's media from the real panel with invented demo content:
# the walkthrough and Usage tour as MP4, a poster, stills of the main tabs, the
# live island, and the Overview in a blood-red accent for the "make it yours"
# section. Output: site/media. Needs ffmpeg.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/site/media"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"

echo "==> default look"
VOIDBAR_GALLERY_OUT="$WORK/default" VOIDBAR_ASSETS_OUT="$WORK/assets" \
    "$ROOT/Scripts/capture-demo.sh" en >/dev/null
for scene in walkthrough usage-tour; do
    ffmpeg -v error -y -i "$ROOT/build/media/$scene.mp4" \
        -vf "scale=1280:-2:flags=lanczos,format=yuv420p" \
        -c:v libx264 -preset slow -crf 22 -tune animation -movflags +faststart -an \
        "$OUT/$scene.mp4"
done
ffmpeg -v error -y -ss 3.4 -i "$ROOT/build/media/walkthrough.mp4" -frames:v 1 \
    -vf "scale=1280:-2:flags=lanczos" -q:v 3 "$OUT/walkthrough-poster.jpg"

still() { # gallery name, output name, crop height fraction
    local src
    src="$(ls "$1"/*-"$2".png | head -1)"
    ffmpeg -v error -y -i "$src" -vf "crop=iw:ih*$4:0:0,scale=1200:-2:flags=lanczos" -q:v 3 "$OUT/$3.jpg"
}
for tab in home media usage timer translate clipboard shelf notes weather calendar monitor; do
    still "$WORK/default" "$tab" "$tab" 0.86
done
# The island: the notch strip only, around the notch.
ffmpeg -v error -y -i "$(ls "$WORK"/default/*-collapsed.png)" \
    -vf "crop=iw*0.5:ih*0.14:iw*0.25:0,scale=1000:-2:flags=lanczos" -q:v 3 "$OUT/island.jpg"

echo "==> blood-red accent"
VOIDBAR_CAPTURE_ACCENT=blood VOIDBAR_CAPTURE_AURORA=accent \
VOIDBAR_GALLERY_OUT="$WORK/blood" VOIDBAR_ASSETS_OUT="$WORK/assets" \
    "$ROOT/Scripts/capture-demo.sh" en >/dev/null
still "$WORK/blood" home home-blood 0.86
still "$WORK/blood" usage usage-blood 0.86

# Page icon and link preview.
sips -s format png -z 256 256 "$ROOT/Resources/AppIcon.icns" --out "$OUT/icon.png" >/dev/null
cp "$ROOT/docs/assets/social-preview.png" "$OUT/og.png"

for file in "$OUT"/*; do
    echo "    $(basename "$file") $(( $(stat -f %z "$file") / 1024 )) KB"
done
