import AppKit
import SwiftUI

/// Shortie's 1-bit pixel art, the same set the website uses (`docs/icons.js`):
/// the classic Mac pointing hand, and small icons for empty lists.
enum PixelArt {
    /// 16 × 16 pixels each: "#" is drawn, "." is empty.
    static let hand = [
        "......##........",
        ".....#..#.......",
        ".....#..#.......",
        ".....#..#.......",
        ".....#..###.....",
        ".....#..#..##...",
        "..##.#..#..#.##.",
        ".#..##..#..#..#.",
        ".#...#........#.",
        "..#...........#.",
        "..#...........#.",
        "...#..........#.",
        "...#.........#..",
        "....#........#..",
        ".....#......#...",
        ".....########...",
    ]

    /// A keycap with ⌘ on it.
    static let key = [
        ".##############.",
        "#..............#",
        "#..##......##..#",
        "#.#..#....#..#.#",
        "#.#..#....#..#.#",
        "#..##########..#",
        "#....#....#....#",
        "#....#....#....#",
        "#....#....#....#",
        "#..##########..#",
        "#.#..#....#..#.#",
        "#.#..#....#..#.#",
        "#..##......##..#",
        "#..............#",
        "################",
        ".##############.",
    ]

    /// A window split into a big pane and two small ones.
    static let layout = [
        "................",
        "################",
        "#.#.#.#.#.#.#.##",
        "################",
        "#......#.......#",
        "#......#.......#",
        "#......#.......#",
        "#......#.......#",
        "#......#########",
        "#......#.......#",
        "#......#.......#",
        "#......#.......#",
        "#......#.......#",
        "################",
        "................",
        "................",
    ]

    /// A window with its three buttons.
    static let windowButtons = [
        "................",
        "################",
        "#..............#",
        "#.##..##..##...#",
        "#.##..##..##...#",
        "#..............#",
        "################",
        "#..............#",
        "#..............#",
        "#..............#",
        "#..............#",
        "#..............#",
        "#..............#",
        "################",
        "................",
        "................",
    ]

    static let mouse = [
        ".......#........",
        "......#.........",
        "......#.........",
        "...####.####....",
        "..#....#....#...",
        ".#.....#.....#..",
        ".#.....#.....#..",
        ".#############..",
        ".#...........#..",
        ".#...........#..",
        ".#...........#..",
        ".#...........#..",
        ".#...........#..",
        "..#.........#...",
        "...#.......#....",
        "....#######.....",
    ]

    /// An "A" and a text cursor, over a line of typing.
    static let typing = [
        "................",
        "...##......####.",
        "..#..#.......#..",
        ".#....#......#..",
        ".#....#......#..",
        ".######......#..",
        ".#....#......#..",
        ".#....#......#..",
        ".#....#......#..",
        "...........####.",
        "................",
        "#.#.#.#.#.#.#.#.",
        "................",
        "################",
        "................",
        "................",
    ]

    static let clipboard = [
        ".....######.....",
        "..###.#..#.###..",
        "..#..######..#..",
        "..#..........#..",
        "..#.########.#..",
        "..#..........#..",
        "..#.######...#..",
        "..#..........#..",
        "..#.########.#..",
        "..#..........#..",
        "..#.#####....#..",
        "..#..........#..",
        "..#.#######..#..",
        "..#..........#..",
        "..############..",
        "................",
    ]

    /// A menu with its second item highlighted.
    static let menu = [
        "################",
        "#..............#",
        "#.#######......#",
        "#..............#",
        "################",
        "################",
        "##.#########.###",
        "################",
        "#..............#",
        "#.#####........#",
        "#..............#",
        "#.########.....#",
        "#..............#",
        "################",
        "................",
        "................",
    ]

    static let bolt = [
        "................",
        "........####....",
        ".......####.....",
        "......####......",
        ".....####.......",
        "....####........",
        "...##########...",
        "........####....",
        ".......####.....",
        "......####......",
        ".....###........",
        "....##..........",
        "...#............",
        "................",
        "................",
        "................",
    ]

