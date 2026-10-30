// Draws the app icon's glyph: the pixel hand, white on transparent, 1024 × 1024.
// Usage: swift Scripts/pixel-glyph.swift <output.png> [outline|framed] [preview]
//   (default) a solid white hand with no outline; the gaps between the fingers show through
//   outline   only the outline, like the website's icons
//   framed    the outline, with a faint fill inside
//   preview   draws it on the icon's gradient, to look at
// To update the app icon: swift Scripts/pixel-glyph.swift Glide/AppIcon.icon/Assets/glyph.png
// The pixels match PixelArt.hand in Glide/App/PixelArt.swift.
import AppKit

let hand = [
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
].map { Array($0) }

let arguments = CommandLine.arguments
let output = URL(fileURLWithPath: arguments[1])
let style = arguments.contains("outline") ? "outline" : arguments.contains("framed") ? "framed" : "solid"
let preview = arguments.contains("preview")

// The inside of the hand: empty pixels that can't be reached from the edge.
var outside = Array(repeating: Array(repeating: false, count: 16), count: 16)
var queue: [(Int, Int)] = []
for i in 0..<16 { queue += [(i, 0), (i, 15), (0, i), (15, i)] }
while let (x, y) = queue.popLast() {
    guard (0..<16).contains(x), (0..<16).contains(y), !outside[y][x], hand[y][x] == "." else { continue }
    outside[y][x] = true
    queue += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
}

let size = 1024
// 16 × 34 = 544 points across, centred like the old glyph. The solid hand has no
// outline, so it is drawn a little larger to fill the same space.
let pixel = style == "solid" ? 38 : 34
let origin = (size - 16 * pixel) / 2

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current!.shouldAntialias = false

if preview {
    let rounded = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: 230, yRadius: 230)
    NSGradient(colors: [
        NSColor(displayP3Red: 0.32, green: 0.38, blue: 0.99, alpha: 1),
        NSColor(displayP3Red: 0.55, green: 0.25, blue: 0.91, alpha: 1),
    ])!.draw(in: rounded, angle: -90)
}

for y in 0..<16 {
    for x in 0..<16 {
        let isOutline = hand[y][x] == "#"
        let isInside = !isOutline && !outside[y][x]
        let alpha: CGFloat
        switch style {
        case "outline": alpha = isOutline ? 1 : 0
        case "framed": alpha = isOutline ? 1 : isInside ? 0.3 : 0
        default: alpha = isInside ? 1 : 0
        }
        guard alpha > 0 else { continue }
        NSColor.white.withAlphaComponent(alpha).setFill()
        // AppKit draws from the bottom up.
        NSRect(x: origin + x * pixel, y: size - origin - (y + 1) * pixel, width: pixel, height: pixel).fill()
    }
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: output)
