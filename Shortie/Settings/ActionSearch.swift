import SwiftUI

/// One specific action you can pick, like "Left Half" or "Dark Mode On or Off".
struct ActionChoice: Identifiable {
    let id = UUID()
    let title: String
    /// The kind of action it belongs to, like "Move Window". Empty when it's the same as the title.
    let group: String
    let action: ShortcutAction
    // The words the search looks at, lowercased.
    private let titleWords: [String]
    private let groupWords: [String]
    private let keywordWords: [String]

    init(_ title: String, group: String, action: ShortcutAction, keywords: String = "") {
        self.title = title
        self.group = group == title ? "" : group
        self.action = action
        titleWords = Self.words(in: title)
        groupWords = Self.words(in: group)
        keywordWords = Self.words(in: keywords)
    }

    /// How well this action fits what's typed: 4 when its name starts with it, 3 when
    /// every word starts a word in its name, 2 when its group helps too, 1 when only
    /// the extra keywords match, and `nil` for no match. Words match from their start,
    /// so "up" finds "Volume Up" but not "Duplicate".
    func score(for query: String) -> Int? {
        let typed = Self.words(in: query)
        guard !typed.isEmpty else { return 0 }
        func fits(_ words: [String]) -> Bool {
            typed.allSatisfy { word in words.contains { $0.hasPrefix(word) } }
        }
        if fits(titleWords) {
            return title.lowercased().hasPrefix(query.lowercased().trimmingCharacters(in: .whitespaces)) ? 4 : 3
        }
        if fits(titleWords + groupWords) { return 2 }
        if fits(titleWords + groupWords + keywordWords) { return 1 }
        return nil
    }

    /// Lowercased words, with American spellings added so "maximize" finds "Maximise".
    private static func words(in text: String) -> [String] {
        let words = text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let american = words.map { $0.replacingOccurrences(of: "ise", with: "ize").replacingOccurrences(of: "entre", with: "enter") }
        return words + american.filter { !words.contains($0) }
    }

    /// The choices that match, best first. Matches that only come from the extra
    /// keywords are left out when anything matches by name or group.
    static func search(_ choices: [ActionChoice], for query: String) -> [ActionChoice] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return choices }
        let scored = choices.enumerated().compactMap { index, choice in
            choice.score(for: query).map { (choice, $0, index) }
        }
        let best = scored.map(\.1).max() ?? 0
        return scored
            .filter { best < 2 || $0.1 >= 2 }
            .sorted { ($0.1, -$0.2) > ($1.1, -$1.2) }
            .map(\.0)
    }

    /// Every action, one entry per specific choice, in the same order as the action menu.
    static func all(forSteps: Bool) -> [ActionChoice] {
        var choices: [ActionChoice] = []
        for kind in forSteps ? ActionKindPicker.stepKinds : ActionKindPicker.order {
            let group = kind.editorTitle
            let keywords = kind.searchKeywords
            switch kind {
            case .system:
                for action in SystemAction.groups.joined() {
                    choices.append(ActionChoice(action.title, group: group, action: .system(action: action), keywords: keywords))
                }
            case .moveWindow:
                for position in WindowPosition.groups.joined() {
                    choices.append(ActionChoice(position.title, group: group, action: .moveWindow(position: position), keywords: keywords))
                }
            case .appCommand:
                for command in AppCommand.groups.joined() {
                    choices.append(ActionChoice(command.title, group: group, action: .appCommand(command: command), keywords: keywords))
                }
            case .mouseClick:
                for click in MouseAction.groups.joined() {
                    choices.append(ActionChoice(click.title, group: group, action: .mouseClick(click: click), keywords: keywords))
                }
            case .text:
                for action in TextAction.groups.joined() {
                    choices.append(ActionChoice(action.title, group: group, action: .text(action: action), keywords: keywords))
                }
            case .restoreLayout where !WindowLayoutStore.shared.layouts.isEmpty:
                for layout in WindowLayoutStore.shared.layouts {
                    choices.append(ActionChoice("Restore “\(layout.name)”", group: group, action: .restoreLayout(id: layout.id, name: layout.name), keywords: keywords))
                }
            case .showMenu where !CustomMenuStore.shared.menus.isEmpty:
                for menu in CustomMenuStore.shared.menus {
                    choices.append(ActionChoice("Show “\(menu.name)”", group: group, action: .showMenu(id: menu.id, name: menu.name), keywords: keywords))
                }
            case .soundOutput:
                choices.append(ActionChoice("Next Sound Output", group: group, action: .soundOutput(uid: SoundOutput.nextDeviceUID, name: ""), keywords: keywords))
                for device in SoundOutput.devices() {
                    choices.append(ActionChoice("Play Sound on \(device.name)", group: group, action: .soundOutput(uid: device.uid, name: device.name), keywords: keywords))
                }
            default:
                choices.append(ActionChoice(group, group: group, action: kind.emptyAction, keywords: keywords))
            }
        }
        return choices
    }
}

