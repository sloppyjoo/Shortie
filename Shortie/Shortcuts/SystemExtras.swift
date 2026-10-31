import AppKit
import Carbon.HIToolbox

/// Night Shift, through the same private framework System Settings uses.
enum NightShift {
    private static let client: NSObject? = {
        guard Bundle(path: "/System/Library/PrivateFrameworks/CoreBrightness.framework")?.load() == true,
              let type = NSClassFromString("CBBlueLightClient") as? NSObject.Type
        else { return nil }
        return type.init()
    }()

    /// `nil` if this Mac can't tell (or has no Night Shift).
    static var isOn: Bool? {
        let selector = NSSelectorFromString("getBlueLightStatus:")
        guard let client, client.responds(to: selector) else { return nil }
        typealias GetStatus = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer) -> Bool
        let getStatus = unsafeBitCast(client.method(for: selector), to: GetStatus.self)
        // The status is a small C struct: { BOOL active; BOOL enabled; … }.
        let status = UnsafeMutableRawPointer.allocate(byteCount: 64, alignment: 8)
        defer { status.deallocate() }
        status.initializeMemory(as: UInt8.self, repeating: 0, count: 64)
        guard getStatus(client, selector, status) else { return nil }
        return status.load(fromByteOffset: 1, as: Bool.self)
    }

    static func set(_ on: Bool) {
        let selector = NSSelectorFromString("setEnabled:")
        guard let client, client.responds(to: selector) else {
            NSSound.beep()
            return
        }
        typealias SetEnabled = @convention(c) (AnyObject, Selector, Bool) -> Bool
        let setEnabled = unsafeBitCast(client.method(for: selector), to: SetEnabled.self)
        _ = setEnabled(client, selector, on)
        HUD.show(on ? "Night Shift On" : "Night Shift Off", systemImage: on ? "moon.circle.fill" : "moon.circle")
    }

    static func toggle() {
        set(!(isOn ?? false))
    }
}

/// Bluetooth on or off, through the functions System Settings uses.
enum Bluetooth {
    private typealias GetPower = @convention(c) () -> Int32
    private typealias SetPower = @convention(c) (Int32) -> Void

    private static let handle = dlopen("/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth", RTLD_LAZY)

    static func toggle() {
        guard let handle,
              let get = dlsym(handle, "IOBluetoothPreferenceGetControllerPowerState"),
              let set = dlsym(handle, "IOBluetoothPreferenceSetControllerPowerState")
        else {
            NSSound.beep()
            return
        }
        let isOn = unsafeBitCast(get, to: GetPower.self)() != 0
        unsafeBitCast(set, to: SetPower.self)(isOn ? 0 : 1)
        HUD.show(isOn ? "Bluetooth Off" : "Bluetooth On", systemImage: "antenna.radiowaves.left.and.right")
    }
}

enum DisplayMirroring {
    /// Mirrors every display to the main one, or stops mirroring if they already are.
    static func toggle() {
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetOnlineDisplayList(UInt32(displays.count), &displays, &count)
        let online = Array(displays.prefix(Int(count)))
        guard online.count > 1 else {
            NSSound.beep()
            return
        }
        let main = CGMainDisplayID()
        let isMirrored = online.contains { CGDisplayIsInMirrorSet($0) != 0 }
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return }
        for display in online where display != main {
            CGConfigureDisplayMirrorOfDisplay(config, display, isMirrored ? kCGNullDirectDisplay : main)
        }
        CGCompleteDisplayConfiguration(config, .permanently)
    }
}

/// Moves a window to the Space beside it, the way you would by hand: hold
/// its title bar and press ⌃← or ⌃→ (macOS's "Move left/right a space").
enum SpaceMover {
    static func move(_ window: AXUIElement, right: Bool) {
        guard let frame = WindowMover.shared.frame(of: window) else {
            NSSound.beep()
            return
        }
        // Just right of the window's buttons is safely on the title bar.
        var grab = CGPoint(x: frame.minX + 90, y: frame.minY + 12)
        if let zoom = AX.element(window, kAXZoomButtonAttribute), let button = WindowMover.shared.frame(of: zoom) {
            grab = CGPoint(x: button.maxX + 24, y: button.midY)
        }
        let pointer = CGEvent(source: nil)?.location
        Task {
            post(.leftMouseDown, at: grab)
            try? await Task.sleep(for: .milliseconds(120))
            KeyPresser.press(
                KeyCombo(keyCode: UInt16(right ? kVK_RightArrow : kVK_LeftArrow), modifiers: .control, keyName: right ? "→" : "←"),
                extraFlags: [.maskSecondaryFn, .maskNumericPad]
            )
            try? await Task.sleep(for: .milliseconds(450))
            post(.leftMouseUp, at: grab)
            if let pointer { post(.mouseMoved, at: pointer) }
        }
    }

    private static func post(_ type: CGEventType, at point: CGPoint) {
        let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
        event?.setIntegerValueField(.eventSourceUserData, value: SyntheticEvent.marker)
        event?.post(tap: .cghidEventTap)
    }
}
