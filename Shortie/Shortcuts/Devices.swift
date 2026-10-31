import AppKit
import CoreMIDI
import IOBluetooth
import IOKit
import Network

/// A property of a private macOS object, or `nil` if it doesn't have one
/// (asking for one it doesn't have would otherwise crash).
func safeValue(_ object: NSObject, _ key: String) -> Any? {
    object.responds(to: NSSelectorFromString(key)) ? object.value(forKey: key) : nil
}

/// What to do to a Bluetooth device, or Sidecar.
nonisolated enum ConnectMode: String, Codable, CaseIterable, Identifiable {
    case connect, disconnect, toggle

    var id: Self { self }

    var title: String {
        switch self {
        case .connect: "Connect"
        case .disconnect: "Disconnect"
        case .toggle: "Connect or Disconnect"
        }
    }
}

/// Paired Bluetooth devices: headphones, keyboards, mice…
enum BluetoothDevices {
    struct Device: Identifiable, Hashable {
        let id: String
        let name: String
    }

    static func paired() -> [Device] {
        (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []).compactMap { device in
            guard let address = device.addressString else { return nil }
            return Device(id: address, name: device.name ?? address)
        }
    }

    static func run(_ mode: ConnectMode, address: String, name: String) {
        guard let device = IOBluetoothDevice(addressString: address) else {
            HUD.show("\(name) Isn't Paired", systemImage: "antenna.radiowaves.left.and.right.slash")
            return
        }
        let connect = mode == .connect || (mode == .toggle && !device.isConnected())
        let result = connect ? device.openConnection() : device.closeConnection()
        if result == kIOReturnSuccess {
            HUD.show(connect ? "Connecting \(name)" : "Disconnected \(name)", systemImage: "antenna.radiowaves.left.and.right")
        } else {
            HUD.show("Couldn't Reach \(name)", systemImage: "exclamationmark.triangle.fill")
        }
    }
}

/// Sends MIDI messages to synths, apps and controllers.
enum MIDI {
    private static var client = MIDIClientRef()
    private static var port = MIDIPortRef()

    static func destinations() -> [String] {
        (0..<MIDIGetNumberOfDestinations()).compactMap { name(of: MIDIGetDestination($0)) }
    }

    /// `bytes` is hex, like "90 3C 7F" (note on, middle C, full velocity).
    static func send(_ bytes: String, to destinationName: String) {
        let data = bytes.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { UInt8($0.replacingOccurrences(of: "0x", with: ""), radix: 16) }
        guard !data.isEmpty,
              let destination = (0..<MIDIGetNumberOfDestinations()).map(MIDIGetDestination).first(where: { name(of: $0) == destinationName })
        else {
            NSSound.beep()
            return
        }
        if client == 0 {
            MIDIClientCreate("Shortie" as CFString, nil, nil, &client)
            MIDIOutputPortCreate(client, "Shortie Out" as CFString, &port)
        }
        var buffer = [UInt8](repeating: 0, count: 1024)
        buffer.withUnsafeMutableBytes { raw in
            guard let list = raw.baseAddress?.assumingMemoryBound(to: MIDIPacketList.self) else { return }
            let packet = MIDIPacketListInit(list)
            _ = MIDIPacketListAdd(list, raw.count, packet, 0, data.count, data)
            MIDISend(port, destination, list)
        }
    }

    private static func name(of endpoint: MIDIEndpointRef) -> String? {
        var value: Unmanaged<CFString>?
        guard MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }
}

