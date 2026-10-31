import Foundation

/// A trackpad gesture Shortie can recognise.
nonisolated enum Gesture: Codable, Hashable {
    case tap(fingers: Int)
    case doubleTap(fingers: Int)
    case tapAndHold(fingers: Int)
    /// Rest one or two fingers, and tap another finger beside them.
    case tipTap(resting: Int, side: TipTapSide)
    case swipe(fingers: Int, direction: SwipeDirection)
    /// Start at an edge of the trackpad and swipe inwards.
    case edgeSwipe(fingers: Int, edge: TrackpadEdge)
    case pinch(fingers: Int, direction: PinchDirection)
    /// Two fingers turning, like turning a dial.
    case rotate(direction: RotationDirection)
    /// Pressing the trackpad down with this many fingers resting on it.
    case click(fingers: Int)
    /// Pressing the trackpad down with one finger in a corner.
    case cornerClick(corner: TrackpadCorner)
    case forceClick

    var title: String {
        switch self {
        case .tap(let fingers): "\(Self.word(for: fingers))-Finger Tap"
        case .doubleTap(let fingers): "\(Self.word(for: fingers))-Finger Double Tap"
        case .tapAndHold(let fingers): "\(Self.word(for: fingers))-Finger Tap and Hold"
        case .tipTap(let resting, let side): "TipTap \(side.title) (\(Self.word(for: resting)) Resting)"
        case .swipe(let fingers, let direction): "\(Self.word(for: fingers))-Finger Swipe \(direction.title)"
        case .edgeSwipe(1, let edge): "Swipe In from \(edge.title) Edge"
        case .edgeSwipe(let fingers, let edge): "\(Self.word(for: fingers))-Finger Swipe In from \(edge.title) Edge"
        case .pinch(let fingers, let direction): "\(Self.word(for: fingers))-Finger Pinch \(direction.title)"
        case .rotate(let direction): "Rotate \(direction.title)"
        case .click(let fingers): "\(Self.word(for: fingers))-Finger Click"
        case .cornerClick(let corner): "Click \(corner.title) Corner"
        case .forceClick: "Force Click"
        }
    }

    private static let numberWords = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten"]

    private static func word(for number: Int) -> String {
        numberWords.indices.contains(number) ? numberWords[number] : "\(number)"
    }
}

nonisolated enum SwipeDirection: String, Codable, CaseIterable, Identifiable {
    case up, down, left, right
    var id: Self { self }
    var title: String { rawValue.capitalized }
}

nonisolated enum TrackpadEdge: String, Codable, CaseIterable, Identifiable {
    case top, bottom, left, right
    var id: Self { self }
    var title: String { rawValue.capitalized }
}

nonisolated enum TipTapSide: String, Codable, CaseIterable, Identifiable {
    case left, right
    var id: Self { self }
    var title: String { rawValue.capitalized }
}

nonisolated enum PinchDirection: String, Codable, CaseIterable, Identifiable {
    case `in`, out
    var id: Self { self }
    var title: String { rawValue.capitalized }
}

nonisolated enum RotationDirection: String, Codable, CaseIterable, Identifiable {
    /// Anticlockwise.
    case left
    /// Clockwise.
    case right
    var id: Self { self }
    var title: String { rawValue.capitalized }
}

nonisolated enum TrackpadCorner: String, Codable, CaseIterable, Identifiable {
    case topLeft, topRight, bottomLeft, bottomRight
    var id: Self { self }

    var title: String {
        switch self {
        case .topLeft: "Top-Left"
        case .topRight: "Top-Right"
        case .bottomLeft: "Bottom-Left"
        case .bottomRight: "Bottom-Right"
        }
    }
}

// MARK: - Describing gestures in the editor

extension Gesture {
    /// The families of gestures. Each has a finger count and/or one "variant"
    /// (a direction, edge, side or corner) to fill in.
    enum Kind: String, CaseIterable, Identifiable {
        case tap, doubleTap, tapAndHold, tipTap, swipe, edgeSwipe, pinch, rotate, click, cornerClick, forceClick
        var id: Self { self }

        var title: String {
            switch self {
            case .tap: "Tap"
            case .doubleTap: "Double Tap"
            case .tapAndHold: "Tap and Hold"
            case .tipTap: "TipTap"
            case .swipe: "Swipe"
            case .edgeSwipe: "Swipe In from Edge"
            case .pinch: "Pinch"
            case .rotate: "Rotate"
            case .click: "Click"
            case .cornerClick: "Corner Click"
            case .forceClick: "Force Click"
            }
        }

