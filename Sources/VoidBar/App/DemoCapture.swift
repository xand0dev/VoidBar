#if DEBUG
import AppKit
import SwiftUI

/// Records the README walkthrough and stills from the real panel views.
///
/// Debug builds only, and only when `VOIDBAR_CAPTURE_DIR` names an output
/// folder. The panel is the same `NotchContentView` a normal launch shows; what
/// differs is the content: an invented track with artwork drawn right here, a
/// fixed translation, and made-up clipboard entries. No system feed, pasteboard
/// monitor, or network request is involved and nothing the capture changes is
/// saved, so a capture looks the same on every Mac and never shows the
/// recording machine's own data.
///
/// `Scripts/capture-demo.sh` builds, runs, and encodes the result.
@MainActor
enum DemoCapture {
    static let environmentKey = "VOIDBAR_CAPTURE_DIR"

    static func requestedDirectory(
        in environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        guard let path = environment[environmentKey], !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static func run(_ app: NSApplication, into directory: URL) {
        let delegate = DemoCaptureDelegate(directory: directory)
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        objc_setAssociatedObject(app, "voidbar.capture", delegate, .OBJC_ASSOCIATION_RETAIN)
        app.run()
    }
}

// MARK: - Script

/// The walkthrough, as timed steps. Kept apart from the recorder so the story
/// can be read — and tested — without running a window.
struct DemoScript {
    enum Action: Equatable {
        case open
        case close
        case select(NotchViewModel.Tab)
        case startTimer
        case type(String)
    }

    struct Step: Equatable {
        let at: TimeInterval
        let action: Action
    }

    static let track = (title: "Graphite Hours", artist: "Quiet Orbit", album: "Night Shift Sessions")
    static let source = "Demo"
    static let trackDuration: TimeInterval = 214
    static let trackStart: TimeInterval = 83

    static let translationInput = "Let's ship the release on Friday."
    static let translationOutput = "Випустімо реліз у пʼятницю."

    static let clipboard: [ClipItem.Payload] = [
        .text("Випустімо реліз у пʼятницю."),
        .text("https://github.com/xand0dev/VoidBar"),
        .file(URL(fileURLWithPath: "/Users/demo/Desktop/Launch checklist.pdf")),
        .text("Standup moved to 10:30"),
        .text("Design review moved to Thursday, 15:00"),
    ]

    /// Music → Focus Timer → Translation → Clipboard, then fold away.
    static let walkthrough: [Step] = [
        Step(at: 0.9, action: .open),
        Step(at: 3.2, action: .select(.timer)),
        Step(at: 4.0, action: .startTimer),
        Step(at: 5.9, action: .select(.translate)),
        Step(at: 6.3, action: .type(translationInput)),
        Step(at: 8.9, action: .select(.clipboard)),
        Step(at: 10.8, action: .close),
    ]

    static let length: TimeInterval = 11.6

    /// The tabs the walkthrough visits, in order, for the caption strip.
    static var chapters: [NotchViewModel.Tab] {
        [.media] + walkthrough.compactMap {
            if case .select(let tab) = $0.action { return tab }
            return nil
        }
    }
}

// MARK: - Recorder

@MainActor
private final class DemoCaptureDelegate: NSObject, NSApplicationDelegate {
    private let directory: URL
    private var window: NSWindow?
    private var vm: NotchViewModel?
    private var stage: StageState?
    private var ticker: Timer?
    private var startedAt = Date()
    private var pending: [DemoScript.Step] = DemoScript.walkthrough
    private var frames: [(file: String, at: TimeInterval)] = []
    private var typing: (text: String, from: TimeInterval)?

    private let framesPerSecond = 20.0
    /// PNG encoding is the slow part; off the main thread it does not delay
    /// the next frame or the animations being sampled.
    private let writer = DispatchQueue(label: "dev.xand0.VoidBar.capture.writer")
    private let stageSize = CGSize(width: 760, height: 318)

    init(directory: URL) {
        self.directory = directory
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try FileManager.default.createDirectory(
                at: directory.appendingPathComponent("frames"), withIntermediateDirectories: true
            )
        } catch {
            fatalError("VoidBar capture: cannot create \(directory.path): \(error)")
        }

