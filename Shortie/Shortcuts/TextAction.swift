import AppKit
import AVFoundation
import Carbon.HIToolbox

/// Things to do with the text you've selected in any app.
nonisolated enum TextAction: String, Codable, CaseIterable, Identifiable {
    case uppercase, lowercase, titleCase, sentenceCase
    case camelCase, snakeCase, kebabCase
    case trimSpaces, joinLines, sortLines, removeDuplicateLines
    case reverseLines, shuffleLines, numberLines, removeEmptyLines, reverseText
    case urlEncode, urlDecode
    case base64Encode, base64Decode, prettifyJSON
    case searchWeb, speak, countWords
    case countCharacters, lookUp, translate, openAsLink
    case pasteAsPlainText

    var id: Self { self }

    var title: String {
        switch self {
        case .uppercase: "Make UPPERCASE"
        case .lowercase: "Make lowercase"
        case .titleCase: "Make Title Case"
        case .sentenceCase: "Make Sentence case"
        case .camelCase: "Make camelCase"
        case .snakeCase: "Make snake_case"
        case .kebabCase: "Make kebab-case"
        case .reverseLines: "Reverse Lines"
        case .shuffleLines: "Shuffle Lines"
        case .numberLines: "Number Lines"
        case .removeEmptyLines: "Remove Empty Lines"
        case .reverseText: "Reverse Text"
        case .base64Encode: "Base64-Encode"
        case .base64Decode: "Base64-Decode"
        case .prettifyJSON: "Format JSON"
        case .countCharacters: "Count Characters in Selection"
        case .lookUp: "Look Up in Dictionary"
        case .translate: "Translate Selection"
        case .openAsLink: "Open Selection as a Link"
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
        [.uppercase, .lowercase, .titleCase, .sentenceCase, .camelCase, .snakeCase, .kebabCase],
        [.trimSpaces, .joinLines, .sortLines, .removeDuplicateLines],
        [.reverseLines, .shuffleLines, .numberLines, .removeEmptyLines, .reverseText],
        [.urlEncode, .urlDecode, .base64Encode, .base64Decode, .prettifyJSON],
        [.searchWeb, .lookUp, .translate, .openAsLink],
        [.speak, .countWords, .countCharacters],
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
        case .camelCase:
            let words = Self.words(of: text).map { $0.lowercased() }
            guard let first = words.first else { return text }
            return first + words.dropFirst().map(\.capitalized).joined()
        case .snakeCase:
            return Self.words(of: text).map { $0.lowercased() }.joined(separator: "_")
        case .kebabCase:
            return Self.words(of: text).map { $0.lowercased() }.joined(separator: "-")
        case .reverseLines:
            return lines(of: text).reversed().joined(separator: "\n")
        case .shuffleLines:
            return lines(of: text).shuffled().joined(separator: "\n")
        case .numberLines:
            return lines(of: text).enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        case .removeEmptyLines:
            return lines(of: text).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: "\n")
        case .reverseText:
            return String(text.reversed())
        case .base64Encode:
            return Data(text.utf8).base64EncodedString()
        case .base64Decode:
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return Data(base64Encoded: trimmed, options: .ignoreUnknownCharacters).flatMap { String(data: $0, encoding: .utf8) } ?? text
        case .prettifyJSON:
            guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8), options: .fragmentsAllowed),
                  let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            else { return text }
            return String(decoding: data, as: UTF8.self)
        case .searchWeb, .speak, .countWords, .pasteAsPlainText, .countCharacters, .lookUp, .translate, .openAsLink:
            return nil
        }
    }

    /// Splits "someText here_and-there" into ["some", "Text", "here", "and", "there"].
    private static func words(of text: String) -> [String] {
        var words: [String] = []
        var current = ""
        var previous: Character?
        for character in text {
            if character.isLetter || character.isNumber {
                // A capital after a small letter starts a new word, as in camelCase.
                if character.isUppercase, let previous, previous.isLowercase || previous.isNumber, !current.isEmpty {
                    words.append(current)
                    current = ""
                }
                current.append(character)
            } else if !current.isEmpty {
                words.append(current)
                current = ""
            }
            previous = character
        }
        if !current.isEmpty { words.append(current) }
        return words
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
        case .countCharacters:
            HUD.show(text.count == 1 ? "1 Character" : "\(text.count.formatted()) Characters", systemImage: "textformat.abc")
        case .lookUp:
            let word = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: "dict://" + (word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word)) {
                NSWorkspace.shared.open(url)
            }
        case .translate:
            var components = URLComponents(string: "https://translate.google.com/")
            components?.queryItems = [
                URLQueryItem(name: "sl", value: "auto"),
                URLQueryItem(name: "tl", value: Locale.current.language.languageCode?.identifier ?? "en"),
                URLQueryItem(name: "text", value: text),
            ]
            if let url = components?.url { NSWorkspace.shared.open(url) }
        case .openAsLink:
            if let url = ShortcutAction.url(for: text) { NSWorkspace.shared.open(url) } else { NSSound.beep() }
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
