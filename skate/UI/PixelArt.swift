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

// MARK: - The skater

/// A short, chunky skater with a big head and a yellow cap on backwards.
/// Everything faces right; the cap's brim sticks out the back.
enum SkaterArt {
    static let colors: [Character: PixelColor] = [
        "c": Palette.yellow, "k": Palette.gold, "h": Palette.hair, "s": Palette.skin, "e": Palette.black,
        "r": Palette.green, "b": Palette.denim, "w": Palette.white, "g": Palette.grey,
    ]

    /// The head and cap, shared by every pose.
    private static let head = [
        "........cccccc........",
        "......cccccccccc......",
        ".....cccccccccccc.....",
        "..kkkkcccccccccccc....",
        ".....hhhsssssssss.....",
        ".....hhsssssssess.....",
        ".....hhssssssssss.....",
        "......hsssssssss......",
        ".......ssssssss.......",
        "........ssssss........",
    ]

    static let roll = PixelSprite(head + [
        ".......rrrrrrrr.......",
        ".....rrrrrrrrrrrr.....",
        "....srrrrrrrrrrrrs....",
        "...ss.rrrrrrrrrr.ss...",
        "......rrrrrrrrrr......",
        "......bbbbbbbbbb......",
        "......bbbbbbbbbbb.....",
        ".....bbbbb...bbbbb....",
        "....bbbbb.....bbbb....",
        "....bbbb.......bbbb...",
        "...wwwwww.....wwwwww..",
        "..ggggggg....ggggggg..",
    ], colors: colors)

    /// Knees bent: winding up an ollie, or riding a rail.
    static let crouch = PixelSprite(head + [
        ".......rrrrrrrr.......",
        ".....rrrrrrrrrrrr.....",
        "....srrrrrrrrrrrrss...",
        "...ss.rrrrrrrrrr..ss..",
        "......bbbbbbbbbb......",
        ".....bbbbbbbbbbbb.....",
        "....bbbbb....bbbbb....",
        "...wwwwww....wwwwww...",
        "..ggggggg....ggggggg..",
    ], colors: colors)

    /// Knees up, arms out.
    static let air = PixelSprite(head + [
        ".s.....rrrrrrrr.....s.",
        ".ss..rrrrrrrrrrrr..ss.",
        "..ssrrrrrrrrrrrrrrss..",
        "......rrrrrrrrrr......",
        "......bbbbbbbbbb......",
        ".....bbbbbbbbbbbb.....",
        "....bbbbbbbbbbbbbb....",
        "....bbbb......bbbb....",
        "...wwwwww....wwwwww...",
        "..ggggggg....ggggggg..",
    ], colors: colors)

    /// One hand down on the board.
    static let grab = PixelSprite(head + [
        ".s.....rrrrrrrr.......",
        ".ss..rrrrrrrrrrrr.....",
        "..ssrrrrrrrrrrrrr.....",
        "......rrrrrrrrrrs.....",
        "......bbbbbbbbbbss....",
        ".....bbbbbbbbbbbbs....",
        "....bbbbbbbbbbbbbs....",
        "....bbbb......bbbs....",
        "...wwwwww....wwwws....",
        "..ggggggg....gggggss..",
    ], colors: colors)

    /// Flat on the ground.
    static let bail = PixelSprite([
        "...............kcccc..",
        "..............cccccccc",
        "wwbbbbbbrrrrrrhhssssss",
        "wwbbbbbbrrrrrrhsssesss",
        "ggbb..bbrrrrrrsssssss.",
        "........ss..ss.ssss...",
    ], colors: colors)
}

enum BoardArt {
    static let colors: [Character: PixelColor] = [
        "d": Palette.brown, "m": Palette.grey, "w": Palette.white,
        "o": Palette.orange, "y": Palette.yellow, "k": Palette.darkGrey,
    ]

    /// Side on, wheels down: how it looks rolling.
    static let side = PixelSprite([
        "dd................dd",
        ".dddddddddddddddddd.",
        "...mmm........mmm...",
        "...ww..........ww...",
    ], colors: colors)

    static let wheelsUp = PixelSprite([
        "...ww..........ww...",
        "...mmm........mmm...",
        ".dddddddddddddddddd.",
        "dd................dd",
    ], colors: colors)

    /// Flipped toward you, showing the graphic underneath.
    static let underside = PixelSprite([
        ".oooooooooooooooooo.",
        "oyyyoooooyyoooooyyyo",
        "oyyyooooyyyyooooyyyo",
        "oyyyoooooyyoooooyyyo",
        ".oooooooooooooooooo.",
    ], colors: colors)

