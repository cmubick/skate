import AppKit
import ImageIO
import UniformTypeIdentifiers

// Draws the promotional images for the three tips: a glass tip jar in the game's
// pixel art, a few coins for the small tip, half full for the medium and
// overflowing for the large. 32 x 32 pixels blown up to 1024 x 1024, square
// corners, no text, nothing in the lower-left corner (Apple's frame can put the
// app icon there), no transparency.
//
//   swift AppStore/make_tip_images.swift "AppStore/upload/In-App Purchases"

let grid = 32
let cell = 1024 / grid
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")

let night: UInt32 = 0x141A3C, glassInside: UInt32 = 0x222C5C, glass: UInt32 = 0x9CD0F8
let shine: UInt32 = 0xD8EEFF, rim: UInt32 = 0xFCFCFC
let coin: UInt32 = 0xF8B800, coinEdge: UInt32 = 0xAC7C00, coinShine: UInt32 = 0xFCE8A0
let pink: UInt32 = 0xE8508C

func render(level: Int, name: String) throws {
    var pixels = [[UInt32]](repeating: [UInt32](repeating: night, count: grid), count: grid)
    func set(_ x: Int, _ y: Int, _ color: UInt32) {
        guard x >= 0, x < grid, y >= 0, y < grid else { return }
        pixels[y][x] = color
    }
    func fill(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: UInt32) {
        for row in y..<(y + h) { for column in x..<(x + w) { set(column, row, color) } }
    }
    /// A coin seen a little from above: a gold top with a darker edge under it.
    func coinAt(_ x: Int, _ y: Int) {
        fill(x, y, 3, 1, coin)
        set(x, y, coinShine)
        fill(x, y + 1, 3, 1, coinEdge)
    }

    // A soft pink glow behind the jar, so it reads at small sizes.
    for y in 0..<grid {
        for x in 0..<grid {
            let dx = Double(x) - 16, dy = Double(y) - 15
            if dx * dx + dy * dy < 13 * 13 { set(x, y, 0x2A2050) }
            if dx * dx + dy * dy < 11 * 11 { set(x, y, 0x3A2460) }
        }
    }

    // The jar: an open neck, shoulders and a round-bottomed body (y counts down).
    let top = 8, bottom = 26
    fill(9, top + 2, 15, bottom - top - 2, glassInside)
    fill(11, top, 11, 2, glassInside)
    // Coins, filled up from the bottom: `level` rows of coins, staggered.
    let rows = min(level, 9)
    for row in 0..<rows {
        let y = bottom - 2 - row * 2
        let offset = row.isMultiple(of: 2) ? 0 : 1
        var x = 9 + offset
        while x + 2 <= 23 {
            coinAt(x, y)
            x += 4
        }
        // Fill the gaps between coins with edge color, like a heap.
        for gx in stride(from: 9, through: 23, by: 1) where pixels[y][gx] == glassInside { set(gx, y, coinEdge) }
        for gx in stride(from: 9, through: 23, by: 1) where pixels[y + 1][gx] == glassInside { set(gx, y + 1, coinEdge) }
    }
    // The glass outline over everything.
    for y in (top + 2)...bottom - 1 { set(8, y, glass); set(24, y, glass) }
    fill(9, bottom, 15, 1, glass)
    set(9, top + 2, glass); set(23, top + 2, glass)
    for y in top..<(top + 2) { set(10, y, glass); set(22, y, glass) }
    fill(10, top - 1, 13, 1, rim)
    // A highlight down the glass.
    for y in (top + 4)...(bottom - 4) { set(10, y, shine) }
    set(11, top + 4, shine)

    // Coins dropping in, and for the big tip a heap spilling over the top and sparkles.
    let falling: [(Int, Int)] = level <= 2 ? [(15, 3)] : level <= 5 ? [(14, 2), (18, 5)] : [(12, 1), (17, 3), (20, 0)]
    for (x, y) in falling { coinAt(x, y) }
    if level >= 9 {
        for (x, y) in [(11, 6), (15, 5), (19, 6), (13, 4)] { coinAt(x, y) }
        for (x, y) in [(5, 6), (27, 9), (26, 3), (6, 13)] {
            set(x, y, rim); set(x - 1, y, pink); set(x + 1, y, pink); set(x, y - 1, pink); set(x, y + 1, pink)
        }
    } else if level >= 5 {
        for (x, y) in [(26, 6), (6, 9)] { set(x, y, rim); set(x - 1, y, pink); set(x + 1, y, pink) }
    }

    // Blow it up, no alpha.
    let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    for y in 0..<grid {
        for x in 0..<grid {
            let value = pixels[y][x]
            context.setFillColor(CGColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                                         green: CGFloat((value >> 8) & 0xFF) / 255,
                                         blue: CGFloat(value & 0xFF) / 255, alpha: 1))
            context.fill(CGRect(x: x * cell, y: (grid - 1 - y) * cell, width: cell, height: cell))
        }
    }
    let url = output.appendingPathComponent(name)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, [kCGImagePropertyDPIWidth: 72, kCGImagePropertyDPIHeight: 72] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    print("wrote \(name)")
}

try render(level: 2, name: "promo-small-tip.png")
try render(level: 5, name: "promo-generous-tip.png")
try render(level: 9, name: "promo-big-tip.png")