        /// How many fingers it can use, or `nil` if that's fixed. One-finger taps
        /// and clicks are just ordinary clicking, and two-finger swipes and pinches
        /// are scrolling and zooming, so those aren't offered.
        var fingerRange: ClosedRange<Int>? {
            switch self {
            case .tap, .doubleTap, .tapAndHold, .click: 2...5
            case .swipe, .pinch: 3...5
            case .edgeSwipe, .tipTap: 1...2
            case .rotate, .cornerClick, .forceClick: nil
            }
        }

        /// The choices for its variant, as (saved name, title).
        var variants: [(id: String, title: String)] {
            switch self {
            case .swipe: SwipeDirection.allCases.map { ($0.rawValue, $0.title) }
            case .edgeSwipe: TrackpadEdge.allCases.map { ($0.rawValue, "From \($0.title) Edge") }
            case .tipTap: TipTapSide.allCases.map { ($0.rawValue, $0.title) }
            case .pinch: PinchDirection.allCases.map { ($0.rawValue, $0.title) }
            case .rotate: RotationDirection.allCases.map { ($0.rawValue, $0.title) }
            case .cornerClick: TrackpadCorner.allCases.map { ($0.rawValue, $0.title) }
            default: []
            }
        }

        /// E.g. "3 fingers" or, for TipTap, "1 resting".
        func fingerTitle(_ count: Int) -> String {
            self == .tipTap ? "\(count) resting" : (count == 1 ? "1 finger" : "\(count) fingers")
        }
    }

    init(kind: Kind, fingers: Int, variant: String) {
        let range = kind.fingerRange ?? 1...1
        let fingers = min(max(fingers, range.lowerBound), range.upperBound)
        switch kind {
        case .tap: self = .tap(fingers: fingers)
        case .doubleTap: self = .doubleTap(fingers: fingers)
        case .tapAndHold: self = .tapAndHold(fingers: fingers)
        case .tipTap: self = .tipTap(resting: fingers, side: TipTapSide(rawValue: variant) ?? .left)
        case .swipe: self = .swipe(fingers: fingers, direction: SwipeDirection(rawValue: variant) ?? .up)
        case .edgeSwipe: self = .edgeSwipe(fingers: fingers, edge: TrackpadEdge(rawValue: variant) ?? .left)
        case .pinch: self = .pinch(fingers: fingers, direction: PinchDirection(rawValue: variant) ?? .in)
        case .rotate: self = .rotate(direction: RotationDirection(rawValue: variant) ?? .left)
        case .click: self = .click(fingers: fingers)
        case .cornerClick: self = .cornerClick(corner: TrackpadCorner(rawValue: variant) ?? .topLeft)
        case .forceClick: self = .forceClick
        }
    }

    var kind: Kind {
        switch self {
        case .tap: .tap
        case .doubleTap: .doubleTap
        case .tapAndHold: .tapAndHold
        case .tipTap: .tipTap
        case .swipe: .swipe
        case .edgeSwipe: .edgeSwipe
        case .pinch: .pinch
        case .rotate: .rotate
        case .click: .click
        case .cornerClick: .cornerClick
        case .forceClick: .forceClick
        }
    }

    var fingers: Int {
        switch self {
        case .tap(let fingers), .doubleTap(let fingers), .tapAndHold(let fingers), .click(let fingers),
             .swipe(let fingers, _), .edgeSwipe(let fingers, _), .pinch(let fingers, _):
            fingers
        case .tipTap(let resting, _): resting
        case .rotate: 2
        case .cornerClick, .forceClick: 1
        }
    }

    var variant: String {
        switch self {
        case .tipTap(_, let side): side.rawValue
        case .swipe(_, let direction): direction.rawValue
        case .edgeSwipe(_, let edge): edge.rawValue
        case .pinch(_, let direction): direction.rawValue
        case .rotate(let direction): direction.rawValue
        case .cornerClick(let corner): corner.rawValue
        default: ""
        }
    }

    /// Whether this gesture can set off an action (see `Kind.fingerRange`).
    var canBeTrigger: Bool {
        kind.fingerRange?.contains(fingers) ?? true
    }

