import AppKit
import Carbon.HIToolbox

/// The workings behind more of the actions BetterTouchTool users expect.
enum ParityActions {
    // MARK: - Keyboard

    /// Lets go of ⌘ ⌥ ⌃ ⇧ and fn, in case a step left one held down.
    static func releaseAllModifiers() {
        let source = CGEventSource(stateID: .hidSystemState)
        for keyCode: CGKeyCode in [55, 54, 56, 60, 58, 61, 59, 62, 63] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
            event?.type = .flagsChanged
            event?.flags = []
            event?.setIntegerValueField(.eventSourceUserData, value: SyntheticEvent.marker)
            event?.post(tap: .cghidEventTap)
        }
    }

    /// Opens the context menu of whatever has keyboard focus, like the menu key on a PC keyboard.
    static func showContextMenuForFocus() {
        let system = AXUIElementCreateSystemWide()
        guard let focused = AX.element(system, kAXFocusedUIElementAttribute),
              AXUIElementPerformAction(focused, kAXShowMenuAction as CFString) == .success
        else {
            NSSound.beep()
            return
        }
    }

    // MARK: - Notifications

    /// Closes every notification on screen and in Notification Centre.
    static func closeAllNotifications() {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first else { return }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        // Closing one can reveal the next, so go round a few times.
        for _ in 0..<5 {
            var closed = 0
            for window in AX.windows(of: app.processIdentifier) + [root] {
                closed += closeNotifications(in: window, depth: 0)
            }
            if closed == 0 { break }
        }
    }

    private static func closeNotifications(in element: AXUIElement, depth: Int) -> Int {
        var names: CFArray?
        if AXUIElementCopyActionNames(element, &names) == .success, let names = names as? [String],
           let close = names.first(where: { $0.contains("Close") || $0.contains("Clear All") }) {
            AXUIElementPerformAction(element, close as CFString)
            return 1
        }
        guard depth < 12 else { return 0 }
        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        return (children as? [AXUIElement] ?? []).reduce(0) { $0 + closeNotifications(in: $1, depth: depth + 1) }
    }

    // MARK: - Clipboard

    private static var savedClipboard: [NSPasteboardItem] = []

    static func saveClipboard() {
        savedClipboard = (NSPasteboard.general.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
        HUD.show("Clipboard Saved", systemImage: "tray.and.arrow.down")
    }

    static func restoreClipboard() {
        guard !savedClipboard.isEmpty else {
            NSSound.beep()
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(savedClipboard)
        // The pasteboard owns them now, so keep copies for next time.
        let restored = savedClipboard
        saveCopies(of: restored)
        HUD.show("Clipboard Restored", systemImage: "tray.and.arrow.up")
    }

    private static func saveCopies(of items: [NSPasteboardItem]) {
        savedClipboard = items.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }

    // MARK: - Finder

    /// The folder shown in the front Finder window, or the Desktop.
    static func finderFolder() -> String? {
        let source = """
        tell application "Finder"
            try
                return POSIX path of (target of front Finder window as alias)
            on error
                return POSIX path of (path to desktop folder)
            end try
        end tell
        """
        var error: NSDictionary?
        return NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue
    }

    /// The files selected in Finder.
    static func finderSelection() -> [String] {
        let source = """
        tell application "Finder" to set picked to selection as alias list
        set paths to {}
        repeat with f in picked
            set end of paths to POSIX path of f
        end repeat
        set AppleScript's text item delimiters to linefeed
        return paths as text
        """
        var error: NSDictionary?
        let text = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue ?? ""
        return text.split(separator: "\n").map(String.init)
    }

    static func newFileInFinder() {
        guard let folder = finderFolder() else {
            NSSound.beep()
            return
        }
        let url = uniqueURL(in: URL(fileURLWithPath: folder), name: "Untitled", extension: "txt")
        guard FileManager.default.createFile(atPath: url.path, contents: Data()) else {
            NSSound.beep()
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func compressFinderSelection() {
        let paths = finderSelection()
        guard let first = paths.first else {
            NSSound.beep()
            return
        }
        let folder = URL(fileURLWithPath: first).deletingLastPathComponent()
        let process = Process()
        if paths.count == 1 {
            let name = URL(fileURLWithPath: first).lastPathComponent
            let archive = uniqueURL(in: folder, name: name, extension: "zip")
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", first, archive.path]
        } else {
            let archive = uniqueURL(in: folder, name: "Archive", extension: "zip")
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.currentDirectoryURL = folder
            process.arguments = ["-r", "-y", "-q", archive.path] + paths.map { URL(fileURLWithPath: $0).lastPathComponent }
        }
        process.terminationHandler = { process in
            let ok = process.terminationStatus == 0
            Task { @MainActor in
                HUD.show(ok ? "Compressed" : "Couldn't Compress", systemImage: ok ? "doc.zipper" : "exclamationmark.triangle.fill")
            }
        }
        try? process.run()
    }

    /// "Name.ext", or "Name 2.ext" and so on if that's taken.
    private static func uniqueURL(in folder: URL, name: String, extension ext: String) -> URL {
        var url = folder.appendingPathComponent(name).appendingPathExtension(ext)
        var number = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(name) \(number)").appendingPathExtension(ext)
            number += 1
        }
        return url
    }

    // MARK: - Screenshots

    /// Takes a screenshot of an area you choose and opens it in Preview to mark up.
    static func screenshotAndEdit() {
        let stamp = Date.now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
            .replacingOccurrences(of: ":", with: ".")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("Screenshot \(stamp).png")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-P", file.path]
        try? process.run()
    }

    // MARK: - Shortie

    static func restartShortie() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? process.run()
        NSApp.terminate(nil)
    }

    static func showColourPanel() {
        NSApp.activate()
        NSColorPanel.shared.orderFront(nil)
    }
}

/// True Tone, through the same private framework System Settings uses.
enum TrueTone {
    private static let client: NSObject? = {
        guard Bundle(path: "/System/Library/PrivateFrameworks/CoreBrightness.framework")?.load() == true,
              let type = NSClassFromString("CBTrueToneClient") as? NSObject.Type
        else { return nil }
        return type.init()
    }()

    static func toggle() {
        let getter = NSSelectorFromString("enabled")
        let setter = NSSelectorFromString("setEnabled:")
        guard let client, client.responds(to: getter), client.responds(to: setter) else {
            NSSound.beep()
            return
        }
        typealias Get = @convention(c) (AnyObject, Selector) -> Bool
        typealias Set = @convention(c) (AnyObject, Selector, Bool) -> Bool
        let isOn = unsafeBitCast(client.method(for: getter), to: Get.self)(client, getter)
        _ = unsafeBitCast(client.method(for: setter), to: Set.self)(client, setter, !isOn)
        HUD.show(isOn ? "True Tone Off" : "True Tone On", systemImage: "sun.max.trianglebadge.exclamationmark")
    }
}

/// Windows from every app, front to back, read from the window server.
enum WindowOrder {
    struct Entry {
        let processID: pid_t
        let frame: CGRect
    }

    /// Ordinary windows on screen (not menus, panels or Shortie's own), front first.
    static func onScreen() -> [Entry] {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let ownID = ProcessInfo.processInfo.processIdentifier
        return list.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let processID = info[kCGWindowOwnerPID as String] as? pid_t, processID != ownID,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds), frame.width > 60, frame.height > 60
            else { return nil }
            return Entry(processID: processID, frame: frame)
        }
    }

    /// The Accessibility window that matches an entry.
    static func window(for entry: Entry) -> AXUIElement? {
        AX.windows(of: entry.processID).first { window in
            guard let frame = WindowMover.shared.frame(of: window) else { return false }
            return abs(frame.minX - entry.frame.minX) < 4 && abs(frame.minY - entry.frame.minY) < 4
                && abs(frame.width - entry.frame.width) < 4 && abs(frame.height - entry.frame.height) < 4
        }
    }

    static func focus(_ window: AXUIElement, processID: pid_t) {
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        NSRunningApplication(processIdentifier: processID)?.activate()
    }

    /// The window you used before this one, from any app.
    static func focusPrevious() {
        let entries = onScreen()
        guard entries.count > 1, let window = window(for: entries[1]) else {
            NSSound.beep()
            return
        }
        focus(window, processID: entries[1].processID)
    }

    /// The front two windows, side by side on the front one's screen.
    static func sideBySide() {
        let entries = onScreen()
        let windows = entries.prefix(2).compactMap { entry in window(for: entry) }
        guard windows.count == 2, let screen = screen(containing: entries[0].frame) else {
            NSSound.beep()
            return
        }
        let area = WindowMover.usableArea(of: screen)
        let half = area.width / 2
        WindowMover.shared.move([
            (windows[0], CGRect(x: area.minX, y: area.minY, width: half, height: area.height)),
            (windows[1], CGRect(x: area.minX + half, y: area.minY, width: half, height: area.height)),
        ])
    }

    /// Every window onto the display the pointer is on; maximised, or keeping
    /// each one's place and size relative to its screen.
    static func gatherOnPointerDisplay(maximize: Bool) {
        guard let pointer = CGEvent(source: nil)?.location, let target = screen(containing: CGRect(origin: pointer, size: CGSize(width: 1, height: 1))) else { return }
        let destination = WindowMover.usableArea(of: target)
        var moves: [(window: AXUIElement, to: CGRect)] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && !app.isHidden {
            for window in AX.windows(of: app.processIdentifier) where AX.bool(window, kAXMinimizedAttribute) != true {
                guard AX.string(window, kAXSubroleAttribute) == kAXStandardWindowSubrole as String,
                      let frame = WindowMover.shared.frame(of: window), let from = screen(containing: frame)
                else { continue }
                if maximize {
                    moves.append((window, destination))
                } else if from != target {
                    let area = WindowMover.usableArea(of: from)
                    moves.append((window, CGRect(
                        x: destination.minX + (frame.minX - area.minX) / area.width * destination.width,
                        y: destination.minY + (frame.minY - area.minY) / area.height * destination.height,
                        width: min(frame.width / area.width, 1) * destination.width,
                        height: min(frame.height / area.height, 1) * destination.height
                    )))
                }
            }
        }
        WindowMover.shared.move(moves)
    }

    /// The screen showing most of a rectangle (in Accessibility coordinates).
    static func screen(containing rect: CGRect) -> NSScreen? {
        NSScreen.screens.max { a, b in
            let first = WindowMover.flipped(a.frame).intersection(rect)
            let second = WindowMover.flipped(b.frame).intersection(rect)
            return (first.isNull ? 0 : first.width * first.height) < (second.isNull ? 0 : second.width * second.height)
        }
    }
}

