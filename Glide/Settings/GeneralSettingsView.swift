import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(DefaultsKey.isPaused) private var isPaused = false
    @AppStorage(DefaultsKey.hyperKey) private var hyperKey = false
    @AppStorage(DefaultsKey.hyperTapAction) private var hyperTapAction = HyperTapAction.capsLock

    var body: some View {
        Form {
            Section {
                LaunchAtLoginToggle()
                Toggle("Pause BestTouchTool", isOn: $isPaused)
            } footer: {
                Text("While paused, BestTouchTool ignores all gestures and shortcuts.")
            }

            Section {
                Toggle("Use Caps Lock as a Hyper key", isOn: $hyperKey)
                    .onChange(of: hyperKey) { HyperKey.shared.apply() }
                Picker("Tapping Caps Lock on its own", selection: $hyperTapAction) {
                    ForEach(HyperTapAction.allCases) { Text($0.title).tag($0) }
                }
                .disabled(!hyperKey)
            } header: {
                Text("Hyper Key")
            } footer: {
                Text("Hold Caps Lock and press a key to get ⌃⌥⇧⌘ plus that key. No app uses that combination, so it's perfect for your own shortcuts: record one by holding Caps Lock. Tap it quickly and it's still Caps Lock. It goes back to plain Caps Lock whenever BestTouchTool isn't running.")
            }

            Section {
                LabeledContent("Version", value: Self.version)
            }
        }
        .formStyle(.grouped)
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}

/// "Open at Login", using the system's own login-items list
/// (it shows up in System Settings › General › Login Items).
struct LaunchAtLoginToggle: View {
    @State private var isOn = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle("Open at Login", isOn: $isOn)
            .onChange(of: isOn) { _, newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    // Put the switch back to whatever macOS actually did.
                    isOn = SMAppService.mainApp.status == .enabled
                }
            }
    }
}

struct PermissionsSettingsView: View {
    private var permissions = Permissions.shared

    var body: some View {
        Form {
            Section {
                PermissionRow.accessibility(permissions)
            } footer: {
                Text("BestTouchTool never records or sends anything you type.")
            }
        }
        .formStyle(.grouped)
    }
}
