import SwiftUI

struct DynamicIslandView: View {
    @ObservedObject var vm: NotchViewModel
    
    private var notchWidth: CGFloat { vm.geometry.notchSize.width }
    private var notchHeight: CGFloat { vm.geometry.notchSize.height }

    var body: some View {
        // Single right-side wing that merges with the notch edge.
        // By placing the pill inside a wider-than-notch frame and aligning it
        // to trailing, we guarantee it sits flush against the notch's right
        // edge regardless of how wide the notch is on a given Mac.
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            
            if pillKind != nil {
                activePill
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        // Extra width so the pill can sit fully outside the notch area.
        // The 6pt trailing padding keeps it clear of the notch's rounded corner.
        .padding(.trailing, 6)
        .frame(width: notchWidth + 140, height: notchHeight)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: pillKind)
    }

    // MARK: - Active Pill

    @ViewBuilder
    private var activePill: some View {
        switch pillKind {
        case .timer:
            pillBody {
                Image(systemName: "timer")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.accent)
                Text(vm.timer.formattedTime)
                    .font(Theme.numeral(11.5))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize()
            }
        case .media:
            pillBody {
                EqualizerBars(isAnimating: true)
                if vm.media.track != nil {
                    Text(formatTime(vm.media.position))
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        case .weather:
            if let w = vm.weather.weather {
                pillBody {
                    Image(systemName: weatherSymbol(for: w.condition))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                    Text(String(format: "%.0f°", w.temperature))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        case .none:
            EmptyView()
        }
    }

    // MARK: - Shared Pill Chrome

    private func pillBody<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 6) {
            content()
        }
        .padding(.horizontal, 11)
        .frame(height: notchHeight)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: notchHeight / 2, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: notchHeight / 2, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.75)
        )
    }

    // MARK: - Pill Priority

    private enum PillKind: Equatable {
        case timer, media, weather
    }

    private var pillKind: PillKind? {
        if vm.timer.state == .running { return .timer }
        if vm.media.isPlaying { return .media }
        if vm.weather.weather != nil { return .weather }
        return nil
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func weatherSymbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 61...67: return "cloud.rain.fill"
        case 71...77: return "cloud.snow.fill"
        case 80...82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.fill"
        default: return "cloud.sun.fill"
        }
    }
}
