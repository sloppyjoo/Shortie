import AppKit

/// Marks events Shortie makes itself (scrolls, clicks), so Shortie's own event taps
/// recognise them and let them straight through.
nonisolated enum SyntheticEvent {
    static let marker: Int64 = 0x474C_4944
}

/// Mouse clicks a shortcut or gesture can make, wherever the pointer is.
nonisolated enum MouseAction: String, Codable, CaseIterable, Identifiable {
    case leftClick, rightClick, middleClick, doubleClick, tripleClick
    case leftButtonDown, leftButtonUp, doubleClickDrag
    case leftClickNoModifiers, commandDoubleClick, commandShiftClick
    case savePointer, restorePointer
    case commandClick, optionClick, shiftClick, controlClick
    case backButton, forwardButton
    case scrollUp, scrollDown, scrollLeft, scrollRight
    case moveToScreenCentre, moveToWindowCentre, moveToNextDisplay

    var id: Self { self }

    var title: String {
        switch self {
        case .leftClick: "Left Click"
        case .rightClick: "Right Click"
        case .middleClick: "Middle Click"
        case .doubleClick: "Double Click"
        case .tripleClick: "Triple Click"
        case .leftButtonDown: "Hold Left Button Down"
        case .leftButtonUp: "Let Go of Left Button"
        case .doubleClickDrag: "Double-Click and Hold"
        case .leftClickNoModifiers: "Left Click Without Modifier Keys"
        case .commandDoubleClick: "⌘-Double-Click"
        case .commandShiftClick: "⇧⌘-Click"
        case .savePointer: "Remember Pointer Position"
        case .restorePointer: "Move Pointer to Remembered Position"
        case .commandClick: "⌘-Click"
        case .optionClick: "⌥-Click"
        case .shiftClick: "⇧-Click"
        case .controlClick: "⌃-Click"
        case .backButton: "Mouse Back Button"
        case .forwardButton: "Mouse Forward Button"
        case .scrollUp: "Scroll Up"
        case .scrollDown: "Scroll Down"
        case .scrollLeft: "Scroll Left"
        case .scrollRight: "Scroll Right"
        case .moveToScreenCentre: "Move Pointer to Centre of Screen"
        case .moveToWindowCentre: "Move Pointer to Centre of Window"
        case .moveToNextDisplay: "Move Pointer to Next Display"
        }
    }

    var systemImage: String {
        switch self {
        case .leftClick: "cursorarrow.click"
        case .rightClick: "contextualmenu.and.cursorarrow"
        case .middleClick: "computermouse"
        case .doubleClick: "cursorarrow.click.2"
        case .tripleClick: "cursorarrow.click.2"
        case .leftButtonDown: "arrow.down.to.line"
        case .leftButtonUp: "arrow.up.to.line"
        case .doubleClickDrag: "hand.draw"
        case .leftClickNoModifiers: "cursorarrow.click"
        case .commandDoubleClick: "command"
        case .commandShiftClick: "command"
        case .savePointer: "mappin"
        case .restorePointer: "mappin.and.ellipse"
        case .commandClick: "command"
        case .optionClick: "option"
        case .shiftClick: "shift"
        case .controlClick: "control"
        case .backButton: "chevron.backward.circle"
        case .forwardButton: "chevron.forward.circle"
        case .scrollUp: "arrow.up.circle"
        case .scrollDown: "arrow.down.circle"
        case .scrollLeft: "arrow.left.circle"
        case .scrollRight: "arrow.right.circle"
        case .moveToScreenCentre: "dot.scope.display"
        case .moveToWindowCentre: "dot.scope"
        case .moveToNextDisplay: "display.2"
        }
    }

    /// For menus, so related actions sit together.
    static let groups: [[MouseAction]] = [
        [.leftClick, .leftClickNoModifiers, .rightClick, .middleClick, .doubleClick, .tripleClick],
        [.commandClick, .optionClick, .shiftClick, .controlClick, .commandDoubleClick, .commandShiftClick],
        [.leftButtonDown, .leftButtonUp, .doubleClickDrag],
        [.backButton, .forwardButton],
        [.scrollUp, .scrollDown, .scrollLeft, .scrollRight],
        [.moveToScreenCentre, .moveToWindowCentre, .moveToNextDisplay, .savePointer, .restorePointer],
    ]
}

