import SwiftUI

/// The Window Layouts page: saved arrangements of your windows, and the
/// shortcuts that put them back.
struct WindowLayoutsSettingsView: View {
    var body: some View {
        ShortcutListView(
            pane: .layouts,
            kinds: [.restoreLayout],
            emptyText: "No layout shortcuts yet.",
            info: "You can also restore a layout from a gesture, a mouse button, a custom menu or an automation: choose the Restore Window Layout action."
        ) {
            EmptyView()
        } topSections: {
            SavedLayoutsSection()
        }
    }
}

private struct SavedLayoutsSection: View {
    private var store = WindowLayoutStore.shared

    @State private var naming: NameRequest?

    var body: some View {
        Section {
            if store.layouts.isEmpty {
                EmptyState("No layouts yet. Arrange your windows how you like them, then save.", pixels: PixelArt.layout)
            }
            ForEach(store.layouts) { layout in
                LayoutRow(
                    layout: layout,
                    rename: { naming = NameRequest(layoutID: layout.id, name: layout.name) },
                    update: { store.updateToCurrent(id: layout.id) },
                    delete: { store.delete(id: layout.id) }
                )
            }
        } header: {
            HStack {
                SectionTitle("Layouts")
                InfoButton("Saves where each open window is. Restoring moves those windows back; apps that aren't open are skipped. Windows are matched by app, then by title.")
                Spacer()
                Button("Save Current Layout", systemImage: "plus") {
                    naming = NameRequest(layoutID: nil, name: "", windows: WindowLayouts.currentWindows())
                }
            }
        }
        .animation(.smooth(duration: 0.25), value: store.layouts)
        .sheet(item: $naming) { request in
            LayoutNameSheet(request: request) { name in
                if let id = request.layoutID {
                    store.rename(id: id, to: name)
                } else {
                    store.saveCurrent(named: name)
                }
            }
        }
    }
}

private struct NameRequest: Identifiable {
    let id = UUID()
    /// `nil` when saving a new layout.
    let layoutID: UUID?
    let name: String
    /// The windows a new layout will hold, shown so you can check them.
    var windows: [SavedWindow] = []
}

private struct LayoutRow: View {
    let layout: WindowLayout
    let rename: () -> Void
    let update: () -> Void
    let delete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(systemImage: ShortcutAction.Kind.restoreLayout.systemImage, color: .blue, size: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(layout.name)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)

            Menu {
                Button("Rename…", action: rename)
                Button("Update to Current Windows", action: update)
                Divider()
                Button("Delete", role: .destructive, action: delete)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .opacity(isHovering ? 1 : 0)

            Button("Restore") { WindowLayouts.restore(layout.id) }
        }
        .contentShape(.rect)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .contextMenu {
            Button("Restore") { WindowLayouts.restore(layout.id) }
            Button("Rename…", action: rename)
            Button("Update to Current Windows", action: update)
            Divider()
            Button("Delete", role: .destructive, action: delete)
        }
    }

    /// Like "5 windows in 3 apps".
    private var summary: String {
        let windows = layout.windows.count == 1 ? "1 window" : "\(layout.windows.count) windows"
        let apps = layout.appCount == 1 ? "1 app" : "\(layout.appCount) apps"
        return "\(windows) in \(apps)"
    }
}

/// Asks for a layout's name. When saving a new layout it also lists the
/// windows that will be saved.
private struct LayoutNameSheet: View {
    let request: NameRequest
    let onSave: (String) -> Void

    @State private var name: String
    @Environment(\.dismiss) private var dismiss

    init(request: NameRequest, onSave: @escaping (String) -> Void) {
        self.request = request
        self.onSave = onSave
        _name = State(initialValue: request.name)
    }

    private var isNew: Bool { request.layoutID == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isNew ? "Save Layout" : "Rename Layout")
                .font(.title3.weight(.semibold))

            EditorCard("Name") {
                TextField("Name", text: $name, prompt: Text("Coding"))
                    .textFieldStyle(.roundedBorder)
            }

            if isNew {
                EditorCard("Windows") {
                    if request.windows.isEmpty {
                        Text("No windows are open.")
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(request.windows.enumerated()), id: \.offset) { _, window in
                                    WindowLine(window: window)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 220)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(name.trimmingCharacters(in: .whitespaces))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (isNew && request.windows.isEmpty))
            }
        }
        .padding(22)
        .frame(width: 440)
    }
}

/// One window in the list: its app's icon, the app, and the window's title.
private struct WindowLine: View {
    let window: SavedWindow

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 18, height: 18)
            Text(window.appName)
            if !window.title.isEmpty {
                Text(window.title)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var icon: NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: window.bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil) ?? NSImage()
    }
}
