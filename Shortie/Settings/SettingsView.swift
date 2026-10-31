import SwiftUI

/// The dashboard, laid out like System Settings: a sidebar of sections grouped
/// under plain headings, and the chosen section on the right.
struct SettingsView: View {
    @State private var selection: SettingsPane?
    /// What's typed in the toolbar's search field. Pages with lists filter by it.
    @State private var search = ""

    init(initialPane: SettingsPane = .general) {
        _selection = State(initialValue: initialPane)
        // AppKit saves the sidebar's width and puts it back next time, ignoring
        // the width asked for below. An old saved width can cut off the titles.
        UserDefaults.standard.removeObject(forKey: "NSSplitView Subview Frames settings, SidebarNavigationSplitView")
    }
    @State private var columns = NavigationSplitViewVisibility.all

    /// Like System Settings, the sidebar is always shown at one fixed width:
    /// wide enough for its longest title, in the sidebar's text size.
    static let sidebarWidth: CGFloat = {
        // System Settings › Appearance › Sidebar icon size: 1 small, 2 medium, 3 large.
        let fontSize: CGFloat = switch UserDefaults.standard.integer(forKey: "NSTableViewDefaultSizeMode") {
        case 1: 11
        case 3: 15
        default: 13
        }
        let font = NSFont.systemFont(ofSize: fontSize)
        let widest = SettingsPane.allCases
            .map { ($0.title as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        // Room for the icon, the row's padding and the sidebar's inset.
        return max(215, (widest + 90).rounded(.up))
    }()

    /// SwiftUI doesn't always honour the column width above, so also fix the
    /// sidebar's width on the window's split view, which AppKit always respects.
    static func pinSidebarWidth(in window: NSWindow) {
        guard let splitView = window.contentView.flatMap(firstSplitView),
              let controller = splitView.delegate as? NSSplitViewController,
              let sidebar = controller.splitViewItems.first
        else { return }
        sidebar.minimumThickness = sidebarWidth
        sidebar.maximumThickness = sidebarWidth
        splitView.setPosition(sidebarWidth, ofDividerAt: 0)
    }

    private static func firstSplitView(in view: NSView) -> NSSplitView? {
        if let splitView = view as? NSSplitView { return splitView }
        for subview in view.subviews {
            if let found = firstSplitView(in: subview) { return found }
        }
        return nil
    }

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
                .environment(\.listSearch, search)
                .modifier(PaneSearch(isOn: pane.hasList, text: $search))
                .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(pane.title)
                .id(pane)
                .transition(.opacity)
        }
        .animation(.smooth(duration: 0.2), value: selection)
        // Each page starts with an empty search.
        .onChange(of: selection) { search = "" }
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
        case .layouts:
            WindowLayoutsSettingsView()
        case .trafficLights:
            TrafficLightsSettingsView()
        case .mouse:
            MouseSettingsView()
        case .textShortcuts:
            TextShortcutsSettingsView()
        case .automations:
            AutomationsSettingsView()
        case .clipboard:
            ClipboardSettingsView()
        case .menus:
            CustomMenusSettingsView()
        case .menuBar:
            MenuBarSettingsView()
        case .gestures:
            GesturesSettingsView()
        case .permissions:
            PermissionsSettingsView()
        }
    }
}

extension EnvironmentValues {
    /// What's typed in the dashboard's search field, for lists to filter by.
    @Entry var listSearch = ""
}

/// The toolbar search field, only on pages that have a list to search.
private struct PaneSearch: ViewModifier {
    let isOn: Bool
    @Binding var text: String

    func body(content: Content) -> some View {
        if isOn {
            content.searchable(text: $text, placement: .toolbar, prompt: "Search")
        } else {
            content
        }
    }
}

