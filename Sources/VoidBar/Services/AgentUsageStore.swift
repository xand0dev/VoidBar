import AppKit

/// One rolling rate-limit window: how much of it is spent and when it starts over.
struct UsageWindow: Equatable, Codable {
    /// 0–100, as the tool itself reports it.
    var usedPercent: Double
    var resetsAt: Date?
    /// Length of the window, when the source says. Codex does; Claude Code's
    /// windows are fixed at five hours and seven days.
    var minutes: Int?

    /// A window whose reset time has passed has started over. The snapshot
    /// cannot know what was spent since, but it does know the old figure no
    /// longer applies — showing it would overstate the usage.
    func current(at now: Date) -> UsageWindow {
        guard let resetsAt, resetsAt <= now else { return self }
        return UsageWindow(usedPercent: 0, resetsAt: nil, minutes: minutes)
    }

    func hasReset(at now: Date) -> Bool {
        guard let resetsAt else { return false }
        return resetsAt <= now
    }
}

/// The last known plan limits of one coding agent.
struct AgentUsage: Equatable, Codable {
    /// The short window — five hours for both tools today.
    var session: UsageWindow?
    /// The long window — seven days.
    var weekly: UsageWindow?
    /// Subscription name when the source reports one ("plus", "pro", …).
    var plan: String?
    /// When the tool recorded these numbers, not when VoidBar read them.
    var recordedAt: Date
    /// Where Claude's numbers came from; nil for Codex.
    var origin: Origin? = nil

    enum Origin: String, Codable {
        /// The status line of one terminal session — as fresh as that
        /// session's last response.
        case statusLine
        /// The account itself, on the user's refresh.
        case account
    }
}

// MARK: - Parsing

/// Pure readers for the two sources, kept apart from file access so they can
/// be tested with literal input.
enum AgentUsageParser {
    /// One line of a Codex session log (`~/.codex/sessions/…/rollout-*.jsonl`).
    ///
    /// Codex appends a `token_count` event after each model response, and that
    /// event carries the account's rate limits: `primary` is the five-hour
    /// window, `secondary` the weekly one, each with `used_percent`,
    /// `window_minutes`, and `resets_at` in Unix seconds.
    static func codex(line: Substring) -> AgentUsage? {
        // Cheap pre-check: most lines are messages and tool output.
        guard line.contains("\"rate_limits\""),
              let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = object["payload"] as? [String: Any],
              let limits = payload["rate_limits"] as? [String: Any] else { return nil }
        // Limits for a specific model come with their own id; the account's
        // general Codex limits are the ones worth showing.
        if let id = limits["limit_id"] as? String, id != "codex" { return nil }

        let session = window(limits["primary"], percentKey: "used_percent", minutesKey: "window_minutes")
        let weekly = window(limits["secondary"], percentKey: "used_percent", minutesKey: "window_minutes")
        guard session != nil || weekly != nil else { return nil }

        let recorded = (object["timestamp"] as? String).flatMap(parseTimestamp) ?? .distantPast
        return AgentUsage(
            session: session,
            weekly: weekly,
            plan: (limits["plan_type"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            recordedAt: recorded
        )
    }

    /// The JSON Claude Code passes to a status line command on stdin.
    ///
    /// `rate_limits` is documented for Pro and Max subscribers and appears only
    /// after the session's first response; either window may be missing.
    static func claudeStatusLine(_ data: Data, now: Date = Date()) -> AgentUsage? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let limits = object["rate_limits"] as? [String: Any] else { return nil }
        var session = window(limits["five_hour"], percentKey: "used_percentage", minutesKey: nil)
        var weekly = window(limits["seven_day"], percentKey: "used_percentage", minutesKey: nil)
        session?.minutes = 5 * 60
        weekly?.minutes = 7 * 24 * 60
        guard session != nil || weekly != nil else { return nil }
        return AgentUsage(session: session, weekly: weekly, plan: nil, recordedAt: now)
    }

    private static func window(_ value: Any?, percentKey: String, minutesKey: String?) -> UsageWindow? {
        guard let dict = value as? [String: Any],
              let percent = (dict[percentKey] as? NSNumber)?.doubleValue else { return nil }
        let reset = (dict["resets_at"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
        let minutes = minutesKey.flatMap { (dict[$0] as? NSNumber)?.intValue }
        return UsageWindow(usedPercent: min(max(percent, 0), 100), resetsAt: reset, minutes: minutes)
    }

    private static func parseTimestamp(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

// MARK: - Sources on disk

enum AgentUsageFiles {
    /// Where the Claude Code status line bridge leaves its snapshot.
    static var claudeSnapshot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VoidBar", isDirectory: true)
            .appendingPathComponent("claude-code-usage.json")
    }

    static var codexSessions: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions", isDirectory: true)
    }

    /// Where the last account refresh is kept, so it survives a relaunch.
    static var claudeAccountSnapshot: URL {
        claudeSnapshot.deletingLastPathComponent().appendingPathComponent("claude-account-usage.json")
    }

    /// The account's numbers once the user has refreshed from it — they are
    /// the source of truth even when older than a status line report, which
    /// can repeat numbers from hours ago with a fresh timestamp. The status
    /// line snapshot is the fallback.
    static func readClaude(account: URL = claudeAccountSnapshot, statusLine: URL = claudeSnapshot) -> AgentUsage? {
        if var usage = read(account) {
            usage.origin = .account
            return usage
        }
        guard var usage = read(statusLine) else { return nil }
        usage.origin = .statusLine
        return usage
    }

    private static func read(_ url: URL) -> AgentUsage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(AgentUsage.self, from: data)
    }

    static func writeClaude(_ usage: AgentUsage, to url: URL = claudeSnapshot) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        try encoder.encode(usage).write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    /// The newest rate-limit snapshot across recent Codex sessions.
    ///
    /// Session logs are sorted into `YYYY/MM/DD` folders and can add up to
    /// gigabytes, so only the last eight days are listed — the longest window
    /// is a week — and only the tail of the few most recently written logs is
    /// read. The snapshot is always near the end of whichever log was active.
    static func readCodex(now: Date = Date(), root: URL = codexSessions) -> AgentUsage? {
        let fm = FileManager.default
        let calendar = Calendar(identifier: .gregorian)
        var logs: [(url: URL, modified: Date)] = []
        for offset in 0..<8 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            guard let year = parts.year, let month = parts.month, let dayOfMonth = parts.day else { continue }
            let folder = root.appendingPathComponent(
                String(format: "%04d/%02d/%02d", year, month, dayOfMonth), isDirectory: true
            )
            guard let names = try? fm.contentsOfDirectory(atPath: folder.path) else { continue }
            for name in names where name.hasPrefix("rollout-") && name.hasSuffix(".jsonl") {
                let url = folder.appendingPathComponent(name)
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                logs.append((url, modified))
            }
        }

        let newest = logs.sorted { $0.modified > $1.modified }.prefix(6)
        return newest
            .compactMap { lastSnapshot(in: $0.url) }
            .max { $0.recordedAt < $1.recordedAt }
    }

    private static func lastSnapshot(in url: URL) -> AgentUsage? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let tailSize: UInt64 = 1 << 20
        guard let size = try? handle.seekToEnd() else { return nil }
        try? handle.seek(toOffset: size > tailSize ? size - tailSize : 0)
        guard let data = try? handle.readToEnd(), let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        for line in text.split(separator: "\n").reversed() {
            if let usage = AgentUsageParser.codex(line: line) { return usage }
        }
        return nil
    }
}