        let vm = makeViewModel()
        self.vm = vm
        let stage = StageState()
        self.stage = stage

        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: stageSize),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.hasShadow = false
        window.backgroundColor = .black
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = NSHostingView(rootView: DemoStage(vm: vm, stage: stage))
        // On screen so SwiftUI animates in real time, but below everything and
        // invisible; frames are read from the view, not from the display.
        window.level = .init(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) - 1)
        window.alphaValue = 0.01
        if let screen = NSScreen.main {
            window.setFrameOrigin(CGPoint(x: screen.frame.minX, y: screen.frame.minY))
        }
        window.orderFrontRegardless()
        self.window = window

        // Give the first layout a moment before anything is recorded.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.captureStills()
            self?.resetForWalkthrough()
            self?.startWalkthrough()
        }
    }

    private func makeViewModel() -> NotchViewModel {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            fatalError("VoidBar capture: no screen")
        }
        let geometry = NotchGeometry(
            screen: screen,
            notchSize: CGSize(width: 185, height: 32),
            notchCenterX: screen.frame.midX,
            isPhysical: true
        )
        let vm = NotchViewModel(geometry: geometry)
        // A private, emptied defaults domain: the rail shows the default tabs,
        // and nothing the capture does can rewrite the user's own layout.
        let suite = "dev.xand0.VoidBar.capture"
        UserDefaults().removePersistentDomain(forName: suite)
        vm.tabManager = TabManager(defaults: UserDefaults(suiteName: suite) ?? .standard)

        vm.media.showDemo(
            title: DemoScript.track.title,
            artist: DemoScript.track.artist,
            album: DemoScript.track.album,
            source: DemoScript.source,
            artwork: DemoArtwork.make(side: 600),
            duration: DemoScript.trackDuration,
            position: DemoScript.trackStart,
            isPlaying: true
        )
        vm.clipboard.showDemo(DemoScript.clipboard)
        return vm
    }

    private func resetForWalkthrough() {
        guard let vm else { return }
        vm.isOpen = false
        vm.tab = .media
        vm.timer.state = .idle
        vm.timer.selectDuration(25 * 60)
        vm.translator.showDemo(input: "", output: "")
        stage?.chapter = 0
    }

    // MARK: Stills

    private func captureStills() {
        guard let vm, let stage else { return }
        vm.tab = .media
        vm.isOpen = true
        stage.showsCaption = false
        window?.setContentSize(CGSize(width: stageSize.width, height: 272))
        settle()
        write(snapshot(), to: "media@2x.png")

        // The social card is a different canvas: the panel with a title.
        stage.layout = .social
        window?.setContentSize(CGSize(width: 960, height: 480))
        settle()
        write(snapshot(), to: "social-preview@2x.png")

        stage.layout = .walkthrough
        stage.showsCaption = true
        window?.setContentSize(stageSize)
        settle()
    }

    /// Lets pending layout and animations finish before a still is taken.
    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.9))
    }

    // MARK: Walkthrough

    private func startWalkthrough() {
        startedAt = Date()
        let timer = Timer(timeInterval: 1 / framesPerSecond, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        guard let vm else { return }
        let now = Date().timeIntervalSince(startedAt)

        while let step = pending.first, step.at <= now {
            pending.removeFirst()
            perform(step.action, at: now)
        }

        // The track plays and the timer counts down on the recording's clock.
        vm.media.showDemo(
            title: DemoScript.track.title,
            artist: DemoScript.track.artist,
            album: DemoScript.track.album,
            source: DemoScript.source,
            artwork: vm.media.artwork,
            duration: DemoScript.trackDuration,
            position: DemoScript.trackStart + now,
            isPlaying: true
        )
        if vm.timer.state == .running, let started = timerStartedAt {
            vm.timer.timeRemaining = max(0, vm.timer.selectedDuration - floor(now - started))
        }
        if let typing {
            let perCharacter = 0.045
            let count = min(typing.text.count, Int((now - typing.from) / perCharacter))
            let typed = String(typing.text.prefix(count))
            let done = count == typing.text.count
            // The result follows the pause after the last keystroke, as the
            // real pane's debounce does.
            let settled = done && now - typing.from - Double(count) * perCharacter > 0.35
            vm.translator.showDemo(input: typed, output: settled ? DemoScript.translationOutput : "")
            if settled { self.typing = nil }
        }

        let name = String(format: "%04d.png", frames.count)
        write(snapshot(), to: "frames/\(name)")
        frames.append((name, now))

        if now >= DemoScript.length {
            finish()
        }
    }

    private var timerStartedAt: TimeInterval?

    private func perform(_ action: DemoScript.Action, at now: TimeInterval) {
        guard let vm, let stage else { return }
        switch action {
        case .open:
            withAnimation(Theme.openAnimation) { vm.isOpen = true }
        case .close:
            withAnimation(Theme.openAnimation) { vm.isOpen = false }
            stage.chapter = nil
        case .select(let tab):
            vm.tab = tab
            stage.chapter = DemoScript.chapters.firstIndex(of: tab)
        case .startTimer:
            vm.timer.state = .running
            timerStartedAt = now
        case .type(let text):
            typing = (text, now)
        }
    }

    private func finish() {
        ticker?.invalidate()
        ticker = nil
        writer.sync {}
        // ffmpeg's concat demuxer: each frame lasts until the next one began.
        var list = "ffconcat version 1.0\n"
        for (index, frame) in frames.enumerated() {
            let next = index + 1 < frames.count ? frames[index + 1].at : DemoScript.length + 0.05
            list += "file 'frames/\(frame.file)'\nduration \(String(format: "%.4f", max(0.01, next - frame.at)))\n"
        }
        if let last = frames.last { list += "file 'frames/\(last.file)'\n" }
        try? list.write(to: directory.appendingPathComponent("frames.ffconcat"), atomically: true, encoding: .utf8)
        print("VoidBar capture: \(frames.count) frames in \(directory.path)")
        UserDefaults().removePersistentDomain(forName: "dev.xand0.VoidBar.capture")
        NSApp.terminate(nil)
    }

    // MARK: Pixels

    private func snapshot() -> NSBitmapImageRep {
        guard let view = window?.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            fatalError("VoidBar capture: cannot allocate a frame")
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep
    }

    private func write(_ rep: NSBitmapImageRep, to name: String) {
        let url = directory.appendingPathComponent(name)
        writer.async {
            guard let data = rep.representation(using: .png, properties: [:]) else { return }
            try? data.write(to: url)
        }
    }
}

