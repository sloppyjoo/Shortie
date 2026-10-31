import AppKit

/// Spots taps of a modifier key on its own, like double-tapping ⌘ or tapping
/// right ⌥, and runs the matching shortcut.
///
/// A tap only counts when the key goes down with no other modifier held, comes
/// back up quickly, and nothing else (a key, a click) happens in between. So
/// ⌘C, ⌘-click and holding ⇧ to type capitals never set one off. The key itself
/// always reaches your apps as normal.
final class ModifierTapDetector {
    static let shared = ModifierTapDetector()

    /// Longest a key can be held and still count as a tap.
    private let maxHold: TimeInterval = 0.3
    /// Longest gap between the two taps of a double tap.
    private let maxGap: TimeInterval = 0.35

    private struct Press {
        let key: ModifierTap.Key
        let side: ModifierTap.Side
        let time: TimeInterval
        let clicks: UInt32
    }

    /// The key that's down right now, while it could still become a tap.
    private var press: Press?
    /// The last tap, while a second one could still make it a double tap.
    private var lastTap: Press?
    /// A single tap waiting to see whether a second tap follows.
    private var pendingSingle: DispatchWorkItem?

    /// Called for every modifier key going down or up.
    func flagsChanged(keyCode: UInt16, flags: CGEventFlags) {
        guard let (key, side) = Self.keys[keyCode] else {
            reset()
            return
        }
        let isDown = flags.rawValue & Self.deviceMask(key: key, side: side) != 0
        let now = ProcessInfo.processInfo.systemUptime

        if isDown {
            // Another modifier is already held, so this is a combination, not a tap.
            let others = Self.allModifiers.subtracting(Self.flag(for: key))
            if press != nil || !flags.intersection(others).isEmpty {
                reset()
                return
            }
            press = Press(key: key, side: side, time: now, clicks: Self.clickCount())
            return
        }

        defer { press = nil }
        guard let press, press.key == key, press.side == side,
              now - press.time <= maxHold, Self.clickCount() == press.clicks
        else { return }

        if let lastTap, lastTap.key == key, lastTap.side == side, now - lastTap.time <= maxGap + maxHold {
            self.lastTap = nil
            pendingSingle?.cancel()
            pendingSingle = nil
            fire(key: key, side: side, taps: 2)
            return
        }

        lastTap = press
        pendingSingle?.cancel()
        // If a double tap of this key does something, wait to see whether this is one.
        if hasShortcut(key: key, side: side, taps: 2) {
            let work = DispatchWorkItem { [weak self] in
                self?.pendingSingle = nil
                self?.fire(key: key, side: side, taps: 1)
            }
            pendingSingle = work
            DispatchQueue.main.asyncAfter(deadline: .now() + maxGap, execute: work)
        } else {
            fire(key: key, side: side, taps: 1)
        }
    }

    /// Any ordinary key press means the modifier was being used for something else.
    func keyPressed() {
        reset()
    }

    private func reset() {
        press = nil
        lastTap = nil
        pendingSingle?.cancel()
        pendingSingle = nil
    }

    private func hasShortcut(key: ModifierTap.Key, side: ModifierTap.Side, taps: Int) -> Bool {
        ShortcutStore.shared.shortcuts.contains {
            $0.isEnabled && $0.modifierTap?.matches(key: key, side: side, taps: taps) == true
        }
    }

    private func fire(key: ModifierTap.Key, side: ModifierTap.Side, taps: Int) {
        guard !ShortcutEngine.shared.isRecording else { return }
        let tap = ModifierTap(key: key, side: side, taps: taps)
        guard let shortcut = ShortcutStore.shared.match(.modifierTap(tap: tap), in: FrontmostApp.bundleID) else { return }
        // While paused, the only shortcut that works is the one that resumes.
        if UserDefaults.standard.bool(forKey: DefaultsKey.isPaused), shortcut.action != .system(action: .togglePause) { return }
        ActionRunner.run(shortcut.action)
    }

    // MARK: - Keys

    /// Which key each key code is.
    private static let keys: [UInt16: (ModifierTap.Key, ModifierTap.Side)] = [
        55: (.command, .left), 54: (.command, .right),
        58: (.option, .left), 61: (.option, .right),
        59: (.control, .left), 62: (.control, .right),
        56: (.shift, .left), 60: (.shift, .right),
        63: (.function, .either), 179: (.function, .either),
    ]

    private static let allModifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift, .maskSecondaryFn]

    private static func flag(for key: ModifierTap.Key) -> CGEventFlags {
        switch key {
        case .command: .maskCommand
        case .option: .maskAlternate
        case .control: .maskControl
        case .shift: .maskShift
        case .function: .maskSecondaryFn
        }
    }

    /// The bit macOS sets while this exact key (left or right) is held.
    private static func deviceMask(key: ModifierTap.Key, side: ModifierTap.Side) -> UInt64 {
        switch (key, side) {
        case (.control, .right): 0x2000
        case (.control, _): 0x0001
        case (.shift, .right): 0x0004
        case (.shift, _): 0x0002
        case (.command, .right): 0x0010
        case (.command, _): 0x0008
        case (.option, .right): 0x0040
        case (.option, _): 0x0020
        case (.function, _): CGEventFlags.maskSecondaryFn.rawValue
        }
    }

    /// How many mouse clicks there have been since the Mac started, so a
    /// ⌘-click while the key was down can be noticed without watching the mouse.
    private static func clickCount() -> UInt32 {
        [CGEventType.leftMouseDown, .rightMouseDown, .otherMouseDown].reduce(0) {
            $0 &+ CGEventSource.counter(forEventType: .combinedSessionState, eventType: $1)
        }
    }
}
