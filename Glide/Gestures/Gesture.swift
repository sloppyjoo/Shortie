import Foundation

/// A trackpad gesture Glide can recognise.
nonisolated enum Gesture: Codable, Hashable {
    case tap(fingers: Int)
    case swipe(fingers: Int, direction: SwipeDirection)
    /// Pressing the trackpad down with this many fingers resting on it.
    case click(fingers: Int)
    case forceClick

    var title: String {
        switch self {
        case .tap(let fingers): "\(Self.word(for: fingers))-Finger Tap"
        case .swipe(let fingers, let direction): "\(Self.word(for: fingers))-Finger Swipe \(direction.title)"
        case .click(let fingers): "\(Self.word(for: fingers))-Finger Click"
        case .forceClick: "Force Click"
        }
    }

    private static let numberWords = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten"]

    private static func word(for number: Int) -> String {
        numberWords.indices.contains(number) ? numberWords[number] : "\(number)"
    }
}

nonisolated enum SwipeDirection: String, Codable, CaseIterable {
    case up, down, left, right

    var title: String { rawValue.capitalized }
}

/// One finger on the trackpad in one frame, copied out of MultitouchSupport's data.
nonisolated struct TouchPoint: Sendable, Identifiable {
    let id: Int32
    /// 0 to 1 across the trackpad, measured from the bottom-left corner.
    let x: Double
    let y: Double
    let state: Int32
    let size: Double

    /// Landing (3) or touching (4); the other states are hovering or lifting off.
    var isTouching: Bool { state == 3 || state == 4 }
}

/// Turns a stream of finger positions into taps and swipes.
///
/// One of these runs per trackpad. A "session" lasts from the first finger
/// landing until the last one lifts.
struct GestureRecognizer {
    /// Tap limits from the open-source MiddleClick app: every finger down and up
    /// within 300 ms, none moving more than 5% of the trackpad.
    static let maxTapDuration = 0.3
    static let maxTapMovement = 0.05

    /// A swipe is three or more fingers moving together this far, in millimetres.
    static let swipeDistance = 20.0

    /// The trackpad's real size in millimetres, so swipes feel the same on any trackpad.
    let surfaceSize: CGSize

    private struct Session {
        let startTime: Double
        var maxFingers = 0
        var startPositions: [Int32: CGPoint] = [:]
        /// The furthest any finger has moved from where it landed (0–1 of the trackpad).
        var maxMovement = 0.0
        var hasSwiped = false
        /// Where the fingers' centre was when the current number of fingers settled.
        var swipeStart: (fingers: Int, centre: CGPoint)?
    }

    private var session: Session?

    init(surfaceSize: CGSize) {
        self.surfaceSize = surfaceSize
    }

    /// Feeds in one frame; returns a gesture if this frame completes one.
    mutating func process(_ touches: [TouchPoint], at time: Double) -> Gesture? {
        let down = touches.filter(\.isTouching)

        // All fingers lifted: the session's over. Was it a tap?
        guard !down.isEmpty else {
            defer { session = nil }
            guard let session, !session.hasSwiped,
                  time - session.startTime <= Self.maxTapDuration,
                  session.maxMovement <= Self.maxTapMovement
            else { return nil }
            return .tap(fingers: session.maxFingers)
        }

        var current = session ?? Session(startTime: time)
        defer { session = current }

        current.maxFingers = max(current.maxFingers, down.count)
        for touch in down {
            let position = CGPoint(x: touch.x, y: touch.y)
            let start = current.startPositions[touch.id] ?? position
            current.startPositions[touch.id] = start
            current.maxMovement = max(current.maxMovement, hypot(position.x - start.x, position.y - start.y))
        }

        // Swipes: once the number of fingers settles, measure how far their centre moves.
        guard down.count >= 3, !current.hasSwiped else { return nil }
        let centre = CGPoint(
            x: down.map(\.x).reduce(0, +) / Double(down.count),
            y: down.map(\.y).reduce(0, +) / Double(down.count)
        )
        guard let swipeStart = current.swipeStart, swipeStart.fingers == down.count else {
            current.swipeStart = (down.count, centre)
            return nil
        }

        let dx = (centre.x - swipeStart.centre.x) * surfaceSize.width
        let dy = (centre.y - swipeStart.centre.y) * surfaceSize.height
        guard hypot(dx, dy) >= Self.swipeDistance else { return nil }

        current.hasSwiped = true
        let direction: SwipeDirection = abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .up : .down)
        return .swipe(fingers: down.count, direction: direction)
    }
}