    /// Flipped away from you, showing the grip tape.
    static let grip = PixelSprite([
        ".kkkkkkkkkkkkkkkkkk.",
        "kkkkkkkkkkkkkkkkkkkk",
        "kkkkkkkkkkkkkkkkkkkk",
        "kkkkkkkkkkkkkkkkkkkk",
        ".kkkkkkkkkkkkkkkkkk.",
    ], colors: colors)
}

// MARK: - Street things

enum FeatureArt {
    static func texture(for feature: Feature) -> SKTexture {
        let width = Int(feature.length)
        let height = Int(feature.height)
        var canvas = PixelCanvas(width: width, height: height)
        switch feature.kind {
        case .rail:
            // A round bar on posts.
            var postX = 2
            while postX < width - 2 {
                canvas.fill(x: postX, y: 0, width: 2, height: height - 2, Palette.grey)
                postX += 30
            }
            canvas.fill(x: width - 4, y: 0, width: 2, height: height - 2, Palette.grey)
            canvas.fill(x: 0, y: height - 2, width: width, height: 1, Palette.steel)
            canvas.fill(x: 0, y: height - 1, width: width, height: 1, Palette.white)
        case .ledge:
            // A concrete bench: a light top edge, a face, and a dark foot.
            canvas.fill(x: 0, y: 0, width: width, height: height, Palette.grey)
            canvas.fill(x: 0, y: height - 2, width: width, height: 2, Palette.lightGrey)
            canvas.fill(x: 0, y: height - 1, width: width, height: 1, Palette.white)
            canvas.fill(x: 0, y: 0, width: width, height: 1, Palette.darkGrey)
            canvas.fill(x: 0, y: 0, width: 1, height: height, Palette.darkGrey)
            canvas.fill(x: width - 1, y: 0, width: 1, height: height, Palette.darkGrey)
        case .block:
            if width < 16 {
                drawCone(&canvas)
            } else {
                drawPlanter(&canvas)
            }
        }
        return canvas.texture()
    }

    private static func drawCone(_ canvas: inout PixelCanvas) {
        let w = canvas.width, h = canvas.height
        canvas.fill(x: 0, y: 0, width: w, height: 1, Palette.darkGrey)
        for y in 1..<h {
            let half = max(0, Int(Double(w) / 2 * (1 - Double(y - 1) / Double(h))))
            let mid = w / 2
            let color = (y == h / 2 || y == h / 2 + 1) ? Palette.white : Palette.orange
            canvas.fill(x: mid - half, y: y, width: half * 2 + 1, height: 1, color)
        }
    }

    private static func drawPlanter(_ canvas: inout PixelCanvas) {
        let w = canvas.width, h = canvas.height
        let boxHeight = h * 2 / 3
        canvas.fill(x: 0, y: 0, width: w, height: boxHeight, Palette.brick)
        canvas.fill(x: 0, y: boxHeight - 1, width: w, height: 1, Palette.lightGrey)
        canvas.fill(x: 0, y: 0, width: w, height: 1, Palette.brickDark)
        var generator = SeededGenerator(seed: UInt64(w * 31 + h))
        for x in 0..<w {
            let top = boxHeight + Int.random(in: 1...(h - boxHeight), using: &generator)
            canvas.fill(x: x, y: boxHeight, width: 1, height: top - boxHeight, Palette.green)
            canvas.set(x, top - 1, x % 3 == 0 ? Palette.darkGreen : Palette.green)
        }
    }

    static func finishLine(height: Int) -> SKTexture {
        var canvas = PixelCanvas(width: 6, height: height)
        for y in 0..<height {
            for x in 0..<6 {
                canvas.set(x, y, ((x / 3) + (y / 3)) % 2 == 0 ? Palette.white : Palette.black)
            }
        }
        return canvas.texture()
    }
}

// MARK: - Background

enum StreetArt {
    /// Feet stand on these lines, in game pixels from the bottom of the screen.
    static func baseline(forLane lane: CGFloat) -> CGFloat {
        15 + (2 - lane) * Tuning.laneSpacing
    }

    /// The top of the back sidewalk, where the buildings start.
    static let groundTop = 54

