import XCTest
@testable import VoidBar

final class AgentUsageTests: XCTestCase {
    private let codexLine: Substring = """
    {"timestamp":"2026-09-29T10:15:30.250Z","type":"event_msg","payload":{"type":"token_count",\
    "info":null,"rate_limits":{"limit_id":"codex","limit_name":null,\
    "primary":{"used_percent":42.0,"window_minutes":300,"resets_at":1790700000},\
    "secondary":{"used_percent":61.5,"window_minutes":10080,"resets_at":1791000000},\
    "credits":null,"plan_type":"plus"}}}
    """

    func testCodexTokenCountEventCarriesBothWindows() throws {
        let usage = try XCTUnwrap(AgentUsageParser.codex(line: codexLine))
        XCTAssertEqual(usage.session?.usedPercent, 42)
        XCTAssertEqual(usage.session?.minutes, 300)
        XCTAssertEqual(usage.session?.resetsAt, Date(timeIntervalSince1970: 1_790_700_000))
        XCTAssertEqual(usage.weekly?.usedPercent, 61.5)
        XCTAssertEqual(usage.weekly?.minutes, 10080)
        XCTAssertEqual(usage.plan, "plus")
        XCTAssertEqual(usage.recordedAt.timeIntervalSince1970, 1_790_676_930.25, accuracy: 0.01)
    }

    func testCodexIgnoresOtherLinesAndModelSpecificLimits() {
        XCTAssertNil(AgentUsageParser.codex(line: #"{"type":"response_item","payload":{"type":"message"}}"#))
        XCTAssertNil(AgentUsageParser.codex(line: #"{"payload":{"type":"token_count","rate_limits":null}}"#))
        let other = codexLine.replacingOccurrences(of: #""limit_id":"codex""#, with: #""limit_id":"gpt-x""#)
        XCTAssertNil(AgentUsageParser.codex(line: Substring(other)))
    }

    func testCodexReadsNewestSnapshotFromSessionFolders() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("voidbar-codex-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let now = Date(timeIntervalSince1970: 1_790_677_000)
        let calendar = Calendar(identifier: .gregorian)
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        let folder = root.appendingPathComponent(
            String(format: "%04d/%02d/%02d", parts.year!, parts.month!, parts.day!), isDirectory: true
        )
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let older = codexLine.replacingOccurrences(of: "42.0", with: "10.0")
            .replacingOccurrences(of: "10:15:30", with: "09:00:00")
        let log = [#"{"type":"session_meta"}"#, older, String(codexLine), #"{"type":"response_item"}"#]
            .joined(separator: "\n")
        try log.write(to: folder.appendingPathComponent("rollout-test.jsonl"), atomically: true, encoding: .utf8)

        let usage = try XCTUnwrap(AgentUsageFiles.readCodex(now: now, root: root))
        XCTAssertEqual(usage.session?.usedPercent, 42)
    }

    func testClaudeStatusLineRateLimits() throws {
        let json = Data("""
        {"model":{"display_name":"Opus"},"rate_limits":{
          "five_hour":{"used_percentage":23.5,"resets_at":1738425600},
          "seven_day":{"used_percentage":41.2,"resets_at":1738857600}}}
        """.utf8)
        let now = Date(timeIntervalSince1970: 1_738_400_000)
        let usage = try XCTUnwrap(AgentUsageParser.claudeStatusLine(json, now: now))
        XCTAssertEqual(usage.session?.usedPercent, 23.5)
        XCTAssertEqual(usage.session?.minutes, 300)
        XCTAssertEqual(usage.weekly?.resetsAt, Date(timeIntervalSince1970: 1_738_857_600))
        XCTAssertEqual(usage.recordedAt, now)
        XCTAssertEqual(ClaudeStatusBridge.line(for: json, usage: usage), "Opus · 5h 24% · 7d 41%")
    }

    func testClaudeStatusLineWithoutLimitsKeepsNothing() {
        let json = Data(#"{"model":{"display_name":"Sonnet"}}"#.utf8)
        XCTAssertNil(AgentUsageParser.claudeStatusLine(json))
        XCTAssertEqual(ClaudeStatusBridge.line(for: json, usage: nil), "Sonnet")
    }

    func testPassedResetClearsTheOldFigure() {
        let window = UsageWindow(usedPercent: 97, resetsAt: Date(timeIntervalSince1970: 100), minutes: 300)
        XCTAssertEqual(window.current(at: Date(timeIntervalSince1970: 50)).usedPercent, 97)
        XCTAssertEqual(window.current(at: Date(timeIntervalSince1970: 100)).usedPercent, 0)
        XCTAssertTrue(window.hasReset(at: Date(timeIntervalSince1970: 150)))
    }

    @MainActor
    func testSetupSnippetPointsAtTheBridge() throws {
        let snippet = AgentUsageStore.claudeSetupSnippet
        XCTAssertTrue(snippet.contains(#""type": "command""#))
        XCTAssertTrue(snippet.contains(ClaudeStatusBridge.argument))
        // The snippet must be valid JSON once wrapped in braces.
        let data = Data("{\(snippet)}".utf8)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testSnapshotRoundTrips() throws {
        let usage = AgentUsage(
            session: UsageWindow(usedPercent: 12, resetsAt: Date(timeIntervalSince1970: 1_000), minutes: 300),
            weekly: nil,
            plan: nil,
            recordedAt: Date(timeIntervalSince1970: 900)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        XCTAssertEqual(try decoder.decode(AgentUsage.self, from: encoder.encode(usage)), usage)
    }

    @MainActor
    func testEveryReadMovesTheClockEvenWithoutNewNumbers() async throws {
        let store = AgentUsageStore()
        await store.refresh()
        let first = store.checkedAt
        try await Task.sleep(for: .milliseconds(20))
        await store.refresh()
        XCTAssertGreaterThan(store.checkedAt, first)
    }
}
