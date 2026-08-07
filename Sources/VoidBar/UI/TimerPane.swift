import SwiftUI

struct TimerPane: View {
    @ObservedObject var timer: TimerStore
    
    let presets: [TimeInterval] = [5 * 60, 10 * 60, 25 * 60, 50 * 60]
    let presetLabels = ["5m", "10m", "25m", "50m"]

    var body: some View {
        VStack(spacing: 16) {
            Text(timer.formattedTime)
                .font(.system(size: 48, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                
            HStack(spacing: 8) {
                ForEach(0..<presets.count, id: \.self) { i in
                    Button(presetLabels[i]) {
                        timer.selectDuration(presets[i])
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(timer.selectedDuration == presets[i] ? .white : Theme.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(timer.selectedDuration == presets[i] ? Color.white.opacity(0.15) : Color.clear)
                    )
                    .buttonStyle(.plain)
                    .disabled(timer.state == .running)
                }
            }

            HStack(spacing: 30) {
                Button {
                    timer.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 20))
                }
                .buttonStyle(NotchButtonStyle(size: 40))

                Button {
                    if timer.state == .running {
                        timer.pause()
                    } else {
                        timer.start()
                    }
                } label: {
                    Image(systemName: timer.state == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 24))
                }
                .buttonStyle(NotchButtonStyle(size: 50, prominent: true))
            }
            .padding(.top, 4)
            
            if timer.completedToday > 0 {
                Text("🍅 Completed today: \(timer.completedToday)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.tertiary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
