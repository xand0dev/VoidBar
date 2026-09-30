import SwiftUI

struct SnippetsPane: View {
    @ObservedObject var snippets: SnippetStore
    /// Whether the panel holds the keyboard, so the fields can follow it.
    @Binding var wantsKeyboard: Bool

    /// Which field has the caret. One state for all three, because only one of
    /// them can be typed into at a time and the pane switches between them.
    private enum Field { case search, label, text }

    @FocusState private var focused: Field?
    @State private var isAdding = false
    @State private var draftLabel = ""
    @State private var draftText = ""

    var body: some View {
        VStack(spacing: 6) {
            if isAdding { editor } else { search }
            list
        }
        .padding(.top, 2)
        .onChange(of: wantsKeyboard) { _, wants in
            guard !wants else {
                focused = isAdding ? .text : .search
                return
            }
            focused = nil
        }
        .animation(Theme.contentAnimation, value: isAdding)
    }

    // MARK: - Search

    private var search: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.tertiary)
            TextField(localized("Search snippets"), text: $snippets.query)
                .textFieldStyle(.plain)
                .font(Theme.body)
                .foregroundStyle(Theme.primary)
                .tint(Theme.secondary)
                .focused($focused, equals: .search)
                .onKeyPress(.escape) {
                    snippets.query = ""
                    return .handled
                }
            if !snippets.query.isEmpty {
                Button { snippets.query = "" } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                }
                .buttonStyle(.plain)
            }
            Button { beginAdding() } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(NotchButtonStyle(size: 22))
            .help(localized("Add a snippet"))
        }
        .padding(.leading, 10)
        .padding(.trailing, 3)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.white.opacity(focused == .search ? 0.22 : 0.08), lineWidth: 0.75)
        )
        .contentShape(Rectangle())
        .onTapGesture { focused = .search }
        // Same reason as the editor: the row asks for the caret once it is
        // actually on screen, so arriving on the tab and coming back from the
        // editor both land the same way.
        .onAppear { if wantsKeyboard { focused = .search } }
    }

    // MARK: - Adding

    /// Takes the place of the search row rather than sitting above it: the pane
    /// is two rows tall in a panel that never resizes, and one of the two is
    /// the list.
    private var editor: some View {
        HStack(spacing: 6) {
            // Each field on its own surface. A hairline between them read as a
            // caret sitting in the wrong place — exactly where one is expected,
            // which is the worst place for something that only looks like one.
            TextField(localized("Name"), text: $draftLabel)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .tint(Theme.secondary)
                .padding(.horizontal, 7)
                .frame(width: 104, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Theme.surface)
                )
                .focused($focused, equals: .label)
                .onSubmit { commit() }

            TextField(localized("Text"), text: $draftText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .tint(Theme.secondary)
                .padding(.horizontal, 7)
                .frame(height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Theme.surface)
                )
                .focused($focused, equals: .text)
                .onSubmit { commit() }

            Button { commit() } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(draftText.isEmpty ? Theme.tertiary : Theme.positive)
            }
            .buttonStyle(.plain)
            .disabled(draftText.isEmpty)

            Button { cancelAdding() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Theme.surfaceHover)
        )
        // Asked for here rather than where the editor is switched on: at that
        // moment this field does not exist yet, and a focus request aimed at a
        // view that is not in the hierarchy is simply dropped. The row would
        // appear with no caret in it, and nothing to type into until clicked.
        //
        // The value is the part that cannot be left out, so the caret starts
        // there; the name is a step back for those who want one.
        .onAppear { focused = .text }
        // Escape leaves the draft rather than the tab. Caught on the row so it
        // works from either field.
        .onKeyPress(.escape) {
            cancelAdding()
            return .handled
        }
    }

    private func beginAdding() {
        draftLabel = ""
        draftText = ""
        // The search field goes away with the row, but the filter behind it
        // would not: a snippet added under a live filter lands in the list and
        // is hidden by it in the same breath, which looks like it was not added
        // at all.
        snippets.query = ""
        isAdding = true
        wantsKeyboard = true
    }

    private func cancelAdding() {
        isAdding = false
        draftLabel = ""
        draftText = ""
    }

    private func commit() {
        guard !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        snippets.add(label: draftLabel, text: draftText)
        // Straight into another one: adding snippets comes in runs, and the
        // list underneath already shows what has landed.
        draftLabel = ""
        draftText = ""
        focused = .text
    }

    // MARK: - List

    @ViewBuilder
    private var list: some View {
        if snippets.filtered.isEmpty {
            EmptyState(
                symbol: snippets.items.isEmpty ? "pin" : "magnifyingglass",
                title: snippets.items.isEmpty && !isAdding ? localized("Nothing here yet — add with +") : localized("No matches")
            )
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 3) {
                    ForEach(snippets.filtered) { item in
                        SnippetRow(item: item, snippets: snippets)
                    }
                }
                .padding(.bottom, 12)
            }
            .fadingBottomEdge()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct SnippetRow: View {
    let item: Snippet
    @ObservedObject var snippets: SnippetStore
    @State private var hovering = false
    @State private var justCopied = false

    var body: some View {
        HStack(spacing: 9) {
            IconChip(symbol: justCopied ? "checkmark" : item.symbol, tint: justCopied ? Theme.positive : .white, size: 20)
            if !item.label.isEmpty {
                Text(item.label)
                    .font(Theme.bodyEmphasis)
                    .foregroundStyle(Theme.primary)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            Text(item.text.replacingOccurrences(of: "\n", with: " "))
                .font(Theme.body)
                .foregroundStyle(item.label.isEmpty ? Theme.primary : Theme.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 6)
            // Only under the pointer: a row of crosses would compete with the
            // snippets themselves for a glance.
            if hovering {
                Button { snippets.remove(item) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                }
                .buttonStyle(.plain)
                .help(localized("Delete"))
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
            snippets.copy(item)
            HapticManager.play(.generic)
            justCopied = true
            // Emptying the search lets go of the panel: nothing is being typed
            // any more, so nothing needs to hold it open.
            snippets.query = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { justCopied = false }
        }
        .animation(Theme.contentAnimation, value: hovering)
        .animation(Theme.contentAnimation, value: justCopied)
    }
}