enum MouseClicker {
    private static var savedPointer: CGPoint?

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
        case .tripleClick:
            for count in Int64(1)...3 {
                click(.leftMouseDown, .leftMouseUp, .left, at: location, count: count)
            }
        // For dragging: hold the button down with one action, move, then let go with another.
        case .leftButtonDown:
            post(.leftMouseDown, at: location)
        case .leftButtonUp:
            post(.leftMouseUp, at: location)
        case .doubleClickDrag:
            // A double click whose second press stays down: drags select word by word.
            click(.leftMouseDown, .leftMouseUp, .left, at: location, count: 1)
            let event = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: location, mouseButton: .left)
            event?.setIntegerValueField(.mouseEventClickState, value: 2)
            event?.setIntegerValueField(.eventSourceUserData, value: SyntheticEvent.marker)
            event?.post(tap: .cghidEventTap)
        case .leftClickNoModifiers:
            click(.leftMouseDown, .leftMouseUp, .left, at: location, flags: [])
        case .commandDoubleClick:
            click(.leftMouseDown, .leftMouseUp, .left, at: location, count: 1, flags: .maskCommand)
            click(.leftMouseDown, .leftMouseUp, .left, at: location, count: 2, flags: .maskCommand)
        case .commandShiftClick:
            click(.leftMouseDown, .leftMouseUp, .left, at: location, flags: [.maskCommand, .maskShift])
        case .savePointer:
            savedPointer = location
            HUD.show("Pointer Position Saved", systemImage: "mappin")
        case .restorePointer:
            if let savedPointer { move(to: savedPointer) } else { NSSound.beep() }
        case .commandClick:
            click(.leftMouseDown, .leftMouseUp, .left, at: location, flags: .maskCommand)
        case .optionClick:
            click(.leftMouseDown, .leftMouseUp, .left, at: location, flags: .maskAlternate)
        case .shiftClick:
            click(.leftMouseDown, .leftMouseUp, .left, at: location, flags: .maskShift)
        case .controlClick:
            click(.leftMouseDown, .leftMouseUp, .left, at: location, flags: .maskControl)
        // Mice number their thumb buttons 3 (back) and 4 (forward).
        case .backButton:
            click(.otherMouseDown, .otherMouseUp, .center, at: location, buttonNumber: 3)
        case .forwardButton:
            click(.otherMouseDown, .otherMouseUp, .center, at: location, buttonNumber: 4)
        case .scrollUp: scroll(vertical: 5)
        case .scrollDown: scroll(vertical: -5)
        case .scrollLeft: scroll(horizontal: 5)
        case .scrollRight: scroll(horizontal: -5)
        case .moveToScreenCentre:
            let screen = NSScreen.screens.first { WindowMover.flipped($0.frame).contains(location) } ?? NSScreen.main
            if let screen { move(to: CGPoint(x: WindowMover.flipped(screen.frame).midX, y: WindowMover.flipped(screen.frame).midY)) }
        case .moveToWindowCentre:
            if let window = ActionTarget.frontmost?.window,
               let frame = WindowMover.shared.frame(of: window) {
                move(to: CGPoint(x: frame.midX, y: frame.midY))
            }
        case .moveToNextDisplay:
            let screens = NSScreen.screens.map { WindowMover.flipped($0.frame) }
            guard screens.count > 1 else { return NSSound.beep() }
            let index = screens.firstIndex { $0.contains(location) } ?? 0
            let next = screens[(index + 1) % screens.count]
            move(to: CGPoint(x: next.midX, y: next.midY))
        }
    }

    private static func post(_ type: CGEventType, at location: CGPoint) {
        let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: location, mouseButton: .left)
        event?.setIntegerValueField(.eventSourceUserData, value: SyntheticEvent.marker)
        event?.post(tap: .cghidEventTap)
    }

    /// Lines to scroll; positive is up or left.
    private static func scroll(vertical: Int32 = 0, horizontal: Int32 = 0) {
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: vertical, wheel2: horizontal, wheel3: 0)
        event?.setIntegerValueField(.eventSourceUserData, value: SyntheticEvent.marker)
        event?.post(tap: .cghidEventTap)
    }

    /// Moves the pointer, as if you'd moved the mouse there.
    private static func move(to point: CGPoint) {
        let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
        event?.setIntegerValueField(.eventSourceUserData, value: SyntheticEvent.marker)
        event?.post(tap: .cghidEventTap)
    }

    private static func click(
        _ down: CGEventType, _ up: CGEventType, _ button: CGMouseButton, at location: CGPoint, count: Int64 = 1,
        flags: CGEventFlags? = nil, buttonNumber: Int64? = nil
    ) {
        for type in [down, up] {
            let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: location, mouseButton: button)
            event?.setIntegerValueField(.mouseEventClickState, value: count)
            if let flags { event?.flags = flags }
            if let buttonNumber { event?.setIntegerValueField(.mouseEventButtonNumber, value: buttonNumber) }
            event?.setIntegerValueField(.eventSourceUserData, value: SyntheticEvent.marker)
            event?.post(tap: .cghidEventTap)
        }
    }
}
