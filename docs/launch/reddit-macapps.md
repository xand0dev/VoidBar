# r/MacApps

**Title**

[OS] VoidBar — a native, open-source productivity panel for the MacBook notch (media, shelf, clipboard, translation, Pomodoro)

**Body**

I'm the developer of VoidBar, a free and open-source macOS app that turns the area around the MacBook notch into a hover-to-open panel.

**Problem**

I kept switching windows for tiny tasks: skip a track, park a file for a minute, grab something I copied ten minutes ago, translate one sentence, start a focus timer. Each is a two-second job that costs a context switch. The notch area is dead space on every modern MacBook, so VoidBar puts those small tools there: hover, do the thing, move the pointer away.

What's inside: media controls (system Now Playing, Apple Music, Spotify, browsers), a temporary file shelf, in-memory clipboard history, notes, snippets, English ↔ Ukrainian translation via Apple's on-device framework, calendar with join links, Pomodoro, weather, TickTick tasks, a teleprompter, and a system monitor. Tabs can be hidden and reordered.

**Comparison**

Most notch apps focus on media and "Dynamic Island" style activity. VoidBar has media controls too, but it's aimed at being a small productivity hub. It's native SwiftUI + AppKit (no Electron), has no account and no VoidBar server, and the full network/storage/permission map is in PRIVACY.md.

**Pricing**

Free and open source (MIT).

**Changelog (0.6.0)**

- First public downloadable release: DMG + SHA-256, built from the tag by GitHub Actions
- English ↔ Ukrainian translation
- Fixed the media progress bar jumping back when the panel opens
- Customizable tab order and visibility

Honest caveats: it's Apple Silicon only, needs macOS 15+, and it is **not notarized** (no Developer ID yet), so the first launch needs System Settings → Privacy & Security → Open Anyway. The README has the exact steps.

**AI disclosure**

Parts of the code, documentation, and release tooling were written with AI coding assistants. I review, test, and maintain everything that ships.

Download: <RELEASE_URL>
Source: <REPO_URL>

Bug reports and "this doesn't fit my workflow because…" feedback are both very welcome.
