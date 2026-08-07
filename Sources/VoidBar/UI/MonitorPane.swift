import SwiftUI

struct MonitorPane: View {
    @ObservedObject var monitor: SystemMonitorStore

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CPU")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.secondary)
                    
                    Text(String(format: "%.1f%%", monitor.cpuUsage))
                        .font(.system(size: 24, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                }
                Spacer()
                CircularProgressView(progress: monitor.cpuUsage / 100.0, color: .orange)
                    .frame(width: 40, height: 40)
            }
            .padding(.horizontal, 16)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Memory")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.secondary)
                    
                    Text(String(format: "%.1f%%", monitor.memoryUsage))
                        .font(.system(size: 24, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                }
                Spacer()
                CircularProgressView(progress: monitor.memoryUsage / 100.0, color: .blue)
                    .frame(width: 40, height: 40)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
    }
}

private struct CircularProgressView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    color.opacity(0.3),
                    lineWidth: 6
                )
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: 6,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: progress)
        }
    }
}
