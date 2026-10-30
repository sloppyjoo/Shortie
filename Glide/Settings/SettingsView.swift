import SwiftUI

/// The settings window, laid out like System Settings: a sidebar of
/// sections on the left, the selected section on the right.
struct SettingsView: View {
    @State private var selection: SettingsPane? = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $selection) { pane in
                Label {
                    Text(pane.title)
                } icon: {
                    SettingsIcon(systemImage: pane.systemImage, color: pane.color)
                }
            }
            .navigationSplitViewColumnWidth(200)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            let pane = selection ?? .general
            detail(for: pane)
                .navigationTitle(pane.title)
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
        case .mouse:
            MouseSettingsView()
        case .gestures:
            ComingSoonView(pane: pane, description: "Custom trackpad and mouse gestures.")
        case .permissions:
            PermissionsSettingsView()
        }
    }
}

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, shortcuts, windows, mouse, gestures, permissions

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .shortcuts: "Shortcuts"
        case .windows: "Windows"
        case .mouse: "Mouse & Scrolling"
        case .gestures: "Gestures"
        case .permissions: "Permissions"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape.fill"
        case .shortcuts: "command"
        case .windows: "macwindow"
        case .mouse: "computermouse.fill"
        case .gestures: "hand.draw.fill"
        case .permissions: "lock.fill"
        }
    }

    var color: Color {
        switch self {
        case .general: .gray
        case .shortcuts: .purple
        case .windows: .blue
        case .mouse: .teal
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
