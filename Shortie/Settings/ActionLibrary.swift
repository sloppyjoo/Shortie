import SwiftUI

/// A category of actions in the action library.
struct ActionCategory: Identifiable {
    let title: String
    let summary: String
    let systemImage: String
    let color: Color
    let kinds: [ShortcutAction.Kind]

    var id: String { title }

    static func all(forSteps: Bool) -> [ActionCategory] {
        let look: [String: (summary: String, image: String, color: Color)] = [
            "Mouse & Keyboard": ("Clicks, keys and the pointer", "cursorarrow.rays", .orange),
            "Windows": ("Snap, move and manage windows", "macwindow", .blue),
            "Apps & Controls": ("Open apps and press their buttons", "square.grid.2x2", .indigo),
            "Text & Clipboard": ("Type, paste and change text", "text.cursor", .purple),
            "System & Devices": ("Sound, displays and Mac settings", "switch.2", .pink),
            "Show": ("Messages, menus and web pages", "text.bubble", .yellow),
            "Scripts & Network": ("Scripts, webhooks and MIDI", "terminal", .gray),
            "Shortie": ("Several actions, and Shortie itself", "hand.point.up.left", .green),
        ]
        var categories = ActionKindPicker.groups.map { group in
            let style = look[group.title] ?? ("", "square.grid.2x2", .gray)
            return ActionCategory(
                title: group.title, summary: style.summary, systemImage: style.image, color: style.color,
                kinds: group.kinds.filter { !forSteps || $0 != .steps }
            )
        }
        if forSteps {
            categories.append(ActionCategory(title: "Steps", summary: "Waits, ifs, repeats and variables", systemImage: "list.number", color: .green, kinds: [.flow, .wait]))
        }
        return categories
    }
}

/// The button that shows the chosen action, and opens the library to change it.
struct ActionLibraryButton: View {
    @Binding var action: ShortcutAction
    var forSteps = false

    @State private var isOpen = false
    @State private var isHovering = false

    var body: some View {
        Button {
            isOpen = true
        } label: {
            HStack(spacing: 8) {
                SettingsIcon(systemImage: action.kind.systemImage, color: action.kind.color, size: 20)
                Text(action.kind.editorTitle)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 4)
            .padding(.trailing, 10)
            .padding(.vertical, 4)
            .background(.quaternary.opacity(isHovering ? 0.9 : 0.6), in: .rect(cornerRadius: 8, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .onHover { isHovering = $0 }
        .help("Choose an action")
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            ActionLibrary(current: action.kind, forSteps: forSteps) { chosen in
                if let chosen { action = chosen }
                isOpen = false
            }
        }
    }
}

/// Every action, organised: categories on the left, their actions as tiles on the
/// right, and a search across everything at the top.
struct ActionLibrary: View {
    let current: ShortcutAction.Kind
    let forSteps: Bool
    /// `nil` means "keep the action as it is" (you picked the one you already had).
    let choose: (ShortcutAction?) -> Void

    @State private var categoryID: String
    @State private var query = ""
    @State private var selection = 0
    @FocusState private var searchFocused: Bool

    private let categories: [ActionCategory]
    private let everything: [ActionChoice]

    init(current: ShortcutAction.Kind, forSteps: Bool, query: String = "", choose: @escaping (ShortcutAction?) -> Void) {
        self.current = current
        self.forSteps = forSteps
        self.choose = choose
        let categories = ActionCategory.all(forSteps: forSteps)
        self.categories = categories
        everything = ActionChoice.all(forSteps: forSteps)
        _query = State(initialValue: query)
        // Open on the category of the action you already have.
        _categoryID = State(initialValue: categories.first { $0.kinds.contains(current) }?.id ?? categories.first?.id ?? "")
    }

    private var category: ActionCategory? {
        categories.first { $0.id == categoryID }
    }

    private var results: [ActionChoice] {
        ActionChoice.search(everything, for: query)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                HStack(spacing: 0) {
                    sidebar
                    Divider()
                    tiles
                }
            } else {
                searchResults
            }
        }
        .frame(width: 640, height: 460)
        .onAppear { searchFocused = true }
    }

