import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(DefaultsKey.isPaused) private var isPaused = false

    var body: some View {
        Form {
            Section {
                LaunchAtLoginToggle()
                Toggle("Pause BestTouchTool", isOn: $isPaused)
            } footer: {
                Text("While paused, BestTouchTool ignores all gestures and shortcuts.")
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
