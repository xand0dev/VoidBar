import SwiftUI

/// Scratch notes: the list on the left, the note itself on the right.
struct NotesPane: View {
    @ObservedObject var notes: NoteStore
    /// Whether the panel holds the keyboard, so the editor can follow it.
    @Binding var wantsKeyboard: Bool

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            list
            editor
        }
        .padding(.top, 2)
        // Arriving means arriving to type. With nothing to select, an empty
        // note is created on the spot: a welcome screen with a button would be
        // slower than the editor window this tab exists to replace.
        .onAppear {
            if notes.notes.isEmpty {
                notes.add()
            } else if notes.selected == nil {
                notes.selected = notes.notes.first?.id
            }
        }
        .onChange(of: wantsKeyboard) { _, wants in focused = wants }
    }

    // MARK: - List

    private var list: some View {
        VStack(spacing: 3) {
            Button {
                notes.add()
                focused = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                    Text("New Note")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Theme.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Theme.surface)
                )
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 3) {
                    ForEach(notes.notes) { note in
                        NoteRow(
                            note: note,
                            isSelected: notes.selected == note.id,
                            select: {
                                notes.selected = note.id
                                focused = true
                            },
                            delete: {
                                notes.remove(note.id)
                                // The tab's invariant: there is always a note
                                // under the caret.
                                if notes.notes.isEmpty { notes.add() }
                            }
                        )
                    }
                }
                .padding(.bottom, 2)
            }
        }
        .frame(width: 170)
    }

    // MARK: - Editor

    private var currentText: String {
        guard let id = notes.selected else { return "" }
        return notes.notes.first(where: { $0.id == id })?.text ?? ""
    }

    private var editorBinding: Binding<String> {
        Binding(
            get: { currentText },
            set: { text in
                guard let id = notes.selected else { return }
                notes.update(id, text: text)
            }
        )
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: editorBinding)
                .textEditorStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .font(.system(size: 12.5))
                .foregroundStyle(.white)
                .tint(Theme.secondary)
                .focused($focused)
                // The editor insets its text by a few points of its own; pull
                // that back so the first character lines up with the padding.
                .padding(.leading, -5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                // One editor for all notes, deliberately NOT remounted per
                // note. A remount (`.id(selected)`) tears the focused view
                // down, and SwiftUI's cleanup for "the focused view
                // disappeared" clears the FocusState at a moment of its own
                // choosing — racing, and regularly beating, every way of
                // re-requesting focus: a plain set, a deferred set, even
                // `defaultFocus`. All three were tried; the new note kept
                // arriving without a caret. With one long-lived editor the
                // text swaps inside a view that never dies, so there is no
                // cleanup and nothing to race. AppKit clamps the caret to the
                // new text's length — for a fresh note that is position zero,
                // exactly where it belongs.
                //
                // A shared undo stack looked like the price of this, but
                // measurement says otherwise: ⌘Z undoes typing fine within a
                // note, and after switching notes the old actions are simply
                // inert — deleted text does not resurface in the neighbour,
                // in either note, on any press. The programmatic text swap
                // leaves the stale actions unable to apply. Verified by
                // driving the real app: type, delete, switch, ⌘Z twice,
                // read the store after each step.
                //
                // Asked in onAppear because on arrival at the tab the request
                // must come from a view that exists (see SnippetsPane).
                .onAppear {
                    DispatchQueue.main.async { focused = wantsKeyboard }
                }
                .onKeyPress(.escape) {
                    // Esc hands the keyboard back, and only that. It never
                    // clears: this pane holds the one kind of text that cannot
                    // be re-derived from anywhere.
                    wantsKeyboard = false
                    return .handled
                }

            if currentText.isEmpty {
                Text("Jot something down…")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.tertiary)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            if !currentText.isEmpty {
                CopyNoteButton(text: currentText)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.surface)
        )
    }
}

private struct NoteRow: View {
    let note: Note
    let isSelected: Bool
    let select: () -> Void
    let delete: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Text(preview)
                .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? .white : Theme.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            if hovering {
                Button(action: delete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.secondary)
                }
                .buttonStyle(.plain)
                .help(localized("Delete"))
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? Theme.surfaceHover : hovering ? Theme.surface : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
        .onHover { hovering = $0 }
        .animation(Theme.contentAnimation, value: hovering)
    }

    /// The first line stands in for a title — notes here are too short-lived
    /// to deserve naming as a separate step.
    private var preview: String {
        let line = note.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines).first ?? ""
        return line.isEmpty ? localized("Empty note") : line
    }
}

private struct CopyNoteButton: View {
    let text: String
    @State private var copied = false

    var body: some View {
        Button {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { copied = false }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(copied ? Color.green : Theme.secondary)
        }
        .buttonStyle(.plain)
        .help(localized("Copy"))
        .animation(Theme.contentAnimation, value: copied)
    }
}
