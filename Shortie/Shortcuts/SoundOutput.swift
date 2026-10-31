import AppKit
import CoreAudio

/// Speakers and headphones, through Core Audio: the part of macOS that
/// manages sound devices. Choosing one here is the same as choosing it in
/// Control Centre's Sound menu.
enum SoundOutput {
    struct Device: Identifiable, Hashable {
        let id: AudioDeviceID
        /// Stays the same across restarts and reconnections, unlike `id`.
        let uid: String
        let name: String
    }

    /// Saved in place of a device's UID to mean "whichever comes next".
    nonisolated static let nextDeviceUID = "next"

    /// Everything that can play sound right now.
    static func devices() -> [Device] {
        var address = Self.address(kAudioHardwarePropertyDevices)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }

        return ids.compactMap { id in
            guard hasOutput(id),
                  let uid = string(of: id, kAudioDevicePropertyDeviceUID),
                  let name = string(of: id, kAudioObjectPropertyName)
            else { return nil }
            return Device(id: id, uid: uid, name: name)
        }
    }

    /// Switches to the device with this UID (or, failing that, this name).
    static func select(uid: String, name: String) {
        let devices = devices()
        let device: Device?
        if uid == nextDeviceUID {
            let current = devices.firstIndex { $0.id == currentDeviceID() } ?? -1
            device = devices.isEmpty ? nil : devices[(current + 1) % devices.count]
        } else {
            device = devices.first { $0.uid == uid } ?? devices.first { $0.name == name }
        }
        guard let device else {
            HUD.show("\(name) Isn't Connected", systemImage: "speaker.slash.fill")
            return
        }

        var id = device.id
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let system = AudioObjectID(kAudioObjectSystemObject)
        // Both music and alert sounds, as System Settings does.
        for selector in [kAudioHardwarePropertyDefaultOutputDevice, kAudioHardwarePropertyDefaultSystemOutputDevice] {
            var address = Self.address(selector)
            AudioObjectSetPropertyData(system, &address, 0, nil, size, &id)
        }
        HUD.show(device.name, systemImage: "hifispeaker.fill")
    }

    /// Sets the volume of the current output, from 0 to 100.
    static func setVolume(_ percent: Int) {
        _ = MacToggles.appleScriptNumber("set volume output volume \(percent)")
        let symbol = percent == 0 ? "speaker.slash.fill" : percent < 34 ? "speaker.wave.1.fill" : percent < 67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
        HUD.show("Volume \(percent)%", systemImage: symbol)
    }

    private static func currentDeviceID() -> AudioDeviceID {
        var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
        var id: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        return id
    }

    /// Whether a device has any output streams (microphones don't).
    private static func hasOutput(_ id: AudioDeviceID) -> Bool {
        var address = Self.address(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func string(of id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = Self.address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    private static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }
}
