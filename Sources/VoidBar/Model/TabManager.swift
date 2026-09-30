import SwiftUI
import Combine

@MainActor
final class TabManager: ObservableObject {
    struct TabConfig: Codable, Identifiable, Equatable {
        var id: NotchViewModel.Tab
        var isEnabled: Bool
    }

    struct WidgetConfig: Codable, Identifiable, Equatable {
        var id: OverviewWidget
        var isEnabled: Bool
    }
    
    @Published var configs: [TabConfig] = [] {
        didSet {
            save()
        }
    }
    
    /// The Overview's widgets, in the order they fill its grid.
    @Published var widgets: [WidgetConfig] = [] {
        didSet { saveWidgets() }
    }

    private let key = "voidbar.tabs.config"
    private let widgetsKey = "voidbar.overview.widgets"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        loadWidgets()
    }

    /// All on by default: a widget still only shows while its tab is on and
    /// it has something to say, so the tab list already does the choosing.
    private func loadWidgets() {
        var merged: [WidgetConfig] = []
        if let data = defaults.data(forKey: widgetsKey),
           let saved = try? JSONDecoder().decode([WidgetConfig].self, from: data) {
            merged = saved
        }
        let known = Set(merged.map(\.id))
        for widget in OverviewWidget.allCases where !known.contains(widget) {
            merged.append(WidgetConfig(id: widget, isEnabled: true))
        }
        widgets = merged
    }

    private func saveWidgets() {
        if let data = try? JSONEncoder().encode(widgets) {
            defaults.set(data, forKey: widgetsKey)
        }
    }
    
    private func load() {
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([TabConfig].self, from: data) {
            var merged = saved
            let savedIds = Set(saved.map { $0.id })
            for tab in NotchViewModel.Tab.allCases where !savedIds.contains(tab) {
                // The overview leads the rail; other new tabs join at the end.
                let config = TabConfig(id: tab, isEnabled: tab.enabledByDefault)
                if tab == .home {
                    merged.insert(config, at: 0)
                } else {
                    merged.append(config)
                }
            }
            // Remove any tabs that no longer exist (if they were removed from the enum, though decoding would fail anyway)
            self.configs = merged
        } else {
            // Default configuration
            self.configs = NotchViewModel.Tab.allCases.map { 
                TabConfig(id: $0, isEnabled: $0.enabledByDefault)
            }
        }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(configs) {
            defaults.set(data, forKey: key)
        }
    }
    
    var activeTabs: [NotchViewModel.Tab] {
        configs.filter { $0.isEnabled }.map { $0.id }
    }
    
    var leftRail: [NotchViewModel.Tab] {
        let active = activeTabs
        if active.isEmpty { return [] }
        let mid = Int(ceil(Double(active.count) / 2.0))
        return Array(active.prefix(mid))
    }
    
    var rightRail: [NotchViewModel.Tab] {
        let active = activeTabs
        if active.count <= 1 { return [] }
        let mid = Int(ceil(Double(active.count) / 2.0))
        return Array(active.suffix(from: mid))
    }
}
