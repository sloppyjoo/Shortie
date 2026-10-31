import AppKit
import SwiftUI

/// The clipboard history panel: search, then paste straight into the app you
/// were using. ↩ pastes, ⌘P pins, ⌘⌫ deletes, Esc closes.
final class ClipboardPanel: NSObject, NSWindowDelegate {
    static let shared = ClipboardPanel()

    private var panel: GlassPanel?
    private let state = ClipboardPanelState()

    func show() {
        state.query = ""
        state.selection = 0
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.showCentred()
    }

    func close() {
        panel?.orderOut(nil)
    }

    /// Clicking anywhere else closes it.
    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func makePanel() -> GlassPanel {
        let panel = GlassPanel(size: NSSize(width: 580, height: 460), content: ClipboardPanelView(
            state: state,
            paste: { [weak self] entry in
                self?.close()
                ClipboardHistory.shared.paste(entry)
            },
            dismiss: { [weak self] in self?.close() }
        ))
        panel.delegate = self
        return panel
    }
}

@Observable
final class ClipboardPanelState {
    var query = "" {
        didSet { selection = 0 }
    }
    var selection = 0

    /// Pinned first, then everything else newest first, filtered by the search.
    var visible: [ClipboardEntry] {
        let words = query.split(separator: " ")
        let matching = ClipboardHistory.shared.entries.filter { entry in
            words.allSatisfy { entry.searchText.localizedCaseInsensitiveContains($0) }
        }
        return matching.filter(\.isPinned) + matching.filter { !$0.isPinned }
    }

    func moveSelection(by step: Int) {
        let count = visible.count
        guard count > 0 else { return }
        selection = (selection + step + count) % count
    }

    var selected: ClipboardEntry? {
        let visible = visible
        return visible.indices.contains(selection) ? visible[selection] : nil
    }
}

struct ClipboardPanelView: View {
    @Bindable var state: ClipboardPanelState
    let paste: (ClipboardEntry) -> Void
    let dismiss: () -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "doc.on.clipboard")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                TextField("Search clipboard", text: $state.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 20))
                    .focused($searchFocused)
                    .onSubmit { state.selected.map(paste) }
                    .onKeyPress(.upArrow) { state.moveSelection(by: -1); return .handled }
                    .onKeyPress(.downArrow) { state.moveSelection(by: 1); return .handled }
                    .onKeyPress(.escape) { dismiss(); return .handled }
                    .onKeyPress(phases: .down) { press in
                        guard press.modifiers == .command, let entry = state.selected else { return .ignored }
                        switch press.key {
                        case "p":
                            ClipboardHistory.shared.togglePin(entry)
                            return .handled
                        case .delete:
                            ClipboardHistory.shared.delete(entry)
                            return .handled
                        default:
                            return .ignored
                        }
                    }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            Divider().opacity(0.5)

            list

            Divider().opacity(0.5)

            HStack(spacing: 16) {
                KeyHint(keys: "↩", label: "Paste")
                KeyHint(keys: "⌘P", label: "Pin")
                KeyHint(keys: "⌘⌫", label: "Delete")
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
        }
        .frame(width: 580, height: 460)
        .background(GlassBackground())
        .onAppear { searchFocused = true }
    }

    private var list: some View {
        let entries = state.visible
        return ScrollViewReader { scroller in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        ClipboardRow(entry: entry, isSelected: index == state.selection)
                            .id(index)
                            .onTapGesture { paste(entry) }
                    }
                    if entries.isEmpty {
                        EmptyState(state.query.isEmpty ? "Nothing copied yet" : "No matches", pixels: PixelArt.clipboard)
                            .padding(.top, 40)
                    }
                }
                .padding(8)
                .animation(.smooth(duration: 0.2), value: entries.map(\.id))
            }
            .onChange(of: state.selection) { _, selection in
                withAnimation(.smooth(duration: 0.15)) { scroller.scrollTo(selection) }
            }
        }
    }
}

private struct ClipboardRow: View {
    let entry: ClipboardEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            preview
            Spacer(minLength: 8)
            if entry.isPinned {
                Image(systemName: "pin.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Text(entry.date, format: .relative(presentation: .named))
                .font(.callout)
                .foregroundStyle(.secondary)
            if let source = entry.sourceBundleID {
                AppIcon(bundleID: source, size: 20)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.primary.opacity(0.1) : .clear)
        )
        .contentShape(.rect)
    }

    @ViewBuilder
    private var preview: some View {
        switch entry.content {
        case .text(let text):
            Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 14))
                .lineLimit(2)
                .truncationMode(.tail)
        case .image(let fileName):
            if let image = ClipboardHistory.shared.image(for: fileName) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200, maxHeight: 64, alignment: .leading)
                    .clipShape(.rect(cornerRadius: 6))
            } else {
                Label("Image", systemImage: "photo")
            }
        case .files(let paths):
            HStack(spacing: 8) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: paths[0]))
                    .resizable()
                    .frame(width: 24, height: 24)
                Text(paths.count == 1 ? (paths[0] as NSString).lastPathComponent : "\(paths.count) files")
                    .font(.system(size: 14))
                    .lineLimit(1)
            }
        }
    }
}

/// "⌘P Pin" at the bottom of the panel.
private struct KeyHint: View {
    let keys: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Text(keys)
                .font(.callout.monospaced())
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.quaternary, in: .rect(cornerRadius: 4))
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
