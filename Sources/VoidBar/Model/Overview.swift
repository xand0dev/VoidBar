import Foundation

/// A widget the Overview can show. Each one belongs to a tab: it only appears
/// while that tab is switched on, so turning off Weather also takes the
/// weather off the Overview.
enum OverviewWidget: String, CaseIterable, Codable, Identifiable {
    case nowPlaying, sound, limits, clipboard, focus, notes, snippets, shelf, tasks, calendar, weather, monitor

    var id: String { rawValue }

    var tab: NotchViewModel.Tab {
        switch self {
        case .nowPlaying: return .media
        case .sound: return .sound
        case .limits: return .usage
        case .clipboard: return .clipboard
        case .focus: return .timer
        case .notes: return .notes
        case .snippets: return .snippets
        case .shelf: return .shelf
        case .tasks: return .tasks
        case .calendar: return .calendar
        case .weather: return .weather
        case .monitor: return .monitor
        }
    }

    var title: String {
        switch self {
        case .nowPlaying: return localized("Now playing")
        case .sound: return localized("Sound")
        case .limits: return localized("AI limits")
        case .clipboard: return localized("Clipboard")
        case .focus: return localized("Focus")
        case .notes: return localized("Latest note")
        case .snippets: return localized("Snippets")
        case .shelf: return localized("Shelf")
        case .tasks: return localized("Tasks")
        case .calendar: return localized("Next meeting")
        case .weather: return localized("Weather")
        case .monitor: return localized("Monitor")
        }
    }

    var symbol: String { tab.symbol }
}

/// Which widgets the Overview shows, and how it lays them out.
enum OverviewLayout {
    struct Plan: Equatable {
        /// The large card on the left — only ever the player, and only while
        /// something is playing.
        var hero: OverviewWidget?
        /// Small cards in reading order: a 2×2 grid beside the hero, or 3×2
        /// without one.
        var tiles: [OverviewWidget]

        var isEmpty: Bool { hero == nil && tiles.isEmpty }
    }

    /// The user's order, minus widgets that are switched off, whose tab is
    /// off, or that have nothing to show right now.
    static func plan(
        order: [TabManager.WidgetConfig],
        activeTabs: [NotchViewModel.Tab],
        hasContent: (OverviewWidget) -> Bool
    ) -> Plan {
        let active = Set(activeTabs)
        let shown = order
            .filter { $0.isEnabled && active.contains($0.id.tab) && hasContent($0.id) }
            .map(\.id)
        if shown.contains(.nowPlaying) {
            return Plan(hero: .nowPlaying, tiles: Array(shown.filter { $0 != .nowPlaying }.prefix(4)))
        }
        return Plan(hero: nil, tiles: Array(shown.prefix(6)))
    }
}
