import SwiftUI

struct TimerPane: View {
    @ObservedObject var timer: TimerStore

    var body: some View {
        VStack(spacing: 20) {
            Text(timer.formattedTime)
                .font(.system(size: 48, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)

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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
