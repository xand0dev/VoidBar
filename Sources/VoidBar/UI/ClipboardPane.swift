import SwiftUI

struct ClipboardPane: View {
    @ObservedObject var clipboard: ClipboardStore

    var body: some View {
        VStack(spacing: 0) {
            if clipboard.items.isEmpty {
                EmptyState(symbol: "list.clipboard", title: localized("Copied items appear here"))
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(clipboard.items) { item in
                            ClipRow(item: item, clipboard: clipboard)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.bottom, 10)
                }
                .fadingBottomEdge()
                footer
            }
        }
        .padding(.top, 2)
    }

    private var footer: some View {
        HStack {
            Text(localized("Kept in memory only"))
                .font(Theme.caption)
                .foregroundStyle(Theme.tertiary)
            Spacer()
            Button(localized("Clear")) { clipboard.clear() }
                .buttonStyle(PillButtonStyle())
        }
        .padding(.top, 4)
    }
}

private struct ClipRow: View {
    let item: ClipItem
    @ObservedObject var clipboard: ClipboardStore
    @State private var hovering = false
    @State private var justCopied = false


    var body: some View {
        HStack(spacing: 9) {
            IconChip(symbol: justCopied ? "checkmark" : item.symbol, tint: justCopied ? Theme.positive : tint, size: 20)
            Text(item.preview.replacingOccurrences(of: "\n", with: " "))
                .font(Theme.body)
                .foregroundStyle(Theme.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 6)
            if !hovering {
                Text(shortAge(since: item.date))
                    .font(Theme.caption)
                    .foregroundStyle(Theme.tertiary)
            }
            if hovering {
                Button { clipboard.remove(item) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 5)
        .padding(.trailing, 10)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(hovering ? Theme.surfaceHover : Theme.surface)
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture {
            clipboard.copy(item)
            justCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { justCopied = false }
        }
        .animation(Theme.contentAnimation, value: hovering)
        .animation(Theme.contentAnimation, value: justCopied)
    }

    /// Links in the accent, files in green, plain text neutral.
    private var tint: Color {
        switch item.symbol {
        case "link": return Theme.accent
        case "doc": return Theme.positive
        default: return .white
        }
    }
}
