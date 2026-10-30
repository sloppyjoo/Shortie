import AppKit

/// Shortie's 1-bit pixel art: the classic Mac pointing hand, the same one the
/// website uses (`docs/icons.js`) and the app icon is made from.
enum PixelArt {
    /// 16 × 16 pixels: "#" is drawn, "." is empty.
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
