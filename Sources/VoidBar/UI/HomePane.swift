import SwiftUI

/// Everything at a glance, built from the tabs you actually use.
///
/// A widget appears only while its tab is switched on, it is switched on in
/// Preferences, and it has something to show — so the Overview of someone who
/// never opens Weather simply has no weather in it. The player takes a large
/// card while something plays; everything else fills a grid in the order set
/// in Preferences. Nothing here makes a request of its own.
struct HomePane: View {
    @ObservedObject var vm: NotchViewModel
    // Observed directly: the view model does not forward these stores, and a
    // widget must be able to appear the moment they change.
    @ObservedObject var tabs: TabManager
    @ObservedObject var usage: AgentUsageStore
    @ObservedObject var notes: NoteStore
    @ObservedObject var snippets: SnippetStore

    private var plan: OverviewLayout.Plan {
        OverviewLayout.plan(order: tabs.widgets, activeTabs: tabs.activeTabs, hasContent: hasContent)
    }

    var body: some View {
        let plan = plan
        Group {
            if plan.isEmpty {
                EmptyState(
                    symbol: "square.grid.2x2",
                    title: localized("Nothing to show yet"),
                    message: localized("Widgets appear for the tabs you use once they have something to show.")
                )
            } else {
                HStack(spacing: 8) {
                    if let hero = plan.hero {
                        widget(hero, large: true)
                            .frame(maxWidth: plan.tiles.isEmpty ? .infinity : 262, maxHeight: .infinity)
                            .reveal(delay: 0.04)
                    }
                    if !plan.tiles.isEmpty {
                        grid(plan.tiles, columns: plan.hero == nil ? 3 : 2)
                    }
                }
            }
        }
        .padding(.top, 2)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: plan)
        // Limits come from files the agents write; a slow re-read keeps the
        // widget current and its countdowns ticking while the Overview shows.
        .task {
            while !Task.isCancelled {
                await usage.refresh()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    /// Two rows. A short last row stretches its cards rather than leaving a hole.
    private func grid(_ tiles: [OverviewWidget], columns: Int) -> some View {
        let rows = stride(from: 0, to: tiles.count, by: columns).map { Array(tiles[$0..<min($0 + columns, tiles.count)]) }
        return VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 8) {
                    ForEach(Array(row.enumerated()), id: \.element) { index, tile in
                        widget(tile, large: false)
                            .reveal(delay: 0.08 + Double(rowIndex * columns + index) * 0.045)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Content rules

    private func hasContent(_ widget: OverviewWidget) -> Bool {
        switch widget {
        case .nowPlaying: return vm.media.track != nil
        case .limits: return usage.claude != nil || usage.codex != nil
        case .clipboard: return !vm.clipboard.items.isEmpty
        case .focus: return true
        case .notes: return notes.notes.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        case .snippets: return !snippets.items.isEmpty
        case .shelf: return !vm.shelf.items.isEmpty
        case .tasks: return vm.tickTick.tasks.contains { !$0.isCompleted }
        case .calendar: return vm.calendar.access == .granted
        case .weather: return vm.weather.weather != nil
        case .monitor: return true
        }
    }

    @ViewBuilder
    private func widget(_ widget: OverviewWidget, large: Bool) -> some View {
        let open = { vm.select(widget.tab) }
        switch widget {
        case .nowPlaying: NowPlayingWidget(media: vm.media, open: open)
        case .limits: LimitsWidget(usage: usage, open: open)
        case .clipboard: ClipboardWidget(clipboard: vm.clipboard, open: open)
        case .focus: FocusWidget(timer: vm.timer, open: open)
        case .notes: NotesWidget(notes: notes, open: open)
        case .snippets: SnippetsWidget(snippets: snippets, open: open)
        case .shelf: ShelfWidget(shelf: vm.shelf, open: open)
        case .tasks: TasksWidget(store: vm.tickTick, open: open)
        case .calendar: NextMeetingWidget(calendar: vm.calendar, open: open)
        case .weather: WeatherWidget(weather: vm.weather, open: open)
        case .monitor: MonitorWidget(monitor: vm.monitor, open: open)
        }
    }
}

// MARK: - Widget chrome

/// A card that opens its tab when clicked, and lifts a little under the pointer.
private struct Widget<Content: View>: View {
    let open: () -> Void
    @ViewBuilder var content: Content
    @State private var hovering = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .card(padding: 10, emphasis: hovering ? 1.6 : 1)
            .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .onTapGesture(perform: open)
            .onHover { hovering = $0 }
            .scaleEffect(hovering ? 1.015 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hovering)
    }
}

private struct WidgetTitle: View {
    let symbol: String
    let text: String
    var tint: Color = Theme.tertiary
    var trailing: String?

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 9, weight: .bold))
            Text(text.uppercased()).font(Theme.micro).tracking(0.9)
            Spacer(minLength: 4)
            if let trailing {
                Text(trailing).font(Theme.numeral(9.5, weight: .semibold))
            }
        }
        .foregroundStyle(tint)
        .lineLimit(1)
    }
}

