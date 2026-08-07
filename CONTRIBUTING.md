# Contributing to VoidBar

Thank you for your interest in contributing to VoidBar! We welcome contributions of all kinds: bug reports, feature requests, and pull requests.

## Development Setup

To build and run VoidBar locally, you will need:
- A Mac running **macOS 15** or later.
- The **Swift 6** toolchain (via Xcode 16+).

1. Clone the repository:
   ```bash
   git clone https://github.com/xand0dev/voidbar.git
   cd voidbar
   ```

2. Build the project:
   VoidBar uses a custom build script that handles compilation, assembling the bundle, compiling the media helper, localization, and ad-hoc signing.
   ```bash
   ./Scripts/bundle.sh
   ```

3. Run the app:
   ```bash
   open build/VoidBar.app
   ```

## Pull Request Process

1. **Fork the repository** and create your branch from `main`.
2. **Ensure it builds**: Run `./Scripts/bundle.sh` locally and verify the app opens and works without crashing.
3. **Check Code Style**: Try to follow the existing code style in the project. VoidBar uses Swift formatting conventions.
4. **Test your changes**: Please test your feature or bug fix manually since the project heavily relies on AppKit and SwiftUI UI components.
5. **Open a PR**: Fill out the provided Pull Request template.

## Issues

- Before opening an issue, please check if a similar issue already exists.
- Use the provided Issue Templates for bug reports and feature requests.
- Provide as much context as possible, including OS version and screenshots.

We are excited to see what you build!
