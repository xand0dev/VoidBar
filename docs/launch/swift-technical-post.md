# Building a hover panel for the MacBook notch with SwiftUI and AppKit

*Draft technical post. Useful content first; the project link is at the end.*

The strip around the MacBook notch looks like a natural place for a small panel, but making one feel native takes more AppKit than SwiftUI. These are the parts that took the most iteration in VoidBar.

## 1. A panel that never steals focus

The panel is a borderless `NSPanel` with `.nonactivatingPanel`, at a level above the menu bar, joined to all Spaces. The app runs with the `.accessory` activation policy, so it has no Dock icon and never becomes the frontmost app.

The subtle part is keyboard focus. Most tabs never need the keyboard, and taking it would dim the caret in whatever the user was typing into. So the panel overrides `canBecomeKey` to follow an explicit flag, and only the tabs with text fields (translation, notes, snippets) raise it. Losing key status (`NSWindow.didResignKeyNotification`) drops the claim without closing the tab, so typed text survives a click elsewhere.

## 2. Pointer sampling instead of tracking areas

Tracking areas assume the window receives mouse events, but a panel that must let clicks through mostly doesn't. VoidBar samples `NSEvent.mouseLocation` instead: at full rate inside a band along the top of the screen, and rarely elsewhere. The collapsed hover target is slightly larger than the notch and includes the top edge, because `CGRect.contains` excludes `maxY`, which is exactly where a pointer thrown at the top of the screen lands.

A dwell threshold separates "the pointer crossed the menu bar" from "the pointer came to the notch", and the same idea switches tabs on hover in the rail: a switch happens only after the pointer rests for about 150 ms.

## 3. Passthrough clicks

Returning `nil` from `hitTest` discards a click; it doesn't forward it to the window underneath. The fix is to toggle `ignoresMouseEvents` from the pointer sampler: true whenever the pointer is outside the visible panel shape, false inside it. The interactive rectangle grows before the open animation starts and shrinks only after the close animation finishes, so there is never a moment when a click lands on the wrong app.

## 4. SwiftUI inside AppKit, without redraw storms

The content is one `NSHostingView` with `sizingOptions = []`, so SwiftUI never asks AppKit to resize the window. Nested `ObservableObject` stores don't propagate changes, so the view model forwards them selectively: always for the stores that drive the collapsed "island" (media, timer, weather), only while open for the rest, and never for stores that change per keystroke. Forwarding those would rebuild the text field on every letter and drop its focus.

Closing is split across two run-loop passes: first the keyboard is released, then the panel collapses. Doing both in one transaction occasionally left SwiftUI with the new state but the old picture.

## 5. Media progress that doesn't jump

Since macOS 15.4, MediaRemote only answers trusted clients. VoidBar hosts a small helper in `/usr/bin/perl`, a platform binary without library validation, and reads JSON lines from it; if that route fails three times, it falls back to scripting Apple Music and Spotify.

Now Playing reports elapsed time as a value plus a timestamp and a rate, and every report arrives slightly late. VoidBar projects the elapsed time forward from the timestamp, keeps its own clock between reports, and treats the two directions differently: forward corrections above ~0.75 s are accepted, backward ones only if they exceed ~2 s (a real seek or a track change). A seek the user makes is held until the player confirms it or 1.5 s pass, so the bar never snaps back to the old position. The ticker only runs while the panel is open; opening it recomputes the position from the anchor instantly.

## Try it or read the code

VoidBar is MIT-licensed: <REPO_URL>. The release (Apple Silicon, macOS 15+, not notarized) is at <RELEASE_URL>. The pieces above live in `Sources/VoidBar/Notch` and `Sources/VoidBar/Services/MediaController.swift`.
