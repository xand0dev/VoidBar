import SwiftUI

struct TasksPane: View {
    @ObservedObject var store: TickTickStore

    var body: some View {
        Group {
            if store.isLoading && store.tasks.isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = store.errorMessage {
                EmptyState(symbol: "checklist", title: localized("TickTick is not connected"), message: error)
            } else if store.tasks.isEmpty {
                EmptyState(symbol: "checkmark.circle", title: localized("All done for today!"))
            } else {
                VStack(spacing: 6) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 3) {
                            ForEach(store.tasks) { task in
                                TaskRow(task: task)
                            }
                        }
                        .padding(.vertical, 2)
                        .padding(.bottom, 8)
                    }
                    .fadingBottomEdge(12)
                    footer
                }
            }
        }
        .padding(.top, 2)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.system(size: 9, weight: .semibold))
            Text(verbatim: "TickTick")
                .font(Theme.caption)
            Spacer()
            Button {
                Task { await store.fetchTasks() }
            } label: {
                Label(localized("Refresh"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(PillButtonStyle())
        }
        .foregroundStyle(Theme.tertiary)
    }
}

private struct TaskRow: View {
    let task: TickTickTask
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(task.isCompleted ? Theme.tertiary : tint)
            Text(task.title)
                .font(Theme.bodyEmphasis)
                .foregroundStyle(task.isCompleted ? Theme.tertiary : Theme.primary)
                .strikethrough(task.isCompleted, color: Theme.tertiary)
                .lineLimit(1)
            Spacer(minLength: 6)
            if let date = task.dueDate, !task.isCompleted {
                Text(Self.due(date))
                    .font(Theme.captionEmphasis)
                    .foregroundStyle(isOverdueOrToday(date) ? tint : Theme.secondary)
                    .padding(.horizontal, 7)
                    .frame(height: 18)
                    .background(Capsule().fill(Theme.surface))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(hovering ? Theme.surfaceHover : Theme.surface)
        )
        .onHover { hovering = $0 }
        .animation(Theme.contentAnimation, value: hovering)
    }

    /// TickTick's four priorities: high, medium, low, none.
    private var tint: Color {
        switch task.priority {
        case 5: return Theme.critical
        case 3: return Theme.warning
        case 1: return Theme.accent
        default: return Theme.secondary
        }
    }

    private func isOverdueOrToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date) || date < Date()
    }

    private static func due(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return localized("Today") }
        if calendar.isDateInTomorrow(date) { return localized("tomorrow").sentenceCased }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appLanguage)
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter.string(from: date)
    }
}
