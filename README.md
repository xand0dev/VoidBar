# VoidBar

<p align="center">
  <strong>A native productivity hub for the MacBook notch.</strong><br>
  Media controls, file shelf, clipboard history, notes, calendar, translation, Pomodoro, weather, and more — one hover away.
</p>

<p align="center">
  <a href="https://github.com/xand0dev/VoidBar/actions/workflows/build.yml"><img alt="Build" src="https://github.com/xand0dev/VoidBar/actions/workflows/build.yml/badge.svg"></a>
  <a href="https://github.com/xand0dev/VoidBar/blob/main/LICENSE"><img alt="MIT License" src="https://img.shields.io/github/license/xand0dev/VoidBar"></a>
  <img alt="macOS 15+" src="https://img.shields.io/badge/macOS-15%2B-black?logo=apple">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white">
</p>

<p align="center"><a href="README.uk.md">Українська</a></p>

![VoidBar media controls inside the MacBook notch](docs/panel.png)

VoidBar stays out of sight until you hover over the notch, then opens a compact panel of native macOS tools. Move away and it collapses again. It is built in Swift with SwiftUI and AppKit, has no third-party runtime dependencies, and includes English and Ukrainian localization.

> [!IMPORTANT]
> VoidBar is in active development. Public, notarized binary releases are not available yet; build it from source using the instructions below.

## Features

| Tool | What it does |
| --- | --- |
| Media | Controls Apple Music, Spotify, and compatible system media sessions, with track progress and artwork. |
| File shelf | Holds file references while you switch between apps and supports drag-in/drag-out workflows. |
| Clipboard | Keeps the latest 40 text, link, file, and image entries in memory while VoidBar runs. |
| Screenshots | Saves copied images to `~/Pictures/VoidBar` and places them on the shelf; this can be disabled. |
| Snippets | Stores reusable text, links, email addresses, and phone numbers in an editable JSON file. |
| Calendar | Shows upcoming meetings and opens Zoom, Google Meet, Teams, and other safe meeting links. |
| Notes | Provides a fast, persistent scratchpad for temporary thoughts. |
| Teleprompter | Keeps scrolling reference text close at hand. |
| Translation | Uses Apple's native Translation framework, with no custom translation service. |
| Pomodoro | Offers 5, 10, 25, and 50 minute presets and tracks completed sessions for the day. |
| System monitor | Displays CPU, memory, upload, and download activity. |
| Weather | Shows current conditions and the next 24 hours using IP-based location and Open-Meteo. |
| TickTick | Reads tasks from a user-provided TickTick iCal subscription URL. |

Tabs can be reordered, hidden, and restored from Preferences. VoidBar can also launch at login and works from a menu bar control on Macs without a display notch.

## Requirements

- macOS 15 Sequoia or later
- Xcode 16+ or another Swift 6 toolchain
- A MacBook notch is optional

## Build from source

```bash
git clone https://github.com/xand0dev/VoidBar.git
cd VoidBar
./Scripts/bundle.sh
open build/VoidBar.app
```

The bundle script builds the Swift package, compiles the media helper, copies localizations and the app icon, assembles `VoidBar.app`, and applies an ad-hoc signature. To produce a drag-to-Applications disk image:

```bash
./Scripts/dmg.sh
```

Because local builds are not notarized, macOS may block the first launch. Open **System Settings → Privacy & Security** and choose **Open Anyway**. Only use `xattr -dr com.apple.quarantine /Applications/VoidBar.app` for an app you built yourself or obtained from a source you trust.

## Test

```bash
swift test
./Scripts/bundle.sh release
```

Pull requests run both commands on macOS 15 in GitHub Actions.

## Privacy

VoidBar has no analytics, advertising, accounts, or project-operated backend. Most data stays on your Mac, but features that need remote data do use the network:

- After the Weather tab is opened, it contacts `ipapi.co` for approximate IP-based location and `api.open-meteo.com` for forecasts.
- TickTick fetches the private iCal URL you configure.
- Spotify artwork may be loaded from allow-listed Spotify CDN hosts.
- Apple's Translation framework may download language assets managed by macOS.

Clipboard history stays in memory. Notes, snippets, preferences, and the optional TickTick URL are stored locally; copied images can be saved under `~/Pictures/VoidBar`. See [PRIVACY.md](PRIVACY.md) for the complete data and permission map, and [SECURITY.md](SECURITY.md) for vulnerability reporting.

## Contributing

Bug reports, feature ideas, documentation improvements, and code contributions are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), use the issue templates, and follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

VoidBar is available under the [MIT License](LICENSE).