// MARK: - Stage

@MainActor
private final class StageState: ObservableObject {
    enum Layout { case walkthrough, social }
    @Published var layout: Layout = .walkthrough
    @Published var showsCaption = true
    /// Index into `DemoScript.chapters`, or nil once the panel folds away.
    @Published var chapter: Int? = 0
}

/// Presentation only: a graphite backdrop, a strip standing in for the top of
/// the display, and an outline so the black panel never melts into the dark.
/// The panel itself is `NotchContentView`, untouched.
private struct DemoStage: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var stage: StageState

    private static let backdrop = Color(red: 0.086, green: 0.090, blue: 0.102)
    private static let menuBar = Color(red: 0.165, green: 0.172, blue: 0.188)

    var body: some View {
        ZStack(alignment: .top) {
            RadialGradient(
                colors: [Color(red: 0.13, green: 0.135, blue: 0.15), Self.backdrop],
                center: .top,
                startRadius: 10,
                endRadius: 520
            )
            VStack(spacing: 0) {
                display
                if stage.layout == .social {
                    Spacer(minLength: 0)
                    socialTitle
                    Spacer(minLength: 0)
                } else {
                    if stage.showsCaption {
                        captions.padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private var display: some View {
        let geometry = vm.geometry
        let open = vm.isOpen
        let size = vm.bodySize
        let radius = open ? Theme.openTopRadius : Theme.collapsedTopRadius
        return ZStack(alignment: .top) {
            Rectangle()
                .fill(Self.menuBar)
                .frame(height: geometry.notchSize.height)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                }
            // A soft shadow under the open panel, built from stacked, slightly
            // larger silhouettes: view snapshots include neither layer shadows
            // nor blur.
            ForEach(Array(1...14), id: \.self) { step in
                let grow = CGFloat(step) * 1.6
                silhouette(size: size, radius: radius, open: open)
                    .fill(Color.black.opacity(open ? 0.055 : 0))
                    .frame(width: size.width + 2 * radius + 2 * grow, height: size.height + grow)
                    .offset(y: CGFloat(step) * 0.9)
            }
            .animation(Theme.openAnimation, value: open)
            NotchContentView(vm: vm)
                .frame(width: geometry.windowSize.width, height: geometry.windowSize.height)
            silhouette(size: size, radius: radius, open: open)
                .stroke(Color.white.opacity(open ? 0.15 : 0), lineWidth: 1)
                .frame(width: size.width + 2 * radius, height: size.height)
                // The top edge meets the display; only the sides and bottom
                // are outlined.
                .mask(Rectangle().padding(.top, 2))
                .animation(Theme.openAnimation, value: open)
        }
        .frame(maxWidth: .infinity)
        .frame(height: geometry.windowSize.height, alignment: .top)
    }

    private func silhouette(size: CGSize, radius: CGFloat, open: Bool) -> NotchShape {
        NotchShape(
            topRadius: radius,
            bottomRadius: open ? Theme.openBottomRadius : Theme.collapsedBottomRadius
        )
    }

    private var captions: some View {
        HStack(spacing: 10) {
            ForEach(Array(DemoScript.chapters.enumerated()), id: \.offset) { index, tab in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.22))
                }
                HStack(spacing: 5) {
                    Image(systemName: tab.symbol).font(.system(size: 10, weight: .semibold))
                    Text(tab.title).font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(stage.chapter == index ? Color.white : Color.white.opacity(0.38))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(Color.white.opacity(stage.chapter == index ? 0.12 : 0))
                )
            }
        }
        .animation(.easeOut(duration: 0.2), value: stage.chapter)
        .frame(maxWidth: .infinity)
    }

    private var socialTitle: some View {
        VStack(spacing: 10) {
            Text(verbatim: "VoidBar")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(.white)
            Text(verbatim: "A native productivity hub for the MacBook notch")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.62))
            Text(verbatim: "Open source  ·  SwiftUI + AppKit  ·  No account")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.38))
                .padding(.top, 4)
        }
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Artwork

