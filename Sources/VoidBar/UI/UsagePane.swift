import SwiftUI

/// Plan limits of Claude Code and Codex, side by side: how much of the
/// five-hour and weekly windows is gone, and when each starts over.
struct UsagePane: View {
    @ObservedObject var usage: AgentUsageStore

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AgentCard(
                name: "Claude Code",
                symbol: "sparkle",
                usage: usage.claude,
                loaded: usage.loaded,
                empty: .claudeSetup
            )
            AgentCard(
                name: "Codex",
                symbol: "chevron.left.forwardslash.chevron.right",
                usage: usage.codex,
                loaded: usage.loaded,
                empty: .codexMissing
            )
        }
        .padding(.top, 2)
        // Re-read while the tab is on screen. The files only change when one of
        // the tools answers, so a relaxed pace is enough, and nothing runs once
        // the pane is gone.
        .task {
            while !Task.isCancelled {
                await usage.refresh()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }
}

private struct AgentCard: View {
    enum Empty { case claudeSetup, codexMissing }

    let name: String
    let symbol: String
    let usage: AgentUsage?
    let loaded: Bool
    let empty: Empty

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                if let plan = usage?.plan {
                    Text(plan.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.surface))
                }
                Spacer(minLength: 4)
                if let usage {
                    Text(UsageFormat.updated(usage.recordedAt))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.tertiary)
                        .lineLimit(1)
                }
            }

            if let usage {
                // Read once per redraw, so both rows agree about "now".
                let now = Date()
                if let session = usage.session {
                    WindowRow(title: localized("5 hours"), window: session, now: now)
                }
                if let weekly = usage.weekly {
                    WindowRow(title: localized("Week"), window: weekly, now: now)
                }
            } else if loaded {
                emptyState
            } else {
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.surface)
        )
    }

    @ViewBuilder
    private var emptyState: some View {
        switch empty {
        case .claudeSetup:
            VStack(alignment: .leading, spacing: 7) {
                Text(localized("Add VoidBar as the Claude Code status line to see Pro and Max limits here."))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    AgentUsageStore.copyClaudeSetup()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { copied = false }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? localized("Copied") : localized("Copy setup"))
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(copied ? Color.green : .white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.surfaceHover))
                }
                .buttonStyle(.plain)
                Text(localized("Paste it into ~/.claude/settings.json."))
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.tertiary)
            }
            .animation(Theme.contentAnimation, value: copied)
        case .codexMissing:
            Text(localized("No Codex session yet. Limits appear after the first response."))
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct WindowRow: View {
    let title: String
    let window: UsageWindow
    let now: Date

    var body: some View {
        let current = window.current(at: now)
        let fraction = current.usedPercent / 100
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                Spacer(minLength: 4)
                Text("\(Int(current.usedPercent.rounded()))%")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(UsageFormat.tint(for: current.usedPercent))
                        .frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: 4)
            Text(UsageFormat.reset(window, now: now))
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.tertiary)
                .lineLimit(1)
        }
    }
}

/// Wording and colour for the usage pane, kept out of the views so it can be
/// tested and so both cards say things the same way.
enum UsageFormat {
    /// White until the window gets tight; the bar is the one thing in the
    /// panel that should draw the eye when a limit is close.
    static func tint(for percent: Double) -> Color {
        switch percent {
        case 90...: return Color(red: 1, green: 0.42, blue: 0.38)
        case 75..<90: return Color(red: 1, green: 0.72, blue: 0.35)
        default: return Color.white.opacity(0.9)
        }
    }

    static func reset(_ window: UsageWindow, now: Date) -> String {
        if window.hasReset(at: now) { return localized("Window has reset") }
        guard let resetsAt = window.resetsAt else { return "" }
        let remaining = resetsAt.timeIntervalSince(now)
        if remaining < 24 * 3600 {
            return localized("Resets in %@", duration(remaining))
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLanguage)
        formatter.setLocalizedDateFormatFromTemplate("EEE HH:mm")
        return localized("Resets %@", formatter.string(from: resetsAt))
    }

    static func updated(_ date: Date, now: Date = Date()) -> String {
        let elapsed = now.timeIntervalSince(date)
        if elapsed < 60 { return localized("just now") }
        return localized("%@ ago", duration(elapsed))
    }

    /// "2 h 5 min", "12 min", "3 d 4 h" — two units at most.
    static func duration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: appLanguage)
        formatter.calendar = calendar
        formatter.unitsStyle = .short
        formatter.maximumUnitCount = 2
        formatter.allowedUnits = seconds >= 24 * 3600 ? [.day, .hour] : [.hour, .minute]
        return formatter.string(from: max(60, seconds)) ?? ""
    }
}
