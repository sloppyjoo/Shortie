import AppKit
import CoreAudio

/// Live input-device settings, through the HID event system: the part of macOS
/// that System Settings itself talks to when you move the tracking-speed slider.
enum HIDSettings {
    private typealias CreateClient = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
    private typealias SetProperty = @convention(c) (AnyObject, CFString, AnyObject) -> DarwinBoolean

    private static let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY)

    private static let client: AnyObject? = {
        guard let handle, let symbol = dlsym(handle, "IOHIDEventSystemClientCreateSimpleClient") else { return nil }
        return unsafeBitCast(symbol, to: CreateClient.self)(kCFAllocatorDefault)?.takeRetainedValue()
    }()

    @discardableResult
    static func set(_ key: String, to value: AnyObject) -> Bool {
        guard let handle, let client, let symbol = dlsym(handle, "IOHIDEventSystemClientSetProperty") else { return false }
        return unsafeBitCast(symbol, to: SetProperty.self)(client, key as CFString, value).boolValue
    }

    /// Writes a setting to the shared ("global") preferences, so it's kept after a restart.
    static func writeGlobal(_ key: String, _ type: String, _ value: String, domain: String = "-g") {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["write", domain, key, "-\(type)", value]
        try? process.run()
        process.waitUntilExit()
    }
}

/// Which pointer setting a "Pointer Setting" action changes.
nonisolated enum PointerSetting: String, Codable, CaseIterable, Identifiable {
    case mouseSpeed, trackpadSpeed, cursorSize

    var id: Self { self }

    var title: String {
        switch self {
        case .mouseSpeed: "Mouse Speed"
        case .trackpadSpeed: "Trackpad Speed"
        case .cursorSize: "Pointer Size"
        }
    }

    /// The range System Settings offers.
    var range: ClosedRange<Double> {
        switch self {
        case .mouseSpeed, .trackpadSpeed: 0...3
        case .cursorSize: 1...4
        }
    }
}

enum PointerSettings {
    private static var lastValues: [PointerSetting: Double] = [:]

    /// Sets it to `value`; or, if `alternate` is given and it's already at `value`, to `alternate`.
    static func apply(_ setting: PointerSetting, value: Double, alternate: Double?) {
        var target = value
        if let alternate, let last = lastValues[setting], abs(last - value) < 0.01 {
            target = alternate
        }
        lastValues[setting] = target

        switch setting {
        case .mouseSpeed:
            HIDSettings.set("HIDMouseAcceleration", to: NSNumber(value: Int(target * 65536)))
            HIDSettings.writeGlobal("com.apple.mouse.scaling", "float", String(target))
        case .trackpadSpeed:
            HIDSettings.set("HIDTrackpadAcceleration", to: NSNumber(value: Int(target * 65536)))
            HIDSettings.writeGlobal("com.apple.trackpad.scaling", "float", String(target))
        case .cursorSize:
            CursorSize.set(target)
        }
        HUD.show("\(setting.title) \(target.formatted(.number.precision(.fractionLength(0...2))))", systemImage: "cursorarrow.motionlines")
    }
}

/// The pointer's size, as in Accessibility › Display › Pointer.
enum CursorSize {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias SetScale = @convention(c) (Int32, Float) -> Int32

    static func set(_ scale: Double) {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
              let connection = dlsym(handle, "CGSMainConnectionID"),
              let setScale = dlsym(handle, "CGSSetCursorScale")
        else {
            NSSound.beep()
            return
        }
        let id = unsafeBitCast(connection, to: MainConnection.self)()
        _ = unsafeBitCast(setScale, to: SetScale.self)(id, Float(scale))
    }
}

/// The keyboard backlight, through the private framework the brightness keys use.
enum KeyboardBacklight {
    private static let client: NSObject? = {
        guard Bundle(path: "/System/Library/PrivateFrameworks/CoreBrightness.framework")?.load() == true,
              let type = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type
        else { return nil }
        return type.init()
    }()

    static func set(_ percent: Int) {
        let idsSelector = NSSelectorFromString("copyKeyboardBacklightIDs")
        let setSelector = NSSelectorFromString("setBrightness:forKeyboard:")
        guard let client, client.responds(to: idsSelector), client.responds(to: setSelector),
              let ids = client.perform(idsSelector)?.takeRetainedValue() as? [NSNumber], !ids.isEmpty
        else {
            NSSound.beep()
            return
        }
        typealias SetBrightness = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool
        let setBrightness = unsafeBitCast(client.method(for: setSelector), to: SetBrightness.self)
        for id in ids {
            _ = setBrightness(client, setSelector, Float(percent) / 100, id.uint64Value)
        }
        HUD.show("Keyboard Brightness \(percent)%", systemImage: "light.max")
    }
}

