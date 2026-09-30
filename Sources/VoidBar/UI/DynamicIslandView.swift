import SwiftUI

/// The folded panel while something is going on: the notch grows a wing on
/// each side, like a Dynamic Island. The left wing says what it is — the cover,
/// a timer ring, the sky — and the right wing shows it live.
struct DynamicIslandView: View {
    @ObservedObject var vm: NotchViewModel

    private var notchWidth: CGFloat { vm.geometry.notchSize.width }
    private var notchHeight: CGFloat { vm.geometry.notchSize.height }
    private let wing: CGFloat = 58

    var body: some View {
        let active = activity != nil
        ZStack(alignment: .top) {
            // One black silhouette, notch included, with the notch's own
            // concave shoulders where it meets the top of the display.
            NotchShape(topRadius: Theme.collapsedTopRadius, bottomRadius: notchHeight / 2)
                .fill(Color.black)
                .frame(
                    width: (active ? notchWidth + 2 * wing : notchWidth) + 2 * Theme.collapsedTopRadius,
                    height: notchHeight
                )
                .opacity(active ? 1 : 0)

            if let activity {
                HStack(spacing: 0) {
                    leading(activity)
                        .frame(width: wing)
                    Color.clear.frame(width: notchWidth)
                    trailing(activity)
                        .frame(width: wing)
                }
                .frame(height: notchHeight)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                .id(activity)
            }
        }
        .frame(width: notchWidth + 2 * wing + 2 * Theme.collapsedTopRadius, height: notchHeight, alignment: .top)
        .animation(.spring(response: 0.42, dampingFraction: 0.74), value: activity)
    }

    // MARK: - Wings

    @ViewBuilder
    private func leading(_ activity: Activity) -> some View {
        switch activity {
        case .media:
            Group {
                if let image = vm.media.artwork {
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .frame(width: 20, height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        case .timer:
            RingGauge(progress: timerProgress, lineWidth: 2.5, tint: Theme.accent)
                .frame(width: 18, height: 18)
        case .weather:
            if let weather = vm.weather.weather {
                Image(systemName: WeatherSymbols.symbol(for: weather.condition))
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 13))
            }
        }
    }

    @ViewBuilder
    private func trailing(_ activity: Activity) -> some View {
        switch activity {
        case .media:
            EqualizerBars(isAnimating: vm.media.isPlaying, tint: vm.media.artworkPalette?.first ?? Theme.accent)
        case .timer:
            Text(vm.timer.formattedTime)
                .font(Theme.numeral(12))
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
        case .weather:
            if let weather = vm.weather.weather {
                Text(String(format: "%.0f°", weather.temperature))
                    .font(Theme.numeral(12))
                    .foregroundStyle(.white)
                    .fixedSize()
            }
        }
    }

    private var timerProgress: Double {
        guard vm.timer.selectedDuration > 0 else { return 0 }
        return 1 - vm.timer.timeRemaining / vm.timer.selectedDuration
    }

    // MARK: - Priority

    private enum Activity: Hashable {
        case timer, media, weather
    }

    /// A running timer outranks music, and music outranks the weather.
    private var activity: Activity? {
        if vm.timer.state == .running { return .timer }
        if vm.media.isPlaying { return .media }
        if vm.weather.weather != nil { return .weather }
        return nil
    }
}
