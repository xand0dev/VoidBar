import AppKit

/// Reads the Now Playing state and turns it into snapshots.
@MainActor
final class NowPlayingFeed {
    struct Snapshot {
        var isPlaying = false
        var title = ""
        var artist = ""
        var album = ""
        var duration: TimeInterval = 0
        var elapsed: TimeInterval = 0
        var rate: Double = 0
        /// Only present on the update where the track changed.
        var artwork: Data?
        /// Name of the app owning the session, resolved from its pid.
        var source: String?

        var isEmpty: Bool { title.isEmpty }
    }

    enum Command: Int {
        case play = 0, pause = 1, togglePlayPause = 2, next = 4, previous = 5
    }

    var onUpdate: ((Snapshot) -> Void)?
    /// Raised when the feed cannot run at all, so the caller can fall back.
    var onUnavailable: (() -> Void)?

    // MARK: - Lifecycle

    func start() {
        // The old media helper has been completely removed for security reasons.
        // We immediately fall back to the safe AppleScript bridge.
        DispatchQueue.main.async { [weak self] in
            self?.onUnavailable?()
        }
    }

    func stop() {}

    // MARK: - Commands

    func refresh() {}
    func send(_ command: Command) {}
    func seek(to seconds: TimeInterval) {}
}
