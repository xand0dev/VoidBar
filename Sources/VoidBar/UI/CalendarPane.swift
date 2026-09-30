import SwiftUI

struct CalendarPane: View {
    @ObservedObject var calendar: CalendarStore

    var body: some View {
        switch calendar.access {
        case .notRequested:
            permissionPrompt
        case .denied:
            deniedState
        case .granted:
            if let next = calendar.next {
                agenda(next: next)
            } else {
                emptyState
                    .overlay(alignment: .topTrailing) { settingsMenu }
            }
        }
    }

    // MARK: - Agenda

    private func agenda(next: CalendarStore.Meeting) -> some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(alignment: .top, spacing: 11) {
                Capsule()
                    .fill(Color(next.calendarColor))
                    .frame(width: 3.5)
                VStack(alignment: .leading, spacing: 0) {
                    Text(Self.countdown(to: next, from: calendar.now))
                        .font(Theme.captionEmphasis)
                        .foregroundStyle(next.isRunning ? Color.black : Theme.accent)
                        .padding(.horizontal, 8)
                        .frame(height: 19)
                        .background(Capsule().fill(next.isRunning ? Theme.positive : Theme.accent.opacity(0.16)))
                    Text(next.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .lineLimit(2)
                        .padding(.top, 8)
                    Text(subtitle(for: next))
                        .font(Theme.body)
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                        .padding(.top, 3)

                    Spacer(minLength: 8)

                    if next.link != nil {
                        Button {
                            calendar.join(next)
                            HapticManager.play(.alignment)
                        } label: {
                            Label(
                                next.provider.map { localized("Join · %@", $0) } ?? localized("Join"),
                                systemImage: "video.fill"
                            )
                        }
                        .buttonStyle(PillButtonStyle(prominent: true))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .card(padding: 12)

            rest
        }
    }

    /// Everything after the next meeting, as a timeline on the right.
    private var rest: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel(text: localized("Later"))
                Spacer()
                settingsMenu
            }
            .frame(height: 22)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(calendar.upcoming.prefix(4)) { meeting in
                    HStack(spacing: 9) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(meeting.calendarColor))
                            .frame(width: 3, height: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(meeting.title)
                                .font(Theme.bodyEmphasis)
                                .foregroundStyle(Theme.primary)
                                .lineLimit(1)
                            Text(timeLabel(for: meeting))
                                .font(Theme.numeral(10, weight: .medium))
                                .foregroundStyle(Theme.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                if calendar.upcoming.isEmpty {
                    Text("No other meetings this week")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(width: 190, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func timeLabel(for meeting: CalendarStore.Meeting) -> String {
        let clock = Self.clock.string(from: meeting.start)
        guard let day = Self.day(for: meeting.start) else { return clock }
        return "\(day.sentenceCased) · \(clock)"
    }

    private func subtitle(for meeting: CalendarStore.Meeting) -> String {
        var parts = [Self.day(for: meeting.start)].compactMap { $0 }
        parts.append("\(Self.clock.string(from: meeting.start))–\(Self.clock.string(from: meeting.end))")
        if let provider = meeting.provider { parts.append(provider) }
        return parts.joined(separator: " · ").sentenceCased
    }

    static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLanguage)
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter
    }()

    /// Nothing for today — the time alone says it. A word for tomorrow, a full
    /// date for anything further out.
    static func day(for date: Date) -> String? {
        let calendar = Foundation.Calendar.current
        if calendar.isDateInToday(date) { return nil }
        if calendar.isDateInTomorrow(date) { return localized("tomorrow") }
        return weekday.string(from: date)
    }

    /// "In 12 min" / "Now" — shown in the panel header, on its own,
    /// so it is a label and starts with a capital in either language.
    static func countdown(to meeting: CalendarStore.Meeting, from now: Date) -> String {
        phrase(to: meeting, from: now).sentenceCased
    }

    /// The wording alone, lower-case as the languages have it. Kept apart from
    /// the capital so the same phrases could stand mid-sentence one day.
    private static func phrase(to meeting: CalendarStore.Meeting, from now: Date) -> String {
        if meeting.isRunning { return localized("now") }
        let minutes = Int((meeting.start.timeIntervalSince(now) / 60).rounded(.up))
        if minutes <= 0 { return localized("any moment") }
        if minutes < 60 { return localized("in %d min", minutes) }
        let hours = minutes / 60
        if hours < 24 {
            let rest = minutes % 60
            return rest == 0 ? localized("in %d h", hours) : localized("in %d h %d min", hours, rest)
        }
        let days = hours / 24
        return days == 1 ? localized("tomorrow") : localized("in %d d", days)
    }

    // MARK: - States

    private var permissionPrompt: some View {
        VStack(spacing: 9) {
            IconChip(symbol: "calendar", tint: Theme.accent, size: 34)
            Text("See your next meetings")
                .font(Theme.bodyEmphasis)
                .foregroundStyle(Theme.primary)
            Text("VoidBar needs Calendar access for this tab. Other features\nmay request their own permissions when used.")
                .font(.system(size: 10))
                .foregroundStyle(Theme.tertiary)
                .multilineTextAlignment(.center)
            // Padding and background belong inside the label: with .plain the
            // hit area is the label itself, so decorating the Button from the
            // outside leaves a capsule that only responds on its lettering.
            Button {
                calendar.requestAccess()
            } label: {
                Text("Allow")
            }
            .buttonStyle(PillButtonStyle(prominent: true))
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var deniedState: some View {
        EmptyState(
            symbol: "calendar.badge.exclamationmark",
            title: localized("Calendar access is off"),
            message: localized("Settings → Privacy → Calendars")
        )
    }

    private var emptyState: some View {
        EmptyState(
            symbol: "checkmark.circle",
            title: localized("No more meetings"),
            message: localized("Nothing on the calendar for the next day")
        )
    }

    private var settingsMenu: some View {
        Menu {
            ForEach(calendar.availableCalendars, id: \.calendarIdentifier) { cal in
                Button {
                    var disabled = calendar.disabledCalendarIDs
                    if disabled.contains(cal.calendarIdentifier) {
                        disabled.remove(cal.calendarIdentifier)
                    } else {
                        disabled.insert(cal.calendarIdentifier)
                    }
                    calendar.disabledCalendarIDs = disabled
                } label: {
                    HStack {
                        if !calendar.disabledCalendarIDs.contains(cal.calendarIdentifier) {
                            Image(systemName: "checkmark")
                        }
                        Text(cal.title)
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.tertiary)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 22, height: 22)
        .help(localized("Calendars"))
    }
}