/// Original cover art for the invented track, drawn at capture time so no
/// image of anybody else's ever enters the repository.
enum DemoArtwork {
    static func make(side: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let space = CGColorSpaceCreateDeviceRGB()

            let base = CGGradient(
                colorsSpace: space,
                colors: [
                    CGColor(red: 0.10, green: 0.11, blue: 0.20, alpha: 1),
                    CGColor(red: 0.20, green: 0.16, blue: 0.36, alpha: 1),
                    CGColor(red: 0.93, green: 0.49, blue: 0.34, alpha: 1),
                ] as CFArray,
                locations: [0, 0.55, 1]
            )!
            context.drawLinearGradient(
                base,
                start: CGPoint(x: rect.minX, y: rect.maxY),
                end: CGPoint(x: rect.maxX, y: rect.minY),
                options: []
            )

            // Orbits around a small sun, low on the canvas.
            let center = CGPoint(x: rect.width * 0.62, y: rect.height * 0.36)
            context.setLineWidth(rect.width * 0.006)
            for ring in 1...7 {
                let radius = rect.width * 0.07 * CGFloat(ring)
                context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.30 - CGFloat(ring) * 0.03))
                context.strokeEllipse(in: CGRect(
                    x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2
                ))
            }
            let glow = CGGradient(
                colorsSpace: space,
                colors: [
                    CGColor(red: 1, green: 0.93, blue: 0.80, alpha: 1),
                    CGColor(red: 1, green: 0.72, blue: 0.50, alpha: 0),
                ] as CFArray,
                locations: [0, 1]
            )!
            context.drawRadialGradient(
                glow,
                startCenter: center, startRadius: 0,
                endCenter: center, endRadius: rect.width * 0.12,
                options: []
            )

            return true
        }
    }
}
#endif
