import AppKit

/// One rule from a BetterTouchTool preset, and what importing it will do.
struct ImportItem: Identifiable {
    enum Outcome {
        case ready
        /// Something you already have uses the same trigger.
        case clash(String)
        /// Shortie can't do this yet; the reason says what's missing.
        case unsupported(String)
    }

    let id = UUID()
    /// Like "⌃⌥← → Left Half", or BetterTouchTool's own names when Shortie can't read it.
    let summary: String
    let shortcut: Shortcut?
    var outcome: Outcome
}

/// Reads BetterTouchTool presets (`.bttpreset` files, which are JSON) and turns
/// their rules into Shortie shortcuts. The trigger and action numbers come from
/// BetterTouchTool's documentation:
/// https://docs.folivora.ai/docs/json/trigger-definitions/ and
/// https://docs.folivora.ai/docs/actions/action-definitions/
enum BTTImport {
    struct NotAPreset: LocalizedError {
        var errorDescription: String? { "This isn't a BetterTouchTool preset file." }
    }

    /// Every rule in the preset, checked against the shortcuts you already have.
    static func read(_ data: Data, existing: [Shortcut]) throws -> [ImportItem] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let groups = root["BTTPresetContent"] as? [[String: Any]]
        else { throw NotAPreset() }

        var items: [ImportItem] = []
        for group in groups {
            let bundleID = group["BTTAppBundleIdentifier"] as? String
            // "BT.G" is BetterTouchTool's name for "every app".
            let scope = (bundleID == nil || bundleID == "BT.G") ? nil : AppScope(mode: .only, bundleIDs: [bundleID!])
            let appName = scope == nil ? nil : group["BTTAppName"] as? String
            for trigger in flatten(group["BTTTriggers"] as? [[String: Any]] ?? []) {
                items.append(item(for: trigger, scope: scope, appName: appName))
            }
        }
        return checkClashes(items, existing: existing)
    }

    /// The name the preset was saved with, if it has one.
    static func presetName(_ data: Data) -> String? {
        let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (root?["BTTPresetName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Folders (type 630) hold their rules inside them.
    private static func flatten(_ triggers: [[String: Any]]) -> [[String: Any]] {
        triggers.flatMap { trigger -> [[String: Any]] in
            if int(trigger["BTTTriggerType"]) == 630 {
                return flatten(trigger["BTTAdditionalActions"] as? [[String: Any]] ?? [])
            }
            return [trigger]
        }
    }

    private static func item(for dict: [String: Any], scope: AppScope?, appName: String?) -> ImportItem {
        let place = appName.map { " (in \($0))" } ?? ""
        switch (trigger(from: dict), action(from: dict)) {
        case let (.success(trigger), .success(action)):
            let shortcut = Shortcut(trigger: trigger, action: action, isEnabled: int(dict["BTTEnabled"]) != 0, apps: scope)
            return ImportItem(summary: "\(label(for: trigger)) → \(action.title)\(place)", shortcut: shortcut, outcome: .ready)
        case let (.failure(reason), _), let (_, .failure(reason)):
            return ImportItem(summary: bttSummary(dict) + place, shortcut: nil, outcome: .unsupported(reason.text))
        }
    }

    /// Marks rules whose trigger you already use, or that appear twice in the preset.
    private static func checkClashes(_ items: [ImportItem], existing: [Shortcut]) -> [ImportItem] {
        var taken = existing.filter(\.isEnabled)
        return items.map { item in
            guard case .ready = item.outcome, let shortcut = item.shortcut, let trigger = shortcut.trigger else { return item }
            if let other = taken.first(where: { $0.trigger?.clashes(with: trigger) == true && ShortcutStore.scopesOverlap($0.apps, shortcut.apps) }) {
                var item = item
                item.outcome = .clash("You already use this for “\(other.action.title)”.")
                return item
            }
            taken.append(shortcut)
            return item
        }
    }

    // MARK: - Triggers

    private struct Reason: Error {
        let text: String
    }

    private static func trigger(from dict: [String: Any]) -> Result<Trigger, Reason> {
        let type = int(dict["BTTTriggerType"])
        let kind = dict["BTTTriggerClass"] as? String ?? ""
        let modifiers = Modifiers(NSEvent.ModifierFlags(rawValue: UInt(max(int(dict["BTTShortcutModifierKeys"]), 0))))

        switch kind {
        case "BTTTriggerTypeKeyboardShortcut":
            let keyCode = int(dict["BTTShortcutKeyCode"])
            guard type == 0, keyCode >= 0 else { return .failure(Reason(text: "Shortie can't read this kind of keyboard trigger yet.")) }
            let code = UInt16(keyCode)
            return .success(.keys(combo: KeyCombo(keyCode: code, modifiers: modifiers, keyName: KeyNames.name(for: code))))

        case let kind where kind.hasPrefix("BTTTriggerTypeTouchpad"):
            guard let gesture = gestures[type] else { return .failure(Reason(text: "This trackpad gesture isn't in Shortie yet.")) }
            return .success(.gesture(gesture: gesture))

        case "BTTTriggerTypeNormalMouse":
            // 1000 + the button's number; Shortie handles the extra buttons (3 and up).
            guard (1002...1009).contains(type) else { return .failure(Reason(text: "This mouse trigger isn't in Shortie yet.")) }
            let required = Modifiers(NSEvent.ModifierFlags(rawValue: UInt(max(int(dict["BTTRequiredModifierKeys"]), 0))))
            return .success(.mouseButton(click: MouseButtonClick(button: type - 1000, modifiers: modifiers.union(required))))

        case "BTTTriggerTypeOtherTriggers":
            if let click = windowButtons[type] {
                return .success(.trafficLight(click: click))
            }
            if let event = event(type: type, dict: dict) {
                return event
            }
            return .failure(Reason(text: "This trigger isn't in Shortie yet."))

        default:
            return .failure(Reason(text: categoryReasons[kind] ?? "This kind of trigger isn't in Shortie yet."))
        }
    }

    private static func event(type: Int, dict: [String: Any]) -> Result<Trigger, Reason>? {
        let simple: [Int: AutomationEvent] = [
            605: .macWillSleep, 606: .macWoke, 738: .screenLocked, 739: .screenUnlocked,
            798: .chargerConnected, 799: .chargerDisconnected,
            736: .screenSaverStarted, 737: .screenSaverStopped, 815: .spaceChanged,
            792: .displayConnected, 793: .displayDisconnected,
        ]
        if let event = simple[type] { return .success(.event(event: event)) }

        let appEvents: [Int: (String) -> AutomationEvent] = [
            670: { .appLaunched(bundleID: $0) }, 671: { .appActivated(bundleID: $0) }, 672: { .appDeactivated(bundleID: $0) },
            673: { .appQuit(bundleID: $0) },
        ]
        guard let make = appEvents[type] else { return nil }
        // The app is given as a file URL, like "file:///Applications/Safari.app/".
        guard let location = dict["BTTAdditionalConfiguration"] as? String,
              let bundleID = appBundleID(location)
        else { return .failure(Reason(text: "Shortie couldn't find the app this trigger watches.")) }
        return .success(.event(event: make(bundleID)))
    }

    private static let gestures: [Int: Gesture] = [
        // Taps, double taps, tap and hold
        173: .tap(fingers: 2), 104: .tap(fingers: 3), 110: .tap(fingers: 4), 111: .tap(fingers: 5),
        179: .doubleTap(fingers: 2), 163: .doubleTap(fingers: 3), 169: .doubleTap(fingers: 4),
        222: .tapAndHold(fingers: 2), 223: .tapAndHold(fingers: 3), 224: .tapAndHold(fingers: 4), 225: .tapAndHold(fingers: 5),
        // TipTaps
        113: .tipTap(resting: 1, side: .left), 114: .tipTap(resting: 1, side: .right),
        132: .tipTap(resting: 2, side: .left), 133: .tipTap(resting: 2, side: .right),
        // Swipes
        100: .swipe(fingers: 3, direction: .left), 101: .swipe(fingers: 3, direction: .right),
        102: .swipe(fingers: 3, direction: .up), 103: .swipe(fingers: 3, direction: .down),
        105: .swipe(fingers: 4, direction: .left), 106: .swipe(fingers: 4, direction: .right),
        107: .swipe(fingers: 4, direction: .down), 108: .swipe(fingers: 4, direction: .up),
        128: .swipe(fingers: 5, direction: .left), 129: .swipe(fingers: 5, direction: .right),
        130: .swipe(fingers: 5, direction: .down), 131: .swipe(fingers: 5, direction: .up),
        // Two fingers in from an edge
        165: .edgeSwipe(fingers: 2, edge: .left), 166: .edgeSwipe(fingers: 2, edge: .right),
        167: .edgeSwipe(fingers: 2, edge: .top), 168: .edgeSwipe(fingers: 2, edge: .bottom),
        // Clicks
        174: .click(fingers: 2), 112: .click(fingers: 3), 121: .click(fingers: 4), 141: .click(fingers: 5),
        157: .cornerClick(corner: .bottomLeft), 158: .cornerClick(corner: .bottomRight),
        182: .cornerClick(corner: .topLeft), 183: .cornerClick(corner: .topRight),
        203: .forceClick,
        // Pinches with the thumb (thumb plus 2, 3 or 4 fingers)
        197: .pinch(fingers: 3, direction: .in), 198: .pinch(fingers: 3, direction: .out),
        194: .pinch(fingers: 4, direction: .in), 195: .pinch(fingers: 4, direction: .out),
        200: .pinch(fingers: 5, direction: .in), 201: .pinch(fingers: 5, direction: .out),
        // Rotation
        117: .rotate(direction: .left), 118: .rotate(direction: .right),
    ]

    private static let windowButtons: [Int: TrafficLightClick] = [
        622: TrafficLightClick(button: .close, mouseButton: .left, modifiers: []),
        621: TrafficLightClick(button: .minimize, mouseButton: .left, modifiers: []),
        615: TrafficLightClick(button: .zoom, mouseButton: .left, modifiers: []),
        601: TrafficLightClick(button: .close, mouseButton: .right, modifiers: []),
        602: TrafficLightClick(button: .minimize, mouseButton: .right, modifiers: []),
        603: TrafficLightClick(button: .zoom, mouseButton: .right, modifiers: []),
        626: TrafficLightClick(button: .close, mouseButton: .middle, modifiers: []),
        625: TrafficLightClick(button: .minimize, mouseButton: .middle, modifiers: []),
        628: TrafficLightClick(button: .zoom, mouseButton: .middle, modifiers: []),
    ]

    private static let categoryReasons: [String: String] = [
        "BTTTriggerTypeKeySequence": "Key sequences aren't in Shortie yet.",
        "BTTTriggerTypeMagicMouse": "Magic Mouse gestures aren't in Shortie yet.",
        "BTTTriggerTypeDrawings": "Drawings aren't in Shortie yet.",
        "BTTTriggerTypeTouchBar": "Touch Bar items aren't in Shortie yet.",
        "BTTTriggerTypeNotchBar": "Notch bar items aren't in Shortie yet.",
        "BTTTriggerTypeFloatingMenu": "Floating menus aren't in Shortie yet. Custom Menus can do some of the same.",
        "BTTTriggerTypeStreamDeck": "Stream Deck isn't supported yet.",
        "BTTTriggerTypeSiriRemote": "The Siri Remote isn't supported yet.",
        "BTTTriggerTypeBTTRemote": "The BTT Remote app isn't supported.",
        "BTTTriggerTypeMIDI": "MIDI isn't supported yet.",
        "BTTTriggerTypeGamepad": "Gamepads aren't supported yet.",
        "BTTTriggerTypeGenericDevice": "Generic devices aren't supported yet.",
    ]

    // MARK: - Actions

    /// The main action, plus any further actions chained after it.
    private static func action(from dict: [String: Any]) -> Result<ShortcutAction, Reason> {
        var steps: [ShortcutAction] = []
        var chained: [[String: Any]] = [dict]
        chained += dict["BTTActionsToExecute"] as? [[String: Any]] ?? []
        chained += dict["BTTAdditionalActions"] as? [[String: Any]] ?? []

        for (index, step) in chained.enumerated() {
            switch single(step) {
            case .success(let action?):
                steps.append(action)
            case .success(nil):
                // The trigger itself may hold no action when its actions are all in the list.
                if index == 0 { continue }
            case .failure(let reason):
                return .failure(reason)
            }
            if let delay = double(step["BTTDelayNextActionBy"]), delay > 0 {
                steps.append(.wait(seconds: delay))
            }
        }
        while case .wait = steps.last { steps.removeLast() }

        switch steps.count {
        case 0: return .failure(Reason(text: "This rule has no action Shortie can read."))
        case 1: return .success(steps[0])
        default: return .success(.steps(actions: steps))
        }
    }

    /// One action, `nil` if there's none here.
    private static func single(_ dict: [String: Any]) -> Result<ShortcutAction?, Reason> {
        let type = int(dict["BTTPredefinedActionType"])
        if let action = simpleActions[type] { return .success(action) }
        let extra = dict["BTTAdditionalActionData"] as? [String: Any] ?? [:]

        switch type {
        case 49:
            guard let location = dict["BTTLaunchPath"] as? String, !location.isEmpty else { break }
            let path = URL(string: location).flatMap { $0.isFileURL ? $0.path : nil } ?? location
            return .success(path.hasSuffix(".app") || path.hasSuffix(".app/") ? .openApp(path: path) : .open(target: path))
        case 193, 118:
            if let text = dict["BTTStringToType"] as? String { return .success(.typeText(text: text)) }
        case 172, 195:
            if let source = (dict["BTTInlineAppleScript"] as? String) ?? (extra["BTTAppleScriptString"] as? String) {
                return .success(.appleScript(source: source))
            }
        case 137, 246:
            if let command = dict["BTTTerminalCommand"] as? String { return .success(.shellScript(source: command)) }
        case 206:
            if let script = dict["BTTShellTaskActionScript"] as? String { return .success(.shellScript(source: script)) }
        case 295:
            if let name = (dict["BTTShortcutName"] as? String) ?? (dict["BTTGenericActionConfig"] as? String), !name.isEmpty {
                return .success(.runShortcut(name: name))
            }
        case 373:
            if let value = double(dict["BTTGenericActionConfig"]) {
                // Saved as 0–1 or 0–100.
                return .success(.setVolume(percent: Int((value <= 1 ? value * 100 : value).rounded())))
            }
        case 129, 345:
            if let seconds = double(dict["BTTDelayNextActionBy"]) ?? double(dict["BTTGenericActionConfig"]) {
                return .success(.wait(seconds: seconds))
            }
        case 124:
            if let path = dict["BTTMenubarPath"] as? String, !path.isEmpty {
                return .success(.menuItem(path: path.replacingOccurrences(of: ";", with: " › ")))
            }
        default:
            break
        }

        // Older presets send keys or open URLs without an action number.
        if let keys = dict["BTTShortcutToSend"] as? String, !keys.isEmpty {
            guard let combo = keyCombo(fromSendString: keys) else { return .failure(Reason(text: "Shortie couldn't read the keys this sends.")) }
            return .success(.pressKeys(combo: combo))
        }
        if let url = dict["BTTOpenURL"] as? String, !url.isEmpty {
            return .success(.open(target: url))
        }
        if type < 0 || type == 366 { return .success(nil) }

        let name = dict["BTTPredefinedActionName"] as? String ?? "This action"
        return .failure(Reason(text: "“\(name)” isn't in Shortie yet."))
    }

    private static let simpleActions: [Int: ShortcutAction] = [
        // Windows
        19: .moveWindow(position: .leftHalf), 20: .moveWindow(position: .rightHalf), 21: .moveWindow(position: .maximize),
        90: .moveWindow(position: .topLeft), 92: .moveWindow(position: .topRight),
        91: .moveWindow(position: .bottomLeft), 93: .moveWindow(position: .bottomRight),
        108: .moveWindow(position: .leftThird), 109: .moveWindow(position: .centerThird), 110: .moveWindow(position: .rightThird),
        174: .moveWindow(position: .leftTwoThirds), 175: .moveWindow(position: .rightTwoThirds),
        96: .moveWindow(position: .topHalf), 95: .moveWindow(position: .bottomHalf),
        97: .moveWindow(position: .center), 47: .moveWindow(position: .nextDisplay), 84: .moveWindow(position: .restore),
        99: .system(action: .windowSwitcher), 100: .system(action: .windowSwitcher),
        102: .appCommand(command: .closePointerWindow), 106: .appCommand(command: .minimizePointerWindow),
        107: .appCommand(command: .zoomPointerWindow), 204: .appCommand(command: .raisePointerWindow),
        247: .appCommand(command: .quitPointerApp), 294: .appCommand(command: .hidePointerApp),
        560: .appCommand(command: .closeWindowOrQuit),
        113: .system(action: .spaceLeft), 114: .system(action: .spaceRight),
        50: .system(action: .hideAllApps), 488: .system(action: .showAllApps), 367: .system(action: .previousApp),
        // System
        13: .system(action: .sleepDisplay), 14: .system(action: .sleep), 15: .system(action: .logOut),
        158: .system(action: .lockScreen), 202: .system(action: .screenSaver), 197: .system(action: .toggleDarkMode),
        16: .system(action: .toggleHiddenFiles), 45: .system(action: .showDesktop), 122: .system(action: .notificationCentre),
        290: .system(action: .controlCentre), 167: .system(action: .emojiAndSymbols), 30: .system(action: .ejectAll),
        5: .system(action: .missionControl), 6: .system(action: .appExpose), 115: .system(action: .apps),
        105: .system(action: .openDashboard), 101: .system(action: .togglePause),
        169: .system(action: .screenshotTool), 263: .system(action: .screenshotTool),
        203: .system(action: .clipboardHistory), 480: .system(action: .clipboardHistory),
        170: .system(action: .screenshotWindow), 498: .system(action: .copyTextFromScreen), 546: .system(action: .pickColour),
        173: .system(action: .siri), 156: .system(action: .emptyTrash), 194: .system(action: .toggleCapsLock),
        // Media, sound, display
        23: .system(action: .playPause), 27: .system(action: .nextTrack), 26: .system(action: .previousTrack),
        24: .system(action: .volumeUp), 25: .system(action: .volumeDown), 22: .system(action: .mute),
        585: .system(action: .toggleMicrophone), 28: .system(action: .brightnessUp), 29: .system(action: .brightnessDown),
        31: .system(action: .keyboardBrightnessUp), 32: .system(action: .keyboardBrightnessDown),
        198: .system(action: .volumeUpSmall), 199: .system(action: .volumeDownSmall),
        259: .system(action: .brightnessUpSmall), 260: .system(action: .brightnessDownSmall),
        // Mouse
        3: .mouseClick(click: .leftClick), 4: .mouseClick(click: .rightClick),
        1: .mouseClick(click: .middleClick), 54: .mouseClick(click: .doubleClick),
        // Text
        58: .text(action: .searchWeb),
    ]

    /// BetterTouchTool writes keys to press as key numbers, like "59,58,123" for ⌃⌥←.
    private static func keyCombo(fromSendString string: String) -> KeyCombo? {
        let modifierKeys: [Int: Modifiers] = [
            55: .command, 54: .command, 56: .shift, 60: .shift, 58: .option, 61: .option, 59: .control, 62: .control,
        ]
        var modifiers: Modifiers = []
        var key: UInt16?
        for part in string.split(separator: ",") {
            guard let code = Int(part.trimmingCharacters(in: .whitespaces)) else { continue }
            if let modifier = modifierKeys[code] {
                modifiers.insert(modifier)
            } else if code != 63 { // 63 is fn
                key = UInt16(code)
            }
        }
        return key.map { KeyCombo(keyCode: $0, modifiers: modifiers, keyName: KeyNames.name(for: $0)) }
    }

    // MARK: - Describing

    private static func label(for trigger: Trigger) -> String {
        switch trigger {
        case .keys(let combo): combo.displayString
        case .gesture(let gesture): gesture.title
        case .mouseButton(let click): click.title
        case .trafficLight(let click): "\(click.clickDescription) \(click.button.title)"
        case .typedText(let abbreviation): abbreviation
        case .event(let event): event.kind.title
        case .modifierTap(let tap): tap.title
        }
    }

    /// BetterTouchTool's own description of a rule it has and Shortie can't read.
    private static func bttSummary(_ dict: [String: Any]) -> String {
        let trigger = [dict["BTTTouchBarButtonName"], dict["BTTWidgetName"], dict["BTTStreamDeckButtonName"], dict["BTTTriggerName"], dict["BTTTriggerTypeDescription"]]
            .compactMap { $0 as? String }
            .first { !$0.isEmpty } ?? "Trigger \(int(dict["BTTTriggerType"]))"
        let action = (dict["BTTPredefinedActionName"] as? String).map { " → \($0)" } ?? ""
        return trigger + action
    }

    // MARK: - Reading values

    private static func appBundleID(_ location: String) -> String? {
        let url = URL(string: location).flatMap { $0.isFileURL ? $0 : nil } ?? URL(fileURLWithPath: location)
        return Bundle(url: url)?.bundleIdentifier
    }

    private static func int(_ value: Any?) -> Int {
        switch value {
        case let number as NSNumber: number.intValue
        case let string as String: Int(string) ?? -1
        default: -1
        }
    }

    private static func double(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber: number.doubleValue
        case let string as String: Double(string)
        default: nil
        }
    }
}
