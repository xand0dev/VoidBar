# Changelog

All notable changes to VoidBar are documented in this file. Versions before 0.6.0 were built locally and never published as tagged releases. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.7.0] - 2026-09-30

A premium redesign built around an Overview of the tabs you use, a live island, and a look you can make your own.

### Added

- Overview tab, where the panel now opens: the player in a large card while something plays and a grid of widgets built from the tabs you use — agent limits, clipboard and snippets that copy with a click, focus timer, latest note, shelf, tasks, meetings, weather, and system load. Widgets can be switched off and reordered in Preferences.
- Live island: while music plays or a timer runs, the folded notch grows a wing on each side with the cover or a timer ring and a live equalizer or countdown.
- Appearance preferences: accent colour (six presets or any colour), aurora by content, in the accent, or off, its strength, and opening animations.
- Usage tab with the five-hour and weekly plan limits of Claude Code and Codex, read locally from Codex session logs and from a Claude Code status line bridge (`VoidBar --claude-statusline`). Off by default.
- A project website on GitHub Pages with a direct download of the latest release.

### Changed

- A full visual redesign: lit cards with hairline edges, one accent colour, SF Rounded numerals, shared components across every tab, a slightly larger panel, a choreographed opening, and a soft aurora behind the content.

## [0.6.0] - 2026-09-29

The first public release: a downloadable, checksummed disk image built from source by GitHub Actions.

### Added

- Downloadable `VoidBar-<version>-arm64.dmg` with a SHA-256 file, built, verified, attested, and published by a release workflow on version tags.
- English ↔ Ukrainian translation: Ukrainian text is translated to English and everything else to Ukrainian, with both languages always named explicitly.
- Customizable tab visibility and ordering in Preferences.
- English and Ukrainian open-source documentation, community templates, and a README walkthrough recorded from the real panel with invented demo content.

### Changed

- CI runs the unit tests, the full application bundle build, and disk-image verification on every pull request.
- A failed ad-hoc signature now stops the build instead of producing an unsigned app.
- Privacy documentation describes every intentional remote request, persisted data category, and system permission.

### Fixed

- Opening the notch no longer resets the displayed media position to the last stale Now Playing update.

## 0.5.1 - 2026-08-05

### Fixed

- A newly created or selected note now receives keyboard focus immediately.

## 0.5.0 - 2026-08-05

### Added

- Persistent scratch notes with automatic focus and cleanup of empty notes.

### Fixed

- File-shelf removal controls now remain visible as cards move under the pointer.

## 0.4.0 - 2026-08-05

### Added

- Menu bar controls for viewing and moving saved screenshots to Trash.

### Changed

- Background work is reduced while the panel is collapsed.

### Fixed

- The panel now closes reliably after leaving text-entry tabs, switching spaces, or sleeping the display.

## 0.3.0 - 2026-08-05

### Added

- First installable disk image.
- Snippets, Calendar, and Translation tabs.
- Hover-based tab switching with a dwell threshold.
- Copied-image handoff to the shelf through the macOS pasteboard.
- English and Russian localization (Ukrainian replaced Russian in a later development version).

[Unreleased]: https://github.com/xand0dev/VoidBar/compare/v0.7.0...HEAD
[0.7.0]: https://github.com/xand0dev/VoidBar/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/xand0dev/VoidBar/releases/tag/v0.6.0
