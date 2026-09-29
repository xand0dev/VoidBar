# Contributing to VoidBar

Thanks for helping improve VoidBar. Bug reports, feature proposals, documentation, localization, tests, and code changes are all welcome.

## Before you start

- Search existing issues before opening a new one.
- Use GitHub Discussions for broad ideas or usage questions when Discussions are available.
- Open an issue before investing in a large feature or architectural change so the direction can be agreed on first.
- Never include clipboard contents, calendar data, private TickTick URLs, credentials, or other personal data in an issue or test fixture.
- Follow the [Code of Conduct](CODE_OF_CONDUCT.md).

Security vulnerabilities must be reported privately as described in [SECURITY.md](SECURITY.md).

## Development setup

You need macOS 15 or later and Xcode 16+ (or another Swift 6 toolchain).

```bash
git clone https://github.com/xand0dev/VoidBar.git
cd VoidBar
swift test
./Scripts/bundle.sh
open build/VoidBar.app
```

`Scripts/bundle.sh` compiles the Swift package and Objective-C media helper, assembles the app bundle, copies resources, and applies an ad-hoc signature. Build output is written to `.build/` and `build/`; neither directory should be committed.

## Project map

- `Sources/VoidBar/App` — app lifecycle, menu bar, and preferences window.
- `Sources/VoidBar/Notch` — panel lifecycle, geometry, shape, and pointer handling.
- `Sources/VoidBar/Model` — shared application and tab state.
- `Sources/VoidBar/Services` — feature state, persistence, system APIs, and remote requests.
- `Sources/VoidBar/UI` — SwiftUI panes and shared visual components.
- `Sources/VoidBarMediaHelper` — Objective-C helper for system media state.
- `Resources` — app icon and localized strings.
- `Tests/VoidBarTests` — unit tests.

## Making a change

1. Fork the repository and branch from `main`.
2. Keep each pull request focused on one logical change.
3. Follow the existing Swift and SwiftUI style; explain non-obvious system behavior in comments.
4. Add or update tests for logic that can be exercised outside the UI.
5. Add localization keys to both `Resources/en.lproj/Localizable.strings` and `Resources/uk.lproj/Localizable.strings`.
6. Update README, privacy documentation, or release notes when behavior changes.
7. Run the checks below before opening a pull request.

```bash
swift test
./Scripts/dmg.sh
```

`Scripts/dmg.sh` rebuilds the release bundle, packs the disk image, writes its checksum, and verifies both. If a change affects the panels shown in the README, re-record the media with `./Scripts/capture-demo.sh` and `./Scripts/capture-demo.sh uk` (requires ffmpeg).

For UI changes, also launch the built app and verify the panel on the relevant display configuration. Include a screenshot or short recording in the pull request when the visual change is meaningful.

## Pull requests

Fill in the pull request template and describe:

- the problem and why the change is needed;
- the implementation and important tradeoffs;
- automated and manual validation;
- privacy, permission, persistence, localization, and performance effects;
- related issues using `Fixes #123` when applicable.

Maintainers may ask for a smaller scope, additional tests, or documentation before merging. By contributing, you agree that your work is licensed under the repository's [MIT License](LICENSE).
