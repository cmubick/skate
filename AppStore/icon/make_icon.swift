import AppKit
import ImageIO

// Draws the Skate app icon: the skater mid-ollie over a cone, in the game's own
// pixel art and palette (from PixelArt.swift), on a 32 x 32 grid blown up to 1024.
// usage: swift make_icon.swift <out.png> <light|dark|tinted>
let args = CommandLine.arguments
let out = args[1]
let mode = args.count > 2 ? args[2] : "light"
let grid = 32
let cell = 1024 / grid

func hex(_ value: UInt32) -> (UInt8, UInt8, UInt8) {
    (UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF))
}

let tinted = mode == "tinted"
let dark = mode == "dark"

/// Tinted icons are greyscale on black; iOS colors them.
func tone(_ value: UInt32) -> (UInt8, UInt8, UInt8) {
    let (r, g, b) = hex(value)
    guard tinted else { return (r, g, b) }
    let grey = UInt8((Int(r) * 30 + Int(g) * 59 + Int(b) * 11) / 100)
    return (grey, grey, grey)
}

var pixels = [[(UInt8, UInt8, UInt8)?]](repeating: [(UInt8, UInt8, UInt8)?](repeating: nil, count: grid), count: grid)
func set(_ x: Int, _ y: Int, _ color: UInt32) {
    guard x >= 0, x < grid, y >= 0, y < grid else { return }
    pixels[y][x] = tone(color)
}
func fill(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: UInt32) {
    for row in y..<(y + h) { for column in x..<(x + w) { set(column, row, color) } }
}
/// Rows top first, drawn with the top-left at (x, y) where y counts down from the top.
func draw(_ rows: [String], _ x: Int, _ y: Int, _ colors: [Character: UInt32]) {
    for (r, row) in rows.enumerated() {
        for (c, key) in row.enumerated() { if let color = colors[key] { set(x + c, y + r, color) } }
    }
}

// Sky, far towers, the back sidewalk and the street.
if tinted {
    fill(0, 0, grid, grid, 0x000000)
} else {
    fill(0, 0, grid, grid, dark ? 0x1C2048 : 0x6888FC)
    let towers: [(Int, Int, Int)] = [(0, 4, 12), (4, 6, 8), (10, 5, 14), (15, 7, 6), (22, 4, 11), (26, 6, 15)]
    for (x, w, h) in towers { fill(x, 22 - h, w, h, dark ? 0x2C3478 : 0x4C5CB8) }
    if dark { for (x, y) in [(2, 13), (11, 11), (24, 14), (28, 10), (12, 16)] { set(x, y, 0xF8D878) } }
    fill(0, 22, grid, 2, 0xFCFCFC)
    fill(0, 24, grid, 8, 0x3C3C3C)
    for x in stride(from: 1, to: grid, by: 8) { fill(x, 28, 4, 1, 0xF8B800) }
}

// A cone on the street.
let coneColors: [Character: UInt32] = ["o": 0xF83800, "w": 0xFCFCFC, "k": 0x545454]
draw(["...o...", "..ooo..", "..www..", ".ooooo.", ".ooooo.", "kkkkkkk"], 24, 23, coneColors)

// The skater in the air, from SkaterArt.air, and the board under the feet.
let skater: [Character: UInt32] = [
    "c": 0xF8B800, "k": 0xAC7C00, "h": 0x503000, "s": 0xE4A06C, "o": 0x6C2C10, "e": 0x101010,
    "t": 0x1C1C1C, "l": 0xFCFCFC, "p": 0xC8A870, "q": 0x907444, "n": 0x101010, "w": 0xFCFCFC,
]
draw([
    "......cccccc......",
    ".....cccccccc.....",
    "..kkkccccccccc....",
    "....ohhhsssss.....",
    "....ohhssssess....",
    "....ohsossssss....",
    "....ossssssos.....",
    ".....sssssss......",
    ".......sss........",
    ".s...tttttttt...s.",
    ".stttttttttttttts.",
    ".....tttllttt.....",
    ".....tttttttt.....",
    ".....pppppppp.....",
    "....ppppppppqp....",
    "...pppp....pppp...",
    "...nnnn....nnnn...",
    "...wwww....wwww...",
], 7, 2, skater)
draw(["dd................dd", ".dddddddddddddddddd.", "...mmm........mmm...", "...ww..........ww..."], 6, 20,
     ["d": 0x7C3C00, "m": 0x7C7C7C, "w": 0xFCFCFC])

// Paint the grid at full size.
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.black.setFill()
NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()
for y in 0..<grid {
    for x in 0..<grid {
        guard let (r, g, b) = pixels[y][x] else { continue }
        NSColor(deviceRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1).setFill()
        NSRect(x: x * cell, y: (grid - 1 - y) * cell, width: cell, height: cell).fill()
    }
}
NSGraphicsContext.restoreGraphicsState()

// App icons must be opaque.
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let opaque = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                       space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
opaque.draw(rep.cgImage!, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, opaque.makeImage()!, nil)
CGImageDestinationFinalize(destination)