extension Shortcut {
    /// Whether this rule's trigger or action mentions every word in `query`.
    func matches(_ query: String) -> Bool {
        let words = query.lowercased().split(separator: " ")
        guard !words.isEmpty else { return true }
        var text = [action.title, action.kind.editorTitle]
        if let keyCombo {
            text.append(keyCombo.displayString)
            if keyCombo.modifiers == [.control, .option, .shift, .command] { text.append("hyper") }
        }
        if let gesture { text.append(gesture.title) }
        if let click = trafficLightClick { text.append("\(click.button.title) \(click.clickDescription)") }
        if let click = mouseButtonClick { text.append(click.title) }
        if let abbreviation { text.append(abbreviation) }
        if let event { text.append(event.kind.title) }
        if let tap = modifierTap { text.append("\(tap.title) \(tap.key.name)") }
        let haystack = text.joined(separator: " ").lowercased()
        return words.allSatisfy { haystack.contains($0) }
    }
}

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, shortcuts, textShortcuts, windows, layouts, trafficLights, mouse, gestures, automations, clipboard, menus, menuBar, permissions

    var id: Self { self }

    /// The sidebar, grouped under plain headings like System Settings.
    static let groups: [(title: String?, panes: [SettingsPane])] = [
        (nil, [.general]),
        ("Triggers", [.shortcuts, .textShortcuts, .gestures, .mouse, .automations]),
        ("Windows", [.windows, .layouts, .trafficLights]),
        ("Mac", [.clipboard, .menus, .menuBar, .permissions]),
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
        case .layouts: "Window Layouts"
        case .trafficLights: "Window Buttons"
        case .clipboard: "Clipboard"
        case .menus: "Custom Menus"
        case .menuBar: "Menu Bar"
        case .permissions: "Permissions"
        }
    }

    /// One short line under the title at the top of the page.
    var subtitle: String {
        switch self {
        case .general: "Look, start-up, haptics and the Hyper key."
        case .shortcuts: "Key combinations that run actions."
        case .textShortcuts: "Abbreviations that expand as you type."
        case .gestures: "Trackpad taps, swipes, pinches and clicks."
        case .mouse: "Extra buttons and scrolling."
        case .automations: "Actions that run when apps open or your Mac wakes."
        case .windows: "Snap windows with keys or by dragging."
        case .layouts: "Save where your windows are, and put them back."
        case .trafficLights: "Actions for the red, yellow and green buttons."
        case .clipboard: "What you've copied, to paste again."
        case .menus: "Your own menus, in the menu bar or at the pointer."
        case .menuBar: "Hide the notch with a black menu bar."
        case .permissions: "Access Shortie needs from macOS."
        }
    }


    /// Pages with a list worth searching.
    var hasList: Bool {
        switch self {
        case .shortcuts, .textShortcuts, .gestures, .mouse, .automations, .windows, .layouts, .trafficLights, .menus: true
        case .general, .clipboard, .menuBar, .permissions: false
        }
    }

    /// The Modern look's icon.
    var systemImage: String {
        switch self {
        case .general: "gearshape.fill"
        case .shortcuts: "command"
        case .windows: "macwindow"
        case .layouts: "rectangle.split.2x1.fill"
        case .trafficLights: "circle.fill"
        case .mouse: "computermouse.fill"
        case .textShortcuts: "character.cursor.ibeam"
        case .automations: "gearshape.2.fill"
        case .clipboard: "doc.on.clipboard.fill"
        case .menus: "list.bullet.rectangle.fill"
        case .menuBar: "menubar.rectangle"
        case .gestures: "hand.draw.fill"
        case .permissions: "lock.fill"
        }
    }

    /// The Retro look's pixel picture.
    var pixels: [String] {
        switch self {
        case .general: PixelArt.mac
        case .shortcuts: PixelArt.key
        case .textShortcuts: PixelArt.typing
        case .gestures: PixelArt.hand
        case .mouse: PixelArt.mouse
        case .automations: PixelArt.bolt
        case .windows: PixelArt.snap
        case .layouts: PixelArt.layout
        case .trafficLights: PixelArt.windowButtons
        case .clipboard: PixelArt.clipboard
        case .menus: PixelArt.menu
        case .menuBar: PixelArt.notch
        case .permissions: PixelArt.lock
        }
    }

    var color: Color {
        switch self {
        case .general: .gray
        case .shortcuts: .purple
        case .windows: .blue
        case .layouts: .indigo
        case .trafficLights: .red
        case .mouse: .teal
        case .textShortcuts: .brown
        case .automations: .indigo
        case .clipboard: .cyan
        case .menus: .mint
        case .menuBar: Color(white: 0.3)
        case .gestures: .orange
        case .permissions: .green
        }
    }
}

/// A section's icon, in the sidebar or (larger) at the top of its page. Retro
/// shows its pixel picture in its colour; Modern shows a glossy coloured tile.
struct PaneIcon: View {
    let pane: SettingsPane
    /// `nil` is the sidebar size for the current look.
    var size: CGFloat?

    @AppStorage(DefaultsKey.look) private var look = Look.retro

    var body: some View {
        switch look {
        case .retro:
            // Multiples of 16, so every pixel stays square.
            PixelIcon(pixels: pane.pixels, size: size ?? 16)
                .foregroundStyle(pane == .menuBar ? Color.primary : pane.color)
        case .modern:
            if pane == .trafficLights {
                TrafficLightsSidebarIcon(size: size ?? 20)
            } else {
                SettingsIcon(systemImage: pane.systemImage, color: pane.color, size: size ?? 20)
            }
        }
    }
}

/// The Modern icon for Window Buttons: the three window buttons on a dark tile.
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
        .background(Color(white: 0.3).gradient, in: .rect(cornerRadius: size * 0.25, style: .continuous))
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
            .padding(.bottom, 10)
            .textCase(nil)
        }
    }
}

/// A section's heading. Set explicitly so every heading looks the same:
/// left alone, macOS styles the first one on a page differently.
struct SectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
            .textCase(nil)
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


#Preview {
    SettingsView()
}
