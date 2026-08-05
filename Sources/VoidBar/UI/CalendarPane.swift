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
            }
        }
    }

    // MARK: - Agenda

    private func agenda(next: CalendarStore.Meeting) -> some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color(next.calendarColor))
                        .frame(width: 7, height: 7)
                    Text(next.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Text(subtitle(for: next))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
                    .padding(.top, 4)
                    .padding(.leading, 14)

                Spacer(minLength: 10)

                if next.link != nil {
                    Button {
                        calendar.join(next)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "video.fill").font(.system(size: 10))
                            Text(next.provider.map { localized("Join · %@", $0) } ?? localized("Join"))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(next.isRunning ? Color.white.opacity(0.92) : Theme.surfaceHover)
                        )
                        .foregroundStyle(next.isRunning ? .black : .white)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 14)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            rest
        }
        .padding(.top, 4)
    }

    /// Everything after the next meeting, as a column on the right.
    private var rest: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(calendar.upcoming.prefix(4)) { meeting in
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color(meeting.calendarColor))
                        .frame(width: 5, height: 5)
                    Text(Self.clock.string(from: meeting.start))
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 34, alignment: .leading)
                        .opacity(Foundation.Calendar.current.isDateInToday(meeting.start) ? 1 : 0.6)
                    Text(meeting.title)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.tertiary)
                        .lineLimit(1)
                }
            }
            if calendar.upcoming.isEmpty {
                Text("No other meetings this week")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.tertiary)
            }
            Spacer(minLength: 0)
        }
        .frame(width: 230, alignment: .leading)
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

    /// "Через 12 мин" / "Идёт сейчас" — shown in the panel header, on its own,
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
            Image(systemName: "calendar")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Theme.tertiary)
            Text("See your next meetings")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.secondary)
            Text("VoidBar needs access to Calendar. It is the only permission\nthe app asks for, and only for this tab.")
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
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.surfaceHover))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var deniedState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Theme.tertiary)
            Text("Calendar access is off")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.secondary)
            Text("Settings → Privacy → Calendars")
                .font(.system(size: 10))
                .foregroundStyle(Theme.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Theme.tertiary)
            Text("No more meetings")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.secondary)
            Text("Nothing on the calendar for the next day")
                .font(.system(size: 10))
                .foregroundStyle(Theme.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
