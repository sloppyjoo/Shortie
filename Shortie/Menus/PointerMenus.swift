import AppKit

/// Ordinary macOS menus that pop up at the pointer: the front app's menu bar,
/// or your shortcuts from the Shortcuts app.
final class PointerMenus: NSObject, NSMenuDelegate {
    static let shared = PointerMenus()

    /// The Accessibility menu behind each submenu, filled in when it opens.
    private var sources: [ObjectIdentifier: AXUIElement] = [:]

    // MARK: - The front app's menu bar

    func showAppMenus() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bar = AX.element(AXUIElementCreateApplication(app.processIdentifier), kAXMenuBarAttribute)
        else {
            NSSound.beep()
            return
        }
        sources.removeAll()
        let menu = NSMenu()
        // Skip the Apple menu; the app's own menus follow it.
        for barItem in children(of: bar).dropFirst() {
            guard let title = AX.string(barItem, kAXTitleAttribute), !title.isEmpty,
                  let axMenu = children(of: barItem).first
            else { continue }
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.submenu = lazyMenu(title: title, source: axMenu)
            menu.addItem(item)
        }
        popUp(menu)
    }

    private func lazyMenu(title: String, source: AXUIElement) -> NSMenu {
        let menu = NSMenu(title: title)
        menu.delegate = self
        // A placeholder, so the arrow shows; replaced when the menu opens.
        menu.addItem(NSMenuItem(title: "…", action: nil, keyEquivalent: ""))
        sources[ObjectIdentifier(menu)] = source
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard let source = sources[ObjectIdentifier(menu)] else { return }
        menu.removeAllItems()
        for axItem in children(of: source) {
            let title = AX.string(axItem, kAXTitleAttribute) ?? ""
            if title.isEmpty {
                menu.addItem(.separator())
                continue
            }
            let item = NSMenuItem(title: title, action: #selector(pressMenuItem(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = axItem
            item.isEnabled = AX.bool(axItem, kAXEnabledAttribute) ?? true
            if let submenu = children(of: axItem).first(where: { AX.string($0, kAXRoleAttribute) == kAXMenuRole }) {
                item.action = nil
                item.submenu = lazyMenu(title: title, source: submenu)
            }
            menu.addItem(item)
        }
        menu.autoenablesItems = false
    }

    @objc private func pressMenuItem(_ sender: NSMenuItem) {
        guard let object = sender.representedObject, CFGetTypeID(object as CFTypeRef) == AXUIElementGetTypeID() else { return }
        let element = object as! AXUIElement
        // Let our menu close first, so the app is ready for its own menu item.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            AXUIElementPerformAction(element, kAXPressAction as CFString)
        }
    }

    // MARK: - Shortcuts

    func showShortcuts() {
        Task {
            let names = await ShortcutsApp.list()
            guard !names.isEmpty else {
                NSSound.beep()
                return
            }
            let menu = NSMenu(title: "Shortcuts")
            for name in names {
                let item = NSMenuItem(title: name, action: #selector(runShortcut(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = name
                menu.addItem(item)
            }
            popUp(menu)
        }
    }

    @objc private func runShortcut(_ sender: NSMenuItem) {
        if let name = sender.representedObject as? String { ShortcutsApp.run(name) }
    }

    // MARK: -

    private func popUp(_ menu: NSMenu) {
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        return value as? [AXUIElement] ?? []
    }
}
