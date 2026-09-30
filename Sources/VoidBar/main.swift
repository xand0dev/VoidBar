import AppKit

// Claude Code status line bridge: read stdin, keep the limits, print a line,
// exit — no app, no window. See ClaudeStatusBridge.
if CommandLine.arguments.dropFirst().first == ClaudeStatusBridge.argument {
    exit(ClaudeStatusBridge.run())
}

// Top-level code runs on the main thread; make that explicit for the compiler.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    #if DEBUG
    // README and social-preview capture; see DemoCapture.
    if let directory = DemoCapture.requestedDirectory() {
        DemoCapture.run(app, into: directory)
        return
    }
    #endif
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    // Keep the delegate alive for the lifetime of the process.
    objc_setAssociatedObject(app, "voidbar.delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
    app.run()
}