extension ShortcutAction.Kind {
    /// Other words people might search for.
    var searchKeywords: String {
        switch self {
        case .openApp: "launch application"
        case .runShortcut: "shortcuts app automation"
        case .open: "url link website file folder"
        case .typeText: "type paste snippet text"
        case .moveWindow: "snap window resize position screen display"
        case .appCommand: "window app close quit hide minimise"
        case .mouseClick: "mouse click"
        case .system: "mac system media trash spaces desktop screenshot ocr color"
        case .pressKeys: "keyboard keys press shortcut"
        case .menuItem: "menu bar item"
        case .appleScript: "script automation"
        case .shellScript: "script terminal command"
        case .wait: "pause delay"
        case .steps: "several multiple chain sequence"
        case .showMenu: "custom menu"
        case .restoreLayout: "window layout arrangement"
        case .text: "selection selected text"
        case .showMessage: "message notification bubble"
        case .speak: "say voice read aloud"
        case .setVolume: "sound audio volume"
        case .soundOutput: "sound audio speakers headphones output device"
        case .appTask: "app application toggle show hide quit restart force"
        case .setBrightness: "display screen brightness dim"
        case .windowFrame: "window custom position size resize move"
        case .moveToDisplay: "window display monitor screen move"
        case .movePointer: "mouse cursor pointer move position"
        case .copyText: "clipboard copy text"
        case .pasteText: "paste insert text snippet clipboard"
        case .notify: "notification alert banner"
        case .webRequest: "http url webhook api request get post home automation"
        case .inputSource: "keyboard layout language input source"
        case .playSound: "sound alert beep play"
        }
    }
}

/// The magnifying glass beside the action menu: opens a list of every action to search.
struct ActionSearchButton: View {
    @Binding var action: ShortcutAction
    var forSteps = false

    @State private var isShowing = false

    var body: some View {
        Button {
            isShowing = true
        } label: {
            Image(systemName: "magnifyingglass")
        }
        .buttonStyle(.borderless)
        .help("Search all actions")
        .accessibilityLabel("Search all actions")
        .popover(isPresented: $isShowing, arrowEdge: .bottom) {
            ActionSearchList(forSteps: forSteps) { chosen in
                action = chosen
                isShowing = false
            }
        }
    }
}

struct ActionSearchList: View {
    let choose: (ShortcutAction) -> Void

    @State private var query = ""
    @State private var selection = 0
    @State private var all: [ActionChoice]
    @FocusState private var isFocused: Bool

    #if DEBUG
    private var typedLater: String?
    #endif

    init(forSteps: Bool, query: String = "", typedLater: String? = nil, choose: @escaping (ShortcutAction) -> Void) {
        self.choose = choose
        _query = State(initialValue: query)
        #if DEBUG
        self.typedLater = typedLater
        #endif
        _all = State(initialValue: ActionChoice.all(forSteps: forSteps))
    }

    private var results: [ActionChoice] {
        ActionChoice.search(all, for: query)
    }

    var body: some View {
        let results = results
        VStack(spacing: 0) {
            TextField("Search actions", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .padding(10)
                .onChange(of: query) { selection = 0 }
                .onSubmit { if results.indices.contains(selection) { choose(results[selection].action) } }
                .onKeyPress(.downArrow) { selection = min(selection + 1, max(results.count - 1, 0)); return .handled }
                .onKeyPress(.upArrow) { selection = max(selection - 1, 0); return .handled }

            Divider()

            if results.isEmpty {
                Text("No actions match.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.rowHeight * 2)
            } else {
                ScrollViewReader { scroller in
                    ScrollView {
                        // Rows are identified by their action, not their position, so the
                        // list redraws correctly as the results change.
                        VStack(alignment: .leading, spacing: 1) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, choice in
                                row(choice, isSelected: index == selection)
                                    .onTapGesture { choose(choice.action) }
                            }
                        }
                        .padding(6)
                    }
                    .onChange(of: selection) {
                        if results.indices.contains(selection) { scroller.scrollTo(results[selection].id) }
                    }
                }
                // As tall as the results, up to about ten rows.
                .frame(height: min(CGFloat(results.count) * (Self.rowHeight + 1) + 12, Self.rowHeight * 10 + 12))
            }
        }
        .frame(width: 340)
        .onAppear { isFocused = true }
        #if DEBUG
        // For snapshots: type after the list has appeared, as a person would.
        .task {
            guard let typedLater else { return }
            try? await Task.sleep(for: .milliseconds(300))
            query = typedLater
        }
        #endif
    }

    private static let rowHeight: CGFloat = 28

    private func row(_ choice: ActionChoice, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: choice.action.kind.systemImage)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            Text(choice.title)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(choice.group)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(height: Self.rowHeight)
        .id(choice.id)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? AnyShapeStyle(.tint.opacity(0.2)) : AnyShapeStyle(.clear))
        )
        .contentShape(.rect)
    }
}
