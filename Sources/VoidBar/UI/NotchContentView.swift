import SwiftUI

struct NotchContentView: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject private var appearance = Appearance.shared

    private var isOpen: Bool { vm.isOpen || vm.isDropTargeted }
    private var size: CGSize { vm.bodySize }
    private var topRadius: CGFloat { isOpen ? Theme.openTopRadius : Theme.collapsedTopRadius }

    var body: some View {
        // The shape is wider than the body by `topRadius` on each side: that
        // slack is where the concave shoulders live, so it must not be clipped.
        ZStack(alignment: .top) {
            NotchShape(
                topRadius: topRadius,
                bottomRadius: isOpen ? Theme.openBottomRadius : Theme.collapsedBottomRadius
            )
            .fill(Color.black)
            .opacity(!isOpen && !vm.geometry.isPhysical ? 0 : 1)
            .frame(width: size.width + 2 * topRadius, height: size.height)
            .shadow(color: .black.opacity(isOpen ? 0.55 : 0), radius: 22, y: 10)

            // Light from below, in the colours of what is on screen.
            if isOpen, appearance.aurora != .off {
                Aurora(colors: auroraColors, intensity: auroraIntensity * appearance.auroraIntensity)
                    .frame(width: size.width + 2 * topRadius, height: size.height)
                    .clipShape(NotchShape(topRadius: topRadius, bottomRadius: Theme.openBottomRadius))
                    .transition(.opacity.animation(.easeOut(duration: 0.5)))
            }

            // A hairline around the open panel, so it keeps its edge over a
            // dark wallpaper or a black window. The top meets the display and
            // stays unlined.
            NotchShape(
                topRadius: topRadius,
                bottomRadius: isOpen ? Theme.openBottomRadius : Theme.collapsedBottomRadius
            )
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.03), Color.white.opacity(0.13)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
            .frame(width: size.width + 2 * topRadius, height: size.height)
            .mask(Rectangle().padding(.top, 3))
            .opacity(isOpen ? 1 : 0)
            .allowsHitTesting(false)

            if isOpen, Theme.palette.animations {
                EdgeSweep(shape: NotchShape(topRadius: topRadius, bottomRadius: Theme.openBottomRadius))
                    .frame(width: size.width + 2 * topRadius, height: size.height)
                    .mask(Rectangle().padding(.top, 3))
            }

            VStack(spacing: 0) {
                header
                if isOpen {
                    content
                        .transition(.opacity)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .top)
            .clipped()
            
            if !isOpen {
                DynamicIslandView(vm: vm)
                    .transition(.opacity)
            }
        }
        .frame(width: size.width + 2 * topRadius, height: size.height, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(Theme.openAnimation, value: isOpen)
        .animation(Theme.paneAnimation, value: vm.tab)
        // A new look repaints everything; views read the palette statically.
        .id(appearance.version)
    }

    // MARK: - Atmosphere

    /// The aurora's palette: the cover's colours for music, the load colours
    /// for the timer, sky and sun for the weather, the accent elsewhere.
    private var auroraColors: [Color] {
        if appearance.aurora == .accent {
            return [Theme.accent, Theme.accentDeep, Theme.accent.opacity(0.8)]
        }
        switch vm.tab {
        case .home, .media:
            if let palette = vm.media.artworkPalette { return palette }
            return [Theme.accentDeep, Theme.accent, Color(red: 0.36, green: 0.78, blue: 0.86)]
        case .timer:
            if vm.timer.state == .paused { return [Theme.warning, Color.orange, Theme.warning] }
            return [Theme.accent, Theme.accentDeep, Color(red: 0.62, green: 0.45, blue: 1)]
        case .weather:
            return [Color(red: 0.35, green: 0.62, blue: 1), Color(red: 1, green: 0.78, blue: 0.4), Theme.accent]
        case .monitor, .usage:
            return [Theme.accent, Theme.positive, Theme.accentDeep]
        case .calendar, .tasks:
            return [Theme.accentDeep, Color(red: 0.62, green: 0.45, blue: 1), Theme.accent]
        default:
            return [Theme.accentDeep, Theme.accent, Color(red: 0.36, green: 0.78, blue: 0.86)]
        }
    }

    /// Stronger where the panel is mostly imagery, softer behind text.
    private var auroraIntensity: Double {
        switch vm.tab {
        case .home, .media, .timer, .weather: return 0.5
        case .translate, .notes, .teleprompter, .snippets, .clipboard: return 0.28
        default: return 0.38
        }
    }

    // MARK: - Header
    //
    // This strip sits directly on top of the menu bar. Menu bar utilities such
    // as Ice watch for clicks there with a global event monitor — a passive
    // observer that sees the click no matter which window consumes it — so
    // clicking here toggles them as a side effect. Nothing interactive goes in
    // this row; the tab switcher lives in the rail below.

    private var header: some View {
        HStack(spacing: 0) {
            if isOpen {
                HStack(spacing: 6) {
                    Image(systemName: vm.tab.symbol)
                        .font(.system(size: 9, weight: .bold))
                    Text(vm.tab.title.uppercased())
                        .font(Theme.micro)
                        .tracking(1)
                }
                .foregroundStyle(Theme.tertiary)
                .padding(.leading, 20)
                .id(vm.tab)
                .transition(.opacity)
            }
            Spacer(minLength: 0)
            Color.clear.frame(width: vm.geometry.notchSize.width, height: 1)
            Spacer(minLength: 0)
            if isOpen {
                trailing
                    .padding(.trailing, 20)
                    .transition(.opacity)
            }
        }
        .frame(height: vm.geometry.notchSize.height)
    }

    @ViewBuilder
    private var trailing: some View {
        switch vm.tab {
        case .home:
            Text(Self.today.string(from: Date()).sentenceCased)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.tertiary)
        case .media:
            HStack(spacing: 6) {
                if vm.media.track != nil {
                    EqualizerBars(isAnimating: vm.media.isPlaying)
                }
                Text(vm.media.sourceName ?? "")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.tertiary)
            }
        case .sound:
            EmptyView()
        case .shelf:
            counter(vm.shelf.items.count)
        case .clipboard:
            counter(vm.clipboard.items.count)
        case .snippets:
            counter(vm.snippets.items.count)
        case .calendar:
            // The pane leads with the countdown itself.
            EmptyView()
        case .timer:
            // The ring already shows the time, large.
            EmptyView()
        case .translate:
            // Nothing: the columns name both languages already, and the strip
            // is the one part of the panel worth not spending on a repeat.
            EmptyView()
        case .notes:
            NotesCounter(notes: vm.notes)
        case .teleprompter:
            EmptyView()
        case .monitor:
            EmptyView()
        case .weather:
            EmptyView()
        case .usage:
            EmptyView()
        case .tasks:
            if !vm.tickTick.tasks.isEmpty {
                counter(vm.tickTick.tasks.filter { !$0.isCompleted }.count)
            } else {
                EmptyView()
            }
        }
    }

    private static let today: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLanguage)
        formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return formatter
    }()

    @ViewBuilder
    private func counter(_ value: Int) -> some View {
        if value > 0 {
            Text("\(value)")
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.tertiary)
        }
    }

    // MARK: - Body

    private var content: some View {
        HStack(spacing: 12) {
            Rail(vm: vm, tabs: vm.tabManager.leftRail, side: -1)
            panes
            Rail(vm: vm, tabs: vm.tabManager.rightRail, side: 1)
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var panes: some View {
        // Content is replaced in place — no travel. The rail is vertical and
        // the panes are unrelated, so a direction would only be decoration.
        ZStack {
            pane
                .id(vm.tab)
                .transition(.asymmetric(
                    insertion: .opacity
                        .combined(with: .scale(scale: 0.97))
                        .animation(Theme.paneIn),
                    removal: .opacity
                        .combined(with: .scale(scale: 1.02))
                        .animation(Theme.paneOut)
                ))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    @ViewBuilder
    private var pane: some View {
        switch vm.tab {
        case .home:
            HomePane(vm: vm, tabs: vm.tabManager, usage: vm.usage, notes: vm.notes, snippets: vm.snippets)
        case .media:
            MediaPane(media: vm.media)
        case .sound:
            SoundPane(sound: vm.sound, nowPlaying: vm.media.sourceName)
        case .shelf:
            ShelfPane(shelf: vm.shelf, isTargeted: vm.isDropTargeted)
        case .clipboard:
            ClipboardPane(clipboard: vm.clipboard)
        case .calendar:
            CalendarPane(calendar: vm.calendar)
        case .timer:
            TimerPane(timer: vm.timer)
        case .snippets:
            SnippetsPane(snippets: vm.snippets, wantsKeyboard: $vm.wantsKeyboard)
        case .translate:
            TranslatePane(translator: vm.translator, wantsKeyboard: $vm.wantsKeyboard)
        case .notes:
            NotesPane(notes: vm.notes, wantsKeyboard: $vm.wantsKeyboard)
        case .teleprompter:
            TeleprompterPane(store: vm.teleprompter)
        case .monitor:
            MonitorPane(monitor: vm.monitor)
        case .weather:
            WeatherPane(weatherStore: vm.weather)
        case .tasks:
            TasksPane(store: vm.tickTick)
        case .usage:
            UsagePane(usage: vm.usage)
        }
    }
}

/// Watches the note store itself rather than reading through the view model:
/// notes are born and deleted inside the pane while this counter is on
/// screen, and the view model deliberately does not forward keystroke-driven
/// stores.
private struct NotesCounter: View {
    @ObservedObject var notes: NoteStore

    var body: some View {
        if !notes.notes.isEmpty {
            Text("\(notes.notes.count)")
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.tertiary)
        }
    }
}

/// Tab switcher.
///
/// Hovering switches tabs, but only after the pointer has stopped: a pointer
/// crossing the rail on its way somewhere else is gone in a few dozen
/// milliseconds, while one that came to choose stays put. The same dwell
/// threshold is what separates "the mouse was flung across the top of the
/// screen" from "the mouse came to the notch" in `PointerWatcher`.
private struct Rail: View {
    @ObservedObject var vm: NotchViewModel
    /// Which icons this rail carries — there are two rails now, one per side.
    let tabs: [NotchViewModel.Tab]
    /// -1 for the left rail, 1 for the right: which way the icons arrive from.
    let side: CGFloat

    @State private var hovered: NotchViewModel.Tab?
    /// The active highlight is one view that moves between icons.
    @Namespace private var indicator

    /// Long enough to swallow a pass-through, short enough that a deliberate
    /// hover still feels like it answered instantly.
    private let dwell = Duration.milliseconds(150)

    var body: some View {
        VStack(spacing: 1) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                Button {
                    vm.select(tab)
                    HapticManager.play(.alignment)
                } label: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 12, weight: vm.tab == tab ? .semibold : .medium))
                        .frame(width: 30, height: 22)
                        .background {
                            if vm.tab == tab {
                                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.22), Color.white.opacity(0.12)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.75)
                                    )
                                    .shadow(color: Theme.accent.opacity(0.35), radius: 6)
                                    .matchedGeometryEffect(id: "active", in: indicator)
                            } else if hovered == tab {
                                RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                                    .fill(Theme.surface)
                            }
                        }
                        .foregroundStyle(vm.tab == tab ? Color.white : Color.white.opacity(hovered == tab ? 0.8 : 0.4))
                        .contentShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
                        // A render-time transform. Growing the frame instead
                        // would re-lay out the rail on every hover, and layout
                        // that runs on pointer movement is exactly the kind
                        // that shows up as a stutter.
                        .scaleEffect(hovered == tab && vm.tab != tab ? 1.06 : 1)
                }
                .buttonStyle(.plain)
                .help(tab.title)
                .reveal(delay: 0.06 + Double(index) * 0.035, dx: side * 12, dy: 0)
                .onHover { inside in
                    if inside {
                        hovered = tab
                    } else if hovered == tab {
                        hovered = nil
                    }
                }
            }
        }
        .frame(width: 30)
        .frame(maxHeight: .infinity, alignment: .center)
        .animation(Theme.contentAnimation, value: hovered)
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: vm.tab)
        // Moving to another icon cancels the pending switch along with the
        // task, so only the icon actually rested on ever wins.
        .task(id: hovered) {
            guard let hovered, hovered != vm.tab else { return }
            try? await Task.sleep(for: dwell)
            guard !Task.isCancelled else { return }
            vm.select(hovered)
            HapticManager.play(.alignment)
        }
    }

}
