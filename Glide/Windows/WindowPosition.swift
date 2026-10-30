import Carbon.HIToolbox
import CoreGraphics

/// Where a window can be snapped to.
nonisolated enum WindowPosition: String, Codable, CaseIterable, Identifiable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, centerThird, rightThird, leftTwoThirds, rightTwoThirds
    case maximize, center, restore, nextDisplay

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
        case .maximize: "Maximise"
        case .center: "Centre"
        case .restore: "Restore"
        case .nextDisplay: "Next Display"
        }
    }

    /// For menus, so related positions sit together.
    static let groups: [[WindowPosition]] = [
        [.leftHalf, .rightHalf, .topHalf, .bottomHalf],
        [.topLeft, .topRight, .bottomLeft, .bottomRight],
        [.leftThird, .centerThird, .rightThird, .leftTwoThirds, .rightTwoThirds],
        [.maximize, .center, .restore, .nextDisplay],
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
        case .maximize: return CGRect(x: 0, y: 0, width: 1, height: 1)
        case .center, .restore, .nextDisplay: return nil
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
        ]
    }()
}
