import AppKit
import Observation

/// One shortcut: what sets it off, and what it does.
nonisolated struct Shortcut: Codable, Identifiable, Hashable {
    var id = UUID()
    /// `nil` for a keyboard shortcut whose keys you haven't recorded yet.
    var trigger: Trigger?
    var action: ShortcutAction
    var isEnabled = true
    /// Which apps it works in; `nil` means everywhere.
    var apps: AppScope?

    init(id: UUID = UUID(), trigger: Trigger? = nil, action: ShortcutAction, isEnabled: Bool = true, apps: AppScope? = nil) {
        self.id = id
        self.trigger = trigger
        self.action = action
        self.isEnabled = isEnabled
        self.apps = apps
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
        case id, trigger, action, isEnabled, apps, keyCombo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        action = try container.decode(ShortcutAction.self, forKey: .action)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        apps = try container.decodeIfPresent(AppScope.self, forKey: .apps)
        trigger = try container.decodeIfPresent(Trigger.self, forKey: .trigger)
            ?? container.decodeIfPresent(KeyCombo.self, forKey: .keyCombo).map { .keys(combo: $0) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(trigger, forKey: .trigger)
        try container.encode(action, forKey: .action)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encodeIfPresent(apps, forKey: .apps)
    }
}

/// Limits a shortcut to some apps, or to every app but some.
nonisolated struct AppScope: Codable, Hashable {
    enum Mode: String, Codable {
        /// Only in these apps.
        case only
        /// Everywhere except these apps.
        case except
    }

    var mode: Mode
    /// The apps, by their permanent IDs (like "com.apple.Safari").
    var bundleIDs: [String]

    func includes(_ bundleID: String?) -> Bool {
        let listed = bundleID.map(bundleIDs.contains) ?? false
        return mode == .only ? listed : !listed
    }

    /// "Only in" with no apps chosen would never work.
    var isValid: Bool {
        mode == .except || !bundleIDs.isEmpty
    }
}

/// The app you're using right now.
enum FrontmostApp {
    static var bundleID: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
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

    /// The shortcut to run for this trigger in this app, if any.
    ///
    /// A shortcut set to work only in certain apps wins over one that works
    /// everywhere, so you can make the same gesture or keys do something
    /// different in just one app.
    func match(_ trigger: Trigger, in app: String?) -> Shortcut? {
        let candidates = shortcuts.filter {
            $0.isEnabled && $0.trigger?.clashes(with: trigger) == true && ($0.apps?.includes(app) ?? true)
        }
        return candidates.first { $0.apps?.mode == .only } ?? candidates.first
    }

    /// Other switched-on shortcuts set off by the same thing in the same apps.
    func conflicts(with shortcut: Shortcut) -> [Shortcut] {
        guard shortcut.isEnabled, let trigger = shortcut.trigger else { return [] }
        return shortcuts.filter { other in
            other.id != shortcut.id && other.isEnabled && other.trigger.map(trigger.clashes) == true
                && Self.scopesOverlap(shortcut.apps, other.apps)
        }
    }

    /// Whether two shortcuts with the same trigger could both want to run in
    /// some app. An app-specific shortcut alongside an everywhere one isn't a
    /// clash: the app-specific one simply takes over in its apps.
    private static func scopesOverlap(_ a: AppScope?, _ b: AppScope?) -> Bool {
        let aApps = a?.mode == .only ? Set(a?.bundleIDs ?? []) : nil
        let bApps = b?.mode == .only ? Set(b?.bundleIDs ?? []) : nil
        switch (aApps, bApps) {
        case (nil, nil): return true
        case let (x?, y?): return !x.isDisjoint(with: y)
        default: return false
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
