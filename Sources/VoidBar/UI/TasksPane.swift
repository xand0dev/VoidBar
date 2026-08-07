import SwiftUI

struct TasksPane: View {
    @ObservedObject var store: TickTickStore
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            if store.isLoading && store.tasks.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error = store.errorMessage {
                Spacer()
                Text(error)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.tertiary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else if store.tasks.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.tertiary)
                    Text("All done for today!")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.tertiary)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(store.tasks) { task in
                            taskRow(task)
                        }
                    }
                    .padding(14)
                }
            }
        }
    }
    
    private var header: some View {
        HStack {
            Text("TickTick")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.secondary)
            Spacer()
            Button {
                Task {
                    await store.fetchTasks()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }
    
    private func taskRow(_ task: TickTickTask) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundColor(task.isCompleted ? Theme.secondary : Theme.tertiary)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(task.isCompleted ? Theme.tertiary : .white)
                    .strikethrough(task.isCompleted)
                
                if let date = task.dueDate {
                    Text(date, style: .date)
                        .font(.system(size: 11))
                        .foregroundColor(priorityColor(task.priority))
                }
            }
            Spacer()
        }
    }
    
    private func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 5: return .red
        case 3: return .orange
        case 1: return .blue
        default: return Theme.tertiary
        }
    }
}
