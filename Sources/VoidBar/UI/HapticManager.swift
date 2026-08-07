import AppKit

enum HapticManager {
    static func play(_ pattern: NSHapticFeedbackManager.FeedbackPattern = .generic, performanceTime: NSHapticFeedbackManager.PerformanceTime = .default) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: performanceTime)
    }
}
