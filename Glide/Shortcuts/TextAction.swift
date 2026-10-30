import AppKit
import AVFoundation
import Carbon.HIToolbox

/// Things to do with the text you've selected in any app.
nonisolated enum TextAction: String, Codable, CaseIterable, Identifiable {
    case uppercase, lowercase, titleCase, sentenceCase
    case trimSpaces, joinLines, sortLines, removeDuplicateLines
    case urlEncode, urlDecode
    case searchWeb, speak, countWords
    case pasteAsPlainText

    var id: Self { self }

    var title: String {
        switch self {
        case .uppercase: "Make UPPERCASE"
        case .lowercase: "Make lowercase"
        case .titleCase: "Make Title Case"
        case .sentenceCase: "Make Sentence case"
        case .trimSpaces: "Trim Spaces"
        case .joinLines: "Join Lines"
        case .sortLines: "Sort Lines"
        case .removeDuplicateLines: "Remove Duplicate Lines"
        case .urlEncode: "URL-Encode"
        case .urlDecode: "URL-Decode"
        case .searchWeb: "Search the Web for Selection"
        case .speak: "Speak Selection"
        case .countWords: "Count Words in Selection"
        case .pasteAsPlainText: "Paste as Plain Text"
        }
    }

    /// For menus, so related actions sit together.
    static let groups: [[TextAction]] = [
        [.uppercase, .lowercase, .titleCase, .sentenceCase],
        [.trimSpaces, .joinLines, .sortLines, .removeDuplicateLines],
        [.urlEncode, .urlDecode],
        [.searchWeb, .speak, .countWords],
        [.pasteAsPlainText],
    ]

    /// The changed text, for actions that replace the selection; `nil` for the others.
    func transformed(_ text: String) -> String? {
        switch self {
        case .uppercase: return text.localizedUppercase
        case .lowercase: return text.localizedLowercase
        case .titleCase: return text.localizedCapitalized
        case .sentenceCase:
            var result = text.localizedLowercase
            var starts: [String.Index] = []
            result.enumerateSubstrings(in: result.startIndex..., options: .bySentences) { _, range, _, _ in
                if let letter = result[range].firstIndex(where: \.isLetter) { starts.append(letter) }
            }
            for start in starts {
                result.replaceSubrange(start...start, with: result[start...start].localizedUppercase)
            }
            return result
        case .trimSpaces:
            return lines(of: text)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case .joinLines:
            return lines(of: text)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        case .sortLines:
            return lines(of: text).sorted { $0.localizedStandardCompare($1) == .orderedAscending }.joined(separator: "\n")
        case .removeDuplicateLines:
            var seen = Set<String>()
            return lines(of: text).filter { seen.insert($0).inserted }.joined(separator: "\n")
        case .urlEncode:
            // Only RFC 3986's "unreserved" characters stay as they are.
            let unreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
            return text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? text
        case .urlDecode:
            return text.removingPercentEncoding ?? text
        case .searchWeb, .speak, .countWords, .pasteAsPlainText:
            return nil
        }
    }

    private func lines(of text: String) -> [String] {
        text.components(separatedBy: .newlines)
    }
}

/// Reads and replaces the selection in whichever app is in front.
///
/// Where the app supports it, the selection is read through the Accessibility
/// API. Otherwise it's copied with ⌘C. Replacing it pastes with ⌘V. Either way,
/// whatever was on your clipboard is put back afterwards, and none of this
/// shows up in clipboard history.
enum SelectedText {
    static func run(_ action: TextAction) {
        Task {
            // Your shortcut's keys would otherwise turn ⌘C into something else.
            await TextTyper.waitForModifiersReleased()
            ClipboardHistory.shared.ignoreChanges(true)
            let saved = savedClipboard()

            if action == .pasteAsPlainText {
                if let text = NSPasteboard.general.string(forType: .string) {
                    await paste(text)
                } else {
                    NSSound.beep()
                }
            } else if let text = await read(), !text.isEmpty {
                await perform(action, on: text)
            } else {
                NSSound.beep()
            }

            restoreClipboard(saved)
            ClipboardHistory.shared.ignoreChanges(false)
        }
    }

    private static func perform(_ action: TextAction, on text: String) async {
        if let result = action.transformed(text) {
            await paste(result)
            return
        }
        switch action {
        case .searchWeb:
            let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
            var components = URLComponents(string: "https://www.google.com/search")
            components?.queryItems = [URLQueryItem(name: "q", value: query)]
            if let url = components?.url { NSWorkspace.shared.open(url) }
        case .speak:
            Speaker.speak(text)
        case .countWords:
            var words = 0
            text.enumerateSubstrings(in: text.startIndex..., options: .byWords) { _, _, _, _ in words += 1 }
            HUD.show(words == 1 ? "1 Word" : "\(words.formatted()) Words", systemImage: "textformat.123")
        default:
            break
        }
    }

    private static func read() async -> String? {
        let system = AXUIElementCreateSystemWide()
        if let focused = AX.element(system, kAXFocusedUIElementAttribute),
           let text = AX.string(focused, kAXSelectedTextAttribute), !text.isEmpty {
            return text
        }
        // Copy it, and wait (up to half a second) for the app to do so.
        let pasteboard = NSPasteboard.general
        let before = pasteboard.changeCount
        KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_ANSI_C), modifiers: .command, keyName: "C"))
        for _ in 0..<25 {
            try? await Task.sleep(for: .milliseconds(20))
            if pasteboard.changeCount != before { return pasteboard.string(forType: .string) }
        }
        return nil
    }

    private static func paste(_ text: String) async {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        KeyPresser.press(KeyCombo(keyCode: UInt16(kVK_ANSI_V), modifiers: .command, keyName: "V"))
        // Apps read the clipboard a moment after ⌘V, so wait before putting it back.
        try? await Task.sleep(for: .milliseconds(300))
    }

    /// A copy of everything on the clipboard, in every format.
    private static func savedClipboard() -> [NSPasteboardItem] {
        (NSPasteboard.general.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }

    private static func restoreClipboard(_ items: [NSPasteboardItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if !items.isEmpty { pasteboard.writeObjects(items) }
    }
}

/// Reads text aloud with the voice chosen in System Settings › Accessibility › Spoken Content.
enum Speaker {
    private static let synthesizer = AVSpeechSynthesizer()

    /// Speaking again while it's still talking stops it instead.
    static func speak(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.prefersAssistiveTechnologySettings = true
        synthesizer.speak(utterance)
    }
}
