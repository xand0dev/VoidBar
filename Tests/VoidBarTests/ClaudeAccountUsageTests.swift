import XCTest
@testable import VoidBar

final class ClaudeAccountUsageTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_780_000)

    func testReadsBothWindowsWithIsoResetTimes() throws {
        let json = Data("""
        {"five_hour":{"utilization":15.0,"resets_at":"2026-09-30T19:59:00.412+00:00"},
         "seven_day":{"utilization":30,"resets_at":"2026-10-07T01:59:00Z"},
         "seven_day_opus":null}
        """.utf8)
        let usage = try XCTUnwrap(ClaudeAccountUsage.parse(json, now: now))
        XCTAssertEqual(usage.session?.usedPercent, 15)
        XCTAssertEqual(usage.session?.minutes, 300)
        XCTAssertEqual(usage.session?.resetsAt?.timeIntervalSince1970 ?? 0, 1_790_798_340.412, accuracy: 0.01)
        XCTAssertEqual(usage.weekly?.usedPercent, 30)
        XCTAssertEqual(usage.weekly?.resetsAt, ISO8601DateFormatter().date(from: "2026-10-07T01:59:00Z"))
        XCTAssertEqual(usage.recordedAt, now)
    }

    func testAcceptsOtherFieldNamesAndEpochTimes() throws {
        let json = Data(#"{"five_hour":{"used_percentage":42.5,"resets_at":1790798340}}"#.utf8)
        let usage = try XCTUnwrap(ClaudeAccountUsage.parse(json, now: now))
        XCTAssertEqual(usage.session?.usedPercent, 42.5)
        XCTAssertEqual(usage.session?.resetsAt, Date(timeIntervalSince1970: 1_790_798_340))
        XCTAssertNil(usage.weekly)
    }

    func testRejectsAnswersWithoutWindows() {
        XCTAssertNil(ClaudeAccountUsage.parse(Data(#"{"error":"nope"}"#.utf8), now: now))
        XCTAssertNil(ClaudeAccountUsage.parse(Data("not json".utf8), now: now))
        XCTAssertNil(ClaudeAccountUsage.parse(Data(#"{"five_hour":{"resets_at":"x"}}"#.utf8), now: now))
    }

    func testCredentialsCarryExpiryInMillisecondsAndPlan() throws {
        let data = Data(#"{"claudeAiOauth":{"accessToken":"t","expiresAt":1790790000000,"subscriptionType":"max"}}"#.utf8)
        let credentials = try XCTUnwrap(ClaudeAccountUsage.parseCredentials(data))
        XCTAssertEqual(credentials.expiresAt, Date(timeIntervalSince1970: 1_790_790_000))
        XCTAssertEqual(credentials.plan, "max")
        XCTAssertNil(ClaudeAccountUsage.parseCredentials(Data(#"{"claudeAiOauth":{}}"#.utf8)))
    }

    func testAccountNumbersWinOverTheStatusLine() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("voidbar-claude-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let account = folder.appendingPathComponent("account.json")
        let statusLine = folder.appendingPathComponent("status.json")

        let old = AgentUsage(session: nil, weekly: UsageWindow(usedPercent: 11, resetsAt: nil, minutes: 10080), plan: nil, recordedAt: now)
        try AgentUsageFiles.writeClaude(old, to: statusLine)
        XCTAssertEqual(AgentUsageFiles.readClaude(account: account, statusLine: statusLine)?.origin, .statusLine)

        let fresh = AgentUsage(session: UsageWindow(usedPercent: 15, resetsAt: nil, minutes: 300), weekly: nil, plan: "max",
                               recordedAt: now.addingTimeInterval(-600))
        try AgentUsageFiles.writeClaude(fresh, to: account)
        let shown = try XCTUnwrap(AgentUsageFiles.readClaude(account: account, statusLine: statusLine))
        XCTAssertEqual(shown.origin, .account)
        XCTAssertEqual(shown.session?.usedPercent, 15)
    }
}
