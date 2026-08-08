# Changelog

All notable changes to VoidBar are documented in this file. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Customizable tab visibility and ordering in Preferences.
- English and Ukrainian open-source documentation and community templates.

### Changed

- CI now runs unit tests as well as the full application bundle build.
- Privacy documentation now describes every intentional remote request, persisted data category, and system permission.

### Fixed

- Opening the notch no longer resets the displayed media position to the last stale MediaRemote update.

## [0.5.1] - 2026-08-05

### Fixed

- A newly created or selected note now receives keyboard focus immediately.

## [0.5.0] - 2026-08-05

### Added

- Persistent scratch notes with automatic focus and cleanup of empty notes.

### Fixed

- File-shelf removal controls now remain visible as cards move under the pointer.

## [0.4.0] - 2026-08-05

### Added

- Menu bar controls for viewing and moving saved screenshots to Trash.

### Changed

- Background work is reduced while the panel is collapsed.

### Fixed

- The panel now closes reliably after leaving text-entry tabs, switching spaces, or sleeping the display.

## [0.3.0] - 2026-08-05

### Added

- First installable disk image.
- Snippets, Calendar, and Translation tabs.
- Hover-based tab switching with a dwell threshold.
- Copied-image handoff to the shelf through the macOS pasteboard.
- English and Russian localization (Ukrainian replaced Russian in a later development version).

[Unreleased]: https://github.com/xand0dev/VoidBar/compare/v0.5.1...HEAD
[0.5.1]: https://github.com/xand0dev/VoidBar/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/xand0dev/VoidBar/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/xand0dev/VoidBar/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/xand0dev/VoidBar/releases/tag/v0.3.0