/// Remembered windows and window frames, for "save" and "go back" actions.
enum SavedWindows {
    private static var savedFrame: (window: AXUIElement, frame: CGRect)?
    private static var savedWindow: (window: AXUIElement, processID: pid_t)?

    static func saveFrame(of window: AXUIElement) {
        guard let frame = WindowMover.shared.frame(of: window) else { return }
        savedFrame = (window, frame)
        HUD.show("Window Position Saved", systemImage: "macwindow")
    }

    /// Puts the saved window back where it was; or, if it's gone, moves `fallback` there.
    static func restoreFrame(fallback: AXUIElement?) {
        guard let savedFrame else {
            NSSound.beep()
            return
        }
        let window = WindowMover.shared.frame(of: savedFrame.window) != nil ? savedFrame.window : fallback
        guard let window else { return }
        WindowMover.shared.move([(window, savedFrame.frame)])
    }

    static func saveActive(_ target: ActionTarget) {
        guard let window = target.window else { return }
        savedWindow = (window, target.processID)
        HUD.show("Window Saved", systemImage: "bookmark")
    }

    static func returnToSaved() {
        guard let savedWindow else {
            NSSound.beep()
            return
        }
        WindowOrder.focus(savedWindow.window, processID: savedWindow.processID)
    }
}
