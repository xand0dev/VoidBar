<h1 align="center">VoidBar</h1>

<p align="center">
  <strong>Your MacBook notch, finally useful.</strong><br>
  A fast, native macOS command shelf that stays invisible until you need it.
</p>

<p align="center">
  <a href="https://github.com/xand0dev/VoidBar/actions/workflows/build.yml"><img alt="Build" src="https://github.com/xand0dev/VoidBar/actions/workflows/build.yml/badge.svg"></a>
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/github/license/xand0dev/VoidBar?color=white"></a>
  <a href="https://github.com/xand0dev/VoidBar/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/xand0dev/VoidBar?color=white"></a>
  <img alt="macOS 15+" src="https://img.shields.io/badge/macOS-15%2B-black?logo=apple">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white">
</p>

<p align="center">
  <a href="https://github.com/xand0dev/VoidBar/releases/latest"><strong>Download the latest release</strong></a>
  &nbsp;·&nbsp; free and open source &nbsp;·&nbsp; macOS 15+ &nbsp;·&nbsp; Apple Silicon
</p>

<p align="center">
  <a href="https://xand0dev.github.io/VoidBar/">Website</a> ·
  <a href="#install">Install</a> ·
  <a href="#what-lives-inside">Features</a> ·
  <a href="#build-from-source">Build from source</a> ·
  <a href="#privacy-without-hand-waving">Privacy</a> ·
  <a href="README.uk.md">Українська</a>
</p>

![VoidBar walkthrough: the notch grows into a live island, opens onto the Overview, then a focus timer, English-to-Ukrainian translation, and clipboard history](docs/assets/walkthrough.gif)

VoidBar turns the unused space around the MacBook notch into a focused set of everyday tools: an Overview of what matters to you, media controls, a temporary file shelf, clipboard history, notes, translation, a focus timer, meetings, weather, and the limits of Claude Code and Codex. It opens on hover, closes when you leave, and never asks you to organize another window.

It is a productivity hub, not only a media widget. No Electron, no account, no VoidBar backend: just SwiftUI, AppKit, and macOS.

## Install

