import AppKit
import ApplicationServices
import Observation

/// A named arrangement of windows, like "Coding": the editor on the left, the
/// browser on the right. Restoring it glides every window back into place.
nonisolated struct WindowLayout: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var windows: [SavedWindow]
    var savedAt = Date()

    /// How many different apps the layout arranges.
    var appCount: Int { Set(windows.map(\.bundleID)).count }
}

/// One window in a layout. The frame is in Accessibility (top-left) coordinates.
nonisolated struct SavedWindow: Codable, Hashable {
    var bundleID: String
    var appName: String
    var title: String
    var frame: CGRect
}

/// Your window layouts, saved to `layouts.json` next to your shortcuts.
@Observable
final class WindowLayoutStore {
    static let shared = WindowLayoutStore()

    var layouts: [WindowLayout] = [] {
        didSet {
            // Loading the file at startup isn't a change worth saving.
            guard isLoaded else { return }
            save()
        }
    }

    @ObservationIgnored private var isLoaded = false

    @ObservationIgnored private let fileURL = AppFolder.url
        .appending(path: "layouts.json")

    private init() {
        defer { isLoaded = true }
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([WindowLayout].self, from: data) {
            layouts = saved
        }
    }

    func layout(id: UUID?) -> WindowLayout? {
        layouts.first { $0.id == id }
    }

    /// Records where your windows are now, as a new layout.
    @discardableResult
    func saveCurrent(named name: String) -> WindowLayout {
        let layout = WindowLayout(name: name, windows: WindowLayouts.currentWindows())
        layouts.append(layout)
        return layout
    }

    /// Replaces a layout's windows with where your windows are now.
    func updateToCurrent(id: UUID) {
        guard let index = layouts.firstIndex(where: { $0.id == id }) else { return }
        layouts[index].windows = WindowLayouts.currentWindows()
        layouts[index].savedAt = Date()
    }

    func rename(id: UUID, to name: String) {
        guard let index = layouts.firstIndex(where: { $0.id == id }) else { return }
        layouts[index].name = name
        // Shortcuts that restore this layout show its name, so keep that up to date.
        let store = ShortcutStore.shared
        for (shortcutIndex, shortcut) in store.shortcuts.enumerated() {
            if case .restoreLayout(id, let oldName) = shortcut.action, oldName != name {
                store.shortcuts[shortcutIndex].action = .restoreLayout(id: id, name: name)
            }
        }
    }

    func delete(id: UUID) {
        layouts.removeAll { $0.id == id }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(layouts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

/// Reads where windows are, and puts them back.
enum WindowLayouts {
    /// Every ordinary window you can see right now: not minimised, not in a
    /// hidden app, not full screen, and not Shortie's own.
    static func currentWindows() -> [SavedWindow] {
        let ownID = ProcessInfo.processInfo.processIdentifier
        var windows: [SavedWindow] = []
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && !app.isHidden && app.processIdentifier != ownID {
            guard let bundleID = app.bundleIdentifier else { continue }
            for window in AX.windows(of: app.processIdentifier) where isArrangeable(window) {
                guard let frame = WindowMover.shared.frame(of: window) else { continue }
                windows.append(SavedWindow(
                    bundleID: bundleID,
                    appName: app.localizedName ?? bundleID,
                    title: AX.string(window, kAXTitleAttribute) ?? "",
                    frame: frame
                ))
            }
        }
        return windows
    }

    /// Puts each window in the layout back where it was. Apps that aren't
    /// open are skipped.
    static func restore(_ layoutID: UUID?) {
        guard let layout = WindowLayoutStore.shared.layout(id: layoutID) else {
            NSSound.beep()
            return
        }

        // Skip windows that were on a display that isn't connected any more.
        let screens = NSScreen.screens.map { WindowMover.flipped($0.frame) }
        let saved = layout.windows.filter { window in screens.contains { $0.intersects(window.frame) } }

        var moves: [(window: AXUIElement, to: CGRect)] = []
        for (bundleID, savedWindows) in Dictionary(grouping: saved, by: \.bundleID) {
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else { continue }
            if app.isHidden { app.unhide() }

            var available = AX.windows(of: app.processIdentifier).filter { isArrangeable($0, allowMinimized: true) }
            var unmatched: [SavedWindow] = []

            // A window with the same title is most likely the same window…
            for savedWindow in savedWindows {
                if let index = available.firstIndex(where: { AX.string($0, kAXTitleAttribute) == savedWindow.title }) {
                    moves.append((available.remove(at: index), savedWindow.frame))
                } else {
                    unmatched.append(savedWindow)
                }
            }
            // …and the rest take the app's other windows in order, front first.
            for savedWindow in unmatched where !available.isEmpty {
                moves.append((available.removeFirst(), savedWindow.frame))
            }
        }

        guard !moves.isEmpty else {
            NSSound.beep()
            return
        }
        for move in moves where AX.bool(move.window, kAXMinimizedAttribute) == true {
            AXUIElementSetAttributeValue(move.window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        WindowMover.shared.move(moves)
    }

    /// A normal document or app window, as opposed to a panel, sheet or pop-up.
    private static func isArrangeable(_ window: AXUIElement, allowMinimized: Bool = false) -> Bool {
        guard AX.string(window, kAXSubroleAttribute) == kAXStandardWindowSubrole as String,
              AX.bool(window, "AXFullScreen") != true
        else { return false }
        return allowMinimized || AX.bool(window, kAXMinimizedAttribute) != true
    }
}
