import AppKit
import SwiftUI

/// A floating list of every rule that's switched on, so you can look up what does what.
/// Esc or clicking elsewhere closes it.
final class CheatSheet: NSObject, NSWindowDelegate {
    static let shared = CheatSheet()

    private var panel: GlassPanel?

    func toggle() {
        if let panel, panel.isVisible {
            close()
        } else {
            show()
        }
    }

    func show() {
        close()
        let panel = GlassPanel(size: NSSize(width: 620, height: 520), content: CheatSheetView(dismiss: { [weak self] in self?.close() }))
        panel.delegate = self
        panel.showCentred()
        self.panel = panel
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}

private struct CheatSheetView: View {
    let dismiss: () -> Void

    private var sections: [(name: String, rules: [Shortcut])] {
        let enabled = ShortcutStore.shared.shortcuts.filter { $0.isEnabled && $0.trigger != nil }
        let names = ["Shortcuts", "Text Shortcuts", "Gestures", "Mouse", "Windows", "Window Layouts", "Traffic Lights", "Automations"]
        return names.compactMap { name in
            let rules = enabled.filter { $0.sectionName == name }
            return rules.isEmpty ? nil : (name, rules)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Cheat Sheet", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                Spacer()
                Text("Esc to close")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            Divider()
            if sections.isEmpty {
                Text("No rules are switched on yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(sections, id: \.name) { section in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(section.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(section.rules) { rule in
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        Text(trigger(of: rule))
                                            .font(.body.monospaced())
                                            .frame(width: 220, alignment: .leading)
                                            .lineLimit(1)
                                        Text(rule.action.title)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer(minLength: 0)
                                        if let apps = rule.apps {
                                            AppScopeBadge(scope: apps)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(14)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onExitCommand(perform: dismiss)
    }

    private func trigger(of rule: Shortcut) -> String {
        let label = ExtraActionFields.label(for: rule)
        return label.components(separatedBy: " → ").first ?? label
    }
}