1. Download `VoidBar-<version>-arm64.dmg` from the [latest release](https://github.com/xand0dev/VoidBar/releases/latest).
2. Open the disk image and drag **VoidBar** to **Applications**.
3. Open VoidBar from Applications. Its icon appears in the menu bar, and the panel opens when you hover over the notch.

**Requirements:** macOS 15 Sequoia or later on an Apple Silicon Mac. Release builds are arm64 only; Intel Macs can [build from source](#build-from-source), although that configuration is untested. On a Mac without a notch, the panel opens from the top center of the screen or from the menu bar icon.

### First launch: the build is not notarized

Releases are ad-hoc signed but not signed with an Apple Developer ID or notarized, so macOS warns that it cannot verify the app. To open it anyway:

1. Open VoidBar once and choose **Done** in the warning. Do not choose **Move to Trash**.
2. Open **System Settings → Privacy & Security**, scroll to **Security**, and choose **Open Anyway** next to the VoidBar message.
3. Confirm with your password. Later launches open normally.

The same warning can appear once more when VoidBar starts its Now Playing helper, the small component that reads system and browser playback. Choose **Done**; if macOS keeps it blocked, VoidBar falls back to controlling Apple Music and Spotify directly, and every other feature works as usual.

To check that your download matches the published build, compare its checksum with the `.sha256` file attached to the release:

```bash
shasum -a 256 -c VoidBar-<version>-arm64.dmg.sha256
```

Release images are built from the tagged source by [GitHub Actions](.github/workflows/release.yml), which also publishes a build provenance attestation.

## What lives inside

### See everything at once

- **Overview** — the first thing the panel shows, built from the tabs you use: the player takes a large card while something plays, and widgets for your coding agents' limits, the latest clipboard entries and snippets (copied with one click), the focus timer, the latest note, shelf files, tasks, meetings, weather, and system load fill a grid around it. A widget only appears while its tab is on and it has something to show; choose and order them in **Preferences → Overview**. Every widget opens its full tab.
- **Live island** — while music plays or a timer runs, the notch grows a wing on each side, like a Dynamic Island: the cover or a timer ring on the left, a live equalizer or countdown on the right.

### Move things

- **Media** — system Now Playing, Apple Music, Spotify, and browser sessions with artwork, progress, seeking, and transport controls.
- **Shelf** — park files in the notch, switch apps, then drag them out where they belong.
- **Clipboard** — the latest 40 texts, links, and files, kept in memory while VoidBar runs. Copied images and screenshots land on the Shelf instead.

### Keep focus

- **Pomodoro** — 5, 10, 25, and 50 minute sessions with a daily completion count.
- **Notes** — a persistent scratchpad for thoughts that do not deserve a document yet.
- **Snippets** — searchable reusable text stored in a human-editable JSON file.
- **Teleprompter** — scrolling reference text without another window covering your work.

### Stay oriented

- **Calendar** — upcoming meetings and safe one-click links for Meet, Zoom, Teams, and more.
- **Translation** — Apple's native Translation framework instead of a custom cloud service.
- **Weather** — current conditions, the day's range, and the next hours through Open-Meteo.
- **TickTick** — tasks from your private TickTick iCal subscription.
- **System monitor** — CPU, memory, upload, and download activity at a glance.
- **Usage** — how much of the five-hour and weekly plan limits of Claude Code and Codex is left, and when each resets. Off by default; turn it on in Preferences. See [Coding agent limits](#coding-agent-limits).

![VoidBar media controller playing a demo track with original cover art](docs/assets/media.png)

## Coding agent limits

![VoidBar Usage tab: Claude Code and Codex plan limits, updating after a new Codex response (demo numbers)](docs/assets/usage-tour.gif)

The Usage tab reads numbers the tools already produce, on this Mac, without any network request or sign-in:

- **Codex** writes its current limits into its own session logs after each response. VoidBar reads the newest one from `~/.codex/sessions`; nothing to set up.
- **Claude Code** reports Pro and Max limits only to its [status line](https://code.claude.com/docs/en/statusline) command. In the Usage tab, choose **Copy setup** and paste the `statusLine` entry into `~/.claude/settings.json`. VoidBar then acts as that command: it prints a short line such as `Opus · 5h 24% · 7d 41%` for Claude Code, and keeps only the two limit windows in `~/Library/Application Support/VoidBar/claude-code-usage.json`. Claude Code runs status line commands in its terminal interface, so sessions started with the `claude` CLI keep the card current. If you already use a custom status line, keep yours; the Claude Code card simply stays empty.

The status line only reports what the last response *in that terminal session* saw, so an idle session or work in the Claude app leaves those numbers behind. Press **↻** on the Claude Code card to read the exact numbers from your Claude account instead — the ones `/usage` shows. The first time, macOS asks whether VoidBar may read Claude Code's sign-in from the Keychain. VoidBar only asks when you press the button, never in the background, and never refreshes or changes that sign-in; if it has expired, run `claude` once. This uses the endpoint Claude Code itself calls, which is not a documented public API.

Codex numbers update when Codex gets a response. A window whose reset time has passed shows as reset until the next response brings fresh numbers.

## Designed like a Mac app

- Native SwiftUI and AppKit UI with no third-party runtime dependencies.
- Hover-first interaction with keyboard focus only when a text tool needs it.
- A panel that feels alive: it pours out of the notch, light runs along its edge, widgets cascade in, and a soft aurora picks up the colours of what is on screen.
- English and Ukrainian localization.
- Optional launch at login and a menu bar control.
- Customizable tab order and visibility.
- Works on Macs without a physical notch through its menu bar entry point.

### Make it yours

**Preferences → Appearance** sets the look: an accent colour from six presets, including a blood red, or any colour you pick; the aurora in the colours of what is on screen, in your accent only, or off, and how strong it is; and whether opening animations play. Reduce Motion always turns animations off, and the panel itself stays black so it keeps blending into the notch. With a red accent, normal load is shown in white, so red still only means a limit is nearly spent.

## Build from source

You need macOS 15 Sequoia or later and Xcode 16+ with a Swift 6 toolchain.

```bash
git clone https://github.com/xand0dev/VoidBar.git
cd VoidBar
./Scripts/bundle.sh
open build/VoidBar.app
```

The build script compiles the Swift package and media helper, assembles `VoidBar.app`, copies the icon and localizations, and applies an ad-hoc signature. A local build runs without the Gatekeeper steps above because it was never downloaded.

To produce the same verified, drag-to-Applications disk image and checksum that a release ships:

```bash
./Scripts/dmg.sh
```

### Run the checks

```bash
swift test
./Scripts/dmg.sh
```

The same tests, bundle build, and disk-image verification run on macOS 15 for every pull request. README media is re-recorded from the real panel with invented demo content by `./Scripts/capture-demo.sh`.

<details>
<summary><strong>Repository map</strong></summary>

```text
Sources/VoidBar/App       app lifecycle, status item, preferences
Sources/VoidBar/Notch     panel geometry, hover tracking, window lifecycle
Sources/VoidBar/Model     shared state and tab configuration
Sources/VoidBar/Services  media, storage, calendar, network-backed features
Sources/VoidBar/UI        SwiftUI panes and visual components
Sources/VoidBarMediaHelper
                         system Now Playing bridge
Resources                icon and en/uk localizations
Tests/VoidBarTests        unit and regression tests
```

</details>

## Privacy, without hand-waving

VoidBar has no analytics, advertising, accounts, or project-operated server. That does **not** mean every feature is offline:

- opening Weather sends a normal HTTPS request to `ipapi.co`, then coordinates to Open-Meteo;
- TickTick fetches the private iCal URL you configure;
- Spotify artwork can load from allow-listed Spotify CDN hosts;
- macOS may download Translation language assets from Apple.

Clipboard history stays in process memory. Notes, snippets, settings, and the optional TickTick URL are stored locally. Copied images can be saved to `~/Pictures/VoidBar`, and that behavior can be disabled.

The complete network, storage, and permission map is in [PRIVACY.md](PRIVACY.md). Security reports belong in [GitHub Security Advisories](https://github.com/xand0dev/VoidBar/security/advisories/new), not public issues.

## Make it better

Good bug reports, focused pull requests, tests, localization improvements, and sharp product ideas are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before starting a large change and use [GitHub Discussions](https://github.com/xand0dev/VoidBar/discussions) for early ideas.

- [Changelog](CHANGELOG.md)
- [Support](SUPPORT.md)
- [Security policy](SECURITY.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)

If VoidBar earns a place in your menu bar, consider starring the repository.

## License

VoidBar is open source under the [MIT License](LICENSE).
