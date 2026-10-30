import Foundation
import Observation

/// One shortcut: what sets it off, and what it does.
nonisolated struct Shortcut: Codable, Identifiable, Hashable {
    var id = UUID()
    /// `nil` for a keyboard shortcut whose keys you haven't recorded yet.
    var trigger: Trigger?
    var action: ShortcutAction
    var isEnabled = true

    init(id: UUID = UUID(), trigger: Trigger? = nil, action: ShortcutAction, isEnabled: Bool = true) {
        self.id = id
        self.trigger = trigger
        self.action = action
        self.isEnabled = isEnabled
    }

    init(keyCombo: KeyCombo?, action: ShortcutAction) {
        self.init(trigger: keyCombo.map { .keys(combo: $0) }, action: action)
    }

    /// The keys, for keyboard shortcuts.
    var keyCombo: KeyCombo? {
        get {
            if case .keys(let combo) = trigger { combo } else { nil }
        }
        set {
            trigger = newValue.map { .keys(combo: $0) }
        }
    }

    /// The click, for traffic light actions.
    var trafficLightClick: TrafficLightClick? {
        if case .trafficLight(let click) = trigger { click } else { nil }
    }

    /// The gesture, for gesture actions.
    var gesture: Gesture? {
        if case .gesture(let gesture) = trigger { gesture } else { nil }
    }

    /// The button, for mouse button actions.
    var mouseButtonClick: MouseButtonClick? {
        if case .mouseButton(let click) = trigger { click } else { nil }
    }

    var isKeyboardShortcut: Bool {
        trigger == nil || keyCombo != nil
    }

    // Saved files from before triggers existed have a plain "keyCombo" instead of
    // a "trigger", so read either.
    private enum CodingKeys: String, CodingKey {
        case id, trigger, action, isEnabled, keyCombo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        action = try container.decode(ShortcutAction.self, forKey: .action)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        trigger = try container.decodeIfPresent(Trigger.self, forKey: .trigger)
            ?? container.decodeIfPresent(KeyCombo.self, forKey: .keyCombo).map { .keys(combo: $0) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(trigger, forKey: .trigger)
        try container.encode(action, forKey: .action)
        try container.encode(isEnabled, forKey: .isEnabled)
    }
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
        let folder = URL.applicationSupportDirectory.appending(path: "BestTouchTool", directoryHint: .isDirectory)
        // The app used to be called Glide; bring its folder across the first time.
        let oldFolder = URL.applicationSupportDirectory.appending(path: "Glide", directoryHint: .isDirectory)
        if !FileManager.default.fileExists(atPath: folder.path), FileManager.default.fileExists(atPath: oldFolder.path) {
            try? FileManager.default.moveItem(at: oldFolder, to: folder)
        }
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

    /// Other switched-on shortcuts set off by the same thing.
    func conflicts(with shortcut: Shortcut) -> [Shortcut] {
        guard shortcut.isEnabled, let trigger = shortcut.trigger else { return [] }
        return shortcuts.filter { other in
            other.id != shortcut.id && other.isEnabled && other.trigger.map(trigger.clashes) == true
        }
    }

    func setEnabled(_ isEnabled: Bool, id: Shortcut.ID) {
        if let index = shortcuts.firstIndex(where: { $0.id == id }) {
            shortcuts[index].isEnabled = isEnabled
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