    /// A classic compact Macintosh.
    static let mac = [
        "..############..",
        ".#............#.",
        ".#.##########.#.",
        ".#.#........#.#.",
        ".#.#........#.#.",
        ".#.#........#.#.",
        ".#.#........#.#.",
        ".#.##########.#.",
        ".#............#.",
        ".#............#.",
        ".#......####..#.",
        ".#............#.",
        ".##############.",
        ".#............#.",
        ".##############.",
        "................",
    ]

    /// A window with its left half filled, as if snapped.
    static let snap = [
        "................",
        "################",
        "#.#.#.#.#.#.#.##",
        "################",
        "########.......#",
        "########.......#",
        "########.......#",
        "########.......#",
        "########.......#",
        "########.......#",
        "########.......#",
        "########.......#",
        "########.......#",
        "################",
        "................",
        "................",
    ]

    /// A screen with a black menu bar and a notch.
    static let notch = [
        "................",
        "################",
        "######....######",
        "#######..#######",
        "#..............#",
        "#..............#",
        "#..............#",
        "#..............#",
        "#..............#",
        "#..............#",
        "################",
        "......####......",
        "......####......",
        "....########....",
        "................",
        "................",
    ]

    static let lock = [
        "................",
        ".....######.....",
        "....#......#....",
        "...#..####..#...",
        "...#.#....#.#...",
        "...#.#....#.#...",
        "..############..",
        "..#..........#..",
        "..#....##....#..",
        "..#...####...#..",
        "..#....##....#..",
        "..#....##....#..",
        "..#..........#..",
        "..############..",
        "................",
        "................",
    ]

    /// The menu bar icon for the current look: the pixel hand (Retro) or the
    /// system's hand symbol (Modern). With `slashed`, it shows Shortie is paused.
    static func menuBarIcon(slashed: Bool) -> NSImage {
        if Look.current == .modern,
           let symbol = NSImage(systemSymbolName: slashed ? "hand.raised.slash" : "hand.draw", accessibilityDescription: nil) {
            return symbol
        }
        return menuBarImage(slashed: slashed)
    }

    /// The hand for the menu bar, one point per pixel so it stays sharp. With
    /// `slashed`, a line runs through it, for when Shortie is paused.
    static func menuBarImage(slashed: Bool) -> NSImage {
        var pixels = hand.map { Array($0) }
        if slashed {
            // A diagonal from top-left to bottom-right, with a gap on each side so it reads clearly.
            for i in 0..<16 {
                if i + 1 < 16 { pixels[i][i + 1] = "." }
                if i - 1 >= 0 { pixels[i][i - 1] = "." }
                pixels[i][i] = "#"
            }
        }
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: true) { _ in
            NSColor.black.setFill()
            for (y, row) in pixels.enumerated() {
                for (x, pixel) in row.enumerated() where pixel == "#" {
                    NSRect(x: x, y: y, width: 1, height: 1).fill()
                }
            }
            return true
        }
        // A template image takes the menu bar's own colour, light or dark.
        image.isTemplate = true
        return image
    }
}

/// Draws one of the pixel icons in the current foreground style, with square
/// pixels at any size. Sizes that are multiples of 16 keep every pixel even.
struct PixelIcon: View {
    let pixels: [String]
    var size: CGFloat = 32

    var body: some View {
        Canvas { context, canvasSize in
            let pixel = canvasSize.width / 16
            var path = Path()
            for (y, row) in pixels.enumerated() {
                for (x, character) in row.enumerated() where character == "#" {
                    path.addRect(CGRect(x: CGFloat(x) * pixel, y: CGFloat(y) * pixel, width: pixel, height: pixel))
                }
            }
            context.fill(path, with: .foreground)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// What an empty list shows: a short message, with a small pixel icon above it
/// in the Retro look.
struct EmptyState: View {
    let pixels: [String]
    let text: String

    @AppStorage(DefaultsKey.look) private var look = Look.retro

    init(_ text: String, pixels: [String]) {
        self.text = text
        self.pixels = pixels
    }

    var body: some View {
        if look == .retro {
            VStack(spacing: 10) {
                PixelIcon(pixels: pixels, size: 32)
                    .foregroundStyle(.tertiary)
                Text(text)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        } else {
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}
