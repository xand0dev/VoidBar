import AppKit
import EventKit

/// Today's meetings, and the link that joins the next one.
///
/// Access is requested only when the user first opens the calendar tab: it is
/// the one permission VoidBar needs at all, and nobody should be asked for it
/// just because the app launched.
@MainActor
final class CalendarStore: ObservableObject {
    enum Access {
        case notRequested
        case granted
        case denied
    }

    struct Meeting: Identifiable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let calendarColor: NSColor
        let link: URL?
        let provider: String?

        var isRunning: Bool {
            let now = Date()
            return start <= now && now < end
        }
    }

    @Published private(set) var access: Access = .notRequested
    @Published private(set) var meetings: [Meeting] = []
    /// Recomputed on a timer so the countdown in the header stays honest.
    @Published private(set) var now = Date()

    private let store = EKEventStore()
    private var timer: Timer?
    private var observer: Any?
    /// Whether the panel is open. The half-minute tick serves eyes only — it
    /// keeps the countdown honest and drops meetings as they end — so it runs
    /// exactly while there are eyes.
    private var isActive = false
    /// A day-long horizon leaves the tab empty every evening, which is exactly
    /// when one wonders what tomorrow looks like. A week is still glanceable
    /// because only the next meeting gets the large treatment.
    private let horizon: TimeInterval = 7 * 24 * 3600

    var next: Meeting? {
        meetings.first { $0.end > Date() }
    }

    var upcoming: [Meeting] {
        guard let next else { return [] }
        return meetings.filter { $0.id != next.id && $0.end > Date() }
    }

    // MARK: - Lifecycle

    func start() {
        access = Self.currentAccess()
        guard access == .granted else { return }
        observe()
        reload()
    }

    func stop() {
        stopTimer()
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    /// Panel opened or closed. Opening refreshes at once — the countdown must
    /// be right on the first frame, not thirty seconds in — and starts the
    /// tick; closing stops it. Meetings still change while the panel is
    /// closed, but `EKEventStoreChanged` covers that without a clock.
    func setActive(_ active: Bool) {
        isActive = active
        guard active else { return stopTimer() }
        guard access == .granted else { return }
        tick()
        startTimer()
    }

    /// Called when the calendar tab is shown. Never prompts — it only notices
    /// that access was granted elsewhere, or since last launch.
    func refreshAccess() {
        access = Self.currentAccess()
        guard access == .granted else { return }
        observe()
        reload()
        if isActive { startTimer() }
    }

    /// Prompts. Only ever called from the button the user presses.
    func requestAccess() {
        guard Self.currentAccess() == .notRequested else {
            refreshAccess()
            return
        }
        store.requestFullAccessToEvents { [weak self] granted, _ in
            Task { @MainActor in
                guard let self else { return }
                self.access = granted ? .granted : .denied
                guard granted else { return }
                self.observe()
                self.reload()
                if self.isActive { self.startTimer() }
            }
        }
    }

    private static func currentAccess() -> Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .granted
        case .notDetermined: return .notRequested
        default: return .denied
        }
    }

    private func observe() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    private func startTimer() {
        guard timer == nil else { return }
        // Half a minute is enough for a countdown shown in whole minutes, and
        // the generous tolerance lets the system fold the wake-up into others.
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        now = Date()
        // Drop finished meetings without a full refetch.
        if meetings.contains(where: { $0.end <= now }) {
            meetings.removeAll { $0.end <= now }
        }
    }

    // MARK: - Loading

    func reload() {
        guard access == .granted else { return }
        let start = Date()
        let predicate = store.predicateForEvents(
            withStart: start,
            end: start.addingTimeInterval(horizon),
            calendars: nil
        )
        meetings = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.status != .canceled }
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                let link = MeetingLink.find(in: event)
                return Meeting(
                    id: event.eventIdentifier ?? "\(event.startDate.timeIntervalSince1970)-\(event.title ?? "")",
                    title: event.title ?? localized("Untitled"),
                    start: event.startDate,
                    end: event.endDate,
                    calendarColor: event.calendar.color ?? .systemBlue,
                    link: link,
                    provider: link.flatMap(MeetingLink.provider)
                )
            }
        now = Date()
    }

    func join(_ meeting: Meeting) {
        guard let link = meeting.link else { return }
        
        if isSafeURL(link) {
            NSWorkspace.shared.open(link)
        } else {
            let alert = NSAlert()
            alert.messageText = "Security Warning"
            alert.informativeText = "VoidBar blocked an attempt to open a calendar link with an unsafe or unrecognized format: \(link.absoluteString)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    // F-05 FIX: Validate calendar links before opening.
    func isSafeURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased() else {
            return false
        }
        
        let allowedSchemes: Set<String> = ["https", "http", "zoommtg", "msteams", "webex"]
        guard allowedSchemes.contains(scheme) else {
            return false
        }
        
        if scheme == "http" || scheme == "https" {
            guard let host = components.host, !host.isEmpty else {
                return false
            }
        }
        
        return true
    }

    func openCalendarApp() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
    }
}

/// Finds the video call in an event. Providers put the link wherever they like:
/// Google Meet in the notes, Zoom often in the location, Teams in both.
enum MeetingLink {
    private static let hosts = [
        "meet.google.com": "Google Meet",
        "zoom.us": "Zoom",
        "teams.microsoft.com": "Teams",
        "teams.live.com": "Teams",
        "webex.com": "Webex",
        "whereby.com": "Whereby",
        "meet.jit.si": "Jitsi",
        "discord.gg": "Discord",
        "telemost.yandex.ru": "Телемост",
    ]

    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    static func find(in event: EKEvent) -> URL? {
        let haystacks = [event.location, event.notes, event.url?.absoluteString].compactMap { $0 }
        for text in haystacks {
            if let url = firstKnownLink(in: text) { return url }
        }
        return event.url
    }

    private static func firstKnownLink(in text: String) -> URL? {
        guard let detector else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        for match in detector.matches(in: text, range: range) {
            guard let url = match.url, let host = url.host?.lowercased() else { continue }
            if hosts.keys.contains(where: { host == $0 || host.hasSuffix(".\($0)") }) { return url }
        }
        return nil
    }

    static func provider(for url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        return hosts.first { host == $0.key || host.hasSuffix(".\($0.key)") }?.value
    }
}