/// One line that copies its text when clicked, with a tick to confirm.
private struct CopyRow: View {
    let symbol: String
    let text: String
    let copy: () -> Void
    @State private var copied = false
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: copied ? "checkmark" : symbol)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(copied ? Theme.positive : Theme.tertiary)
                .frame(width: 12)
            Text(text)
                .font(Theme.caption)
                .foregroundStyle(Theme.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 5)
        .frame(height: 21)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(hovering ? Theme.surfaceHover : Theme.surface)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            copy()
            HapticManager.play(.generic)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { copied = false }
        }
        .help(localized("Copy"))
        .animation(Theme.contentAnimation, value: copied)
        .animation(Theme.contentAnimation, value: hovering)
    }
}

// MARK: - Now playing

private struct NowPlayingWidget: View {
    @ObservedObject var media: MediaController
    let open: () -> Void

    var body: some View {
        Widget(open: open) {
            if let track = media.track {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            if let image = media.artwork {
                                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                            } else {
                                SkeletonBox(cornerRadius: 12)
                            }
                        }
                        .frame(width: 78, height: 78)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.75)
                        )
                        .shadow(color: (media.artworkPalette?.first ?? .black).opacity(0.5), radius: 14, y: 4)

                        VStack(alignment: .leading, spacing: 3) {
                            WidgetTitle(symbol: "waveform", text: localized("Now playing"), tint: Theme.accent)
                            Text(track.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.primary)
                                .lineLimit(2)
                                .padding(.top, 3)
                            Text(track.artist)
                                .font(Theme.body)
                                .foregroundStyle(Theme.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    CapsuleProgress(
                        fraction: media.duration > 0 ? media.position / media.duration : 0,
                        tint: .white,
                        height: 4
                    )
                    HStack(spacing: 14) {
                        Text(formatTime(media.position))
                            .font(Theme.numeral(10, weight: .medium))
                            .foregroundStyle(Theme.tertiary)
                        Spacer()
                        Button { media.previous() } label: { Image(systemName: "backward.fill") }
                            .buttonStyle(NotchButtonStyle(size: 28))
                        Button { media.togglePlayPause() } label: {
                            Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                        }
                        .buttonStyle(NotchButtonStyle(size: 34, prominent: true))
                        Button { media.next() } label: { Image(systemName: "forward.fill") }
                            .buttonStyle(NotchButtonStyle(size: 28))
                        Spacer()
                        Text(formatTime(media.duration))
                            .font(Theme.numeral(10, weight: .medium))
                            .foregroundStyle(Theme.tertiary)
                    }
                    .padding(.top, 6)
                }
            }
        }
    }
}

// MARK: - Limits

private struct LimitsWidget: View {
    @ObservedObject var usage: AgentUsageStore
    let open: () -> Void

