import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(DefaultsKey.isPaused) private var isPaused = false
    @AppStorage(DefaultsKey.hyperKey) private var hyperKey = false
    @AppStorage(DefaultsKey.hyperTapAction) private var hyperTapAction = HyperTapAction.capsLock

    var body: some View {
        Form {
            PaneHeader(pane: .general)

            Section {
                LaunchAtLoginToggle()
                Toggle("Pause All Shortcuts and Gestures", isOn: $isPaused)
            }

            Section {
                HStack {
                    Toggle("Caps Lock as Hyper Key", isOn: $hyperKey)
                        .onChange(of: hyperKey) { HyperKey.shared.apply() }
                    InfoButton("Hold Caps Lock with another key for ⌃⌥⇧⌘ plus that key, a combination no app uses. Record a Hyper shortcut by holding Caps Lock. Caps Lock is back to normal whenever Shortie isn't running.")
                }
                if hyperKey {
                    Picker("When Tapped", selection: $hyperTapAction) {
                        ForEach(HyperTapAction.allCases) { Text($0.title).tag($0) }
                    }
                }
            } header: {
                SectionTitle("Hyper Key")
            }

            Section {
                LabeledContent("Version", value: Self.version)
                LabeledContent("Your Shortcuts") {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([ShortcutStore.shared.fileURL])
                    }
                }
            }
        }
        .animation(.smooth(duration: 0.2), value: hyperKey)
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
            PaneHeader(pane: .permissions)

            Section {
                PermissionRow.accessibility(permissions)
            }
        }
        .formStyle(.grouped)
    }
}
