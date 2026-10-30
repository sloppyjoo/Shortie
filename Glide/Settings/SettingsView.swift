import SwiftUI

/// The settings window, laid out like System Settings: a sidebar of
/// sections on the left, the selected section on the right.
struct SettingsView: View {
    @State private var selection: SettingsPane? = .general
    @State private var columns = NavigationSplitViewVisibility.all

    /// Like System Settings, the sidebar is always shown at one fixed width.
    private static let sidebarWidth: CGFloat = 215

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            List(SettingsPane.allCases, selection: $selection) { pane in
                Label {
                    Text(pane.title)
                } icon: {
                    if pane == .trafficLights {
                        TrafficLightsSidebarIcon()
                    } else {
                        SettingsIcon(systemImage: pane.systemImage, color: pane.color)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: Self.sidebarWidth, ideal: Self.sidebarWidth, max: Self.sidebarWidth)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            let pane = selection ?? .general
            detail(for: pane)
                .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(pane.title)
        }
        // Don't let the sidebar be collapsed (for example by dragging its edge).
        .onChange(of: columns) { _, newValue in
            if newValue != .all { columns = .all }
        }
    }

    @ViewBuilder
    private func detail(for pane: SettingsPane) -> some View {
        switch pane {
        case .general:
            GeneralSettingsView()
        case .shortcuts:
            ShortcutsSettingsView()
        case .windows:
            WindowsSettingsView()
        case .trafficLights:
            TrafficLightsSettingsView()
        case .mouse:
            MouseSettingsView()
        case .textShortcuts:
            TextShortcutsSettingsView()
        case .automations:
            AutomationsSettingsView()
        case .menuBar:
            MenuBarSettingsView()
        case .gestures:
            GesturesSettingsView()
        case .permissions:
            PermissionsSettingsView()
        }
    }
}

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, shortcuts, textShortcuts, windows, trafficLights, mouse, gestures, automations, menuBar, permissions

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .shortcuts: "Shortcuts"
        case .windows: "Windows"
        case .trafficLights: "Traffic Lights"
        case .mouse: "Mouse"
        case .textShortcuts: "Text Shortcuts"
        case .automations: "Automations"
        case .menuBar: "Menu Bar"
        case .gestures: "Gestures"
        case .permissions: "Permissions"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape.fill"
        case .shortcuts: "command"
        case .windows: "macwindow"
        case .trafficLights: "circle.fill"
        case .mouse: "computermouse.fill"
        case .textShortcuts: "character.cursor.ibeam"
        case .automations: "gearshape.2.fill"
        case .menuBar: "menubar.rectangle"
        case .gestures: "hand.draw.fill"
        case .permissions: "lock.fill"
        }
    }

    var color: Color {
        switch self {
        case .general: .gray
        case .shortcuts: .purple
        case .windows: .blue
        case .trafficLights: .red
        case .mouse: .teal
        case .textShortcuts: .brown
        case .automations: .indigo
        case .menuBar: .black
        case .gestures: .orange
        case .permissions: .green
        }
    }
}

/// The small rounded, coloured icon next to each sidebar item.
struct SettingsIcon: View {
    let systemImage: String
    let color: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(color.gradient, in: .rect(cornerRadius: 5))
    }
}

/// The sidebar icon for Traffic Lights: the three window buttons on a dark tile.
struct TrafficLightsSidebarIcon: View {
    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(TrafficLightButton.allCases) { button in
                Circle()
                    .fill(button.color)
                    .frame(width: 4.5, height: 4.5)
            }
        }
        .frame(width: 20, height: 20)
        .background(Color(white: 0.22).gradient, in: .rect(cornerRadius: 5))
    }
}

/// Placeholder for sections we haven't built yet.
struct ComingSoonView: View {
    let pane: SettingsPane
    let description: String

    var body: some View {
        ContentUnavailableView {
            Label(pane.title, systemImage: pane.systemImage)
        } description: {
            Text(description)
        }
    }
}

#Preview {
    SettingsView()
}
