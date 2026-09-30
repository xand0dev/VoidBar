import SwiftUI

/// Everything at a glance: what is playing, what is next, the focus timer,
/// the weather, and the latest thing copied or the coding agents' limits.
///
/// Every widget is a doorway: a click opens its full tab. Nothing here makes a
/// request of its own — weather appears once the Weather tab has been opened,
/// and the calendar once access was granted there.
struct HomePane: View {
    @ObservedObject var vm: NotchViewModel

    var body: some View {
        HStack(spacing: 8) {
            NowPlayingWidget(media: vm.media) { vm.select(.media) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .reveal(delay: 0.04)

            VStack(spacing: 8) {
                NextMeetingWidget(calendar: vm.calendar) { vm.select(.calendar) }
                    .reveal(delay: 0.09)
                WeatherWidget(weather: vm.weather) { vm.select(.weather) }
                    .reveal(delay: 0.14)
            }
            .frame(width: 164)

            VStack(spacing: 8) {
                FocusWidget(timer: vm.timer) { vm.select(.timer) }
                    .reveal(delay: 0.12)
                if vm.usage.claude != nil || vm.usage.codex != nil {
                    LimitsWidget(usage: vm.usage) { vm.select(.usage) }
                        .reveal(delay: 0.17)
                } else {
                    LastCopiedWidget(clipboard: vm.clipboard) { vm.select(.clipboard) }
                        .reveal(delay: 0.17)
                }
            }
            .frame(width: 150)
        }
        .padding(.top, 2)
        .task { await vm.usage.refresh() }
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
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 9, weight: .bold))
            Text(text.uppercased()).font(Theme.micro).tracking(0.9)
        }
        .foregroundStyle(tint)
        .lineLimit(1)
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
            } else {
                EmptyState(symbol: "music.note", title: localized("Nothing is playing"))
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
                WidgetTitle(symbol: "calendar", text: localized("Next"))
                if calendar.access == .granted, let next = calendar.next {
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
                } else if calendar.access == .granted {
                    Spacer(minLength: 0)
                    Text(localized("No more meetings"))
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondary)
                } else {
                    Spacer(minLength: 0)
                    Text(localized("Connect in Calendar"))
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
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    WidgetTitle(symbol: "cloud.sun", text: localized("Weather"))
                    Spacer(minLength: 0)
                    Text(localized("Open Weather to turn it on"))
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondary)
                }
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

// MARK: - Limits / clipboard

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
        if let window = agent?.session?.current(at: Date()) {
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

private struct LastCopiedWidget: View {
    @ObservedObject var clipboard: ClipboardStore
    let open: () -> Void

    var body: some View {
        Widget(open: open) {
            VStack(alignment: .leading, spacing: 4) {
                WidgetTitle(symbol: "list.clipboard", text: localized("Last copied"))
                Spacer(minLength: 0)
                Text(clipboard.items.first?.preview.replacingOccurrences(of: "\n", with: " ") ?? "—")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.primary)
                    .lineLimit(2)
            }
        }
    }
}
