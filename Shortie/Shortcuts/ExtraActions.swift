import AppKit
import Carbon

/// Things to do to one particular app, whether or not it's in front.
nonisolated enum AppTask: String, Codable, CaseIterable, Identifiable {
    case toggle, showOnly, hide, quit, forceQuit, restart

    var id: Self { self }

    var title: String {
        switch self {
        case .toggle: "Show or Hide"
        case .showOnly: "Show Only"
        case .hide: "Hide"
        case .quit: "Quit"
        case .forceQuit: "Force Quit"
        case .restart: "Restart"
        }
    }
}

/// An area of the screen in percent, measured from the top-left of the
/// usable area (below the menu bar, beside the Dock).
nonisolated struct WindowFrame: Codable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var unitRect: CGRect {
        CGRect(x: x / 100, y: y / 100, width: width / 100, height: height / 100)
    }

    var summary: String {
        "\(Int(width))% × \(Int(height))% at \(Int(x))%, \(Int(y))%"
    }
}

/// A web address to call, for webhooks and home automation.
nonisolated struct WebRequest: Codable, Hashable {
    static let methods = ["GET", "POST", "PUT", "PATCH", "DELETE"]

    var method = "GET"
    var url = ""
    var body = ""
}

enum AppTaskRunner {
    static func run(_ task: AppTask, path: String) {
        let url = URL(fileURLWithPath: path)
        let running = Bundle(url: url)?.bundleIdentifier.map { NSRunningApplication.runningApplications(withBundleIdentifier: $0) } ?? []

        switch task {
        case .toggle:
            if let app = running.first, app.isActive {
                app.hide()
            } else {
                open(url)
            }
        case .showOnly:
            open(url)
            let ownID = ProcessInfo.processInfo.processIdentifier
            let keep = Set(running.map(\.processIdentifier))
            for other in NSWorkspace.shared.runningApplications
            where other.activationPolicy == .regular && !keep.contains(other.processIdentifier) && other.processIdentifier != ownID {
                other.hide()
            }
        case .hide:
            running.forEach { $0.hide() }
        case .quit:
            running.forEach { $0.terminate() }
        case .forceQuit:
            running.forEach { $0.forceTerminate() }
        case .restart:
            guard let app = running.first else {
                open(url)
                return
            }
            app.terminate()
            Task {
                // Give it up to ten seconds to quit (it may ask to save first).
                for _ in 0..<100 where !app.isTerminated {
                    try? await Task.sleep(for: .milliseconds(100))
                }
                if app.isTerminated { open(url) }
            }
        }
    }

    private static func open(_ url: URL) {
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }
}

/// The brightness of the built-in display (and Apple displays), through the
/// same private framework the brightness keys use.
enum Brightness {
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    static func set(_ percent: Int) {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
              let symbol = dlsym(handle, "DisplayServicesSetBrightness")
        else {
            NSSound.beep()
            return
        }
        let setBrightness = unsafeBitCast(symbol, to: SetBrightness.self)
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetOnlineDisplayList(UInt32(displays.count), &displays, &count)
        var changed = false
        for display in displays.prefix(Int(count)) where setBrightness(display, Float(percent) / 100) == 0 {
            changed = true
        }
        if changed {
            HUD.show("Brightness \(percent)%", systemImage: "sun.max.fill")
        } else {
            NSSound.beep()
        }
    }
}

/// Keyboard layouts and input methods (ABC, British, Pinyin…).
enum InputSources {
    struct Source: Identifiable, Hashable {
        let id: String
        let name: String
    }

    /// Stands for "whichever comes next".
    nonisolated static let nextID = "next"

    /// The ones turned on in System Settings › Keyboard › Text Input.
    static func all() -> [Source] {
        list().compactMap { source in
            guard let id = string(source, kTISPropertyInputSourceID), let name = string(source, kTISPropertyLocalizedName) else { return nil }
            return Source(id: id, name: name)
        }
    }

    static func select(_ id: String) {
        let sources = list()
        let target: TISInputSource?
        if id == nextID {
            let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
            let currentID = current.flatMap { string($0, kTISPropertyInputSourceID) }
            let index = sources.firstIndex { string($0, kTISPropertyInputSourceID) == currentID } ?? -1
            target = sources.isEmpty ? nil : sources[(index + 1) % sources.count]
        } else {
            target = sources.first { string($0, kTISPropertyInputSourceID) == id }
        }
        guard let target else {
            NSSound.beep()
            return
        }
        TISSelectInputSource(target)
        if let name = string(target, kTISPropertyLocalizedName) {
            HUD.show(name, systemImage: "globe")
        }
    }

    private static func list() -> [TISInputSource] {
        let filter = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as Any,
            kTISPropertyInputSourceIsSelectCapable as String: true,
        ] as CFDictionary
        return TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] ?? []
    }

    private static func string(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }
}

/// The alert sounds that come with macOS.
enum SystemSounds {
    static func names() -> [String] {
        let folder = URL(fileURLWithPath: "/System/Library/Sounds")
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.map { $0.deletingPathExtension().lastPathComponent }.sorted()
    }

    static func play(_ name: String) {
        if let sound = NSSound(named: NSSound.Name(name)) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}

enum ExtraActionRunner {
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        HUD.show("Copied", systemImage: "doc.on.clipboard")
    }

    /// Pastes the text in one go (much faster than typing it for long text),
    /// then puts back whatever was on the clipboard.
    static func paste(_ text: String) {
        Task {
            await TextTyper.waitForModifiersReleased()
            let pasteboard = NSPasteboard.general
            ClipboardHistory.shared.ignoreChanges(true)
            let saved = (pasteboard.pasteboardItems ?? []).map { item in
                let copy = NSPasteboardItem()
                for type in item.types {
                    if let data = item.data(forType: type) { copy.setData(data, forType: type) }
                }
                return copy
            }
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_ANSI_V), modifiers: .command, keyName: "V"))
            // Apps read the clipboard a moment after ⌘V, so wait before putting it back.
            try? await Task.sleep(for: .milliseconds(400))
            pasteboard.clearContents()
            if !saved.isEmpty { pasteboard.writeObjects(saved) }
            ClipboardHistory.shared.ignoreChanges(false)
        }
    }

    /// A Notification Centre notification from Shortie.
    static func notify(_ text: String) {
        let escaped = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        var error: NSDictionary?
        NSAppleScript(source: "display notification \"\(escaped)\" with title \"Shortie\"")?.executeAndReturnError(&error)
    }

    static func send(_ request: WebRequest) {
        guard let url = ShortcutAction.url(for: request.url) else {
            NSSound.beep()
            return
        }
        var urlRequest = URLRequest(url: url, timeoutInterval: 15)
        urlRequest.httpMethod = request.method
        if request.method != "GET", !request.body.isEmpty {
            urlRequest.httpBody = Data(request.body.utf8)
            let trimmed = request.body.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        Task {
            let response = try? await URLSession.shared.data(for: urlRequest).1 as? HTTPURLResponse
            if !(200..<300).contains(response?.statusCode ?? 0) {
                HUD.show("Web Request Failed", systemImage: "exclamationmark.triangle.fill")
            }
        }
    }

    /// Moves the pointer to a point measured from the top-left of the main display.
    static func movePointer(x: Int, y: Int) {
        let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: .left)
        event?.setIntegerValueField(.eventSourceUserData, value: SyntheticEvent.marker)
        event?.post(tap: .cghidEventTap)
    }
}
