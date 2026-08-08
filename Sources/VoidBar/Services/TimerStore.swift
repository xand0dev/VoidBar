import Foundation
import Combine
import UserNotifications

@MainActor
final class TimerStore: ObservableObject {
    enum State {
        case idle
        case running
        case paused
    }

    @Published var state: State = .idle
    @Published var timeRemaining: TimeInterval = 25 * 60
    @Published var selectedDuration: TimeInterval = 25 * 60
    @Published var completedToday: Int = 0
    
    private var timer: Timer?
    private var lastCompletionDate: Date?

    var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    init() {
        let defaults = UserDefaults.standard
        completedToday = defaults.integer(forKey: "pomodoroCompletedToday")
        if let lastDate = defaults.object(forKey: "pomodoroLastDate") as? Date {
            lastCompletionDate = lastDate
        }
        checkNewDay()
    }

    func start() {
        checkNewDay()
        requestNotificationAccess()
        if state == .idle {
            timeRemaining = selectedDuration
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
        timeRemaining = selectedDuration
    }
    
    func selectDuration(_ duration: TimeInterval) {
        selectedDuration = duration
        if state == .idle {
            timeRemaining = duration
        }
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
        checkNewDay()
        completedToday += 1
        lastCompletionDate = Date()
        
        let defaults = UserDefaults.standard
        defaults.set(completedToday, forKey: "pomodoroCompletedToday")
        defaults.set(lastCompletionDate, forKey: "pomodoroLastDate")
        
        reset()
        deliverCompletionNotification()
    }

    private func requestNotificationAccess() {
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        }
    }

    private func deliverCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Pomodoro Finished"
        content.body = "Time to take a break! You have completed \(completedToday) today."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "voidbar.pomodoro.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
    
    private func checkNewDay() {
        guard let lastDate = lastCompletionDate else { return }
        if !Calendar.current.isDateInToday(lastDate) {
            completedToday = 0
            let defaults = UserDefaults.standard
            defaults.set(0, forKey: "pomodoroCompletedToday")
        }
    }
}