    /// One repeating stretch of sidewalk, street and sidewalk. The front and middle
    /// lanes are in the street, the back lane on the far sidewalk.
    static func ground(width: Int = 64) -> SKTexture {
        var canvas = PixelCanvas(width: width, height: groundTop)
        // Near sidewalk.
        canvas.fill(x: 0, y: 0, width: width, height: 7, Palette.lightGrey)
        for x in stride(from: 0, to: width, by: 16) { canvas.fill(x: x, y: 0, width: 1, height: 7, Palette.grey) }
        // Near curb and gutter.
        canvas.fill(x: 0, y: 7, width: width, height: 2, Palette.white)
        canvas.fill(x: 0, y: 9, width: width, height: 1, Palette.grey)
        // Street, with a dashed line between the front and middle lanes.
        canvas.fill(x: 0, y: 10, width: width, height: 27, Palette.asphalt)
        for x in stride(from: 0, to: width, by: 16) { canvas.fill(x: x, y: 22, width: 8, height: 1, Palette.yellow) }
        // Far curb and the back sidewalk.
        canvas.fill(x: 0, y: 37, width: width, height: 1, Palette.grey)
        canvas.fill(x: 0, y: 38, width: width, height: 2, Palette.white)
        canvas.fill(x: 0, y: 40, width: width, height: groundTop - 40, Palette.lightGrey)
        for x in stride(from: 8, to: width, by: 16) { canvas.fill(x: x, y: 40, width: 1, height: groundTop - 40, Palette.grey) }
        canvas.fill(x: 0, y: groundTop - 1, width: width, height: 1, Palette.grey)
        return canvas.texture()
    }

    /// Far-off towers in haze. Repeats every `width` pixels.
    static func skyline(width: Int = 384, height: Int = 100) -> SKTexture {
        var canvas = PixelCanvas(width: width, height: height)
        var generator = SeededGenerator(seed: 7)
        var x = 0
        while x < width {
            let w = Int.random(in: 14...34, using: &generator)
            let h = Int.random(in: 24...(height - 10), using: &generator)
            canvas.fill(x: x, y: 0, width: min(w, width - x), height: h, Palette.farCity)
            if Bool.random(using: &generator) {
                canvas.fill(x: x + w / 2, y: h, width: 1, height: 6, Palette.farCity)
            }
            for wy in stride(from: 6, to: h - 4, by: 6) {
                for wx in stride(from: x + 3, to: min(x + w - 2, width), by: 5) where Int.random(in: 0..<4, using: &generator) == 0 {
                    canvas.set(wx, wy, Palette.farCityLight)
                }
            }
            x += w + Int.random(in: 0...6, using: &generator)
        }
        return canvas.texture()
    }

    /// Brick buildings across the street, with lit windows. Repeats every `width` pixels.
    static func buildings(width: Int = 320, height: Int = 70) -> SKTexture {
        var canvas = PixelCanvas(width: width, height: height)
        var generator = SeededGenerator(seed: 11)
        var x = 0
        while x < width {
            let w = min(Int.random(in: 40...72, using: &generator), width - x)
            let h = Int.random(in: 30...height, using: &generator)
            let wall = Bool.random(using: &generator) ? Palette.brick : Palette.grey
            let trim = wall == Palette.brick ? Palette.brickDark : Palette.darkGrey
            canvas.fill(x: x, y: 0, width: w, height: h, wall)
            canvas.fill(x: x, y: h - 2, width: w, height: 2, trim)
            canvas.fill(x: x, y: 0, width: 1, height: h, trim)
            for wy in stride(from: 10, to: h - 6, by: 9) {
                for wx in stride(from: x + 5, to: x + w - 6, by: 9) {
                    let lit = Int.random(in: 0..<3, using: &generator) == 0
                    canvas.fill(x: wx, y: wy, width: 4, height: 5, lit ? Palette.window : Palette.black)
                }
            }
            // A shop door at street level.
            canvas.fill(x: x + w / 2 - 3, y: 0, width: 6, height: 8, Palette.black)
            x += w
        }
        return canvas.texture()
    }

    /// A soft oval shadow on the ground.
    static func shadow(width: Int = 18) -> SKTexture {
        var canvas = PixelCanvas(width: width, height: 2)
        canvas.fill(x: 1, y: 0, width: width - 2, height: 2, Palette.shadow)
        canvas.fill(x: 0, y: 1, width: width, height: 1, Palette.shadow)
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
        " ": ["...", "...", "...", "...", "...", "...", "..."],
    ]

    private static func glyph(_ character: Character) -> [String] {
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
