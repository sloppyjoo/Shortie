import Foundation
import Observation

/// One keyboard shortcut: which keys, and what they do.
nonisolated struct Shortcut: Codable, Identifiable, Hashable {
    var id = UUID()
    /// `nil` until you've recorded the keys.
    var keyCombo: KeyCombo?
    var action: ShortcutAction
    var isEnabled = true
}

/// All your shortcuts, saved to a plain, readable JSON file:
/// `~/Library/Application Support/Glide/shortcuts.json`
@Observable
final class ShortcutStore {
    static let shared = ShortcutStore()

    var shortcuts: [Shortcut] = [] {
        didSet { save() }
    }

    let fileURL: URL

    private init() {
        let folder = URL.applicationSupportDirectory.appending(path: "Glide", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appending(path: "shortcuts.json")

        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            shortcuts = try JSONDecoder().decode([Shortcut].self, from: data)
        } catch {
            // If the file was hand-edited into something we can't read, keep a copy
            // rather than overwriting it the next time something changes.
            let backup = folder.appending(path: "shortcuts (unreadable).json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: fileURL, to: backup)
        }
    }

    func update(_ shortcut: Shortcut) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index] = shortcut
        }
    }

    func delete(id: Shortcut.ID) {
        shortcuts.removeAll { $0.id == id }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(shortcuts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
