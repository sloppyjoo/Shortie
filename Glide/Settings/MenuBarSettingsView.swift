import SwiftUI

/// The Menu Bar section of the dashboard: a black menu bar, switched on per screen.
struct MenuBarSettingsView: View {
    private var notchBar = NotchBar.shared
    @State private var screens = NSScreen.screens

    var body: some View {
        Form {
            PaneHeader(pane: .menuBar)

            Section {
                ForEach(screens, id: \.stableID) { screen in
                    Toggle(isOn: Binding(
                        get: { notchBar.isEnabled(on: screen) },
                        set: { notchBar.setEnabled($0, on: screen) }
                    )) {
                        Label {
                            Text(screen.localizedName)
                            if screen.menuBarFrame == nil {
                                Text("Menu bar hides itself here")
                            } else if screen.hasNotch {
                                Text("Has a notch")
                            }
                        } icon: {
                            Image(systemName: screen.hasNotch ? "laptopcomputer" : "display")
                        }
                    }
                }
            } header: {
                Text("Black Menu Bar")
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screens = NSScreen.screens
        }
    }
}