/// An Open Sound Control message, sent over UDP (to lighting desks, audio apps…).
nonisolated struct OSCMessage: Codable, Hashable {
    var host = "127.0.0.1"
    var port = 8000
    var address = "/"
    /// Separated by spaces: whole numbers, decimals, or text ("quotes" for text with spaces).
    var arguments = ""

    /// The message in OSC's binary format.
    var packet: Data {
        var data = Self.padded(address)
        var tags = ","
        var payload = Data()
        for argument in Self.split(arguments) {
            if let int = Int32(argument) {
                tags += "i"
                payload.append(contentsOf: withUnsafeBytes(of: int.bigEndian, Array.init))
            } else if let float = Float(argument) {
                tags += "f"
                payload.append(contentsOf: withUnsafeBytes(of: float.bitPattern.bigEndian, Array.init))
            } else {
                tags += "s"
                payload.append(Self.padded(argument))
            }
        }
        data.append(Self.padded(tags))
        data.append(payload)
        return data
    }

    /// Text in OSC: zero-terminated, then padded to a multiple of four bytes.
    private static func padded(_ text: String) -> Data {
        var data = Data(text.utf8)
        data.append(0)
        while data.count % 4 != 0 { data.append(0) }
        return data
    }

    private static func split(_ text: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var quoted = false
        for character in text {
            if character == "\"" {
                quoted.toggle()
            } else if character == " ", !quoted {
                if !current.isEmpty { parts.append(current) }
                current = ""
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }

    func send() {
        guard let port = NWEndpoint.Port(rawValue: UInt16(clamping: port)) else { return }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .udp)
        connection.start(queue: .global())
        connection.send(content: packet, completion: .contentProcessed { _ in connection.cancel() })
    }
}

/// An iPad as a second display, through the private framework Control Centre uses.
enum Sidecar {
    static func run(_ mode: ConnectMode) {
        guard Bundle(path: "/System/Library/PrivateFrameworks/SidecarCore.framework")?.load() == true,
              let managerType = NSClassFromString("SidecarDisplayManager") as? NSObject.Type,
              (managerType as AnyObject).responds(to: NSSelectorFromString("sharedManager")),
              let manager = (managerType as AnyObject).perform(NSSelectorFromString("sharedManager"))?.takeUnretainedValue() as? NSObject
        else {
            NSSound.beep()
            return
        }
        let devices = safeValue(manager, "devices") as? [NSObject] ?? []
        let connected = safeValue(manager, "connectedDevices") as? [NSObject] ?? []
        let disconnect = mode == .disconnect || (mode == .toggle && !connected.isEmpty)
        guard let device = disconnect ? connected.first : devices.first else {
            HUD.show(disconnect ? "No iPad Connected" : "No iPad Found", systemImage: "ipad.and.iphone.slash")
            return
        }
        typealias Call = @convention(c) (AnyObject, Selector, AnyObject, @convention(block) (NSError?) -> Void) -> Void
        let selector = NSSelectorFromString(disconnect ? "disconnectFromDevice:completion:" : "connectToDevice:completion:")
        guard manager.responds(to: selector) else {
            NSSound.beep()
            return
        }
        unsafeBitCast(manager.method(for: selector), to: Call.self)(manager, selector, device) { _ in }
        HUD.show(disconnect ? "Sidecar Disconnected" : "Connecting Sidecar", systemImage: "ipad.landscape")
    }
}

/// External displays' brightness, over the display cable (DDC/CI), on Apple silicon Macs.
enum ExternalBrightness {
    private typealias CreateService = @convention(c) (CFAllocator?, io_service_t) -> Unmanaged<AnyObject>?
    private typealias WriteI2C = @convention(c) (AnyObject, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> IOReturn

    /// Displays don't report their brightness reliably, so remember what we last set.
    private static var level = 50

    static func step(_ change: Int) {
        set(min(max(level + change, 0), 100))
    }

    static func set(_ percent: Int) {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY),
              let createSymbol = dlsym(handle, "IOAVServiceCreateWithService"),
              let writeSymbol = dlsym(handle, "IOAVServiceWriteI2C")
        else {
            NSSound.beep()
            return
        }
        let create = unsafeBitCast(createSymbol, to: CreateService.self)
        let write = unsafeBitCast(writeSymbol, to: WriteI2C.self)

        var iterator = io_iterator_t()
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("DCPAVServiceProxy"), &iterator) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }

        var changed = false
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            let location = IORegistryEntryCreateCFProperty(service, "Location" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
            guard location == "External", let avService = create(kCFAllocatorDefault, service)?.takeRetainedValue() else { continue }
            // Set VCP code 0x10 (brightness): length, opcode, code, value high, value low, checksum.
            var packet: [UInt8] = [0x84, 0x03, 0x10, 0, UInt8(percent)]
            packet.append(packet.reduce(0x6E ^ 0x51) { $0 ^ $1 })
            for _ in 0..<2 {
                _ = packet.withUnsafeMutableBytes { write(avService, 0x37, 0x51, $0.baseAddress!, UInt32($0.count)) }
                usleep(10_000)
            }
            changed = true
        }
        if changed {
            level = percent
            HUD.show("External Display \(percent)%", systemImage: "sun.max.fill")
        } else {
            HUD.show("No External Display Found", systemImage: "display.trianglebadge.exclamationmark")
        }
    }
}

/// Turns the display under the pointer, through the private framework
/// System Settings uses for its Rotation menu.
enum DisplayRotation {
    static func rotate(clockwise: Bool) {
        guard Bundle(path: "/System/Library/PrivateFrameworks/MonitorPanel.framework")?.load() == true,
              let managerType = NSClassFromString("MPDisplayMgr") as? NSObject.Type
        else {
            NSSound.beep()
            return
        }
        let manager = managerType.init()
        let pointer = CGEvent(source: nil)?.location ?? .zero
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetDisplaysWithPoint(pointer, UInt32(ids.count), &ids, &count)
        guard count > 0,
              let displays = safeValue(manager, "displays") as? [NSObject],
              let display = displays.first(where: { (safeValue($0, "displayID") as? NSNumber)?.uint32Value == ids[0] }),
              let current = safeValue(display, "orientation") as? NSNumber,
              display.responds(to: NSSelectorFromString("setOrientation:"))
        else {
            NSSound.beep()
            return
        }
        let next = (current.intValue + (clockwise ? 90 : 270)) % 360
        display.setValue(NSNumber(value: next), forKey: "orientation")
    }
}
