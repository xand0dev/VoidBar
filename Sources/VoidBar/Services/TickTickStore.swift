import Foundation
import Combine
import SwiftUI

struct TickTickTask: Identifiable, Equatable {
    let id: String
    let title: String
    let isCompleted: Bool
    let dueDate: Date?
    let priority: Int // 0, 1, 3, 5
}

@MainActor
final class TickTickStore: ObservableObject {
    @Published var tasks: [TickTickTask] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // The user's iCal subscription URL from TickTick
    @AppStorage("tickTickCalendarURL") var calendarURLString: String = ""
    
    private var timer: Timer?
    #if DEBUG
    /// Set by `showDemo`: the subscription URL is never fetched.
    fileprivate(set) var showsDemo = false
    #endif
    
    init() {
        // Initial fetch
        if !calendarURLString.isEmpty {
            Task { await fetchTasks() }
        }
        
        // Refresh every 15 minutes
        timer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchTasks()
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func fetchTasks() async {
        #if DEBUG
        if showsDemo { return }
        #endif
        guard let url = URL(string: calendarURLString), !calendarURLString.isEmpty else {
            errorMessage = "Please set your TickTick calendar URL in Settings."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let icalString = String(data: data, encoding: .utf8) else {
                throw URLError(.cannotDecodeRawData)
            }
            
            let parsedTasks = parseICal(icalString)
            self.tasks = parsedTasks.sorted { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) }
        } catch {
            self.errorMessage = "Failed to load tasks: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func parseICal(_ ical: String) -> [TickTickTask] {
        var tasks: [TickTickTask] = []
        let lines = ical.components(separatedBy: .newlines)
        
        var currentId = ""
        var currentTitle = ""
        var isCompleted = false
        var priority = 0
        var inEvent = false
        var dueDate: Date? = nil
        
        // Very basic iCal parser
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if line == "BEGIN:VTODO" || line == "BEGIN:VEVENT" {
                inEvent = true
                currentId = UUID().uuidString // fallback
                currentTitle = "Untitled Task"
                isCompleted = false
                priority = 0
                dueDate = nil
            } else if line == "END:VTODO" || line == "END:VEVENT" {
                if inEvent {
                    tasks.append(TickTickTask(id: currentId, title: currentTitle, isCompleted: isCompleted, dueDate: dueDate, priority: priority))
                }
                inEvent = false
            } else if inEvent {
                if line.hasPrefix("UID:") {
                    currentId = String(line.dropFirst(4))
                } else if line.hasPrefix("SUMMARY:") {
                    currentTitle = String(line.dropFirst(8))
                } else if line.hasPrefix("STATUS:COMPLETED") {
                    isCompleted = true
                } else if line.hasPrefix("PRIORITY:") {
                    priority = Int(line.dropFirst(9)) ?? 0
                }
            }
        }
        
        return tasks
    }
}

#if DEBUG
extension TickTickStore {
    /// Capture-only: invented tasks. See `DemoCapture`.
    func showDemo(_ demo: [TickTickTask]) {
        showsDemo = true
        tasks = demo
        isLoading = false
        errorMessage = nil
    }
}
#endif
