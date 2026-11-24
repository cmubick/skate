//
//  PixelArt.swift
//  skate
//
//  The palette, and everything the game draws, made in code from little
//  strings of pixels. Every texture uses nearest-neighbour scaling so pixels
//  stay square and sharp.
//

import CoreGraphics
import SpriteKit

// MARK: - Colors

struct PixelColor: Hashable {
    var r: UInt8, g: UInt8, b: UInt8, a: UInt8

    init(_ hex: UInt32, alpha: UInt8 = 255) {
        r = UInt8((hex >> 16) & 0xFF)
        g = UInt8((hex >> 8) & 0xFF)
        b = UInt8(hex & 0xFF)
        a = alpha
    }

    static let clear = PixelColor(0, alpha: 0)

    init(_ choice: ColorChoice) {
        self.init(choice.hex)
    }

    /// The same color in shadow.
    func darker(_ amount: Double = 0.65) -> PixelColor {
        var color = self
        color.r = UInt8(Double(r) * amount)
        color.g = UInt8(Double(g) * amount)
        color.b = UInt8(Double(b) * amount)
        return color
    }

    var skColor: SKColor {
        SKColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

/// One fixed palette for the whole game, NES style. Shared with the Angie game later.
enum Palette {
    static let black = PixelColor(0x101010)
    static let white = PixelColor(0xFCFCFC)
    static let lightGrey = PixelColor(0xBCBCBC)
    static let grey = PixelColor(0x7C7C7C)
    static let darkGrey = PixelColor(0x545454)
    static let asphalt = PixelColor(0x3C3C3C)

    static let sky = PixelColor(0x6888FC)
    static let farCity = PixelColor(0x4C5CB8)
    static let farCityLight = PixelColor(0x8CA4FC)
    static let window = PixelColor(0xF8D878)
    static let brick = PixelColor(0x883C24)
    static let brickDark = PixelColor(0x5C2414)

    static let yellow = PixelColor(0xF8B800)
    static let gold = PixelColor(0xAC7C00)
    static let orange = PixelColor(0xF83800)
    static let red = PixelColor(0xD82800)
    static let blue = PixelColor(0x0058F8)
    static let denim = PixelColor(0x24489C)
    static let green = PixelColor(0x00A844)
    static let darkGreen = PixelColor(0x005800)
    static let brown = PixelColor(0x7C3C00)
    static let hair = PixelColor(0x503000)
    static let skin = PixelColor(0xE4A06C)
    /// A dark brown line around faces, so heads read as heads.
    static let outline = PixelColor(0x6C2C10)
    static let shirt = PixelColor(0x1C1C1C)
    static let khaki = PixelColor(0xC8A870)
    static let khakiDark = PixelColor(0x907444)
    static let steel = PixelColor(0xA4E4FC)

    /// A see-through dark for shadows on the ground.
    static let shadow = PixelColor(0x000000, alpha: 90)
}

// MARK: - Canvas

/// A small RGBA bitmap. `y` counts up from the bottom, as in SpriteKit.
struct PixelCanvas {
    let width: Int
    let height: Int
    private var pixels: [UInt8]

    init(width: Int, height: Int, fill: PixelColor = .clear) {
        self.width = max(1, width)
        self.height = max(1, height)
        pixels = [UInt8](repeating: 0, count: self.width * self.height * 4)
        if fill != .clear { self.fill(x: 0, y: 0, width: self.width, height: self.height, fill) }
    }

    mutating func set(_ x: Int, _ y: Int, _ color: PixelColor) {
        guard x >= 0, x < width, y >= 0, y < height, color.a > 0 else { return }
        let index = ((height - 1 - y) * width + x) * 4
        // Premultiplied, as Core Graphics wants it.
        let alpha = Int(color.a)
        pixels[index] = UInt8(Int(color.r) * alpha / 255)
        pixels[index + 1] = UInt8(Int(color.g) * alpha / 255)
        pixels[index + 2] = UInt8(Int(color.b) * alpha / 255)
        pixels[index + 3] = color.a
    }

    mutating func fill(x: Int, y: Int, width w: Int, height h: Int, _ color: PixelColor) {
        for row in y..<(y + max(0, h)) {
            for column in x..<(x + max(0, w)) { set(column, row, color) }
        }
    }

    /// Makes pixels see-through again.
    mutating func erase(x: Int, y: Int, width w: Int, height h: Int) {
        for row in max(0, y)..<min(height, y + max(0, h)) {
            for column in max(0, x)..<min(width, x + max(0, w)) {
                let index = ((height - 1 - row) * width + column) * 4
                pixels[index] = 0; pixels[index + 1] = 0; pixels[index + 2] = 0; pixels[index + 3] = 0
            }
        }
    }

    /// Draws another canvas with its bottom-left corner at (x, y). See-through pixels are skipped.
    mutating func draw(_ other: PixelCanvas, x: Int, y: Int) {
        for row in 0..<other.height {
            for column in 0..<other.width {
                let px = x + column, py = y + row
                guard px >= 0, px < width, py >= 0, py < height else { continue }
                let from = ((other.height - 1 - row) * other.width + column) * 4
                guard other.pixels[from + 3] > 0 else { continue }
                let to = ((height - 1 - py) * width + px) * 4
                for channel in 0..<4 { pixels[to + channel] = other.pixels[from + channel] }
            }
        }
    }

    /// Draws a sprite with its bottom-left corner at (x, y).
    mutating func draw(_ sprite: PixelSprite, x: Int, y: Int, mirrored: Bool = false) {
        for (rowIndex, row) in sprite.rows.enumerated() {
            let py = y + sprite.height - 1 - rowIndex
            for (columnIndex, key) in row.enumerated() {
                guard let color = sprite.colors[key] else { continue }
                let px = mirrored ? x + sprite.width - 1 - columnIndex : x + columnIndex
                set(px, py, color)
            }
        }
    }

    func cgImage() -> CGImage? {
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    func texture() -> SKTexture {
        let texture = cgImage().map { SKTexture(cgImage: $0) } ?? SKTexture()
        texture.filteringMode = .nearest
        return texture
    }
}

/// A sprite drawn as rows of characters, top row first. Each character is looked up
/// in `colors`; anything not in it (like ".") is see-through. Short rows are padded.
struct PixelSprite {
    let rows: [[Character]]
    let colors: [Character: PixelColor]
    let width: Int
    var height: Int { rows.count }

    init(_ rows: [String], colors: [Character: PixelColor]) {
        width = rows.map(\.count).max() ?? 0
        self.rows = rows.map { Array($0) + Array(repeating: ".", count: (rows.map(\.count).max() ?? 0) - $0.count) }
        self.colors = colors
    }

    func texture(mirrored: Bool = false) -> SKTexture {
        var canvas = PixelCanvas(width: width, height: height)
        canvas.draw(self, x: 0, y: 0, mirrored: mirrored)
        return canvas.texture()
    }
}

// MARK: - Text

/// A 7-pixel-high font, 5 pixels wide for most letters: capitals, digits and a
/// little punctuation. Big enough to read at a glance mid-run.
enum PixelFont {
    static let glyphHeight = 7
    /// Space between letters.
    static let gap = 1
    /// Two bars, for the pause button.
    static let pauseSymbol = "\u{23F8}"

    /// The biggest scale, up to `maxScale`, that fits text `width` game pixels wide into
    /// `available` game pixels. Only scales where each font pixel is a whole number of
    /// screen pixels, so the letters stay sharp (1.5x is 18 screen pixels at 12x).
    static func fittingScale(width: Int, into available: CGFloat, maxScale: CGFloat, screenPixelsPerPixel: Int) -> CGFloat {
        let steps = CGFloat(max(1, screenPixelsPerPixel))
        guard width > 0 else { return maxScale }
        let fit = (available * steps / CGFloat(width)).rounded(.down)
        return max(1, min(maxScale * steps, fit)) / steps
    }

    private static let glyphs: [Character: [String]] = [
        "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
        "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
        "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
        "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
        "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
        "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
        "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
        "J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
        "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
        "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
        "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
        "N": ["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
        "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
        "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
        "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
        "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
        "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
        "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
        "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
        "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
        "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
        "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
        "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
        "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
        "+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
        "-": ["...", "...", "...", "###", "...", "...", "..."],
        "!": ["#", "#", "#", "#", "#", ".", "#"],
        ":": [".", ".", "#", ".", ".", "#", "."],
        ".": [".", ".", ".", ".", ".", ".", "#"],
        "/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
        "?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
        "<": ["...#", "..#.", ".#..", "#...", ".#..", "..#.", "...#"],
        ">": ["#...", ".#..", "..#.", "...#", "..#.", ".#..", "#..."],
        // The pause symbol: two solid bars.
        "\u{23F8}": ["##.##", "##.##", "##.##", "##.##", "##.##", "##.##", "##.##"],
        " ": ["...", "...", "...", "...", "...", "...", "..."],
    ]

    static func glyph(_ character: Character) -> [String] {
        glyphs[character] ?? glyphs["?"]!
    }

    static func width(of text: String) -> Int {
        max(1, text.reduce(0) { $0 + glyph($1)[0].count + gap } - gap)
    }

    private static var cache: [String: SKTexture] = [:]

    /// The text drawn in `color` with a dark drop shadow, so it reads over anything.
    static func texture(_ text: String, color: PixelColor = Palette.white) -> SKTexture {
        let text = text.uppercased()
        let key = "\(text)|\(color.r),\(color.g),\(color.b)"
        if let cached = cache[key] { return cached }
        // The shadow sits straight below each letter, so it never fills the gap between them.
        var canvas = PixelCanvas(width: width(of: text), height: glyphHeight + 1)
        for (pass, ink) in [(1, Palette.black), (0, color)] {
            var x = 0
            for character in text {
                let rows = glyph(character)
                let sprite = PixelSprite(rows.map { $0.replacingOccurrences(of: "#", with: "x") }, colors: ["x": ink])
                canvas.draw(sprite, x: x, y: 1 - pass)
                x += rows[0].count + gap
            }
        }
        let texture = canvas.texture()
        if cache.count > 200 { cache.removeAll() }
        cache[key] = texture
        return texture
    }

    /// Draws text into a canvas, with no shadow.
    static func draw(_ text: String, into canvas: inout PixelCanvas, x: Int, y: Int, color: PixelColor) {
        var cursor = x
        for character in text.uppercased() {
            let rows = glyph(character)
            canvas.draw(PixelSprite(rows.map { $0.replacingOccurrences(of: "#", with: "x") }, colors: ["x": color]), x: cursor, y: y)
            cursor += rows[0].count + gap
        }
    }

    /// Text in several colors side by side, each with the drop shadow: say, found
    /// letters in gold and missing ones in grey.
    static func texture(runs: [(String, PixelColor)]) -> SKTexture {
        let text = runs.map(\.0).joined()
        var canvas = PixelCanvas(width: width(of: text), height: glyphHeight + 1)
        for pass in [1, 0] {
            var x = 0
            for (part, color) in runs {
                draw(part, into: &canvas, x: x, y: 1 - pass, color: pass == 1 ? Palette.black : color)
                x += width(of: part) + gap
            }
        }
        return canvas.texture()
    }

    /// Every glyph, for checking they're all the right size.
    static var allGlyphs: [[String]] { Array(glyphs.values) }
}

// MARK: - Randomness

/// The same "random" numbers every launch, so generated art doesn't change.
nonisolated struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
