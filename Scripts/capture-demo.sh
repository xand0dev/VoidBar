#!/bin/bash
# Re-records the README walkthrough, the media still, and the social preview
# from the real panel views, filled with invented demo content.
#
# Needs ffmpeg. The capture runs a debug build with VOIDBAR_CAPTURE_DIR set;
# see Sources/VoidBar/App/DemoCapture.swift. Nothing is read from this Mac's
# media, clipboard, or settings.
#
# Usage: Scripts/capture-demo.sh [en|uk]   (default: en)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LANGUAGE="${1:-en}"
case "$LANGUAGE" in
  en) SUFFIX="" ;;
  uk) SUFFIX=".uk" ;;
  *) echo "usage: capture-demo.sh [en|uk]" >&2; exit 1 ;;
esac
command -v ffmpeg >/dev/null || { echo "ffmpeg is required" >&2; exit 1; }

# VOIDBAR_ASSETS_OUT sends the README media elsewhere, for recordings that
# must not replace the committed ones.
ASSETS="${VOIDBAR_ASSETS_OUT:-$ROOT/docs/assets}"
mkdir -p "$ASSETS"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

"$ROOT/Scripts/bundle.sh" debug

echo "==> capturing ($LANGUAGE)"
VOIDBAR_CAPTURE_DIR="$WORK" \
    "$ROOT/build/VoidBar.app/Contents/MacOS/VoidBar" \
    -AppleLanguages "($LANGUAGE)" -AppleShowScrollBars WhenScrolling

# Optional: keep the per-tab stills for design reviews.
if [ -n "${VOIDBAR_GALLERY_OUT:-}" ]; then
    mkdir -p "$VOIDBAR_GALLERY_OUT"
    cp "$WORK"/gallery/*.png "$VOIDBAR_GALLERY_OUT"/
    echo "==> gallery: $(ls "$WORK"/gallery | wc -l | tr -d ' ') stills"
fi

echo "==> encoding"
# GIFs for the README: only the changed rectangle of each frame is stored,
# which is what keeps a mostly still panel small. MP4s at full resolution go to
# build/media for posts and launch pages; they are not committed.
MEDIA="$ROOT/build/media"
mkdir -p "$MEDIA"
for scene in walkthrough usage-tour; do
    ffmpeg -v error -y -f concat -i "$WORK/$scene.ffconcat" \
        -vf "fps=30,scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p" \
        -c:v libx264 -preset slow -crf 14 -tune animation -movflags +faststart -an \
        "$MEDIA/$scene$SUFFIX.mp4"
    # The GIF is made from the MP4: video encoding smooths the aurora's
    # gradients, which the GIF palette then needs far fewer bytes to hold.
    ffmpeg -v error -y -i "$MEDIA/$scene$SUFFIX.mp4" -vf "\
fps=12,scale=800:-1:flags=lanczos,split[a][b];\
[a]palettegen=max_colors=96:stats_mode=diff:reserve_transparent=0[p];\
[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
        -loop 0 "$ASSETS/$scene$SUFFIX.gif"
done

for still in media usage; do
    ffmpeg -v error -y -i "$WORK/$still@2x.png" -vf "\
split[a][b];[a]palettegen=max_colors=256[p];[b][p]paletteuse=dither=none" \
        "$ASSETS/$still$SUFFIX.png"
done

if [ "$LANGUAGE" = en ]; then
    ffmpeg -v error -y -i "$WORK/social-preview@2x.png" -vf "\
scale=1280:640:flags=lanczos,split[a][b];[a]palettegen=max_colors=256[p];[b][p]paletteuse=dither=none" \
        "$ASSETS/social-preview.png"
fi

for file in "$ASSETS"/walkthrough$SUFFIX.gif "$ASSETS"/usage-tour$SUFFIX.gif \
    "$ASSETS"/media$SUFFIX.png "$ASSETS"/usage$SUFFIX.png "$MEDIA"/*$SUFFIX.mp4; do
    echo "    $(basename "$file") $(( $(stat -f %z "$file") / 1024 )) KB"
done