// MARK: - Store

/// Plan limits of Claude Code and Codex, read from files those tools (or the
/// status line bridge) already write. Nothing here touches the network.
@MainActor
final class AgentUsageStore: ObservableObject {
    @Published private(set) var claude: AgentUsage?
    @Published private(set) var codex: AgentUsage?
    /// Whether the first read has finished — so the pane can tell "nothing
    /// yet" from "still looking".
    @Published private(set) var loaded = false
    /// When the files were last read. Published on every read, even when the
    /// numbers did not change, so "updated … ago", reset countdowns, and a
    /// window that has just reset stay current on screen.
    @Published private(set) var checkedAt = Date()
    /// A refresh from the Claude account is in flight.
    @Published private(set) var claudeRefreshing = false
    /// Why the last refresh from the account failed, in words for the card.
    @Published private(set) var claudeError: String?

    private var refreshing = false
    #if DEBUG
    /// Set by `showDemo`: a capture must never pick up the recording
    /// machine's real limits.
    private var showsDemo = false
    #endif

    func refresh() async {
        #if DEBUG
        if showsDemo { return }
        #endif
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        let (claude, codex) = await Task.detached(priority: .utility) {
            (AgentUsageFiles.readClaude(), AgentUsageFiles.readCodex())
        }.value
        if claude != self.claude { self.claude = claude }
        if codex != self.codex { self.codex = codex }
        loaded = true
        checkedAt = Date()
    }

    /// Asks the Claude account for its limits — only ever from the refresh
    /// button. The first time, macOS asks whether VoidBar may read Claude
    /// Code's sign-in from the Keychain.
    func refreshClaudeFromAccount() async {
        #if DEBUG
        if showsDemo { return }
        #endif
        guard !claudeRefreshing else { return }
        claudeRefreshing = true
        defer { claudeRefreshing = false }
        let result: Result<AgentUsage, Error> = await Task.detached(priority: .userInitiated) {
            do { return .success(try await ClaudeAccountUsage.fetch()) } catch { return .failure(error) }
        }.value
        switch result {
        case .success(let usage):
            try? AgentUsageFiles.writeClaude(usage, to: AgentUsageFiles.claudeAccountSnapshot)
            var shown = usage
            shown.origin = .account
            claude = shown
            claudeError = nil
        case .failure(let error):
            claudeError = error.localizedDescription
        }
        checkedAt = Date()
    }

    /// The `statusLine` entry for `~/.claude/settings.json`, pointing at this
    /// copy of VoidBar wherever it is installed.
    static var claudeSetupSnippet: String {
        let executable = Bundle.main.executablePath ?? "/Applications/VoidBar.app/Contents/MacOS/VoidBar"
        let command = "'\(executable)' \(ClaudeStatusBridge.argument)"
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return """
        "statusLine": {
          "type": "command",
          "command": "\(escaped)"
        }
        """
    }

    static func copyClaudeSetup() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(claudeSetupSnippet, forType: .string)
    }
}

#if DEBUG
extension AgentUsageStore {
    /// Capture-only: invented limits. See `DemoCapture`; nothing in a normal
    /// launch reaches this.
    func showDemo(claude: AgentUsage?, codex: AgentUsage?) {
        showsDemo = true
        self.claude = claude
        self.codex = codex
        loaded = true
    }
}
#endif
