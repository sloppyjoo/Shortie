import SwiftUI

/// The Custom Menus page: your own menus of actions, shown in the menu bar
/// or opened at the pointer.
struct CustomMenusSettingsView: View {
    private var store = CustomMenuStore.shared
    @State private var editing: CustomMenu?

    var body: some View {
        @Bindable var store = store

        Form {
            PaneHeader(pane: .menus)

            Section {
                if store.menus.isEmpty {
                    EmptyState("No menus yet.", pixels: PixelArt.menu)
                }
                ForEach($store.menus) { $menu in
                    CustomMenuRow(menu: $menu, edit: { editing = menu }, delete: { store.delete(id: menu.id) })
                }
            } header: {
                HStack {
                    SectionTitle("Menus")
                    InfoButton("Switch on Menu Bar to give a menu its own icon there. To open a menu at the pointer instead, give any trigger the Show Custom Menu action.")
                    Spacer()
                    Button("Add", systemImage: "plus") {
                        editing = CustomMenu(name: "", symbol: "star.fill", items: [], showsInMenuBar: true)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .animation(.smooth(duration: 0.25), value: store.menus.map(\.id))
        .sheet(item: $editing) { menu in
            CustomMenuEditor(menu: menu) { store.save($0) }
        }
    }
}

private struct CustomMenuRow: View {
    @Binding var menu: CustomMenu
    let edit: () -> Void
    let delete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: edit) {
                HStack(spacing: 10) {
                    SettingsIcon(systemImage: menu.symbol, color: .mint, size: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(menu.name)
                        Text(menu.items.count == 1 ? "1 item" : "\(menu.items.count) items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Toggle("Menu Bar", isOn: $menu.showsInMenuBar)
                .toggleStyle(.switch)
                .controlSize(.small)

            Menu {
                Button("Edit…", action: edit)
                Button("Delete", role: .destructive, action: delete)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .opacity(isHovering ? 1 : 0)
        }
        .contentShape(.rect)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .contextMenu {
            Button("Edit…", action: edit)
            Button("Delete", role: .destructive, action: delete)
        }
    }
}

/// The sheet for one custom menu: its name and icon, then its items.
struct CustomMenuEditor: View {
    @State var menu: CustomMenu
    let onSave: (CustomMenu) -> Void

    @Environment(\.dismiss) private var dismiss

    /// A handful of clear symbols to choose from.
    private static let symbols = [
        "star.fill", "bolt.fill", "heart.fill", "folder.fill", "doc.text.fill", "pencil",
        "paintbrush.fill", "hammer.fill", "wrench.and.screwdriver.fill", "globe", "music.note", "camera.fill",
        "gamecontroller.fill", "terminal.fill", "keyboard.fill", "macwindow", "sparkles", "flag.fill",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Custom Menu")
                .font(.title3.weight(.semibold))

            EditorCard("Name") {
                HStack {
                    TextField("Name", text: $menu.name, prompt: Text("Writing"))
                        .textFieldStyle(.roundedBorder)
                    Toggle("Show in Menu Bar", isOn: $menu.showsInMenuBar)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 6), count: 9), alignment: .leading, spacing: 6) {
                    ForEach(Self.symbols, id: \.self) { symbol in
                        Button { menu.symbol = symbol } label: {
                            Image(systemName: symbol)
                                .frame(width: 30, height: 30)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(menu.symbol == symbol ? AnyShapeStyle(.tint.opacity(0.25)) : AnyShapeStyle(.clear))
                                )
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(symbol)
                    }
                }
            }

            EditorCard("Items") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(menu.items.indices), id: \.self) { index in
                            itemEditor(index)
                        }
                        Menu("Add Item", systemImage: "plus") {
                            ForEach(ActionKindPicker.stepKinds.filter { $0 != .wait }) { kind in
                                Button(kind.editorTitle, systemImage: kind.systemImage) {
                                    menu.items.append(CustomMenuItem(title: "", action: kind.emptyAction))
                                }
                            }
                        }
                        .fixedSize()
                    }
                }
                .frame(maxHeight: 320)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(menu)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(menu.name.trimmingCharacters(in: .whitespaces).isEmpty || !menu.items.allSatisfy(\.action.isComplete))
            }
        }
        .padding(22)
        .frame(width: 560)
        .animation(.smooth(duration: 0.2), value: menu.items)
    }

    private func itemEditor(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Title", text: $menu.items[index].title, prompt: Text(menu.items[index].action.title))
                    .textFieldStyle(.roundedBorder)
                ActionKindPicker(action: $menu.items[index].action, forSteps: true)
                Group {
                    Button { move(index, by: -1) } label: { Image(systemName: "chevron.up") }
                        .disabled(index == 0)
                    Button { move(index, by: 1) } label: { Image(systemName: "chevron.down") }
                        .disabled(index == menu.items.count - 1)
                    Button { menu.items.remove(at: index) } label: { Image(systemName: "minus.circle") }
                }
                .buttonStyle(.borderless)
            }
            ActionFields(action: $menu.items[index].action)
                .padding(.leading, 4)
        }
        .padding(10)
        .background(.background.opacity(0.6), in: .rect(cornerRadius: 9, style: .continuous))
    }

    private func move(_ index: Int, by offset: Int) {
        let target = index + offset
        guard menu.items.indices.contains(target) else { return }
        menu.items.swapAt(index, target)
    }
}
