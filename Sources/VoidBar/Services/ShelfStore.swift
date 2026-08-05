import AppKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

extension NSPasteboard.PasteboardType {
    /// Marker VoidBar puts on pasteboard writes of its own.
    static let voidbarInternal = NSPasteboard.PasteboardType("com.voidbar.internal")
}

struct ShelfItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    /// Starts as the file-type icon and is replaced by a real preview once
    /// QuickLook renders one — a shelf of identical PNG icons is useless when
    /// what it holds is screenshots.
    var icon: NSImage
    var name: String { url.lastPathComponent }

    static func == (lhs: ShelfItem, rhs: ShelfItem) -> Bool { lhs.url == rhs.url }
}

/// Drop zone contents. Files are referenced, never copied — the shelf is a
/// holding area, so moving the original away simply removes it from the shelf.
@MainActor
final class ShelfStore: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []
    /// Cards picked for a group drag. Empty means "drag whatever is grabbed".
    @Published private(set) var selection: Set<UUID> = []

    private let defaultsKey = "shelf.urls"
    /// Generous, because saved screenshots accumulate here and nothing is
    /// deleted behind the user's back. Cards past the limit leave the shelf,
    /// but their files stay in the folder.
    private let limit = 60

    func load() {
        let paths = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        items = paths
            .map(URL.init(fileURLWithPath:))
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .map { ShelfItem(url: $0, icon: NSWorkspace.shared.icon(forFile: $0.path)) }
        items.forEach(loadThumbnail)
    }

    func add(_ urls: [URL]) {
        for url in urls where !items.contains(where: { $0.url == url }) {
            let item = ShelfItem(url: url, icon: NSWorkspace.shared.icon(forFile: url.path))
            items.insert(item, at: 0)
            loadThumbnail(item)
        }
        if items.count > limit { items.removeLast(items.count - limit) }
        persist()
    }

    private func loadThumbnail(_ item: ShelfItem) {
        // A square box QuickLook fits the content into, whatever its shape.
        // Generous enough that a landscape screenshot still lands above the
        // card's pixel size once it has been fitted.
        let request = QLThumbnailGenerator.Request(
            fileAt: item.url,
            size: CGSize(width: 96, height: 96),
            scale: 2,
            representationTypes: .thumbnail
        )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] rep, _ in
            guard let rep else { return }
            // `nsImage` already carries the right point size for the
            // representation; deriving one from `contentRect` risks describing
            // a shape the bitmap does not have.
            let image = rep.nsImage
            Task { @MainActor in
                guard let self, let index = self.items.firstIndex(where: { $0.url == item.url }) else { return }
                self.items[index].icon = image
            }
        }
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        selection.remove(item.id)
        persist()
    }

    func clear() {
        items.removeAll()
        selection.removeAll()
        persist()
    }

    // MARK: - Selection

    /// Plain click replaces the selection; ⌘ or ⇧ adds to it, matching Finder.
    func select(_ item: ShelfItem, modifiers: NSEvent.ModifierFlags) {
        if modifiers.contains(.command) || modifiers.contains(.shift) {
            if selection.contains(item.id) {
                selection.remove(item.id)
            } else {
                selection.insert(item.id)
            }
        } else if selection == [item.id] {
            selection.removeAll()
        } else {
            selection = [item.id]
        }
    }

    func isSelected(_ item: ShelfItem) -> Bool { selection.contains(item.id) }

    func clearSelection() { selection.removeAll() }

    /// Files a drag started on `item` should carry: the whole selection when
    /// the grabbed card belongs to it, otherwise just that card.
    func dragURLs(startingAt item: ShelfItem) -> [URL] {
        guard selection.contains(item.id) else { return [item.url] }
        return items.filter { selection.contains($0.id) }.map(\.url)
    }

    func reveal(_ item: ShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    /// Puts the card back on the pasteboard. Images go as image data as well as
    /// a file reference, so pasting works both in Finder and in an editor.
    func copy(_ item: ShelfItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        // Tells ClipboardStore this change came from us, so a copied screenshot
        // is not saved to disk a second time.
        pasteboard.setData(Data(), forType: .voidbarInternal)
        pasteboard.writeObjects([item.url as NSURL])
        if let type = UTType(filenameExtension: item.url.pathExtension),
           type.conforms(to: .image),
           let data = try? Data(contentsOf: item.url) {
            pasteboard.setData(data, forType: type == .png ? .png : .tiff)
        }
    }

    func open(_ item: ShelfItem) {
        NSWorkspace.shared.open(item.url)
    }

    private func persist() {
        UserDefaults.standard.set(items.map(\.url.path), forKey: defaultsKey)
    }
}
