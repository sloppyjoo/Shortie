import AppKit
import Carbon.HIToolbox

/// What a shortcut does when you press it.
nonisolated indirect enum ShortcutAction: Codable, Hashable {
    case openApp(path: String)
    /// Runs a shortcut from Apple's Shortcuts app, by name.
    case runShortcut(name: String)
    /// A website (`apple.com`) or a file or folder (`~/Documents/notes.txt`).
    case open(target: String)
    case typeText(text: String)
    /// Snaps the front window somewhere, like the left half of the screen.
    case moveWindow(position: WindowPosition)
    /// Closes, minimises, hides or quits a window or app.
    case appCommand(command: AppCommand)
    /// Clicks wherever the pointer is.
    case mouseClick(click: MouseAction)
    /// Media keys, Control Centre, Mission Control, screenshots, locking…
    case system(action: SystemAction)
    /// Presses a keyboard shortcut in the app in front. `nil` until chosen.
    case pressKeys(combo: KeyCombo?)
    /// Chooses an item from the front app's menus, like "File › Export as PDF…".
    case menuItem(path: String)
    case appleScript(source: String)
    case shellScript(source: String)
    /// Pauses between the steps of a multi-step action.
    case wait(seconds: Double)
    /// Several actions, one after another.
    case steps(actions: [ShortcutAction])
    /// Opens one of your custom menus at the pointer. The name is kept for
    /// showing in lists; it's updated if you rename the menu.
    case showMenu(id: UUID?, name: String)
    /// Puts your windows back in one of your saved layouts. The name is kept
    /// for showing in lists, like `showMenu`'s.
    case restoreLayout(id: UUID?, name: String)
    /// Changes, searches for, speaks or counts the text you've selected.
    case text(action: TextAction)
    /// A short message in a glass bubble near the bottom of the screen.
    case showMessage(text: String)
    case speak(text: String)
    case setVolume(percent: Int)
    /// Switches speakers or headphones. The UID picks the device; the name is
    /// for showing in lists, and as a fallback if the UID isn't found.
    case soundOutput(uid: String, name: String)
    /// Shows, hides, quits or restarts one particular app.
    case appTask(task: AppTask, path: String)
    case setBrightness(percent: Int)
    /// Puts the window at an exact place and size, in percent of the screen.
    case windowFrame(frame: WindowFrame)
    /// Moves the window to a particular display, 1 being the leftmost.
    case moveToDisplay(number: Int)
    /// Moves the pointer to a point, measured from the top-left of the main display.
    case movePointer(x: Int, y: Int)
    case copyText(text: String)
    /// Puts text in through the clipboard, which is quicker than typing it.
    case pasteText(text: String)
    /// A notification in Notification Centre.
    case notify(text: String)
    /// Calls a web address, for webhooks and home automation.
    case webRequest(request: WebRequest)
    /// Switches keyboard layout or input method. The ID picks it; the name is for lists.
    case inputSource(id: String, name: String)
    case playSound(name: String)

    enum Kind: CaseIterable, Identifiable {
        case openApp, runShortcut, open, typeText, moveWindow, appCommand, mouseClick, system, pressKeys
        case menuItem, appleScript, shellScript, wait, steps, showMenu, restoreLayout
        case text, showMessage, speak, setVolume, soundOutput
        case appTask, setBrightness, windowFrame, moveToDisplay, movePointer
        case copyText, pasteText, notify, webRequest, inputSource, playSound
        var id: Self { self }
    }

    var kind: Kind {
        switch self {
        case .openApp: .openApp
        case .runShortcut: .runShortcut
        case .open: .open
        case .typeText: .typeText
        case .moveWindow: .moveWindow
        case .appCommand: .appCommand
        case .mouseClick: .mouseClick
        case .system: .system
        case .pressKeys: .pressKeys
        case .menuItem: .menuItem
        case .appleScript: .appleScript
        case .shellScript: .shellScript
        case .wait: .wait
        case .steps: .steps
        case .showMenu: .showMenu
        case .restoreLayout: .restoreLayout
        case .text: .text
        case .showMessage: .showMessage
        case .speak: .speak
        case .setVolume: .setVolume
        case .soundOutput: .soundOutput
        case .appTask: .appTask
        case .setBrightness: .setBrightness
        case .windowFrame: .windowFrame
        case .moveToDisplay: .moveToDisplay
        case .movePointer: .movePointer
        case .copyText: .copyText
        case .pasteText: .pasteText
        case .notify: .notify
        case .webRequest: .webRequest
        case .inputSource: .inputSource
        case .playSound: .playSound
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
        case .appCommand(let command): command.rawValue
        case .mouseClick(let click): click.rawValue
        case .system(let action): action.rawValue
        case .pressKeys(let combo): combo?.displayString ?? ""
        case .menuItem(let path): path
        case .appleScript(let source): source
        case .shellScript(let source): source
        case .wait(let seconds): String(seconds)
        case .steps(let actions): actions.isEmpty ? "" : "steps"
        case .showMenu(let id, _): id?.uuidString ?? ""
        case .restoreLayout(let id, _): id?.uuidString ?? ""
        case .text(let action): action.rawValue
        case .showMessage(let text): text
        case .speak(let text): text
        case .setVolume(let percent): String(percent)
        case .soundOutput(let uid, _): uid
        case .appTask(_, let path): path
        case .setBrightness(let percent): String(percent)
        case .windowFrame(let frame): frame.width > 0 && frame.height > 0 ? frame.summary : ""
        case .moveToDisplay(let number): String(number)
        case .movePointer(let x, let y): "\(x),\(y)"
        case .copyText(let text): text
        case .pasteText(let text): text
        case .notify(let text): text
        case .webRequest(let request): request.url
        case .inputSource(let id, _): id
        case .playSound(let name): name
        }
    }

    func with(payload: String) -> ShortcutAction {
        switch self {
        case .openApp: .openApp(path: payload)
        case .runShortcut: .runShortcut(name: payload)
        case .open: .open(target: payload)
        case .typeText: .typeText(text: payload)
        case .moveWindow: .moveWindow(position: WindowPosition(rawValue: payload) ?? .maximize)
        case .appCommand: .appCommand(command: AppCommand(rawValue: payload) ?? .closeWindow)
        case .mouseClick: .mouseClick(click: MouseAction(rawValue: payload) ?? .rightClick)
        case .system: .system(action: SystemAction(rawValue: payload) ?? .controlCentre)
        case .menuItem: .menuItem(path: payload)
        case .appleScript: .appleScript(source: payload)
        case .shellScript: .shellScript(source: payload)
        case .wait: .wait(seconds: Double(payload) ?? 0.5)
        case .text: .text(action: TextAction(rawValue: payload) ?? .uppercase)
        case .showMessage: .showMessage(text: payload)
        case .speak: .speak(text: payload)
        case .setVolume: .setVolume(percent: Int(payload) ?? 50)
        case .setBrightness: .setBrightness(percent: Int(payload) ?? 50)
        case .moveToDisplay: .moveToDisplay(number: Int(payload) ?? 1)
        case .copyText: .copyText(text: payload)
        case .pasteText: .pasteText(text: payload)
        case .notify: .notify(text: payload)
        case .playSound: .playSound(name: payload)
        case .appTask(let task, _): .appTask(task: task, path: payload)
        // Keys and steps are edited directly (see `ActionFields`), not as text.
        case .pressKeys, .steps, .showMenu, .restoreLayout, .soundOutput,
             .windowFrame, .movePointer, .webRequest, .inputSource: self
        }
    }

    var isComplete: Bool {
        if case .steps(let actions) = self {
            return !actions.isEmpty && actions.allSatisfy(\.isComplete)
        }
        return !payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        case .appCommand(let command):
            command.title
        case .mouseClick(let click):
            click.title
        case .system(let action):
            action.title
        case .pressKeys(let combo?):
            KeyPreset.matching(combo).map(\.title) ?? "Press \(combo.displayString)"
        case .pressKeys(nil):
            "Press Keys"
        case .menuItem(let path):
            "Choose \(MenuClicker.steps(of: path).joined(separator: " › "))"
        case .appleScript:
            "Run AppleScript"
        case .shellScript:
            "Run Shell Script"
        case .wait(let seconds):
            "Wait \(seconds.formatted()) s"
        case .steps(let actions):
            actions.map(\.title).joined(separator: ", then ")
        case .showMenu(_, let name):
            name.isEmpty ? "Show Custom Menu" : "Show “\(name)” Menu"
        case .restoreLayout(_, let name):
            name.isEmpty ? "Restore Window Layout" : "Restore “\(name)” Layout"
        case .text(let action):
            action.title
        case .showMessage(let text):
            "Show “\(text.count > 30 ? text.prefix(30) + "…" : text)”"
        case .speak(let text):
            "Say “\(text.count > 30 ? text.prefix(30) + "…" : text)”"
        case .setVolume(let percent):
            "Set Volume to \(percent)%"
        case .soundOutput(let uid, let name):
            uid == SoundOutput.nextDeviceUID ? "Next Sound Output" : name.isEmpty ? "Sound Output" : "Play Sound on \(name)"
        case .appTask(let task, let path):
            path.isEmpty ? "\(task.title) App"
                : "\(task.title) \(FileManager.default.displayName(atPath: path).replacingOccurrences(of: ".app", with: ""))"
        case .setBrightness(let percent):
            "Set Brightness to \(percent)%"
        case .windowFrame(let frame):
            "Move Window to \(frame.summary)"
        case .moveToDisplay(let number):
            "Move Window to Display \(number)"
        case .movePointer(let x, let y):
            "Move Pointer to \(x), \(y)"
        case .copyText(let text):
            "Copy “\(text.count > 30 ? text.prefix(30) + "…" : text)”"
        case .pasteText(let text):
            "Paste “\(text.count > 30 ? text.prefix(30) + "…" : text)”"
        case .notify(let text):
            "Notify “\(text.count > 30 ? text.prefix(30) + "…" : text)”"
        case .webRequest(let request):
            "\(request.method) \(Self.shortName(for: request.url))"
        case .inputSource(let id, let name):
            id == InputSources.nextID ? "Next Input Source" : name.isEmpty ? "Input Source" : "Switch to \(name)"
        case .playSound(let name):
            "Play “\(name)” Sound"
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
    /// Runs an action. Window actions apply to `target`'s window, or to the
    /// window you're using if there's no target.
    static func run(_ action: ShortcutAction, on target: ActionTarget? = nil) {
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
            WindowMover.shared.move(position, window: target?.window)
        case .appCommand(let command):
            if let target = target ?? ActionTarget.frontmost {
                AppCommandRunner.run(command, on: target)
            }
        case .mouseClick(let click):
            MouseClicker.perform(click)
        case .system(let action):
            SystemActionRunner.run(action)
        case .pressKeys(let combo):
            combo.map { KeyPresser.press($0) }
        case .menuItem(let path):
            let processID = target?.processID ?? NSWorkspace.shared.frontmostApplication?.processIdentifier
            if let processID, !MenuClicker.choose(path, in: processID) { NSSound.beep() }
        case .appleScript(let source):
            ScriptRunner.runAppleScript(source)
        case .shellScript(let source):
            ScriptRunner.runShellScript(source)
        case .wait:
            break // Only means something between steps.
        case .showMenu(let id, _):
            FloatingMenu.shared.show(id)
        case .restoreLayout(let id, _):
            WindowLayouts.restore(id)
        case .text(let action):
            SelectedText.run(action)
        case .showMessage(let text):
            HUD.show(text, systemImage: "text.bubble.fill")
        case .speak(let text):
            Speaker.speak(text)
        case .setVolume(let percent):
            SoundOutput.setVolume(percent)
        case .soundOutput(let uid, let name):
            SoundOutput.select(uid: uid, name: name)
        case .appTask(let task, let path):
            AppTaskRunner.run(task, path: path)
        case .setBrightness(let percent):
            Brightness.set(percent)
        case .windowFrame(let frame):
            WindowMover.shared.move(toUnit: frame.unitRect, window: target?.window)
        case .moveToDisplay(let number):
            WindowMover.shared.move(toDisplay: number, window: target?.window)
        case .movePointer(let x, let y):
            ExtraActionRunner.movePointer(x: x, y: y)
        case .copyText(let text):
            ExtraActionRunner.copy(text)
        case .pasteText(let text):
            ExtraActionRunner.paste(text)
        case .notify(let text):
            ExtraActionRunner.notify(text)
        case .webRequest(let request):
            ExtraActionRunner.send(request)
        case .inputSource(let id, _):
            InputSources.select(id)
        case .playSound(let name):
            SystemSounds.play(name)
        case .steps(let actions):
            Task {
                for step in actions {
                    if case .wait(let seconds) = step {
                        try? await Task.sleep(for: .seconds(seconds))
                    } else {
                        run(step, on: target)
                        // A moment for each step to take effect before the next.
                        try? await Task.sleep(for: .milliseconds(80))
                    }
                }
            }
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
        await waitForModifiersReleased()

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

    /// Waits (up to a second) for you to let go of the shortcut's keys. Otherwise
    /// a ⌘ still being held down would turn a typed "c" into Copy.
    static func waitForModifiersReleased() async {
        let modifierFlags: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
        for _ in 0..<50 {
            if CGEventSource.flagsState(.combinedSessionState).intersection(modifierFlags).isEmpty { return }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private static func send(_ string: String, source: CGEventSource?) {
        var characters = Array(string.utf16)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: isDown)
            event?.flags = []
            event?.setIntegerValueField(.eventSourceUserData, value: SyntheticEvent.marker)
            event?.keyboardSetUnicodeString(stringLength: characters.count, unicodeString: &characters)
            event?.post(tap: .cghidEventTap)
        }
    }

    private static func press(keyCode: CGKeyCode, source: CGEventSource?) {
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown)
            event?.flags = []
            event?.setIntegerValueField(.eventSourceUserData, value: SyntheticEvent.marker)
            event?.post(tap: .cghidEventTap)
        }
    }
}
