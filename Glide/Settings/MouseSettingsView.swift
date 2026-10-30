import SwiftUI

/// The Mouse & Scrolling section of the dashboard.
struct MouseSettingsView: View {
    @AppStorage(DefaultsKey.wheelDirection) private var wheelDirection = WheelDirection.system
    @AppStorage(DefaultsKey.smoothScrolling) private var smoothScrolling = true
    @AppStorage(DefaultsKey.scrollSpeed) private var scrollSpeed = 1.0
    @State private var linearMouse: NSRunningApplication?

    var body: some View {
        Form {
            if let linearMouse {
                Section {
                    HStack {
                        Label(
                            "LinearMouse is running, so it may also flip your scrolling. Quit it to stop the two apps fighting.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.orange)
                        Spacer()
                        Button("Quit LinearMouse") {
                            linearMouse.terminate()
                            self.linearMouse = nil
                        }
                    }
                }
            }

            Section {
                Toggle("Smooth scrolling", isOn: $smoothScrolling)
                if smoothScrolling {
                    Slider(value: $scrollSpeed, in: 0.5...3) {
                        Text("Speed")
                    } minimumValueLabel: {
                        Image(systemName: "tortoise")
                    } maximumValueLabel: {
                        Image(systemName: "hare")
                    }
                }
            } header: {
                Text("Mouse Wheel")
            } footer: {
                Text("Each click of the wheel glides and eases to a stop, like scrolling on a trackpad. Scrolling with ⌘, ⌥, ⌃ or ⇧ held isn't smoothed, so zooming and sideways scrolling still work as apps expect.")
            }

            Section {
                Picker("Mouse wheel", selection: $wheelDirection) {
                    ForEach(WheelDirection.allCases) { direction in
                        Text(direction.title).tag(direction)
                    }
                }
                .pickerStyle(.inline)
            } header: {
                Text("Scroll Direction")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(footer)
                    if !systemIsNatural {
                        // Glide only changes the wheel, so the trackpad's direction comes from macOS.
                        HStack(spacing: 4) {
                            Text("Natural scrolling is off in System Settings, so your trackpad scrolls traditionally.")
                            Button("Open Trackpad Settings") {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension")!)
                            }
                            .buttonStyle(.link)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refresh)
        // Pick up changes you make in System Settings while this is open.
        .onReceive(NSApp.publisher(for: \.isActive)) { _ in refresh() }
    }

    @State private var systemIsNatural = true

    private func refresh() {
        linearMouse = NSRunningApplication.runningApplications(withBundleIdentifier: "com.lujjjh.LinearMouse").first
        systemIsNatural = UserDefaults(suiteName: UserDefaults.globalDomain)?
            .object(forKey: "com.apple.swipescrolldirection") as? Bool ?? true
    }

    private var footer: String {
        let detail = switch wheelDirection {
        case .system: "The wheel scrolls the same way as your trackpad."
        case .traditional: "Rolling the wheel down moves the page down."
        case .natural: "Rolling the wheel down moves the page up, like dragging it."
        }
        return detail + " Your trackpad follows System Settings › Trackpad › Natural scrolling."
    }
}
