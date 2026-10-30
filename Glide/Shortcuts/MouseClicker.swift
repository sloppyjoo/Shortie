import CoreGraphics

/// Marks events Glide makes itself (scrolls, clicks), so Glide's own event taps
/// recognise them and let them straight through.
nonisolated enum SyntheticEvent {
    static let marker: Int64 = 0x474C_4944
}

/// Mouse clicks a shortcut or gesture can make, wherever the pointer is.
nonisolated enum MouseAction: String, Codable, CaseIterable, Identifiable {
    case leftClick, rightClick, middleClick, doubleClick

    var id: Self { self }

    var title: String {
        switch self {
        case .leftClick: "Left Click"
        case .rightClick: "Right Click"
        case .middleClick: "Middle Click"
        case .doubleClick: "Double Click"
        }
    }

    var systemImage: String {
        switch self {
        case .leftClick: "cursorarrow.click"
        case .rightClick: "contextualmenu.and.cursorarrow"
        case .middleClick: "computermouse"
        case .doubleClick: "cursorarrow.click.2"
        }
    }
}

enum MouseClicker {
    static func perform(_ action: MouseAction) {
        let location = CGEvent(source: nil)?.location ?? .zero
        switch action {
        case .leftClick:
            click(.leftMouseDown, .leftMouseUp, .left, at: location)
        case .rightClick:
            click(.rightMouseDown, .rightMouseUp, .right, at: location)
        case .middleClick:
            click(.otherMouseDown, .otherMouseUp, .center, at: location)
        case .doubleClick:
            // Apps tell a double click by the second click's "click count" of 2.
            click(.leftMouseDown, .leftMouseUp, .left, at: location, count: 1)
            click(.leftMouseDown, .leftMouseUp, .left, at: location, count: 2)
        }
    }

    private static func click(
        _ down: CGEventType, _ up: CGEventType, _ button: CGMouseButton, at location: CGPoint, count: Int64 = 1
    ) {
        for type in [down, up] {
            let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: location, mouseButton: button)
            event?.setIntegerValueField(.mouseEventClickState, value: count)
            event?.setIntegerValueField(.eventSourceUserData, value: SyntheticEvent.marker)
            event?.post(tap: .cghidEventTap)
        }
    }
}
