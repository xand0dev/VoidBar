import SwiftUI

struct MonitorPane: View {
    @ObservedObject var monitor: SystemMonitorStore

    var body: some View {
        HStack(spacing: 10) {
            gaugeTile(title: localized("CPU"), symbol: "cpu", percent: monitor.cpuUsage)
            gaugeTile(title: localized("Memory"), symbol: "memorychip", percent: monitor.memoryUsage)
            networkTile
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func gaugeTile(title: String, symbol: String, percent: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(title: title, symbol: symbol)
            Spacer(minLength: 0)
            HStack(alignment: .bottom) {
                Text(String(format: "%.0f", percent))
                    .font(Theme.numeral(30))
                    .foregroundStyle(Theme.primary)
                + Text("%")
                    .font(Theme.numeral(14, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                Spacer(minLength: 4)
                RingGauge(progress: percent / 100, lineWidth: 5, tint: Theme.load(percent / 100))
                    .frame(width: 40, height: 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card(padding: 12)
        .animation(.easeOut(duration: 0.4), value: percent)
    }

    private var networkTile: some View {
        VStack(alignment: .leading, spacing: 8) {
            header(title: localized("Network"), symbol: "network")
            Spacer(minLength: 0)
            speedRow(symbol: "arrow.down", value: monitor.networkDownloadSpeed, tint: Theme.accent)
            speedRow(symbol: "arrow.up", value: monitor.networkUploadSpeed, tint: Theme.positive)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card(padding: 12)
    }

    private func header(title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.tertiary)
            SectionLabel(text: title)
        }
    }

    private func speedRow(symbol: String, value: Double, tint: Color) -> some View {
        HStack(spacing: 7) {
            IconChip(symbol: symbol, tint: tint, size: 20)
            Text(formatSpeed(value))
                .font(Theme.numeral(15))
                .foregroundStyle(Theme.primary)
        }
    }

    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let kbps = bytesPerSecond / 1024
        if kbps > 1024 {
            return String(format: "%.1f MB/s", kbps / 1024)
        } else {
            return String(format: "%.0f KB/s", kbps)
        }
    }
}
