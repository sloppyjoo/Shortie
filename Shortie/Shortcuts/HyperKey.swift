import AppKit
import Carbon.HIToolbox
import IOKit.hidsystem

/// What tapping Caps Lock on its own does while it's the Hyper key.
enum HyperTapAction: String, CaseIterable, Identifiable {
    /// Turns Caps Lock on or off, just as it normally would.
    case capsLock
    case escape
    case nothing

    var id: Self { self }

    var title: String {
        switch self {
        case .capsLock: "Turns Caps Lock On or Off"
        case .escape: "Presses Escape"
        case .nothing: "Does Nothing"
        }
    }
}

/// Turns Caps Lock into a "Hyper" key: hold it and every key you press gets
/// ⌃⌥⇧⌘ added, a combination no app uses, so Hyper shortcuts never clash.
/// Tapped on its own, it still works as Caps Lock (or Escape, if you prefer).
///
/// How: macOS's built-in `hidutil` tool remaps Caps Lock to F18 (a key no
/// keyboard has) while Shortie runs. `ShortcutEngine` then watches F18
/// and adds the modifiers to keys pressed while it's held. Caps Lock itself
/// is switched through IOKit, the layer under the keyboard.
final class HyperKey {
    static let shared = HyperKey()

    /// Hyper can only be held from Caps Lock, which we send as F18.
    nonisolated static let keyCode = UInt16(kVK_F18)
    nonisolated static let flags: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]

    /// A press shorter than this, with no other key pressed, counts as a tap.
    /// Karabiner-Elements' widely used default (`to_if_alone_timeout_milliseconds`).
    private static let tapTimeout: TimeInterval = 1.0

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: DefaultsKey.hyperKey) }

    private var tapAction: HyperTapAction {
        UserDefaults.standard.string(forKey: DefaultsKey.hyperTapAction).flatMap(HyperTapAction.init) ?? .capsLock
    }

    private(set) var isHeld = false
    private var pressedAt = Date.distantPast
    private var wasUsedWithAnotherKey = false
    /// Whether Caps Lock was on when you pressed it.
    private var capsLockWasOn = false

    /// Applies the Caps Lock remapping to match the setting. Call at launch and when it changes.
    func apply() {
        remapCapsLock(isEnabled)
    }

    /// Puts Caps Lock back to normal, for when Shortie quits.
    func restoreCapsLock() {
        KeyRemapper.clearAll()
    }

    /// Note: this replaces any other `hidutil` key remappings, which is fine
    /// unless you've set some up yourself with other tools.
    private func remapCapsLock(_ remap: Bool) {
        // Shared with any keys remapped by actions, since there's one list for both.
        KeyRemapper.write(hyper: remap)
    }

    /// Caps Lock (as F18) went down or up. Always swallowed: apps never see it.
    func capsLock(isDown: Bool, isRepeat: Bool) {
        if isDown {
            guard !isRepeat else { return }
            isHeld = true
            pressedAt = Date()
            wasUsedWithAnotherKey = false
            capsLockWasOn = CapsLockState.isOn
        } else {
            isHeld = false
            let wasTap = !wasUsedWithAnotherKey && Date().timeIntervalSince(pressedAt) < Self.tapTimeout
            guard wasTap else { return }
            switch tapAction {
            case .capsLock: CapsLockState.set(!capsLockWasOn)
            case .escape: KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_Escape), modifiers: [], keyName: "⎋"))
            case .nothing: break
            }
        }
    }

    /// Another key was pressed while Hyper is held, so releasing it isn't a tap.
    func noteUsed() {
        wasUsedWithAnotherKey = true
    }
}

/// Reads and sets Caps Lock (and with it, its light) through IOKit.
enum CapsLockState {
    /// A connection to the system's keyboard service, opened once and kept.
    private static let connection: io_connect_t = {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        defer { IOObjectRelease(service) }
        var connection: io_connect_t = 0
        IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connection)
        return connection
    }()

    static var isOn: Bool {
        var state = false
        IOHIDGetModifierLockState(connection, Int32(kIOHIDCapsLockState), &state)
        return state
    }

    static func set(_ on: Bool) {
        IOHIDSetModifierLockState(connection, Int32(kIOHIDCapsLockState), on)
    }
}