/// On/off settings BetterTouchTool can flip.
enum SettingToggles {
    /// "Use F1, F2, etc. keys as standard function keys".
    static func toggleFunctionKeys() {
        let on = !UserDefaults.standard.bool(forKey: "com.apple.keyboard.fnState")
        HIDSettings.set("HIDFKeyMode", to: NSNumber(value: on ? 1 : 0))
        HIDSettings.writeGlobal("com.apple.keyboard.fnState", "bool", on ? "true" : "false")
        HUD.show(on ? "F1, F2… Are Function Keys" : "F1, F2… Are Media Keys", systemImage: "fn")
    }

    static func toggleStageManager() {
        let on = !(UserDefaults(suiteName: "com.apple.WindowManager")?.bool(forKey: "GloballyEnabled") ?? false)
        HIDSettings.writeGlobal("GloballyEnabled", "bool", on ? "true" : "false", domain: "com.apple.WindowManager")
        HUD.show(on ? "Stage Manager On" : "Stage Manager Off", systemImage: "squares.leading.rectangle")
    }

    /// "Ignore built-in trackpad when mouse or wireless trackpad is present".
    static func toggleIgnoreTrackpad() {
        let on = (UserDefaults(suiteName: "com.apple.AppleMultitouchTrackpad")?.integer(forKey: "USBMouseStopsTrackpad") ?? 0) == 0
        HIDSettings.set("USBMouseStopsTrackpad", to: NSNumber(value: on ? 1 : 0))
        HIDSettings.writeGlobal("USBMouseStopsTrackpad", "int", on ? "1" : "0", domain: "com.apple.AppleMultitouchTrackpad")
        HUD.show(on ? "Trackpad Ignored While a Mouse Is Connected" : "Trackpad Always On", systemImage: "rectangle.and.hand.point.up.left")
    }
}

/// Microphones and other inputs, like `SoundOutput` for speakers.
enum SoundInput {
    nonisolated static let nextDeviceUID = "next"

    static func devices() -> [SoundOutput.Device] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            var streams = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: kAudioObjectPropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &streamSize) == noErr, streamSize > 0,
                  let uid = string(of: id, kAudioDevicePropertyDeviceUID),
                  let name = string(of: id, kAudioObjectPropertyName)
            else { return nil }
            return SoundOutput.Device(id: id, uid: uid, name: name)
        }
    }

    static func select(uid: String, name: String) {
        let devices = devices()
        let device: SoundOutput.Device?
        if uid == nextDeviceUID {
            var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var current: AudioDeviceID = 0
            var size = UInt32(MemoryLayout<AudioDeviceID>.size)
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &current)
            let index = devices.firstIndex { $0.id == current } ?? -1
            device = devices.isEmpty ? nil : devices[(index + 1) % devices.count]
        } else {
            device = devices.first { $0.uid == uid } ?? devices.first { $0.name == name }
        }
        guard let device else {
            HUD.show("\(name) Isn't Connected", systemImage: "mic.slash.fill")
            return
        }
        var id = device.id
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id)
        HUD.show(device.name, systemImage: "mic.fill")
    }

    private static func string(of id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }
}

/// A click with any button, any modifier keys, any number of times.
nonisolated struct CustomClick: Codable, Hashable {
    enum Button: String, Codable, CaseIterable, Identifiable {
        case left, right, middle, back, forward
        var id: Self { self }
        var title: String {
            switch self {
            case .left: "Left"
            case .right: "Right"
            case .middle: "Middle"
            case .back: "Back"
            case .forward: "Forward"
            }
        }
    }

    var button: Button = .left
    var modifiers: Modifiers = []
    var count = 1

    var title: String {
        let times = count == 2 ? "Double " : count == 3 ? "Triple " : ""
        let keys = modifiers.isEmpty ? "" : "\(modifiers.symbols) "
        return "\(keys)\(times)\(button.title) Click"
    }
}

/// Clipboard history entries, by position (1 is the newest).
enum ClipboardItems {
    static func paste(number: Int, remove: Bool) {
        let history = ClipboardHistory.shared
        guard history.entries.indices.contains(number - 1) else {
            NSSound.beep()
            return
        }
        let entry = history.entries[number - 1]
        history.paste(entry)
        if remove {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { history.delete(entry) }
        }
    }
}