    var systemImage: String {
        switch self {
        case .tap: "hand.tap"
        case .doubleTap: "hand.tap.fill"
        case .tapAndHold: "hand.point.up.left"
        case .tipTap: "hand.point.up"
        case .swipe(_, .up), .edgeSwipe(_, .bottom): "arrow.up"
        case .swipe(_, .down), .edgeSwipe(_, .top): "arrow.down"
        case .swipe(_, .left), .edgeSwipe(_, .right): "arrow.left"
        case .swipe(_, .right), .edgeSwipe(_, .left): "arrow.right"
        case .pinch(_, .in): "arrow.down.right.and.arrow.up.left"
        case .pinch(_, .out): "arrow.up.left.and.arrow.down.right"
        case .rotate(.left): "arrow.counterclockwise"
        case .rotate(.right): "arrow.clockwise"
        case .click: "cursorarrow.click"
        case .cornerClick: "square.grid.2x2"
        case .forceClick: "cursorarrow.click.2"
        }
    }
}

// MARK: - Recognising gestures from finger positions

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

/// Turns a stream of finger positions into gestures.
///
/// One of these runs per trackpad. A "session" lasts from the first finger
/// landing until the last one lifts, and recognises at most one gesture.
/// (Double taps are two taps, put together by `GestureEngine`.)
///
/// Where Apple publishes a standard, we use it; otherwise the limits come from
/// established open-source tools, noted on each one.
struct GestureRecognizer {
    /// Taps, from the open-source MiddleClick app: every finger down and up within
    /// 300 ms, none moving more than 5% of the trackpad.
    static let maxTapDuration = 0.3
    static let maxTapMovement = 0.05

    /// Tap and hold: Apple's standard long-press time (`UILongPressGestureRecognizer`).
    static let holdDuration = 0.5

    /// Swipes: three or more fingers moving together this far, in millimetres.
    static let swipeDistance = 20.0

    /// Edge swipes: start within this share of an edge, then move this far inwards (mm).
    static let edgeZone = 0.04
    static let edgeSwipeDistance = 15.0

    /// Pinches: the fingers' average distance from their centre changes this much (mm).
    static let pinchDistance = 12.0

    /// Rotation: the line between two fingers turns this far (30°).
    static let rotationAngle = Double.pi / 6

    /// TipTap: the resting finger(s) must have landed at least this long before
    /// the tapping one, so a sloppy two-finger tap doesn't count.
    static let restingTime = 0.15

    /// The trackpad's real size in millimetres, so gestures feel the same on any trackpad.
    let surfaceSize: CGSize

    private struct Finger {
        let landedAt: Double
        /// 0–1 across the trackpad.
        let start: CGPoint
        var current: CGPoint
        /// The furthest it's been from where it landed (0–1 of the trackpad).
        var maxMovement = 0.0
    }

    private struct Session {
        let startTime: Double
        var fingers: [Int32: Finger] = [:]
        var maxFingers = 0
        var maxMovement = 0.0
        /// A gesture was already recognised, so nothing else should be.
        var isUsed = false
        /// The trackpad was physically clicked, so this wasn't a tap.
        var hasClicked = false
        /// Measurements taken when the current set of fingers settled.
        var baseline: Baseline?
    }

    private struct Baseline {
        let ids: Set<Int32>
        /// In millimetres.
        let centre: CGPoint
        let spread: Double
        let angle: Double
    }

    private var session: Session?

    init(surfaceSize: CGSize) {
        self.surfaceSize = surfaceSize
    }

    mutating func noteClick() {
        session?.hasClicked = true
    }