    // MARK: Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search all actions", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($searchFocused)
                .onChange(of: query) { selection = 0 }
                .onSubmit {
                    let results = results
                    if results.indices.contains(selection) { choose(results[selection].action) }
                }
                .onKeyPress(.downArrow) { selection = min(selection + 1, max(results.count - 1, 0)); return .handled }
                .onKeyPress(.upArrow) { selection = max(selection - 1, 0); return .handled }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var searchResults: some View {
        let results = results
        return Group {
            if results.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Text("No actions match “\(query)”.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { scroller in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, choice in
                                HStack(spacing: 10) {
                                    SettingsIcon(systemImage: choice.action.kind.systemImage, color: choice.action.kind.color, size: 24)
                                    Text(choice.title)
                                        .lineLimit(1)
                                    Spacer(minLength: 8)
                                    Text(choice.group)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(index == selection ? AnyShapeStyle(.tint.opacity(0.2)) : AnyShapeStyle(.clear),
                                            in: .rect(cornerRadius: 8, style: .continuous))
                                .contentShape(.rect)
                                .onTapGesture { choose(choice.action) }
                                .onHover { if $0 { selection = index } }
                                .id(choice.id)
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: selection) {
                        if results.indices.contains(selection) { scroller.scrollTo(results[selection].id) }
                    }
                }
            }
        }
    }

    // MARK: Categories

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(categories) { item in
                    Button {
                        categoryID = item.id
                    } label: {
                        HStack(spacing: 9) {
                            SettingsIcon(systemImage: item.systemImage, color: item.color, size: 22)
                            Text(item.title)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if item.kinds.contains(current) {
                                Circle()
                                    .fill(.tint)
                                    .frame(width: 6, height: 6)
                                    .help("Your current action is in here")
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(item.id == categoryID ? AnyShapeStyle(.tint.opacity(0.18)) : AnyShapeStyle(.clear),
                                    in: .rect(cornerRadius: 8, style: .continuous))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
        .frame(width: 200)
        .background(.quaternary.opacity(0.25))
    }

    private var tiles: some View {
        ScrollView {
            if let category {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.title)
                            .font(.title3.weight(.semibold))
                        Text(category.summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(category.kinds) { kind in
                            ActionTile(kind: kind, isCurrent: kind == current) {
                                choose(kind == current ? nil : kind.emptyAction)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// One action type in the library: its icon, name and what it's for.
private struct ActionTile: View {
    let kind: ShortcutAction.Kind
    let isCurrent: Bool
    let choose: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: choose) {
            HStack(alignment: .top, spacing: 10) {
                SettingsIcon(systemImage: kind.systemImage, color: kind.color, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.editorTitle)
                        .font(.callout.weight(.medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(kind.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
            .background(.quaternary.opacity(isHovering ? 0.8 : 0.4), in: .rect(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 1.5)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

extension ShortcutAction.Kind {
    /// One line on what it's for, shown in the action library.
    var summary: String {
        switch self {
        case .mouseClick: "Click, scroll or move the pointer"
        case .customClick: "Any button, any modifier keys, any count"
        case .movePointer: "Put the pointer at exact coordinates"
        case .pointerSetting: "Mouse or trackpad speed, pointer size"
        case .pressKeys: "Press a keyboard shortcut"
        case .pressKeysInApp: "Send keys to an app in the background"
        case .modifierKeys: "Hold ⌘ ⌥ ⌃ ⇧ down, or let go"
        case .remapKey: "Make one key act as another, or as Hyper"
        case .moveWindow: "Halves, thirds, corners and displays"
        case .windowFrame: "An exact position and size"
        case .moveToDisplay: "Send the window to another screen"
        case .moveToDesktop: "Send the window to Desktop 1–9"
        case .appCommand: "Close, minimise, hide, quit and more"
        case .focusWindow: "Find a window by its title"
        case .restoreLayout: "Put your saved windows back"
        case .openApp: "Open an app, or switch to it"
        case .appTask: "Toggle, hide, quit or restart an app"
        case .open: "A website, file or folder"
        case .runShortcut: "One from the Shortcuts app"
        case .menuItem: "Choose from the front app's menus"
        case .clickButton: "Press a button by its name"
        case .clickMenuBarExtra: "Click an icon in the menu bar"
        case .contextMenuItem: "Right-click, then choose an item"
        case .slider: "Set a slider in the front window"
        case .clickText: "Read the screen and click some text"
        case .clickImage: "Find a picture on screen and click it"
        case .typeText: "Type text as if from the keyboard"
        case .pasteText: "Paste text in one go"
        case .copyText: "Put text on the clipboard"
        case .text: "Change case, sort, encode, look up…"
        case .transformText: "Rewrite text with your own JavaScript"
        case .clipboardItem: "Paste something you copied earlier"
        case .callService: "Run a Services menu item on the selection"
        case .ai: "Rewrite, translate or answer with Claude"
        case .system: "Media, Mission Control, toggles and more"
        case .setVolume: "Set the volume to a level"
        case .setBrightness: "Set the display's brightness"
        case .externalBrightness: "An external display's brightness"
        case .keyboardBrightness: "The keyboard backlight level"
        case .soundOutput: "Switch speakers or headphones"
        case .soundInput: "Switch microphones"
        case .inputSource: "Switch keyboard layout or language"
        case .playSound: "An alert sound or audio file"
        case .bluetoothDevice: "Connect or disconnect a device"
        case .showMessage: "A short message on screen"
        case .notify: "A Notification Centre banner"
        case .speak: "Read text aloud"
        case .webView: "A web page in a floating window"
        case .searchList: "Pick from a list you write"
        case .showMenu: "One of your custom menus"
        case .appleScript: "Control apps with AppleScript"
        case .javaScript: "JavaScript for Automation (JXA)"
        case .browserJavaScript: "Run JavaScript in the page in front"
        case .shellScript: "Run a Terminal command"
        case .runWorkflow: "Run an Automator workflow"
        case .webRequest: "Call a web address or webhook"
        case .distributedNotification: "Send a signal other apps listen for"
        case .midi: "Notes and controls for MIDI gear"
        case .osc: "Open Sound Control messages"
        case .steps: "Several actions in a row"
        case .cycle: "A different action each time"
        case .otherRule: "Run, switch on or off another rule"
        case .pauseShortie: "Pause every trigger for a while"
        case .openSettingsPane: "A page of Shortie's settings"
        case .wait: "Pause between steps"
        case .flow: "If, repeat, wait until and variables"
        }
    }
}
