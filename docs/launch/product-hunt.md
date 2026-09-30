# Product Hunt

**Name:** VoidBar

**Tagline (60 characters max):** A native productivity panel for your MacBook notch

**Topics:** Mac, Productivity, Open Source, Developer Tools

**Description (260 characters max)**

VoidBar turns the MacBook notch into a hover-to-open panel: media controls, file shelf, clipboard history, notes, translation, calendar, Pomodoro, and more. Native SwiftUI + AppKit, free and open source, no account.

**Links:** <RELEASE_URL> · <REPO_URL>

**Pricing:** Free

## First maker comment

Hi Product Hunt, I'm the developer of VoidBar.

The space around the MacBook notch is empty on every modern MacBook, and I kept switching windows for two-second jobs. VoidBar puts those jobs there: hover over the notch, skip a track, drop a file on the shelf, grab something from clipboard history, translate a sentence, start a focus timer, and move on.

It's built natively with SwiftUI and AppKit, has no account and no VoidBar server, and is MIT-licensed on GitHub. Two honest caveats: it needs an Apple Silicon Mac on macOS 15+, and it isn't notarized yet, so the first launch needs one trip to Privacy & Security → Open Anyway.

I'd love to hear which tabs you'd actually keep and what feels missing.

## Feature bullets

- Media controls for system Now Playing, Apple Music, Spotify, and browsers
- Temporary file shelf you can drag files into and out of
- Clipboard history kept in memory only
- Notes and searchable snippets
- English ↔ Ukrainian translation with Apple's on-device framework
- Calendar with one-click meeting links, Pomodoro timer, weather, TickTick tasks
- Hide and reorder tabs; English and Ukrainian interface

## Image checklist

- [ ] Thumbnail 240×240: the VoidBar app icon (`Resources/AppIcon.icns`, exported to PNG)
- [ ] Gallery 1270×760, recorded with `Scripts/capture-demo.sh`: media, timer, translation, clipboard
- [ ] Walkthrough GIF: `docs/assets/walkthrough.gif`; Usage tab: `docs/assets/usage-tour.gif` or the still `docs/assets/usage.png`
- [ ] Full-resolution MP4s for the gallery and social posts: run `./Scripts/capture-demo.sh`, then use `build/media/walkthrough.mp4` and `build/media/usage-tour.mp4`
- [ ] No third-party album artwork, player logos, or personal data in any image