    /// Feeds in one frame; returns a gesture if this frame completes one.
    /// `wants` says whether anyone wants a gesture that could get in the way of
    /// others (like holding two fingers still), so it's only reported when useful.
    mutating func process(_ touches: [TouchPoint], at time: Double, wants: (Gesture) -> Bool) -> Gesture? {
        let down = touches.filter(\.isTouching)
        if session == nil, down.isEmpty { return nil }
        var current = session ?? Session(startTime: time)
        defer { session = down.isEmpty ? nil : current }

        let downIDs = Set(down.map(\.id))
        var found: Gesture?

        // Fingers that just lifted: was one of them a TipTap?
        let lifted = current.fingers.filter { !downIDs.contains($0.key) }.map(\.value)
        current.fingers = current.fingers.filter { downIDs.contains($0.key) }
        let stillDown = Array(current.fingers.values)
        for finger in lifted {
            let resting = stillDown.filter { finger.landedAt - $0.landedAt >= Self.restingTime }
            if found == nil, !current.isUsed, !current.hasClicked,
               time - finger.landedAt <= Self.maxTapDuration,
               finger.maxMovement <= Self.maxTapMovement,
               (1...2).contains(resting.count), resting.count == stillDown.count {
                let restingX = resting.map(\.current.x).reduce(0, +) / Double(resting.count)
                found = .tipTap(resting: resting.count, side: finger.current.x < restingX ? .left : .right)
                current.isUsed = true
            }
        }

        // All fingers lifted: the session's over. Was it a tap?
        if down.isEmpty {
            guard found == nil, !current.isUsed, !current.hasClicked,
                  time - current.startTime <= Self.maxTapDuration,
                  current.maxMovement <= Self.maxTapMovement
            else { return found }
            return .tap(fingers: current.maxFingers)
        }

        // Track every finger that's down.
        for touch in down {
            let position = CGPoint(x: touch.x, y: touch.y)
            var finger = current.fingers[touch.id] ?? Finger(landedAt: time, start: position, current: position)
            finger.current = position
            finger.maxMovement = max(finger.maxMovement, hypot(position.x - finger.start.x, position.y - finger.start.y))
            current.fingers[touch.id] = finger
            current.maxMovement = max(current.maxMovement, finger.maxMovement)
        }
        current.maxFingers = max(current.maxFingers, down.count)

        if let found { return found }
        guard !current.isUsed else { return nil }

        let fingers = Array(current.fingers.values)
        let count = fingers.count

        // Tap and hold: every finger still, for Apple's long-press time.
        if count >= 2, count == current.maxFingers,
           time - current.startTime >= Self.holdDuration,
           current.maxMovement <= Self.maxTapMovement,
           wants(.tapAndHold(fingers: count)) {
            current.isUsed = true
            return .tapAndHold(fingers: count)
        }

        // Swipe in from an edge: every finger landed near the same edge, then moved inwards.
        if count <= 2, let gesture = edgeSwipe(fingers) {
            current.isUsed = true
            return gesture
        }

        // Swipes, pinches and rotations compare against the moment the current
        // set of fingers settled.
        let points = fingers.map { millimetres($0.current) }
        let centre = CGPoint(
            x: points.map(\.x).reduce(0, +) / Double(count),
            y: points.map(\.y).reduce(0, +) / Double(count)
        )
        let spread = points.map { hypot($0.x - centre.x, $0.y - centre.y) }.reduce(0, +) / Double(count)
        let angle = count == 2 ? atan2(points[1].y - points[0].y, points[1].x - points[0].x) : 0
        let ids = Set(current.fingers.keys)

        guard let baseline = current.baseline, baseline.ids == ids else {
            current.baseline = Baseline(ids: ids, centre: centre, spread: spread, angle: angle)
            return nil
        }

        if count == 2 {
            // The two fingers might be listed in either order, and a line turned by
            // half a circle is the same line, so fold the change into −90°…90°.
            var turn = angle - baseline.angle
            while turn > .pi / 2 { turn -= .pi }
            while turn < -.pi / 2 { turn += .pi }
            guard abs(turn) >= Self.rotationAngle else { return nil }
            current.isUsed = true
            // Angles grow anticlockwise (the trackpad measures from the bottom-left).
            return .rotate(direction: turn > 0 ? .left : .right)
        }

        guard count >= 3 else { return nil }

        let spreadChange = spread - baseline.spread
        if abs(spreadChange) >= Self.pinchDistance {
            current.isUsed = true
            return .pinch(fingers: count, direction: spreadChange < 0 ? .in : .out)
        }

        let dx = centre.x - baseline.centre.x
        let dy = centre.y - baseline.centre.y
        if hypot(dx, dy) >= Self.swipeDistance {
            current.isUsed = true
            let direction: SwipeDirection = abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .up : .down)
            return .swipe(fingers: count, direction: direction)
        }
        return nil
    }

    private func edgeSwipe(_ fingers: [Finger]) -> Gesture? {
        let zone = Self.edgeZone
        for edge in TrackpadEdge.allCases {
            let allStartedThere = fingers.allSatisfy { finger in
                switch edge {
                case .left: finger.start.x <= zone
                case .right: finger.start.x >= 1 - zone
                case .bottom: finger.start.y <= zone
                case .top: finger.start.y >= 1 - zone
                }
            }
            guard allStartedThere else { continue }

            let inwards = fingers.map { finger -> Double in
                switch edge {
                case .left: (finger.current.x - finger.start.x) * surfaceSize.width
                case .right: (finger.start.x - finger.current.x) * surfaceSize.width
                case .bottom: (finger.current.y - finger.start.y) * surfaceSize.height
                case .top: (finger.start.y - finger.current.y) * surfaceSize.height
                }
            }
            if inwards.allSatisfy({ $0 >= Self.edgeSwipeDistance }) {
                return .edgeSwipe(fingers: fingers.count, edge: edge)
            }
        }
        return nil
    }

    private func millimetres(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x * surfaceSize.width, y: point.y * surfaceSize.height)
    }
}
