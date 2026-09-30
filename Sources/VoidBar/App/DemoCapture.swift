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
        /// A new Codex response lands and the usage pane re-reads its limits.
        case codexResponse
    }

    /// One recording: a named loop of timed steps.
    struct Scene {
        let name: String
        let steps: [Step]
        let length: TimeInterval
        /// Shows the Usage tab in the rail, as after turning it on in Preferences.
        let showsUsageTab: Bool

        /// The tabs the scene visits, in order, for the caption strip. The
        /// panel opens on the overview.
        var chapters: [NotchViewModel.Tab] {
            [.home] + steps.compactMap {
                if case .select(let tab) = $0.action { return tab }
                return nil
            }
        }
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

    /// Overview → Focus Timer → Translation → Clipboard, then fold away.
    static let walkthrough: [Step] = [
        Step(at: 1.2, action: .open),
        Step(at: 4.1, action: .select(.timer)),
        Step(at: 4.8, action: .startTimer),
        Step(at: 6.5, action: .select(.translate)),
        Step(at: 6.9, action: .type(translationInput)),
        Step(at: 9.4, action: .select(.clipboard)),
        Step(at: 11.2, action: .close),
    ]

    static let length: TimeInterval = 11.95

    /// Music → Usage: open the panel, look at both agents' limits, watch a
    /// fresh Codex response move the numbers, fold away.
    static let usageTour: [Step] = [
        Step(at: 0.8, action: .open),
        Step(at: 2.0, action: .select(.usage)),
        Step(at: 4.6, action: .codexResponse),
        Step(at: 6.9, action: .close),
    ]

    static let scenes: [Scene] = [
        Scene(name: "walkthrough", steps: walkthrough, length: length, showsUsageTab: false),
        Scene(name: "usage-tour", steps: usageTour, length: 7.7, showsUsageTab: true),
    ]

    /// Invented limits for the usage still, relative to the capture time so
    /// the reset countdowns read naturally.
    static func claudeUsage(now: Date = Date()) -> AgentUsage {
        AgentUsage(
            session: UsageWindow(usedPercent: 38, resetsAt: now.addingTimeInterval(2 * 3600 + 14 * 60), minutes: 300),
            weekly: UsageWindow(usedPercent: 61, resetsAt: now.addingTimeInterval(3 * 86400 + 5 * 3600), minutes: 10080),
            plan: nil,
            recordedAt: now.addingTimeInterval(-3 * 60)
        )
    }

    static func codexUsage(now: Date = Date(), afterResponse: Bool = false) -> AgentUsage {
        AgentUsage(
            session: UsageWindow(usedPercent: afterResponse ? 86 : 82, resetsAt: now.addingTimeInterval(47 * 60), minutes: 300),
            weekly: UsageWindow(usedPercent: afterResponse ? 25 : 24, resetsAt: now.addingTimeInterval(5 * 86400 + 2 * 3600), minutes: 10080),
            plan: "plus",
            recordedAt: afterResponse ? now : now.addingTimeInterval(-9 * 60)
        )
    }

    /// The tabs the walkthrough visits, in order, for the caption strip.
    static var chapters: [NotchViewModel.Tab] { scenes[0].chapters }
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
    private var sceneIndex = 0
    private var scene: DemoScript.Scene { DemoScript.scenes[sceneIndex] }
    private var pending: [DemoScript.Step] = []
    private var frames: [(file: String, at: TimeInterval)] = []
    private var typing: (text: String, from: TimeInterval)?

    private let framesPerSecond = 30.0
    /// PNG encoding is the slow part; off the main thread it does not delay
    /// the next frame or the animations being sampled.
    private let writer = DispatchQueue(label: "dev.xand0.VoidBar.capture.writer")
    private let stageSize = CGSize(width: 860, height: 352)

    init(directory: URL) {
        self.directory = directory
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            for scene in DemoScript.scenes {
                try FileManager.default.createDirectory(
                    at: directory.appendingPathComponent("frames-\(scene.name)"), withIntermediateDirectories: true
                )
            }
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
            self?.startScene(0)
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

    private func reset(for scene: DemoScript.Scene) {
        guard let vm else { return }
        vm.isOpen = false
        vm.tab = .home
        vm.timer.state = .idle
        vm.timer.selectDuration(25 * 60)
        timerStartedAt = nil
        vm.translator.showDemo(input: "", output: "")
        vm.usage.showDemo(claude: DemoScript.claudeUsage(), codex: DemoScript.codexUsage())
        setUsageTabEnabled(scene.showsUsageTab)
        stage?.chapters = scene.chapters
        stage?.chapter = 0
        settle()
    }

    // MARK: Stills

    private func captureStills() {
        guard let vm, let stage else { return }
        vm.tab = .media
        vm.isOpen = true
        stage.showsCaption = false
        window?.setContentSize(CGSize(width: stageSize.width, height: 302))
        settle()
        write(snapshot(), to: "media@2x.png")

        // The usage tab is off by default; switch it on in the capture's own
        // defaults suite so the rail shows it selected, then put it back.
        setUsageTabEnabled(true)
        vm.usage.showDemo(claude: DemoScript.claudeUsage(), codex: DemoScript.codexUsage())
        vm.tab = .usage
        settle()
        write(snapshot(), to: "usage@2x.png")
        vm.tab = .media
        setUsageTabEnabled(false)

        captureGallery()

        // The social card is a different canvas: the overview with a title.
        vm.tab = .home
        stage.layout = .social
        window?.setContentSize(CGSize(width: 960, height: 480))
        settle()
        write(snapshot(), to: "social-preview@2x.png")

        stage.layout = .walkthrough
        stage.showsCaption = true
        window?.setContentSize(stageSize)
        settle()
    }

    /// One still per tab, every tab switched on, plus the folded island —
    /// the before/after material for design reviews.
    private func captureGallery() {
        guard let vm else { return }
        try? FileManager.default.createDirectory(
            at: directory.appendingPathComponent("gallery"), withIntermediateDirectories: true
        )
        let manager = vm.tabManager
        let saved = manager.configs
        manager.configs = saved.map { TabManager.TabConfig(id: $0.id, isEnabled: true) }
        DemoGallery.fill(vm)

        vm.isOpen = false
        vm.timer.state = .running
        settle()
        write(snapshot(), to: "gallery/00-collapsed.png")

        vm.isOpen = true
        for (index, tab) in NotchViewModel.Tab.allCases.enumerated() {
            vm.tab = tab
            settle()
            write(snapshot(), to: String(format: "gallery/%02d-%@.png", index + 1, tab.rawValue))
        }
        vm.tab = .media
        vm.timer.state = .idle

        // The preferences window, rendered on its own.
        let settings = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 420, height: 560),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        settings.isReleasedWhenClosed = false
        settings.appearance = NSAppearance(named: .darkAqua)
        settings.contentView = NSHostingView(rootView: SettingsView(tabManager: manager))
        settings.alphaValue = 0.01
        settings.orderFrontRegardless()
        settle()
        if let view = settings.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: rep)
            write(rep, to: "gallery/99-settings.png")
        }
        settings.orderOut(nil)

        manager.configs = saved
        settle()
    }

    private func setUsageTabEnabled(_ enabled: Bool) {
        guard let manager = vm?.tabManager,
              let index = manager.configs.firstIndex(where: { $0.id == .usage }) else { return }
        manager.configs[index].isEnabled = enabled
    }

    /// Lets pending layout and animations finish before a still is taken.
    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.9))
    }

    // MARK: Walkthrough

    private func startScene(_ index: Int) {
        sceneIndex = index
        reset(for: scene)
        pending = scene.steps
        frames = []
        typing = nil
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
        write(snapshot(), to: "frames-\(scene.name)/\(name)")
        frames.append((name, now))

        if now >= scene.length {
            finishScene()
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
            stage.chapter = scene.chapters.firstIndex(of: tab)
        case .startTimer:
            vm.timer.state = .running
            timerStartedAt = now
        case .type(let text):
            typing = (text, now)
        case .codexResponse:
            vm.usage.showDemo(claude: vm.usage.claude, codex: DemoScript.codexUsage(afterResponse: true))
        }
    }

    private func finishScene() {
        ticker?.invalidate()
        ticker = nil
        writer.sync {}
        // ffmpeg's concat demuxer: each frame lasts until the next one began.
        let folder = "frames-\(scene.name)"
        var list = "ffconcat version 1.0\n"
        for (index, frame) in frames.enumerated() {
            let next = index + 1 < frames.count ? frames[index + 1].at : scene.length + 0.05
            list += "file '\(folder)/\(frame.file)'\nduration \(String(format: "%.4f", max(0.01, next - frame.at)))\n"
        }
        if let last = frames.last { list += "file '\(folder)/\(last.file)'\n" }
        try? list.write(
            to: directory.appendingPathComponent("\(scene.name).ffconcat"), atomically: true, encoding: .utf8
        )
        print("VoidBar capture: \(scene.name), \(frames.count) frames over \(scene.length) s")

        if sceneIndex + 1 < DemoScript.scenes.count {
            startScene(sceneIndex + 1)
        } else {
            UserDefaults().removePersistentDomain(forName: "dev.xand0.VoidBar.capture")
            NSApp.terminate(nil)
        }
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
    @Published var chapters: [NotchViewModel.Tab] = DemoScript.chapters
    /// Index into `chapters`, or nil once the panel folds away.
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
            ForEach(Array(stage.chapters.enumerated()), id: \.offset) { index, tab in
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

// MARK: - Gallery content

/// Invented content for every tab. Stores switched into demo mode stop
/// reading and writing their real files, calendars, and network sources.
@MainActor
enum DemoGallery {
    static func fill(_ vm: NotchViewModel) {
        let now = Date()
        vm.shelf.showDemo([
            ("Launch checklist.pdf", NSWorkspace.shared.icon(for: .pdf)),
            ("Hero shot.png", DemoArtwork.make(side: 256)),
            ("Release notes.md", NSWorkspace.shared.icon(for: .plainText)),
            ("VoidBar-0.6.0-arm64.dmg", NSWorkspace.shared.icon(for: .diskImage)),
            ("Roadmap.key", NSWorkspace.shared.icon(for: .presentation)),
        ])
        vm.snippets.showDemo([
            Snippet(label: "Email", text: "hello@example.com"),
            Snippet(label: "Repository", text: "https://github.com/xand0dev/VoidBar"),
            Snippet(label: "Office", text: "+1 555 010 0199"),
            Snippet(label: "Sign-off", text: "Thanks — talk soon."),
        ])
        vm.notes.showDemo([
            "Release checklist\n– Tag v0.6.0\n– Upload the social preview\n– Draft the Show HN post",
            "Menu bar quick toggles?",
            "Call the design team at 16:00",
        ])
        let calendar = Foundation.Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        vm.calendar.showDemo([
            .init(id: "1", title: "Design review", start: now.addingTimeInterval(25 * 60),
                  end: now.addingTimeInterval(55 * 60), calendarColor: .systemBlue,
                  link: URL(string: "https://example.com/meet"), provider: "Zoom"),
            .init(id: "2", title: "Launch sync", start: now.addingTimeInterval(3 * 3600),
                  end: now.addingTimeInterval(3.5 * 3600), calendarColor: .systemPurple, link: nil, provider: nil),
            .init(id: "3", title: "Standup", start: tomorrow.addingTimeInterval(10.5 * 3600),
                  end: tomorrow.addingTimeInterval(10.75 * 3600), calendarColor: .systemGreen, link: nil, provider: nil),
            .init(id: "4", title: "1:1 with Alex", start: tomorrow.addingTimeInterval(14 * 3600),
                  end: tomorrow.addingTimeInterval(14.5 * 3600), calendarColor: .systemOrange, link: nil, provider: nil),
        ])
        vm.timer.selectDuration(25 * 60)
        vm.timer.timeRemaining = 18 * 60 + 42
        vm.timer.completedToday = 3
        vm.translator.showDemo(input: DemoScript.translationInput, output: DemoScript.translationOutput)
        let codes = [2, 2, 1, 0, 0, 1, 3, 3, 61, 61, 3, 2]
        let hour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        vm.weather.showDemo(WeatherData(
            temperature: 18.4,
            condition: 2,
            locationName: "Lisbon",
            hourly: codes.enumerated().map { index, code in
                HourlyWeather(
                    time: hour.addingTimeInterval(Double(index) * 3600),
                    temperature: 18.4 + sin(Double(index) / 2) * 2.5,
                    condition: code
                )
            }
        ))
        vm.tickTick.showDemo([
            TickTickTask(id: "a", title: "Record the new README walkthrough", isCompleted: false,
                         dueDate: now, priority: 5),
            TickTickTask(id: "b", title: "Reply to the Product Hunt comments", isCompleted: false,
                         dueDate: now.addingTimeInterval(86400), priority: 3),
            TickTickTask(id: "c", title: "Review the translation strings", isCompleted: false,
                         dueDate: nil, priority: 1),
            TickTickTask(id: "d", title: "Tag v0.6.0", isCompleted: true, dueDate: now, priority: 0),
        ])
        vm.monitor.cpuUsage = 23.4
        vm.monitor.memoryUsage = 61.2
        vm.monitor.networkDownloadSpeed = 2.4 * 1024 * 1024
        vm.monitor.networkUploadSpeed = 320 * 1024
        vm.teleprompter.text = "Hi, I'm showing VoidBar today. It lives in the MacBook notch, opens when you hover, and gets out of the way when you leave."
        vm.usage.showDemo(claude: DemoScript.claudeUsage(), codex: DemoScript.codexUsage())
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
