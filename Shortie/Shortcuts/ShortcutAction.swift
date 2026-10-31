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
    /// JavaScript for Automation (JXA), run like AppleScript.
    case javaScript(source: String)
    case pressKeysInApp(combo: KeyCombo?, path: String)
    case modifierKeys(modifiers: Modifiers, down: Bool)
    case moveToDesktop(number: Int)
    case focusWindow(title: String)
    case transformText(script: String, onClipboard: Bool)
    case browserJavaScript(source: String)
    case runWorkflow(path: String)
    case pauseShortie(seconds: Double)
    case clickButton(name: String)
    case clickMenuBarExtra(name: String)
    case distributedNotification(name: String)
    case otherRule(id: UUID?, name: String, mode: RuleMode)

    /// Repeats, if/else, waits and variables, inside "Several Actions".
    case flow(step: FlowStep)
    /// Reads the screen, finds this text, and clicks it.
    case clickText(text: String)

    /// Switches microphone or other input. The UID picks it; the name is for lists.
    case soundInput(uid: String, name: String)
    /// Pastes an item from clipboard history, 1 being the newest.
    case clipboardItem(number: Int, remove: Bool)
    /// Mouse or trackpad speed, or pointer size; with `alternate`, switches back and forth.
    case pointerSetting(setting: PointerSetting, value: Double, alternate: Double?)
    case keyboardBrightness(percent: Int)
    /// Any mouse button, with any modifier keys, one to three times.
    case customClick(click: CustomClick)

    /// Makes one key act as another, until reset or Shortie quits.
    case remapKey(from: UInt16, to: UInt16)
    /// Opens Shortie's settings at a particular page.
    case openSettingsPane(pane: String)
    /// Runs a macOS Service (Services menu) on the selected text.
    case callService(name: String)

    /// Connects or disconnects a paired Bluetooth device. The address picks it; the name is for lists.
    case bluetoothDevice(address: String, name: String, mode: ConnectMode)
    /// Sends a MIDI message (hex bytes) to a MIDI destination.
    case midi(destination: String, bytes: String)
    /// Sends an Open Sound Control message over the network.
    case osc(message: OSCMessage)
    case externalBrightness(percent: Int)
    /// Right-clicks where the pointer is and chooses the item with this name.
    case contextMenuItem(name: String)
    /// Sets (or changes, if relative) a slider in the front window.
    case slider(name: String, value: Double, relative: Bool)

    enum Kind: CaseIterable, Identifiable {
        case openApp, runShortcut, open, typeText, moveWindow, appCommand, mouseClick, system, pressKeys
        case menuItem, appleScript, shellScript, wait, steps, showMenu, restoreLayout
        case text, showMessage, speak, setVolume, soundOutput
        case appTask, setBrightness, windowFrame, moveToDisplay, movePointer
        case copyText, pasteText, notify, webRequest, inputSource, playSound, javaScript
        case pressKeysInApp, modifierKeys, moveToDesktop, focusWindow, transformText, browserJavaScript, runWorkflow, pauseShortie, clickButton, clickMenuBarExtra, distributedNotification, otherRule
        case flow, clickText
        case soundInput, clipboardItem, pointerSetting, keyboardBrightness, customClick
        case remapKey, openSettingsPane, callService
        case bluetoothDevice, midi, osc, externalBrightness, contextMenuItem, slider
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
        case .bluetoothDevice: .bluetoothDevice
        case .midi: .midi
        case .osc: .osc
        case .externalBrightness: .externalBrightness
        case .contextMenuItem: .contextMenuItem
        case .slider: .slider
        case .remapKey: .remapKey
        case .openSettingsPane: .openSettingsPane
        case .callService: .callService
        case .soundInput: .soundInput
        case .clipboardItem: .clipboardItem
        case .pointerSetting: .pointerSetting
        case .keyboardBrightness: .keyboardBrightness
        case .customClick: .customClick
        case .flow: .flow
        case .clickText: .clickText
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
        case .javaScript: .javaScript
        case .pressKeysInApp: .pressKeysInApp
        case .modifierKeys: .modifierKeys
        case .moveToDesktop: .moveToDesktop
        case .focusWindow: .focusWindow
        case .transformText: .transformText
        case .browserJavaScript: .browserJavaScript
        case .runWorkflow: .runWorkflow
        case .pauseShortie: .pauseShortie
        case .clickButton: .clickButton
        case .clickMenuBarExtra: .clickMenuBarExtra
        case .distributedNotification: .distributedNotification
        case .otherRule: .otherRule
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
        case .bluetoothDevice(let address, _, _): address
        case .midi(let destination, let bytes): destination.isEmpty || bytes.isEmpty ? "" : bytes
        case .osc(let message): message.host.isEmpty || message.address.count < 2 ? "" : message.address
        case .externalBrightness(let percent): String(percent)
        case .contextMenuItem(let name): name
        case .slider(_, let value, _): String(value)
        case .remapKey(let from, let to): from == to ? "" : "\(from)>\(to)"
        case .openSettingsPane(let pane): pane
        case .callService(let name): name
        case .soundInput(let uid, _): uid
        case .clipboardItem(let number, _): String(number)
        case .pointerSetting(let setting, _, _): setting.rawValue
        case .keyboardBrightness(let percent): String(percent)
        case .customClick(let click): click.title
        case .flow(let step): step.isComplete ? step.title : ""
        case .clickText(let text): text
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
        case .javaScript(let source): source
        case .pressKeysInApp(let combo, let path): combo == nil ? "" : path
        case .modifierKeys(let modifiers, _): modifiers.isEmpty ? "" : modifiers.symbols
        case .moveToDesktop(let number): String(number)
        case .focusWindow(let title): title
        case .transformText(let script, _): script
        case .browserJavaScript(let source): source
        case .runWorkflow(let path): path
        case .pauseShortie(let seconds): String(seconds)
        case .clickButton(let name): name
        case .clickMenuBarExtra(let name): name
        case .distributedNotification(let name): name
        case .otherRule(let id, _, _): id?.uuidString ?? ""
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
        case .externalBrightness: .externalBrightness(percent: Int(payload) ?? 50)
        case .contextMenuItem: .contextMenuItem(name: payload)
        case .openSettingsPane: .openSettingsPane(pane: payload)
        case .callService: .callService(name: payload)
        case .keyboardBrightness: .keyboardBrightness(percent: Int(payload) ?? 50)
        case .clickText: .clickText(text: payload)
        case .setBrightness: .setBrightness(percent: Int(payload) ?? 50)
        case .moveToDisplay: .moveToDisplay(number: Int(payload) ?? 1)
        case .copyText: .copyText(text: payload)
        case .pasteText: .pasteText(text: payload)
        case .notify: .notify(text: payload)
        case .playSound: .playSound(name: payload)
        case .javaScript: .javaScript(source: payload)
        case .moveToDesktop: .moveToDesktop(number: Int(payload) ?? 1)
        case .focusWindow: .focusWindow(title: payload)
        case .transformText(_, let onClipboard): .transformText(script: payload, onClipboard: onClipboard)
        case .browserJavaScript: .browserJavaScript(source: payload)
        case .runWorkflow: .runWorkflow(path: payload)
        case .pauseShortie: .pauseShortie(seconds: Double(payload) ?? 10)
        case .clickButton: .clickButton(name: payload)
        case .clickMenuBarExtra: .clickMenuBarExtra(name: payload)
        case .distributedNotification: .distributedNotification(name: payload)
        case .appTask(let task, _): .appTask(task: task, path: payload)
        // Keys and steps are edited directly (see `ActionFields`), not as text.
        case .pressKeys, .steps, .showMenu, .restoreLayout, .soundOutput,
             .bluetoothDevice,
             .midi,
             .osc,
             .slider,
             .remapKey,
             .soundInput,
             .clipboardItem,
             .pointerSetting,
             .customClick,
             .flow,
             .windowFrame, .movePointer, .webRequest, .inputSource, .pressKeysInApp, .modifierKeys, .otherRule: self
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
        case .bluetoothDevice(_, let name, let mode):
            "\(mode.title) \(name.isEmpty ? "Bluetooth Device" : name)"
        case .midi(let destination, let bytes):
            "Send MIDI \(bytes) to \(destination)"
        case .osc(let message):
            "Send OSC \(message.address)"
        case .externalBrightness(let percent):
            "Set External Display Brightness to \(percent)%"
        case .contextMenuItem(let name):
            "Right-Click and Choose “\(name)”"
        case .slider(let name, let value, let relative):
            relative ? "Change \(name.isEmpty ? "Slider" : name) by \(value.formatted())" : "Set \(name.isEmpty ? "Slider" : name) to \(value.formatted())"
        case .remapKey(let from, let to):
            "Make \(KeyRemapper.name(for: from)) Act as \(KeyRemapper.name(for: to))"
        case .openSettingsPane(let pane):
            "Open Shortie Settings: \(SettingsPane.title(of: pane))"
        case .callService(let name):
            "Run “\(name)” Service"
        case .soundInput(let uid, let name):
            uid == SoundInput.nextDeviceUID ? "Next Sound Input" : name.isEmpty ? "Sound Input" : "Record from \(name)"
        case .clipboardItem(let number, let remove):
            remove ? "Paste and Remove Clipboard Item \(number)" : "Paste Clipboard Item \(number)"
        case .pointerSetting(let setting, let value, let alternate):
            alternate.map { "Switch \(setting.title) Between \(value.formatted()) and \($0.formatted())" } ?? "Set \(setting.title) to \(value.formatted())"
        case .keyboardBrightness(let percent):
            "Set Keyboard Brightness to \(percent)%"
        case .customClick(let click):
            click.title
        case .flow(let step):
            step.title
        case .clickText(let text):
            "Click “\(text)” on Screen"
        case .appTask(let task, let path):
            task.describe(path.isEmpty ? "App" : FileManager.default.displayName(atPath: path).replacingOccurrences(of: ".app", with: ""))
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
            "Play “\(((name as NSString).lastPathComponent as NSString).deletingPathExtension)” Sound"
        case .javaScript:
            "Run JavaScript"
        case .pressKeysInApp(let combo, let path):
            "Press \(combo?.displayString ?? "Keys") in \(path.isEmpty ? "an App" : FileManager.default.displayName(atPath: path).replacingOccurrences(of: ".app", with: ""))"
        case .modifierKeys(let modifiers, let down):
            down ? "Hold \(modifiers.symbols) Down" : "Let Go of \(modifiers.symbols)"
        case .moveToDesktop(let number):
            "Move Window to Desktop \(number)"
        case .focusWindow(let title):
            "Bring “\(title)” Window Forward"
        case .transformText(_, let onClipboard):
            onClipboard ? "Change Clipboard with JavaScript" : "Change Selected Text with JavaScript"
        case .browserJavaScript:
            "Run JavaScript in Browser"
        case .runWorkflow(let path):
            "Run “\(((path as NSString).lastPathComponent as NSString).deletingPathExtension)” Workflow"
        case .pauseShortie(let seconds):
            "Pause Shortie for \(seconds.formatted()) s"
        case .clickButton(let name):
            "Click “\(name)” Button"
        case .clickMenuBarExtra(let name):
            "Click “\(name)” in Menu Bar"
        case .distributedNotification(let name):
            "Post “\(name)”"
        case .otherRule(_, let name, let mode):
            name.isEmpty ? "\(mode.title) Another Rule" : "\(mode.title) “\(name)”"
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
        // Fill in {{variables}} wherever the action carries text.
        let action = Variables.expanded(action)
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
        case .bluetoothDevice(let address, let name, let mode):
            BluetoothDevices.run(mode, address: address, name: name)
        case .midi(let destination, let bytes):
            MIDI.send(bytes, to: destination)
        case .osc(let message):
            message.send()
        case .externalBrightness(let percent):
            ExternalBrightness.set(percent)
        case .contextMenuItem(let name):
            UIAutomation.chooseContextMenuItem(name)
        case .slider(let name, let value, let relative):
            UIAutomation.setSlider(named: name, value: value, relative: relative)
        case .remapKey(let from, let to):
            KeyRemapper.remap(from: from, to: to)
        case .openSettingsPane(let pane):
            SettingsPane(rawValue: pane)?.show()
        case .callService(let name):
            Task {
                guard let text = await SelectedText.selectedText() else { NSSound.beep(); return }
                let pasteboard = NSPasteboard(name: NSPasteboard.Name("Shortie Service"))
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                guard NSPerformService(name, pasteboard) else { NSSound.beep(); return }
                // Services that change the text hand it back on the same pasteboard.
                if let result = pasteboard.string(forType: .string), result != text { ExtraActionRunner.paste(result) }
            }
        case .soundInput(let uid, let name):
            SoundInput.select(uid: uid, name: name)
        case .clipboardItem(let number, let remove):
            ClipboardItems.paste(number: number, remove: remove)
        case .pointerSetting(let setting, let value, let alternate):
            PointerSettings.apply(setting, value: value, alternate: alternate)
        case .keyboardBrightness(let percent):
            KeyboardBacklight.set(percent)
        case .customClick(let click):
            MouseClicker.perform(click)
        case .flow:
            StepRunner.run([action], target: target)
        case .clickText(let text):
            Task {
                if let point = await ScreenOCR.find(text) {
                    MouseClicker.click(at: point)
                } else {
                    HUD.show("“\(text)” Not Found", systemImage: "text.magnifyingglass")
                }
            }
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
        case .javaScript(let source):
            ScriptRunner.runJavaScript(source)
        case .pressKeysInApp(let combo, let path):
            if let combo { MoreActionKindsRunner.press(combo, inAppAt: path) }
        case .modifierKeys(let modifiers, let down):
            MoreActionKindsRunner.modifierKeys(modifiers, down: down)
        case .moveToDesktop(let number):
            if let window = target?.window ?? ActionTarget.frontmost?.window { SpaceMover.move(window, toDesktop: number) }
        case .focusWindow(let title):
            MoreActionKindsRunner.focusWindow(titled: title)
        case .transformText(let script, let onClipboard):
            MoreActionKindsRunner.transformText(script: script, onClipboard: onClipboard)
        case .browserJavaScript(let source):
            MoreActionKindsRunner.runInBrowser(source)
        case .runWorkflow(let path):
            MoreActionKindsRunner.runWorkflow(at: path)
        case .pauseShortie(let seconds):
            MoreActionKindsRunner.pause(for: seconds)
        case .clickButton(let name):
            MoreActionKindsRunner.clickButton(named: name)
        case .clickMenuBarExtra(let name):
            MoreActionKindsRunner.clickMenuBarExtra(named: name)
        case .distributedNotification(let name):
            DistributedNotificationCenter.default().postNotificationName(Notification.Name(name), object: nil, userInfo: nil, deliverImmediately: true)
        case .otherRule(let id, _, let mode):
            MoreActionKindsRunner.otherRule(id, mode: mode)
        case .steps(let actions):
            StepRunner.run(actions, target: target)
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
