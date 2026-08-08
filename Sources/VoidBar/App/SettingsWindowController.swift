import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VoidBar Preferences"
        window.center()
        window.setFrameAutosaveName("VoidBarPreferencesWindow")
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(tabManager: TabManager) {
        if window?.contentViewController == nil {
            let settingsView = SettingsView(tabManager: tabManager)
            let hostingController = NSHostingController(rootView: settingsView)
            window?.contentViewController = hostingController
        }
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
