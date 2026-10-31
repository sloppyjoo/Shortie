import Carbon.HIToolbox
import CoreGraphics

/// Where a window can be snapped to.
nonisolated enum WindowPosition: String, Codable, CaseIterable, Identifiable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, centerThird, rightThird, leftTwoThirds, rightTwoThirds
    case firstFourth, secondFourth, thirdFourth, lastFourth, leftThreeFourths, rightThreeFourths
    case topThird, middleThird, bottomThird, topTwoThirds, bottomTwoThirds
    case topLeftSixth, topCenterSixth, topRightSixth, bottomLeftSixth, bottomCenterSixth, bottomRightSixth
    case centerHalf, centerTwoThirds
    case maximize, almostMaximize, maximizeHeight, maximizeWidth, center, restore
    case larger, smaller
    case moveLeft, moveRight, moveUp, moveDown
    case nextDisplay, previousDisplay, centerOnNextDisplay, maximizeOnNextDisplay
    case nudgeLeft, nudgeRight, nudgeUp, nudgeDown

    var id: Self { self }

    var title: String {
        switch self {
        case .leftHalf: "Left Half"
        case .rightHalf: "Right Half"
        case .topHalf: "Top Half"
        case .bottomHalf: "Bottom Half"
        case .topLeft: "Top Left"
        case .topRight: "Top Right"
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        case .leftThird: "Left Third"
        case .centerThird: "Centre Third"
        case .rightThird: "Right Third"
        case .leftTwoThirds: "Left Two Thirds"
        case .rightTwoThirds: "Right Two Thirds"
        case .firstFourth: "First Fourth"
        case .secondFourth: "Second Fourth"
        case .thirdFourth: "Third Fourth"
        case .lastFourth: "Last Fourth"
        case .leftThreeFourths: "Left Three Fourths"
        case .rightThreeFourths: "Right Three Fourths"
        case .topThird: "Top Third"
        case .middleThird: "Middle Third"
        case .bottomThird: "Bottom Third"
        case .topTwoThirds: "Top Two Thirds"
        case .bottomTwoThirds: "Bottom Two Thirds"
        case .topLeftSixth: "Top Left Sixth"
        case .topCenterSixth: "Top Centre Sixth"
        case .topRightSixth: "Top Right Sixth"
        case .bottomLeftSixth: "Bottom Left Sixth"
        case .bottomCenterSixth: "Bottom Centre Sixth"
        case .bottomRightSixth: "Bottom Right Sixth"
        case .centerHalf: "Centre Half"
        case .centerTwoThirds: "Centre Two Thirds"
        case .maximize: "Maximise"
        case .almostMaximize: "Almost Maximise"
        case .maximizeHeight: "Maximise Height"
        case .maximizeWidth: "Maximise Width"
        case .center: "Centre"
        case .restore: "Restore"
        case .larger: "Make Larger"
        case .smaller: "Make Smaller"
        case .moveLeft: "Move to Left Edge"
        case .moveRight: "Move to Right Edge"
        case .moveUp: "Move to Top Edge"
        case .moveDown: "Move to Bottom Edge"
        case .nextDisplay: "Next Display"
        case .previousDisplay: "Previous Display"
        case .centerOnNextDisplay: "Centre on Next Display"
        case .maximizeOnNextDisplay: "Maximise on Next Display"
        case .nudgeLeft: "Nudge Left"
        case .nudgeRight: "Nudge Right"
        case .nudgeUp: "Nudge Up"
        case .nudgeDown: "Nudge Down"
        }
    }

    /// For menus, so related positions sit together.
    static let groups: [[WindowPosition]] = [
        [.leftHalf, .rightHalf, .topHalf, .bottomHalf],
        [.topLeft, .topRight, .bottomLeft, .bottomRight],
        [.leftThird, .centerThird, .rightThird, .leftTwoThirds, .rightTwoThirds],
        [.topThird, .middleThird, .bottomThird, .topTwoThirds, .bottomTwoThirds],
        [.firstFourth, .secondFourth, .thirdFourth, .lastFourth, .leftThreeFourths, .rightThreeFourths],
        [.topLeftSixth, .topCenterSixth, .topRightSixth, .bottomLeftSixth, .bottomCenterSixth, .bottomRightSixth],
        [.centerHalf, .centerTwoThirds],
        [.maximize, .almostMaximize, .maximizeHeight, .maximizeWidth, .center, .restore],
        [.larger, .smaller],
        [.moveLeft, .moveRight, .moveUp, .moveDown],
        [.nudgeLeft, .nudgeRight, .nudgeUp, .nudgeDown],
        [.nextDisplay, .previousDisplay, .centerOnNextDisplay, .maximizeOnNextDisplay],
    ]

    /// Halves and corners get narrower or wider each time you press them again.
    var cyclesSizes: Bool {
        switch self {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf,
             .topLeft, .topRight, .bottomLeft, .bottomRight: true
        default: false
        }
    }

    private static let cycleFractions: [CGFloat] = [1 / 2, 1 / 3, 2 / 3]

    /// The area to fill, as fractions of the screen, measured from the top-left.
    /// `cycle` counts repeat presses: 0 = ½, 1 = ⅓, 2 = ⅔.
    /// `nil` for positions that don't fill a fixed area.
    func unitRect(cycle: Int = 0) -> CGRect? {
        let f = Self.cycleFractions[cycle % Self.cycleFractions.count]
        switch self {
        case .leftHalf: return CGRect(x: 0, y: 0, width: f, height: 1)
        case .rightHalf: return CGRect(x: 1 - f, y: 0, width: f, height: 1)
        case .topHalf: return CGRect(x: 0, y: 0, width: 1, height: f)
        case .bottomHalf: return CGRect(x: 0, y: 1 - f, width: 1, height: f)
        case .topLeft: return CGRect(x: 0, y: 0, width: f, height: 0.5)
        case .topRight: return CGRect(x: 1 - f, y: 0, width: f, height: 0.5)
        case .bottomLeft: return CGRect(x: 0, y: 0.5, width: f, height: 0.5)
        case .bottomRight: return CGRect(x: 1 - f, y: 0.5, width: f, height: 0.5)
        case .leftThird: return CGRect(x: 0, y: 0, width: 1 / 3, height: 1)
        case .centerThird: return CGRect(x: 1 / 3, y: 0, width: 1 / 3, height: 1)
        case .rightThird: return CGRect(x: 2 / 3, y: 0, width: 1 / 3, height: 1)
        case .leftTwoThirds: return CGRect(x: 0, y: 0, width: 2 / 3, height: 1)
        case .rightTwoThirds: return CGRect(x: 1 / 3, y: 0, width: 2 / 3, height: 1)
        case .firstFourth: return CGRect(x: 0, y: 0, width: 1 / 4, height: 1)
        case .secondFourth: return CGRect(x: 1 / 4, y: 0, width: 1 / 4, height: 1)
        case .thirdFourth: return CGRect(x: 2 / 4, y: 0, width: 1 / 4, height: 1)
        case .lastFourth: return CGRect(x: 3 / 4, y: 0, width: 1 / 4, height: 1)
        case .leftThreeFourths: return CGRect(x: 0, y: 0, width: 3 / 4, height: 1)
        case .rightThreeFourths: return CGRect(x: 1 / 4, y: 0, width: 3 / 4, height: 1)
        // Thirds stacked top to bottom, handy on a portrait display.
        case .topThird: return CGRect(x: 0, y: 0, width: 1, height: 1 / 3)
        case .middleThird: return CGRect(x: 0, y: 1 / 3, width: 1, height: 1 / 3)
        case .bottomThird: return CGRect(x: 0, y: 2 / 3, width: 1, height: 1 / 3)
        case .topTwoThirds: return CGRect(x: 0, y: 0, width: 1, height: 2 / 3)
        case .bottomTwoThirds: return CGRect(x: 0, y: 1 / 3, width: 1, height: 2 / 3)
        // A 3 × 2 grid.
        case .topLeftSixth: return CGRect(x: 0, y: 0, width: 1 / 3, height: 0.5)
        case .topCenterSixth: return CGRect(x: 1 / 3, y: 0, width: 1 / 3, height: 0.5)
        case .topRightSixth: return CGRect(x: 2 / 3, y: 0, width: 1 / 3, height: 0.5)
        case .bottomLeftSixth: return CGRect(x: 0, y: 0.5, width: 1 / 3, height: 0.5)
        case .bottomCenterSixth: return CGRect(x: 1 / 3, y: 0.5, width: 1 / 3, height: 0.5)
        case .bottomRightSixth: return CGRect(x: 2 / 3, y: 0.5, width: 1 / 3, height: 0.5)
        case .centerHalf: return CGRect(x: 1 / 4, y: 0, width: 1 / 2, height: 1)
        case .centerTwoThirds: return CGRect(x: 1 / 6, y: 0, width: 2 / 3, height: 1)
        case .maximize: return CGRect(x: 0, y: 0, width: 1, height: 1)
        // Rectangle's "Almost Maximise": 90% of the screen, centred.
        case .almostMaximize: return CGRect(x: 0.05, y: 0.05, width: 0.9, height: 0.9)
        // These depend on where the window is now, so `WindowMover` works them out.
        case .maximizeHeight, .maximizeWidth, .center, .restore, .larger, .smaller,
             .moveLeft, .moveRight, .moveUp, .moveDown, .nextDisplay, .previousDisplay,
             .centerOnNextDisplay, .maximizeOnNextDisplay, .nudgeLeft, .nudgeRight, .nudgeUp, .nudgeDown: return nil
        }
    }

    /// The one-click standard set, using the key layout most Mac window tools share.
    static let standardShortcuts: [(position: WindowPosition, keyCode: Int, modifiers: Modifiers)] = {
        let ctrlOpt: Modifiers = [.control, .option]
        return [
            (.leftHalf, kVK_LeftArrow, ctrlOpt),
            (.rightHalf, kVK_RightArrow, ctrlOpt),
            (.topHalf, kVK_UpArrow, ctrlOpt),
            (.bottomHalf, kVK_DownArrow, ctrlOpt),
            (.topLeft, kVK_ANSI_U, ctrlOpt),
            (.topRight, kVK_ANSI_I, ctrlOpt),
            (.bottomLeft, kVK_ANSI_J, ctrlOpt),
            (.bottomRight, kVK_ANSI_K, ctrlOpt),
            (.leftThird, kVK_ANSI_D, ctrlOpt),
            (.centerThird, kVK_ANSI_F, ctrlOpt),
            (.rightThird, kVK_ANSI_G, ctrlOpt),
            (.leftTwoThirds, kVK_ANSI_E, ctrlOpt),
            (.rightTwoThirds, kVK_ANSI_T, ctrlOpt),
            (.maximize, kVK_Return, ctrlOpt),
            (.center, kVK_ANSI_C, ctrlOpt),
            (.restore, kVK_Delete, ctrlOpt),
            (.nextDisplay, kVK_RightArrow, [.control, .option, .command]),
            // The rest follow Rectangle's defaults.
            (.previousDisplay, kVK_LeftArrow, [.control, .option, .command]),
            (.maximizeHeight, kVK_UpArrow, [.control, .option, .shift]),
            (.larger, kVK_ANSI_Equal, ctrlOpt),
            (.smaller, kVK_ANSI_Minus, ctrlOpt),
        ]
    }()
}
