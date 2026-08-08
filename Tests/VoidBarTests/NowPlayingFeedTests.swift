import XCTest
@testable import VoidBar

@MainActor
final class NowPlayingFeedTests: XCTestCase {
    func testProjectedElapsedAdvancesFromPlaybackTimestamp() {
        var snapshot = NowPlayingFeed.Snapshot()
        snapshot.elapsed = 5
        snapshot.rate = 1
        snapshot.timestamp = Date(timeIntervalSince1970: 100)

        XCTAssertEqual(
            snapshot.projectedElapsed(at: Date(timeIntervalSince1970: 130)),
            35,
            accuracy: 0.001
        )
    }

    func testProjectedElapsedDoesNotAdvanceWhilePaused() {
        var snapshot = NowPlayingFeed.Snapshot()
        snapshot.elapsed = 42
        snapshot.rate = 0
        snapshot.timestamp = Date(timeIntervalSince1970: 100)

        XCTAssertEqual(
            snapshot.projectedElapsed(at: Date(timeIntervalSince1970: 130)),
            42,
            accuracy: 0.001
        )
    }

    func testProjectedElapsedIgnoresFutureTimestamp() {
        var snapshot = NowPlayingFeed.Snapshot()
        snapshot.elapsed = 12
        snapshot.rate = 1
        snapshot.timestamp = Date(timeIntervalSince1970: 110)

        XCTAssertEqual(
            snapshot.projectedElapsed(at: Date(timeIntervalSince1970: 100)),
            12,
            accuracy: 0.001
        )
    }
}
