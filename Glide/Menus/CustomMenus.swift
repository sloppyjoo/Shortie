import AppKit
import Observation
import SwiftUI

/// A named list of actions you can open from the menu bar, or at the pointer
/// with the "Show Custom Menu" action.
nonisolated struct CustomMenu: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    /// An SF Symbol, shown in the menu bar and the dashboard.
    var symbol: String
    var items: [CustomMenuItem]
    var showsInMenuBar: Bool
}

nonisolated struct CustomMenuItem: Codable, Identifiable, Hashable {
    var id = UUID()
    /// Blank means "use the action's own name".
    var title: String
    var action: ShortcutAction

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespaces).isEmpty ? action.title : title
    }
}

/// Your custom menus, saved to `menus.json` next to your shortcuts.
@Observable
final class CustomMenuStore {
    static let shared = CustomMenuStore()

    var menus: [CustomMenu] = [] {
        didSet {
            // Loading the file at startup isn't a change worth reacting to.
            guard isLoaded else { return }
            save()
            MenuBarMenus.shared.refresh()
        }
    }

    @ObservationIgnored private var isLoaded = false

    @ObservationIgnored private let fileURL = URL.applicationSupportDirectory
        .appending(path: "BestTouchTool", directoryHint: .isDirectory)
        .appending(path: "menus.json")

    private init() {
        defer { isLoaded = true }
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([CustomMenu].self, from: data) {
            menus = saved
        }
    }

    func menu(id: UUID?) -> CustomMenu? {
        menus.first { $0.id == id }
    }

    func save(_ menu: CustomMenu) {
        if let index = menus.firstIndex(where: { $0.id == menu.id }) {
            menus[index] = menu
        } else {
            menus.append(menu)
        }
        // Shortcuts that open this menu show its name, so keep that up to date.
        let store = ShortcutStore.shared
        for (index, shortcut) in store.shortcuts.enumerated() {
            if case .showMenu(menu.id, let name) = shortcut.action, name != menu.name {
                store.shortcuts[index].action = .showMenu(id: menu.id, name: menu.name)
            }
        }
    }

    func delete(id: UUID) {
        menus.removeAll { $0.id == id }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(menus) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - In the menu bar

/// One menu bar icon per custom menu that has "Show in Menu Bar" on. Clicking
/// it opens an ordinary Mac menu of its actions.
final class MenuBarMenus: NSObject {
    static let shared = MenuBarMenus()

    private var statusItems: [UUID: NSStatusItem] = [:]

    func refresh() {
        let wanted = CustomMenuStore.shared.menus.filter { $0.showsInMenuBar && !$0.items.isEmpty }
        for (id, item) in statusItems where !wanted.contains(where: { $0.id == id }) {
            NSStatusBar.system.removeStatusItem(item)
            statusItems[id] = nil
        }
        for menu in wanted {
            let item = statusItems[menu.id] ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = NSImage(systemSymbolName: menu.symbol, accessibilityDescription: menu.name)
            item.button?.toolTip = menu.name
            item.menu = nsMenu(for: menu)
            statusItems[menu.id] = item
        }
    }

    private func nsMenu(for menu: CustomMenu) -> NSMenu {
        let nsMenu = NSMenu(title: menu.name)
        for entry in menu.items {
            let item = NSMenuItem(title: entry.displayTitle, action: #selector(run(_:)), keyEquivalent: "")
            item.target = self
            item.image = NSImage(systemSymbolName: entry.action.kind.systemImage, accessibilityDescription: nil)
            item.representedObject = ActionBox(entry.action)
            nsMenu.addItem(item)
        }
        return nsMenu
    }

    @objc private func run(_ sender: NSMenuItem) {
        guard let box = sender.representedObject as? ActionBox else { return }
        ActionRunner.run(box.action)
    }
}

/// Lets a menu item carry its action.
private final class ActionBox: NSObject {
    let action: ShortcutAction
    init(_ action: ShortcutAction) { self.action = action }
}

// MARK: - At the pointer

/// Shows a custom menu right where the pointer is, as a small glass list.
/// It doesn't take over from the app you're using, so actions like pressing
/// keys or choosing menu items still go to that app.
final class FloatingMenu: NSObject, NSWindowDelegate {
    static let shared = FloatingMenu()

    private var panel: GlassPanel?

    func show(_ menuID: UUID?) {
        guard let menu = CustomMenuStore.shared.menu(id: menuID), !menu.items.isEmpty else {
            NSSound.beep()
            return
        }
        close()

        let rowHeight: CGFloat = 32
        let size = NSSize(width: 280, height: min(CGFloat(menu.items.count) * rowHeight + 52, 440))
        let panel = GlassPanel(size: size, content: FloatingMenuView(
            menu: menu,
            choose: { [weak self] item in
                self?.close()
                // Let the panel go before acting, so the action reaches your app.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { ActionRunner.run(item.action) }
            },
            dismiss: { [weak self] in self?.close() }
        ))
        panel.delegate = self

        // Open just below and right of the pointer, kept on screen.
        let mouse = NSEvent.mouseLocation
        var origin = NSPoint(x: mouse.x + 4, y: mouse.y - size.height - 4)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) {
            let area = screen.visibleFrame
            origin.x = min(max(origin.x, area.minX + 8), area.maxX - size.width - 8)
            origin.y = min(max(origin.y, area.minY + 8), area.maxY - size.height - 8)
        }
        panel.setFrameOrigin(origin)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    /// Clicking anywhere else closes it.
    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}

private struct FloatingMenuView: View {
    let menu: CustomMenu
    let choose: (CustomMenuItem) -> Void
    let dismiss: () -> Void

    @State private var selection = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(menu.name, systemImage: menu.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.bottom, 4)

            ForEach(Array(menu.items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 10) {
                    Image(systemName: item.action.kind.systemImage)
                        .frame(width: 18)
                        .foregroundStyle(.secondary)
                    Text(item.displayTitle)
                        .lineLimit(1)
                    Spacer()
                    if index < 9 {
                        Text("\(index + 1)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(index == selection ? Color.primary.opacity(0.1) : .clear)
                )
                .contentShape(.rect)
                .onHover { if $0 { selection = index } }
                .onTapGesture { choose(item) }
            }
        }
        .padding(10)
        .frame(width: 280, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(GlassBackground(cornerRadius: 16))
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(.upArrow) { selection = max(selection - 1, 0); return .handled }
        .onKeyPress(.downArrow) { selection = min(selection + 1, menu.items.count - 1); return .handled }
        .onKeyPress(.return) { choose(menu.items[selection]); return .handled }
        .onKeyPress(.escape) { dismiss(); return .handled }
        .onKeyPress(characters: .decimalDigits) { press in
            guard let number = Int(press.characters), number >= 1, number <= menu.items.count else { return .ignored }
            choose(menu.items[number - 1])
            return .handled
        }
    }
}
