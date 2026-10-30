import SwiftUI

/// The dashboard, laid out like System Settings: a sidebar of sections grouped
/// under plain headings, and the chosen section on the right.
struct SettingsView: View {
    @State private var selection: SettingsPane? = .general
    @State private var columns = NavigationSplitViewVisibility.all

    /// Like System Settings, the sidebar is always shown at one fixed width.
    private static let sidebarWidth: CGFloat = 215

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            List(selection: $selection) {
                ForEach(SettingsPane.groups, id: \.panes) { group in
                    Section {
                        ForEach(group.panes) { pane in
                            Label {
                                Text(pane.title)
                            } icon: {
                                PaneIcon(pane: pane)
                            }
                            .tag(pane)
                        }
                    } header: {
                        if let title = group.title { Text(title) }
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
                .id(pane)
                .transition(.opacity)
        }
        .animation(.smooth(duration: 0.2), value: selection)
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

    /// The sidebar, grouped under plain headings like System Settings.
    static let groups: [(title: String?, panes: [SettingsPane])] = [
        (nil, [.general]),
        ("Triggers", [.shortcuts, .textShortcuts, .gestures, .mouse, .automations]),
        ("Windows", [.windows, .trafficLights]),
        ("Mac", [.menuBar, .permissions]),
    ]

    var title: String {
        switch self {
        case .general: "General"
        case .shortcuts: "Keyboard Shortcuts"
        case .textShortcuts: "Text Shortcuts"
        case .gestures: "Trackpad Gestures"
        case .mouse: "Mouse"
        case .automations: "Automations"
        case .windows: "Window Snapping"
        case .trafficLights: "Window Buttons"
        case .menuBar: "Menu Bar"
        case .permissions: "Permissions"
        }
    }

    /// One short line under the title at the top of the page.
    var subtitle: String {
        switch self {
        case .general: "Start-up, pausing and the Hyper key."
        case .shortcuts: "Press keys to open apps, control your Mac and more."
        case .textShortcuts: "Type a short abbreviation to expand it."
        case .gestures: "Taps, swipes, pinches and clicks that do things."
        case .mouse: "Extra buttons and smoother scrolling."
        case .automations: "Do things when apps open or your Mac wakes."
        case .windows: "Snap windows with keys or by dragging."
        case .trafficLights: "New tricks for the red, yellow and green buttons."
        case .menuBar: "Hide the notch with a black menu bar."
        case .permissions: "What BestTouchTool needs to work."
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

/// A section's icon: a coloured rounded tile, in the sidebar or (larger) at
/// the top of its page.
struct PaneIcon: View {
    let pane: SettingsPane
    var size: CGFloat = 20

    var body: some View {
        if pane == .trafficLights {
            TrafficLightsSidebarIcon(size: size)
        } else {
            SettingsIcon(systemImage: pane.systemImage, color: pane.color, size: size)
        }
    }
}

/// The top of each page: big icon, title, and one short line, like System Settings.
struct PaneHeader: View {
    let pane: SettingsPane

    var body: some View {
        Section {
        } header: {
            VStack(spacing: 6) {
                PaneIcon(pane: pane, size: 48)
                    .padding(.bottom, 4)
                Text(pane.title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(pane.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
            .padding(.bottom, 2)
            .textCase(nil)
        }
    }
}

/// The small rounded, coloured icon used for sections and actions.
struct SettingsIcon: View {
    let systemImage: String
    let color: Color
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.55, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: .rect(cornerRadius: size * 0.25, style: .continuous))
    }
}

/// The icon for Window Buttons: the three window buttons on a dark tile.
struct TrafficLightsSidebarIcon: View {
    var size: CGFloat = 20

    var body: some View {
        HStack(spacing: size * 0.075) {
            ForEach(TrafficLightButton.allCases) { button in
                Circle()
                    .fill(button.color)
                    .frame(width: size * 0.225, height: size * 0.225)
            }
        }
        .frame(width: size, height: size)
        .background(Color(white: 0.22).gradient, in: .rect(cornerRadius: size * 0.25, style: .continuous))
    }
}

#Preview {
    SettingsView()
}
