import SwiftUI

struct DynamicIslandView: View {
    @ObservedObject var vm: NotchViewModel
    
    // The width of the actual physical notch
    private var notchWidth: CGFloat { vm.geometry.notchSize.width }
    // The height of the physical notch
    private var notchHeight: CGFloat { vm.geometry.notchSize.height }
    
    // Animation for equalizer
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            if vm.timer.state == .running {
                timerPill
            } else if vm.media.isPlaying {
                mediaPill
            } else if let weather = vm.weather.weather {
                weatherPill(weather)
            }
        }
        .frame(width: notchWidth, height: notchHeight) // Center aligns with notch
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: vm.media.isPlaying || vm.timer.state == .running || vm.weather.weather != nil)
    }

    @ViewBuilder
    private var timerPill: some View {
        if vm.geometry.isPhysical {
            HStack {
                Spacer()
                Image(systemName: "timer")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.tertiary)
                    .padding(.trailing, 10)
            }
            .frame(width: 44, height: notchHeight)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: notchHeight / 2, style: .continuous))
            .offset(x: -notchWidth / 2 - 22 + 8)

            HStack {
                Text(vm.timer.formattedTime)
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundColor(Color.white)
                    .padding(.leading, 10)
                Spacer()
            }
            .frame(width: 44, height: notchHeight)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: notchHeight / 2, style: .continuous))
            .offset(x: notchWidth / 2 + 22 - 8)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.tertiary)
                Text(vm.timer.formattedTime)
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundColor(Color.white)
            }
            .padding(.horizontal, 12)
            .frame(height: notchHeight)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: notchHeight / 2, style: .continuous))
        }
    }

    @ViewBuilder
    private var mediaPill: some View {
        if vm.geometry.isPhysical {
            // Left Wing (Equalizer / Icon)
            HStack {
                Spacer() // push to right edge of the left wing
                EqualizerBars(isAnimating: true)
                    .padding(.trailing, 10)
            }
            .frame(width: 44, height: notchHeight)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: notchHeight / 2, style: .continuous))
            .offset(x: -notchWidth / 2 - 22 + 8) // Overlap slightly to merge with notch
            
            // Right Wing (Timer / Source)
            HStack {
                if vm.media.track != nil {
                    Text(formatTime(vm.media.position))
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundColor(Color.white)
                        .padding(.leading, 10)
                }
                Spacer()
            }
            .frame(width: 44, height: notchHeight)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: notchHeight / 2, style: .continuous))
            .offset(x: notchWidth / 2 + 22 - 8)
        } else {
            // Unified Pill for non-notched screens
            HStack(spacing: 8) {
                EqualizerBars(isAnimating: true)
                
                if vm.media.track != nil {
                    Text(formatTime(vm.media.position))
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundColor(Color.white)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: notchHeight)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: notchHeight / 2, style: .continuous))
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    @ViewBuilder
    private func weatherPill(_ weather: WeatherData) -> some View {
        if vm.geometry.isPhysical {
            // Right Wing (Weather)
            HStack {
                Text(String(format: "%.0f°", weather.temperature))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.white)
                    .padding(.leading, 12)
                Spacer()
            }
            .frame(width: 44, height: notchHeight)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: notchHeight / 2, style: .continuous))
            .offset(x: notchWidth / 2 + 22 - 8)
        } else {
            // Unified Pill
            HStack(spacing: 4) {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                Text(String(format: "%.0f°", weather.temperature))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.white)
            }
            .padding(.horizontal, 12)
            .frame(height: notchHeight)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: notchHeight / 2, style: .continuous))
        }
    }
}
