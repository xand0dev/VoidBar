import AppKit

struct Snippet: Identifiable, Codable, Equatable {
    var id: String { label.isEmpty ? text : label }
    /// Optional name. Without one the row shows the value itself, which is
    /// usually enough for an address or a phone number.
    var label: String = ""
    var text: String

    /// Guessed from the value, so a row is recognisable before it is read.
    var symbol: String {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.contains("@"), !value.contains(" ") { return "at" }
        if value.hasPrefix("http://") || value.hasPrefix("https://") { return "link" }
        let digits = value.filter(\.isNumber).count
        if digits >= 7, value.allSatisfy({ $0.isNumber || " +-()".contains($0) }) { return "phone.fill" }
        return "text.alignleft"
    }

    /// An unnamed snippet is written without the key rather than with an empty
    /// one: the file is documented as taking `label` or leaving it out, and
    /// what the app writes should look like what it asks people to write.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !label.isEmpty { try container.encode(label, forKey: .label) }
        try container.encode(text, forKey: .text)
    }
}

/// A hand-kept list of things worth not retyping.
///
/// Deliberately not fed by the clipboard: the clipboard is a queue ordered by
/// recency, which loses exactly the entry used once a month, and anything
/// automatic would fill this with whatever happened to pass through. What
/// belongs here is decided by hand — from the panel or in the file, whichever
/// is closer at the time. Both edit the same list.
@MainActor
final class SnippetStore: ObservableObject {
    @Published private(set) var items: [Snippet] = []
    @Published var query = ""

    /// Matches the name and the value alike: one remembers an address either by
    /// what it is called or by what is in it, rarely reliably by both.
    var filtered: [Snippet] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return items }
        return items.filter { $0.label.matches(needle) || $0.text.matches(needle) }
    }

    /// `~/Library/Application Support/VoidBar/snippets.json`. A plain array of
    /// `{"label": "...", "text": "..."}`, where `label` may be left out.
    // F-07 FIX: Use VoidBar directory.
    static let file: URL = {
        let fm = FileManager.default
        let folder = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VoidBar", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileURL = folder.appendingPathComponent("snippets.json")
        return fileURL
    }()
    
    // F-07 FIX: Enforce 0600 file permissions on persist.
    static func enforcePermissions() {
        let attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o600]
        try? FileManager.default.setAttributes(attributes, ofItemAtPath: file.path)
    }

    /// Re-read on every visit to the tab. The file is edited from outside the
    /// app, so the only sensible moment to trust what is in memory is the
    /// moment before it is shown.
    func reload() {
        guard let data = try? Data(contentsOf: Self.file) else {
            items = []
            return
        }
        do {
            items = try JSONDecoder().decode([Snippet].self, from: data)
        } catch {
            NSLog("VoidBar: snippets.json is not readable: \(error.localizedDescription)")
        }
    }

    /// Adds one and writes the file.
    ///
    /// Re-reads first, because the file is also edited by hand and the copy in
    /// memory is only as fresh as the last visit to the tab. Writing over it
    /// blind would silently undo whatever was added in an editor meanwhile.
    func add(label: String, text: String) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        let snippet = Snippet(label: label.trimmingCharacters(in: .whitespacesAndNewlines), text: value)
        reload()
        // Identity is the name, or the value when there is no name. Two rows
        // sharing one identity is not a duplicate to tidy up later — SwiftUI
        // lists them by it, so the newer simply replaces the older.
        items.removeAll { $0.id == snippet.id }
        items.insert(snippet, at: 0)
        persist()
    }

    func remove(_ snippet: Snippet) {
        items.removeAll { $0.id == snippet.id }
        persist()
    }

    /// Pretty-printed, and slashes left alone: the file is meant to be opened
    /// and edited by hand, and `\/` in every URL would be the app making that
    /// harder for its own convenience.
    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        do {
            try encoder.encode(items).write(to: Self.file, options: .atomic)
            Self.enforcePermissions()
        } catch {
            NSLog("VoidBar: cannot write snippets.json: \(error.localizedDescription)")
        }
    }

    /// Puts a snippet on the pasteboard, ready to paste.
    ///
    /// The pasteboard is the only way to hand text to another app without
    /// asking for Accessibility, which this app is built not to do. Whatever
    /// was there is overwritten, and stays available in the clipboard tab.
    func copy(_ snippet: Snippet) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(snippet.text, forType: .string)
    }

    static func reveal() {
        NSWorkspace.shared.activateFileViewerSelecting([file])
    }
}

private extension String {
    /// Case- and accent-blind, so "почта" finds "Почта" and "Nagy" finds "Nagy".
    func matches(_ needle: String) -> Bool {
        range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
