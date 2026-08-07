import Foundation
import Combine
import AppKit

@MainActor
final class TimerStore: ObservableObject {
    enum State {
        case idle
        case running
        case paused
    }

    @Published var state: State = .idle
    @Published var timeRemaining: TimeInterval = 25 * 60
    
    let defaultDuration: TimeInterval = 25 * 60
    private var timer: Timer?

    var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func start() {
        if state == .idle {
            timeRemaining = defaultDuration
        }
        state = .running
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func pause() {
        state = .paused
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        state = .idle
        timer?.invalidate()
        timer = nil
        timeRemaining = defaultDuration
    }

    private func tick() {
        guard state == .running else { return }
        if timeRemaining > 0 {
            timeRemaining -= 1
        } else {
            finish()
        }
    }

    private func finish() {
        reset()
        let notification = NSUserNotification()
        notification.title = "Pomodoro Finished"
        notification.informativeText = "Time to take a break!"
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliverNotification(notification)
        HapticManager.play(.generic)
    }
}
