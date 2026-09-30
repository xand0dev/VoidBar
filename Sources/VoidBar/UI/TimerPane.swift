import SwiftUI

struct TimerPane: View {
    @ObservedObject var timer: TimerStore

    let presets: [TimeInterval] = [5 * 60, 10 * 60, 25 * 60, 50 * 60]
    let presetLabels = ["5m", "10m", "25m", "50m"]

    private var progress: Double {
        guard timer.selectedDuration > 0, timer.state != .idle else { return 0 }
        return 1 - timer.timeRemaining / timer.selectedDuration
    }

    private var stateLabel: String {
        switch timer.state {
        case .idle: return localized("Ready")
        case .running: return localized("Focus")
        case .paused: return localized("Paused")
        }
    }

    var body: some View {
        HStack(spacing: 26) {
            ZStack {
                RingGauge(
                    progress: progress,
                    lineWidth: 7,
                    tint: timer.state == .paused ? Theme.warning : Theme.accent
                )
                VStack(spacing: 2) {
                    Text(timer.formattedTime)
                        .font(Theme.numeral(30))
                        .foregroundStyle(Theme.primary)
                        .contentTransition(.numericText())
                    Text(stateLabel.uppercased())
                        .font(Theme.micro)
                        .tracking(1)
                        .foregroundStyle(timer.state == .running ? Theme.accent : Theme.tertiary)
                }
            }
            .frame(width: 136, height: 136)
            .animation(.easeOut(duration: 0.3), value: timer.timeRemaining)

            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: localized("Duration"))
                presetPicker
                HStack(spacing: 12) {
                    Button {
                        if timer.state == .running {
                            timer.pause()
                        } else {
                            timer.start()
                        }
                    } label: {
                        Image(systemName: timer.state == .running ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(NotchButtonStyle(size: 42, prominent: true))

                    Button {
                        timer.reset()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(NotchButtonStyle(size: 34))
                    .help(localized("Reset"))

                    Spacer(minLength: 0)
                    sessions
                }
            }
            .frame(width: 230)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var presetPicker: some View {
        HStack(spacing: 2) {
            ForEach(0..<presets.count, id: \.self) { i in
                let selected = timer.selectedDuration == presets[i]
                Button {
                    timer.selectDuration(presets[i])
                } label: {
                    Text(presetLabels[i])
                        .font(Theme.captionEmphasis)
                        .foregroundStyle(selected ? Theme.primary : Theme.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(selected ? Theme.surfaceActive : .clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(timer.state == .running)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.surface)
        )
        .opacity(timer.state == .running ? 0.55 : 1)
        .animation(Theme.contentAnimation, value: timer.selectedDuration)
    }

    /// One dot per finished session today, up to eight.
    @ViewBuilder
    private var sessions: some View {
        if timer.completedToday > 0 {
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 3) {
                    ForEach(0..<min(timer.completedToday, 8), id: \.self) { _ in
                        Circle().fill(Theme.accent).frame(width: 5, height: 5)
                    }
                }
                Text(localized("%d today", timer.completedToday))
                    .font(Theme.caption)
                    .foregroundStyle(Theme.tertiary)
            }
        }
    }
}
