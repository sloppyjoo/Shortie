import AppKit
import ApplicationServices
import Observation
import SwiftUI

/// A Spotlight-style panel listing every open window (not just every app, like
/// ⌘-Tab). Type to filter, ↑↓ to choose, ↩ to switch, Esc to close.
///
/// Windows come from the Accessibility API, so no Screen Recording permission
/// is needed: we show titles and app icons rather than pictures of windows.
final class WindowSwitcher: NSObject, NSWindowDelegate {
    static let shared = WindowSwitcher()

    private var panel: GlassPanel?
    private let model = WindowSwitcherModel()

    func show() {
        model.reload()
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
        let panel = GlassPanel(size: NSSize(width: 560, height: 430), content: WindowSwitcherView(
            model: model,
            choose: { [weak self] window in
                self?.close()
                window.focus()
            },
            dismiss: { [weak self] in self?.close() }
        ))
        panel.delegate = self
        return panel
    }
}

/// One window in the list.
struct SwitchableWindow: Identifiable {
    let id = UUID()
    let element: AXUIElement
    let processID: pid_t
    let title: String
    let appName: String
    let appIcon: NSImage
    let isMinimized: Bool

    /// Brings this window to the front (un-minimising it if needed), and its app with it.
    func focus() {
        if isMinimized {
            AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        NSRunningApplication(processIdentifier: processID)?.activate()
    }
}

@Observable
final class WindowSwitcherModel {
    var query = "" {
        didSet { selection = 0 }
    }
    var selection = 0
    private(set) var windows: [SwitchableWindow] = []

    init() {
        // If an app is frozen, don't hold up the switcher waiting for it to answer.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.25)
    }

    var filtered: [SwitchableWindow] {
        let words = query.split(separator: " ")
        guard !words.isEmpty else { return windows }
        return windows.filter { window in
            words.allSatisfy { word in
                window.title.localizedCaseInsensitiveContains(word) || window.appName.localizedCaseInsensitiveContains(word)
            }
        }
    }

    func moveSelection(by step: Int) {
        let count = filtered.count
        guard count > 0 else { return }
        selection = (selection + step + count) % count
    }

    /// Gathers every window of every app, ordered the way they're stacked on
    /// screen (front first), with minimised and hidden ones after.
    func reload() {
        query = ""
        let stackOrder = Self.stackOrder()
        var found: [(window: SwitchableWindow, order: Int)] = []

        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            for element in AX.windows(of: app.processIdentifier) {
                guard AX.string(element, kAXSubroleAttribute) == kAXStandardWindowSubrole else { continue }
                let title = AX.string(element, kAXTitleAttribute) ?? ""
                let window = SwitchableWindow(
                    element: element,
                    processID: app.processIdentifier,
                    title: title.isEmpty ? (app.localizedName ?? "Untitled") : title,
                    appName: app.localizedName ?? "",
                    appIcon: app.icon ?? NSWorkspace.shared.icon(for: .application),
                    isMinimized: AX.bool(element, kAXMinimizedAttribute) ?? false
                )
                let frame = WindowMover.shared.frame(of: element)
                let order = stackOrder.firstIndex { $0.processID == app.processIdentifier && $0.bounds == frame } ?? Int.max
                found.append((window, order))
            }
        }
        windows = found.sorted { $0.order < $1.order }.map(\.window)
        selection = windows.count > 1 && windows.first?.processID == NSWorkspace.shared.frontmostApplication?.processIdentifier ? 1 : 0
    }

    /// The window server's front-to-back list of visible windows.
    private static func stackOrder() -> [(processID: pid_t, bounds: CGRect)] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  let processID = info[kCGWindowOwnerPID as String] as? pid_t,
                  let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo)
            else { return nil }
            return (processID, bounds)
        }
    }
}

struct WindowSwitcherView: View {
    @Bindable var model: WindowSwitcherModel
    let choose: (SwitchableWindow) -> Void
    let dismiss: () -> Void

    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                TextField("Switch to a window", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .focused($searchFocused)
                    .onSubmit(chooseSelected)
                    .onKeyPress(.upArrow) { model.moveSelection(by: -1); return .handled }
                    .onKeyPress(.downArrow) { model.moveSelection(by: 1); return .handled }
                    .onKeyPress(.escape) { dismiss(); return .handled }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            Divider().opacity(0.5)

            list
        }
        .frame(width: 560, height: 430)
        .background(GlassBackground())
        .onAppear { searchFocused = true }
    }

    private var list: some View {
        let windows = model.filtered
        return ScrollViewReader { scroller in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(windows.enumerated()), id: \.element.id) { index, window in
                        row(window, isSelected: index == model.selection)
                            .id(index)
                            .onTapGesture { choose(window) }
                    }
                    if windows.isEmpty {
                        Text("No matching windows")
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    }
                }
                .padding(8)
            }
            .onChange(of: model.selection) { _, selection in
                withAnimation(.smooth(duration: 0.15)) { scroller.scrollTo(selection) }
            }
        }
    }

    private func row(_ window: SwitchableWindow, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: window.appIcon)
                .resizable()
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(window.title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(window.isMinimized ? "\(window.appName) · Minimised" : window.appName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.primary.opacity(0.1) : .clear)
        )
        .contentShape(.rect)
    }

    private func chooseSelected() {
        let windows = model.filtered
        guard windows.indices.contains(model.selection) else { return }
        choose(windows[model.selection])
    }
}
