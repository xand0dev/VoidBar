# Show HN

**Title**

Show HN: VoidBar – An open-source productivity panel for the MacBook notch

**URL**

<REPO_URL>

**First comment**

Hi HN, I built VoidBar because the strip around the MacBook notch is unused, and I kept paying context switches for two-second tasks: pause music, park a file, find something I copied earlier, translate a sentence, start a timer.

VoidBar is a hover-to-open panel that hangs from the notch. It has media controls, a file shelf, clipboard history, notes, snippets, translation, calendar join links, Pomodoro, weather, TickTick tasks, a teleprompter, and a system monitor. The aim is a small productivity hub rather than a media widget.

Some technical notes:

- It's SwiftUI inside a borderless, non-activating `NSPanel`. It never becomes the active app; it only takes key status when a text tab needs the keyboard, and gives it back when you click elsewhere.
- Hover is driven by sampling the pointer rather than tracking areas, with a dwell threshold so a pointer flung across the menu bar doesn't open anything. Outside the visible panel, `ignoresMouseEvents` is flipped so clicks reach the app underneath.
- Since macOS 15.4, MediaRemote answers only trusted clients. VoidBar loads a small helper into `/usr/bin/perl` (a platform binary without library validation) to read system Now Playing, and falls back to scripting Apple Music and Spotify if that's unavailable.
- The progress bar projects the player's elapsed time from its timestamp and playback rate, and ignores small backward corrections so it never visibly jumps back.

Download (Apple Silicon, macOS 15+): <RELEASE_URL>

It's MIT-licensed, has no account or server, and PRIVACY.md lists every network request. It is not notarized yet (no Developer ID), so first launch needs "Open Anyway"; the DMG ships with a SHA-256 checksum and a GitHub build provenance attestation, and it builds from source with one command.

I'd especially like feedback on the interaction model (hover-to-open vs. click) and on anything that feels un-Mac-like.
