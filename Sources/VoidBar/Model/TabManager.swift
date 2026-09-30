import SwiftUI
import Combine

@MainActor
final class TabManager: ObservableObject {
    struct TabConfig: Codable, Identifiable, Equatable {
        var id: NotchViewModel.Tab
        var isEnabled: Bool
    }
    
    @Published var configs: [TabConfig] = [] {
        didSet {
            save()
        }
    }
    
    private let key = "voidbar.tabs.config"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
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
