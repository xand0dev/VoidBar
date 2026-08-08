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
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Network")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.secondary)
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(Theme.tertiary)
                            Text(formatSpeed(monitor.networkDownloadSpeed))
                                .font(.system(size: 14, weight: .medium).monospacedDigit())
                                .foregroundStyle(.white)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(Theme.tertiary)
                            Text(formatSpeed(monitor.networkUploadSpeed))
                                .font(.system(size: 14, weight: .medium).monospacedDigit())
                                .foregroundStyle(.white)
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
    }
    
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let kbps = bytesPerSecond / 1024
        if kbps > 1024 {
            let mbps = kbps / 1024
            return String(format: "%.1f MB/s", mbps)
        } else {
            return String(format: "%.0f KB/s", kbps)
        }
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
