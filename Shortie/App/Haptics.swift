import AppKit

/// Little taps on a Force Touch trackpad, so you can feel that something happened.
/// They're only felt while a finger is on the trackpad, so they're used for things
/// you do with the trackpad: gestures, window-button clicks and snapping windows.
///
/// macOS's own haptics API only works for the app you're using, and Shortie works
/// in the background, so the taps go straight to the trackpad's actuator (the motor
/// behind its click), as other trackpad tools do. If that isn't available, Shortie
/// falls back to the standard API.
enum Haptics {
    enum Strength: Int, CaseIterable, Identifiable {
        case light = 1, medium, firm
        var id: Self { self }

        var title: String {
            switch self {
            case .light: "Light"
            case .medium: "Medium"
            case .firm: "Firm"
            }
        }

        /// The actuator's own patterns, from weakest to strongest.
        fileprivate var actuationID: Int32 {
            switch self {
            case .light: 3
            case .medium: 4
            case .firm: 6
            }
        }
    }

    static var isOn: Bool {
        UserDefaults.standard.object(forKey: DefaultsKey.haptics) as? Bool ?? true
    }

    static var strength: Strength {
        Strength(rawValue: UserDefaults.standard.integer(forKey: DefaultsKey.hapticStrength)) ?? .medium
    }

    /// A gesture or window-button click ran its action.
    static func actionRan() {
        guard isOn else { return }
        tap(strength)
    }

    /// A dragged window moved onto (or off) a snap zone. One step lighter, like a detent.
    static func snapZoneChanged() {
        guard isOn else { return }
        tap(Strength(rawValue: strength.rawValue - 1) ?? .light)
    }

    /// Taps once at this strength, whether or not haptics are switched on, so you
    /// can feel the setting as you choose it.
    static func tap(_ strength: Strength) {
        if !Actuators.shared.actuate(strength.actuationID) {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
    }
}

/// One open actuator per trackpad (built in, and Magic Trackpad if connected).
private final class Actuators {
    static let shared = Actuators()

    private var actuators: [UnsafeMutableRawPointer] = []
    private var actuate: MTActuatorActuateFunction?
    private var lastLookup = Date.distantPast

    /// Taps every trackpad; only the one you're touching is felt. Returns whether it worked.
    func actuate(_ actuationID: Int32) -> Bool {
        // Look for trackpads again if none were found, now and then, in case one was connected.
        if actuators.isEmpty, Date().timeIntervalSince(lastLookup) > 10 { findTrackpads() }
        guard let actuate, !actuators.isEmpty else { return false }
        var worked = false
        for actuator in actuators where actuate(actuator, actuationID, 0, 0, 2) == 0 {
            worked = true
        }
        if !worked { actuators = [] }
        return worked
    }

    private func findTrackpads() {
        lastLookup = Date()
        guard
            let framework = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW),
            let createList = dlsym(framework, "MTDeviceCreateList").map({ unsafeBitCast($0, to: MTDeviceCreateListFunction.self) }),
            let getID = dlsym(framework, "MTDeviceGetDeviceID").map({ unsafeBitCast($0, to: MTDeviceGetDeviceIDFunction.self) }),
            let create = dlsym(framework, "MTActuatorCreateFromDeviceID").map({ unsafeBitCast($0, to: MTActuatorCreateFromDeviceIDFunction.self) }),
            let open = dlsym(framework, "MTActuatorOpen").map({ unsafeBitCast($0, to: MTActuatorOpenFunction.self) }),
            let actuate = dlsym(framework, "MTActuatorActuate").map({ unsafeBitCast($0, to: MTActuatorActuateFunction.self) }),
            let list = createList()?.takeRetainedValue()
        else { return }

        self.actuate = actuate
        for index in 0..<CFArrayGetCount(list) {
            guard let pointer = CFArrayGetValueAtIndex(list, index) else { continue }
            var deviceID: UInt64 = 0
            guard getID(UnsafeMutableRawPointer(mutating: pointer), &deviceID) == 0, deviceID != 0,
                  let actuator = create(deviceID), open(actuator) == 0
            else { continue }
            actuators.append(actuator)
        }
    }
}
