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
        // To be implemented in next commit
        return []
    }
}
