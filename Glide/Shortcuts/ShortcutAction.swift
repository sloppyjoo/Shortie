import AppKit
import Carbon.HIToolbox

/// What a shortcut does when you press it.
nonisolated enum ShortcutAction: Codable, Hashable {
    case openApp(path: String)
    /// Runs a shortcut from Apple's Shortcuts app, by name.
    case runShortcut(name: String)
    /// A website (`apple.com`) or a file or folder (`~/Documents/notes.txt`).
    case open(target: String)
    case typeText(text: String)
    /// Snaps the front window somewhere, like the left half of the screen.
    case moveWindow(position: WindowPosition)

    enum Kind: CaseIterable, Identifiable {
        case openApp, runShortcut, open, typeText, moveWindow
        var id: Self { self }
    }

    var kind: Kind {
        switch self {
        case .openApp: .openApp
        case .runShortcut: .runShortcut
        case .open: .open
        case .typeText: .typeText
        case .moveWindow: .moveWindow
        }
    }

    /// The one piece of text each action carries, so editors can share code.
    var payload: String {
        switch self {
        case .openApp(let path): path
        case .runShortcut(let name): name
        case .open(let target): target
        case .typeText(let text): text
        case .moveWindow(let position): position.rawValue
        }
    }

    func with(payload: String) -> ShortcutAction {
        switch self {
        case .openApp: .openApp(path: payload)
        case .runShortcut: .runShortcut(name: payload)
        case .open: .open(target: payload)
        case .typeText: .typeText(text: payload)
        case .moveWindow: .moveWindow(position: WindowPosition(rawValue: payload) ?? .maximize)
        }
    }

    var isComplete: Bool {
        !payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// A short human description, like "Open Safari" or "Type “Thanks!”".
    var title: String {
        switch self {
        case .openApp(let path):
            "Open \(FileManager.default.displayName(atPath: path).replacingOccurrences(of: ".app", with: ""))"
        case .runShortcut(let name):
            "Run “\(name)”"
        case .open(let target):
            "Open \(Self.shortName(for: target))"
        case .typeText(let text):
            "Type “\(text.count > 30 ? text.prefix(30) + "…" : text)”"
        case .moveWindow(let position):
            position.title
        }
    }

    /// Works out whether you typed a website or a file path.
    static func url(for target: String) -> URL? {
        let target = target.trimmingCharacters(in: .whitespacesAndNewlines)
        if target.hasPrefix("/") || target.hasPrefix("~") {
            return URL(fileURLWithPath: (target as NSString).expandingTildeInPath)
        }
        if target.contains("://") {
            return URL(string: target)
        }
        return URL(string: "https://" + target)
    }

    private static func shortName(for target: String) -> String {
        guard let url = url(for: target) else { return target }
        if url.isFileURL {
            return url.lastPathComponent
        }
        if let host = url.host() {
            return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        }
        return target
    }
}

/// Carries out actions.
enum ActionRunner {
    static func run(_ action: ShortcutAction) {
        switch action {
        case .openApp(let path):
            // Opens the app, or brings it to the front if it's already running.
            NSWorkspace.shared.openApplication(
                at: URL(fileURLWithPath: path),
                configuration: NSWorkspace.OpenConfiguration(),
                completionHandler: nil
            )
        case .runShortcut(let name):
            ShortcutsApp.run(name)
        case .open(let target):
            if let url = ShortcutAction.url(for: target) {
                NSWorkspace.shared.open(url)
            }
        case .typeText(let text):
            Task { await TextTyper.type(text) }
        case .moveWindow(let position):
            WindowMover.shared.move(position)
        }
    }
}

/// Talks to Apple's Shortcuts app through its built-in `shortcuts` command-line tool.
enum ShortcutsApp {
    nonisolated private static let tool = URL(fileURLWithPath: "/usr/bin/shortcuts")

    static func run(_ name: String) {
        let process = Process()
        process.executableURL = tool
        process.arguments = ["run", name]
        try? process.run()
    }

    /// The names of all your shortcuts, alphabetically.
    static func list() async -> [String] {
        await Task.detached {
            let process = Process()
            let output = Pipe()
            process.executableURL = tool
            process.arguments = ["list"]
            process.standardOutput = output
            guard (try? process.run()) != nil else { return [] }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(decoding: data, as: UTF8.self)
                .split(separator: "\n")
                .map(String.init)
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        }.value
    }
}

/// Types text into whichever app is in front, as if you'd typed it yourself.
enum TextTyper {
    static func type(_ text: String) async {
        // Wait (up to a second) for you to let go of the shortcut's keys. Otherwise
        // a ⌘ still being held down would turn a typed "c" into Copy.
        let modifierFlags: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
        for _ in 0..<50 {
            if CGEventSource.flagsState(.combinedSessionState).intersection(modifierFlags).isEmpty { break }
            try? await Task.sleep(for: .milliseconds(20))
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let lines = text.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            if index > 0 {
                press(keyCode: CGKeyCode(kVK_Return), source: source)
            }
            // Send a few characters at a time; some apps drop very long bursts.
            var remaining = Substring(line)
            while !remaining.isEmpty {
                let chunk = remaining.prefix(20)
                remaining = remaining.dropFirst(chunk.count)
                send(String(chunk), source: source)
            }
        }
    }

    private static func send(_ string: String, source: CGEventSource?) {
        var characters = Array(string.utf16)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: isDown)
            event?.flags = []
            event?.keyboardSetUnicodeString(stringLength: characters.count, unicodeString: &characters)
            event?.post(tap: .cghidEventTap)
        }
    }

    private static func press(keyCode: CGKeyCode, source: CGEventSource?) {
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown)
            event?.flags = []
            event?.post(tap: .cghidEventTap)
        }
    }
}
