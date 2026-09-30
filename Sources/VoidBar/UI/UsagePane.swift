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
                empty: .claudeSetup,
                now: usage.checkedAt,
                staleHint: usage.claude?.origin == .account
                    ? localized("Press ↻ to refresh from your Claude account.")
                    : localized("Status line numbers can be hours old. Press ↻ to read them from your Claude account."),
                refreshing: usage.claudeRefreshing,
                error: usage.claudeError,
                refreshHelp: localized("Refresh from your Claude account"),
                refresh: { Task { await usage.refreshClaudeFromAccount() } }
            )
            AgentCard(
                name: "Codex",
                symbol: "chevron.left.forwardslash.chevron.right",
                usage: usage.codex,
                loaded: usage.loaded,
                empty: .codexMissing,
                now: usage.checkedAt,
                staleHint: localized("Updates after your next Codex response."),
                refreshing: false,
                error: nil,
                refreshHelp: localized("Read Codex's logs again"),
                refresh: { Task { await usage.refresh() } }
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
    /// The store's last read; a new value redraws the countdowns.
    let now: Date
    /// Said when the numbers are over an hour old: they only move when the
    /// tool itself reports, which is easy to forget.
    let staleHint: String
    let refreshing: Bool
    let error: String?
    let refreshHelp: String
    let refresh: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                IconChip(symbol: symbol, tint: Theme.accent, size: 20)
                Text(name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.primary)
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
                    Text(UsageFormat.updated(usage.recordedAt, now: now))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.tertiary)
                        .lineLimit(1)
                }
                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(refreshing ? 360 : 0))
                        .animation(
                            refreshing ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default,
                            value: refreshing
                        )
                }
                .buttonStyle(NotchButtonStyle(size: 22))
                .disabled(refreshing)
                .help(refreshHelp)
            }

            if let usage {
                if let session = usage.session {
                    WindowRow(title: localized("5 hours"), window: session, now: now)
                }
                if let weekly = usage.weekly {
                    WindowRow(title: localized("Week"), window: weekly, now: now)
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.warning)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else if now.timeIntervalSince(usage.recordedAt) > 3600 {
                    Label(staleHint, systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.tertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if loaded {
                emptyState
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card(padding: 12)
    }

    @ViewBuilder
    private var emptyState: some View {
        switch empty {
        case .claudeSetup:
            VStack(alignment: .leading, spacing: 7) {
                Text(localized("Press ↻ to read Pro and Max limits from your Claude account, or add VoidBar as the Claude Code status line."))
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
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(copied ? Theme.surfaceHover : Color.white.opacity(0.9)))
                    .foregroundStyle(copied ? Theme.positive : Color.black)
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
                    .font(Theme.numeral(13))
                    .foregroundStyle(Theme.primary)
            }
            CapsuleProgress(fraction: fraction, tint: UsageFormat.tint(for: current.usedPercent), height: 5)
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
        Theme.load(percent / 100)
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