    var body: some View {
        Widget(open: open) {
            VStack(alignment: .leading, spacing: 6) {
                WidgetTitle(symbol: "gauge.with.dots.needle.33percent", text: localized("5-hour limits"))
                Spacer(minLength: 0)
                row("Claude", usage.claude)
                row("Codex", usage.codex)
            }
        }
    }

    @ViewBuilder
    private func row(_ name: String, _ agent: AgentUsage?) -> some View {
        if let window = agent?.session?.current(at: usage.checkedAt) {
            HStack(spacing: 6) {
                Text(verbatim: name)
                    .font(Theme.captionEmphasis)
                    .foregroundStyle(Theme.secondary)
                    .frame(width: 42, alignment: .leading)
                CapsuleProgress(fraction: window.usedPercent / 100, tint: Theme.load(window.usedPercent / 100), height: 4)
                Text("\(Int(window.usedPercent.rounded()))%")
                    .font(Theme.numeral(10, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                    .frame(width: 30, alignment: .trailing)
            }
        }
    }
}

// MARK: - Clipboard

private struct ClipboardWidget: View {
    @ObservedObject var clipboard: ClipboardStore
    let open: () -> Void

    var body: some View {
        Widget(open: open) {
            VStack(alignment: .leading, spacing: 4) {
                WidgetTitle(symbol: "list.clipboard", text: localized("Clipboard"), trailing: "\(clipboard.items.count)")
                Spacer(minLength: 0)
                ForEach(clipboard.items.prefix(2)) { item in
                    CopyRow(
                        symbol: item.symbol,
                        text: item.preview.replacingOccurrences(of: "\n", with: " ")
                    ) { clipboard.copy(item) }
                }
            }
        }
    }
}

// MARK: - Snippets

private struct SnippetsWidget: View {
    @ObservedObject var snippets: SnippetStore
    let open: () -> Void

    var body: some View {
        Widget(open: open) {
            VStack(alignment: .leading, spacing: 4) {
                WidgetTitle(symbol: "pin.fill", text: localized("Snippets"), trailing: "\(snippets.items.count)")
                Spacer(minLength: 0)
                ForEach(snippets.items.prefix(2)) { item in
                    CopyRow(symbol: item.symbol, text: item.label.isEmpty ? item.text : item.label) {
                        snippets.copy(item)
                    }
                }
            }
        }
    }
}

// MARK: - Notes

private struct NotesWidget: View {
    @ObservedObject var notes: NoteStore
    let open: () -> Void

    private var latest: Note? {
        notes.notes
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .max { $0.edited < $1.edited }
    }

    var body: some View {
        Widget(open: open) {
            VStack(alignment: .leading, spacing: 4) {
                WidgetTitle(symbol: "note.text", text: localized("Latest note"))
                if let latest {
                    Text(latest.text.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(Theme.caption)
                        .foregroundStyle(Theme.primary)
                        .lineLimit(3)
                        .padding(.top, 2)
                    Spacer(minLength: 0)
                    Text(localized("%@ ago", shortAge(since: latest.edited)))
                        .font(Theme.micro)
                        .foregroundStyle(Theme.tertiary)
                }
            }
        }
    }
}

// MARK: - Shelf

private struct ShelfWidget: View {
    @ObservedObject var shelf: ShelfStore
    let open: () -> Void

    var body: some View {
        Widget(open: open) {
            VStack(alignment: .leading, spacing: 6) {
                WidgetTitle(symbol: "tray.full.fill", text: localized("Shelf"), trailing: "\(shelf.items.count)")
                Spacer(minLength: 0)
                HStack(spacing: 5) {
                    ForEach(shelf.items.prefix(4)) { item in
                        Image(nsImage: item.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                            .frame(width: 36, height: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.black.opacity(0.35))
                            )
                            .help(item.name)
                    }
                }
            }
        }
    }
}

// MARK: - Tasks

private struct TasksWidget: View {
    @ObservedObject var store: TickTickStore
    let open: () -> Void

    var body: some View {
        Widget(open: open) {
            VStack(alignment: .leading, spacing: 5) {
                let pending = store.tasks.filter { !$0.isCompleted }
                WidgetTitle(symbol: "checkmark.circle", text: localized("Tasks"), trailing: "\(pending.count)")
                Spacer(minLength: 0)
                ForEach(pending.prefix(2)) { task in
                    HStack(spacing: 6) {
                        Image(systemName: "circle")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(task.priority >= 3 ? Theme.warning : Theme.tertiary)
                        Text(task.title)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.primary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

// MARK: - Next meeting

private struct NextMeetingWidget: View {
    @ObservedObject var calendar: CalendarStore
    let open: () -> Void

    var body: some View {
        Widget(open: open) {
            VStack(alignment: .leading, spacing: 4) {
                WidgetTitle(symbol: "calendar", text: localized("Next meeting"))
                if let next = calendar.next {
                    Text(next.title)
                        .font(Theme.bodyEmphasis)
                        .foregroundStyle(Theme.primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        Circle().fill(Color(next.calendarColor)).frame(width: 6, height: 6)
                        Text(CalendarPane.countdown(to: next, from: calendar.now))
                            .font(Theme.captionEmphasis)
                            .foregroundStyle(next.isRunning ? Theme.positive : Theme.accent)
                    }
                } else {
                    Spacer(minLength: 0)
                    Text(localized("No more meetings"))
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondary)
                }
            }
        }
    }
}

// MARK: - Weather

private struct WeatherWidget: View {
    @ObservedObject var weather: WeatherStore
    let open: () -> Void

    var body: some View {
        Widget(open: open) {
            if let current = weather.weather {
                HStack(spacing: 8) {
                    Image(systemName: WeatherSymbols.symbol(for: current.condition))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(String(format: "%.0f°", current.temperature))
                            .font(Theme.numeral(22, weight: .medium))
                            .foregroundStyle(Theme.primary)
                        Text(current.locationName ?? WeatherSymbols.name(for: current.condition))
                            .font(Theme.caption)
                            .foregroundStyle(Theme.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Focus

private struct FocusWidget: View {
    @ObservedObject var timer: TimerStore
    let open: () -> Void

    private var progress: Double {
        guard timer.selectedDuration > 0, timer.state != .idle else { return 0 }
        return 1 - timer.timeRemaining / timer.selectedDuration
    }

    var body: some View {
        Widget(open: open) {
            HStack(spacing: 10) {
                ZStack {
                    RingGauge(progress: progress, lineWidth: 4, tint: timer.state == .paused ? Theme.warning : Theme.accent)
                    Button {
                        timer.state == .running ? timer.pause() : timer.start()
                    } label: {
                        Image(systemName: timer.state == .running ? "pause.fill" : "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.primary)
                            .frame(width: 30, height: 30)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text(timer.formattedTime)
                        .font(Theme.numeral(19))
                        .foregroundStyle(Theme.primary)
                    Text(localized("Focus").uppercased())
                        .font(Theme.micro)
                        .tracking(0.9)
                        .foregroundStyle(timer.state == .running ? Theme.accent : Theme.tertiary)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}

// MARK: - Monitor

private struct MonitorWidget: View {
    @ObservedObject var monitor: SystemMonitorStore
    let open: () -> Void

    var body: some View {
        Widget(open: open) {
            VStack(alignment: .leading, spacing: 6) {
                WidgetTitle(symbol: "cpu", text: localized("Monitor"))
                Spacer(minLength: 0)
                bar(localized("CPU"), monitor.cpuUsage)
                bar(localized("Memory"), monitor.memoryUsage)
            }
        }
    }

    private func bar(_ title: String, _ percent: Double) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(Theme.captionEmphasis)
                .foregroundStyle(Theme.secondary)
                .frame(width: 50, alignment: .leading)
                .lineLimit(1)
            CapsuleProgress(fraction: percent / 100, tint: Theme.load(percent / 100), height: 4)
            Text("\(Int(percent.rounded()))%")
                .font(Theme.numeral(10, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 30, alignment: .trailing)
        }
    }
}
