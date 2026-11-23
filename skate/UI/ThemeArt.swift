//
//  ThemeArt.swift
//  skate
//
//  Each spot's sky, backdrops and ground, drawn in code. Backdrops repeat
//  sideways and scroll slower than the street to give depth.
//

import SpriteKit

/// One backdrop layer: a repeating picture, how fast it scrolls, and how high above
/// the back sidewalk it sits.
struct BackdropLayer {
    var texture: SKTexture
    var factor: CGFloat
    var lift: CGFloat = 0
}

struct ThemeLook {
    var sky: PixelColor
    var layers: [BackdropLayer]
    var ground: SKTexture
}

enum StreetArt {
    /// Feet stand on these lines, in game pixels from the bottom of the screen.
    static func baseline(forLane lane: CGFloat) -> CGFloat {
        15 + (2 - lane) * Tuning.laneSpacing
    }

    /// The top of the back sidewalk, where the backdrops start.
    static let groundTop = 54

    /// A soft oval shadow on the ground.
    static func shadow(width: Int = 18) -> SKTexture {
        var canvas = PixelCanvas(width: width, height: 2)
        canvas.fill(x: 1, y: 0, width: width - 2, height: 2, Palette.shadow)
        canvas.fill(x: 0, y: 1, width: width, height: 1, Palette.shadow)
        return canvas.texture()
    }
}

enum ThemeArt {
    static func look(for theme: Theme) -> ThemeLook {
        switch theme {
        case .downtown:
            return ThemeLook(sky: Palette.sky, layers: [
                BackdropLayer(texture: skyline(), factor: 0.2),
                BackdropLayer(texture: buildings(), factor: 0.5),
            ], ground: street(sidewalk: .slabs))
        case .skidmore:
            return ThemeLook(sky: PixelColor(0x7C98D8), layers: [
                BackdropLayer(texture: overpass(), factor: 0.3),
                BackdropLayer(texture: oldTown(), factor: 0.5),
            ], ground: street(sidewalk: .bricks))
        case .burnside:
            return ThemeLook(sky: PixelColor(0x24242C), layers: [
                BackdropLayer(texture: bridgeUnderside(), factor: 0.25),
                BackdropLayer(texture: skateparkWalls(), factor: 0.6),
            ], ground: skateparkConcrete())
        case .northPortland:
            return ThemeLook(sky: PixelColor(0x88B8F8), layers: [
                BackdropLayer(texture: stJohnsBridge(), factor: 0.15),
                BackdropLayer(texture: foodCartsAndTrees(), factor: 0.5),
            ], ground: street(sidewalk: .grassEdge))
        case .waterfront:
            return ThemeLook(sky: PixelColor(0x78A8F0), layers: [
                BackdropLayer(texture: cityAcrossTheRiver(), factor: 0.12, lift: 11),
                BackdropLayer(texture: river(), factor: 0.6),
            ], ground: esplanade())
        case .zooBomb:
            return ThemeLook(sky: PixelColor(0xA4C8E8), layers: [
                BackdropLayer(texture: forestedHills(), factor: 0.15),
                BackdropLayer(texture: zooWoods(), factor: 0.55),
            ], ground: zooRoad())
        }
    }

    // MARK: - Grounds

    enum Sidewalk { case slabs, bricks, grassEdge }

    /// Sidewalk, street and sidewalk. The front and middle lanes are in the street,
    /// the back lane on the far sidewalk.
    static func street(sidewalk: Sidewalk, width: Int = 64) -> SKTexture {
        let top = StreetArt.groundTop
        var canvas = PixelCanvas(width: width, height: top)
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
        switch sidewalk {
        case .slabs:
            canvas.fill(x: 0, y: 40, width: width, height: top - 40, Palette.lightGrey)
            for x in stride(from: 8, to: width, by: 16) { canvas.fill(x: x, y: 40, width: 1, height: top - 40, Palette.grey) }
        case .bricks:
            canvas.fill(x: 0, y: 40, width: width, height: top - 40, PixelColor(0xA84C34))
            for row in 0..<((top - 40) / 3) {
                let y = 40 + row * 3
                canvas.fill(x: 0, y: y, width: width, height: 1, PixelColor(0x7C3020))
                for x in stride(from: row % 2 == 0 ? 0 : 4, to: width, by: 8) { canvas.set(x, y + 1, PixelColor(0x7C3020)); canvas.set(x, y + 2, PixelColor(0x7C3020)) }
            }
        case .grassEdge:
            canvas.fill(x: 0, y: 40, width: width, height: top - 44, Palette.lightGrey)
            for x in stride(from: 8, to: width, by: 16) { canvas.fill(x: x, y: 40, width: 1, height: top - 44, Palette.grey) }
            canvas.fill(x: 0, y: top - 4, width: width, height: 4, Palette.green)
            for x in stride(from: 1, to: width, by: 3) { canvas.set(x, top - 1, Palette.darkGreen) }
        }
        canvas.fill(x: 0, y: top - 1, width: width, height: 1, sidewalk == .grassEdge ? Palette.darkGreen : Palette.grey)
        return canvas.texture()
    }

    /// Under the bridge: concrete everywhere, with expansion joints and stains.
    static func skateparkConcrete(width: Int = 64) -> SKTexture {
        let top = StreetArt.groundTop
        var canvas = PixelCanvas(width: width, height: top, fill: PixelColor(0x9C9C9C))
        var generator = SeededGenerator(seed: 21)
        for x in stride(from: 0, to: width, by: 32) { canvas.fill(x: x, y: 0, width: 1, height: top, PixelColor(0x7C7C7C)) }
        for y in [8, 22, 37] { canvas.fill(x: 0, y: y, width: width, height: 1, PixelColor(0x848484)) }
        for _ in 0..<14 {
            canvas.set(Int.random(in: 0..<width, using: &generator), Int.random(in: 0..<top, using: &generator), PixelColor(0x8C8C8C))
        }
        // A metal coping edge along the back.
        canvas.fill(x: 0, y: top - 2, width: width, height: 1, Palette.lightGrey)
        canvas.fill(x: 0, y: top - 1, width: width, height: 1, Palette.grey)
        return canvas.texture()
    }

    /// The Eastbank esplanade: a boardwalk with a railing along the river, then paths.
    static func esplanade(width: Int = 64) -> SKTexture {
        let top = StreetArt.groundTop
        var canvas = PixelCanvas(width: width, height: top)
        // Grass at the near edge.
        canvas.fill(x: 0, y: 0, width: width, height: 8, Palette.green)
        for x in stride(from: 2, to: width, by: 5) { canvas.set(x, 7, Palette.darkGreen) }
        // The concrete path: front and middle lanes.
        canvas.fill(x: 0, y: 8, width: width, height: 30, PixelColor(0xB4B0A8))
        for x in stride(from: 0, to: width, by: 32) { canvas.fill(x: x, y: 8, width: 1, height: 30, PixelColor(0x949088)) }
        canvas.fill(x: 0, y: 22, width: width, height: 1, PixelColor(0x949088))
        // The boardwalk: planks.
        canvas.fill(x: 0, y: 38, width: width, height: top - 38, PixelColor(0x9C6C3C))
        for y in stride(from: 38, to: top, by: 3) { canvas.fill(x: 0, y: y, width: width, height: 1, PixelColor(0x6C4424)) }
        // The railing along the water.
        canvas.fill(x: 0, y: top - 3, width: width, height: 1, Palette.lightGrey)
        for x in stride(from: 0, to: width, by: 8) { canvas.fill(x: x, y: top - 6, width: 1, height: 4, Palette.grey) }
        return canvas.texture()
    }

    /// Down from the zoo: a park path at the back, then the road with a double yellow line.
    static func zooRoad(width: Int = 64) -> SKTexture {
        let top = StreetArt.groundTop
        var canvas = PixelCanvas(width: width, height: top)
        // Forest floor at the near edge.
        canvas.fill(x: 0, y: 0, width: width, height: 8, PixelColor(0x3C6C24))
        var generator = SeededGenerator(seed: 31)
        for _ in 0..<20 { canvas.set(Int.random(in: 0..<width, using: &generator), Int.random(in: 0..<8, using: &generator), PixelColor(0x5C4424)) }
        canvas.fill(x: 0, y: 8, width: width, height: 2, PixelColor(0x8C8478))
        // Road.
        canvas.fill(x: 0, y: 10, width: width, height: 27, PixelColor(0x444448))
        canvas.fill(x: 0, y: 22, width: width, height: 1, Palette.yellow)
        canvas.fill(x: 0, y: 24, width: width, height: 1, Palette.yellow)
        canvas.fill(x: 0, y: 36, width: width, height: 1, Palette.white)
        // Park path.
        canvas.fill(x: 0, y: 37, width: width, height: top - 37, PixelColor(0xC8B080))
        for _ in 0..<16 { canvas.set(Int.random(in: 0..<width, using: &generator), Int.random(in: 38..<top, using: &generator), PixelColor(0xA89060)) }
        canvas.fill(x: 0, y: top - 3, width: width, height: 3, Palette.green)
        return canvas.texture()
    }

    // MARK: - Backdrops: downtown

    /// Far-off towers in haze.
    static func skyline(width: Int = 384, height: Int = 100) -> SKTexture {
        var canvas = PixelCanvas(width: width, height: height)
        var generator = SeededGenerator(seed: 7)
        var x = 0
        while x < width {
            let w = Int.random(in: 14...34, using: &generator)
            let h = Int.random(in: 24...(height - 10), using: &generator)
            canvas.fill(x: x, y: 0, width: min(w, width - x), height: h, Palette.farCity)
            if Bool.random(using: &generator) { canvas.fill(x: x + w / 2, y: h, width: 1, height: 6, Palette.farCity) }
            for wy in stride(from: 6, to: h - 4, by: 6) {
                for wx in stride(from: x + 3, to: min(x + w - 2, width), by: 5) where Int.random(in: 0..<4, using: &generator) == 0 {
                    canvas.set(wx, wy, Palette.farCityLight)
                }
            }
            x += w + Int.random(in: 0...6, using: &generator)
        }
        return canvas.texture()
    }

    /// Brick and concrete buildings across the street, with lit windows.
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
            canvas.fill(x: x + w / 2 - 3, y: 0, width: 6, height: 8, Palette.black)
            x += w
        }
        return canvas.texture()
    }

    // MARK: - Backdrops: Skidmore Fountain

    /// The bridge approach overhead: a concrete deck on tall columns.
    static func overpass(width: Int = 384, height: Int = 64) -> SKTexture {
        var canvas = PixelCanvas(width: width, height: height)
        let concrete = PixelColor(0x8C8C98), shade = PixelColor(0x6C6C78)
        // Low enough to show above Old Town's rooftops.
        let deck = 30
        canvas.fill(x: 0, y: deck, width: width, height: 8, concrete)
        canvas.fill(x: 0, y: deck, width: width, height: 2, shade)
        canvas.fill(x: 0, y: deck + 8, width: width, height: 1, Palette.lightGrey)
        for x in stride(from: 0, to: width, by: 6) { canvas.fill(x: x, y: deck + 9, width: 1, height: 3, Palette.grey) }
        canvas.fill(x: 0, y: deck + 12, width: width, height: 1, Palette.grey)
        for x in stride(from: 40, to: width, by: 128) {
            canvas.fill(x: x, y: 0, width: 10, height: deck, concrete)
            canvas.fill(x: x + 8, y: 0, width: 2, height: deck, shade)
            canvas.fill(x: x - 3, y: deck - 4, width: 16, height: 4, concrete)
        }
        return canvas.texture()
    }

    /// Old Town: low brick and cast-iron fronts with tall arched windows, and old lamps.
    static func oldTown(width: Int = 320, height: Int = 30) -> SKTexture {
        var canvas = PixelCanvas(width: width, height: height)
        var generator = SeededGenerator(seed: 13)
        let walls = [PixelColor(0xA84C34), PixelColor(0xE0D0A8), PixelColor(0x6C7C5C), PixelColor(0xB89C6C)]
        var x = 0
        while x < width {
            let w = min(Int.random(in: 36...60, using: &generator), width - x)
            let h = Int.random(in: 20...height, using: &generator)
            let wall = walls[Int.random(in: 0..<walls.count, using: &generator)]
            canvas.fill(x: x, y: 0, width: w, height: h, wall)
            canvas.fill(x: x, y: h - 3, width: w, height: 3, wall.darker(0.7))
            canvas.fill(x: x, y: 0, width: 1, height: h, wall.darker(0.7))
            // Tall arched windows, two floors.
            for wy in stride(from: 4, to: h - 10, by: 12) {
                for wx in stride(from: x + 4, to: x + w - 6, by: 8) {
                    canvas.fill(x: wx, y: wy, width: 4, height: 7, Palette.black)
                    canvas.fill(x: wx + 1, y: wy + 7, width: 2, height: 1, Palette.black)
                    if Int.random(in: 0..<4, using: &generator) == 0 { canvas.fill(x: wx + 1, y: wy + 1, width: 2, height: 5, Palette.window) }
                }
            }
            x += w
        }
        // Old-fashioned street lamps.
        for lampX in stride(from: 24, to: width, by: 80) {
            canvas.fill(x: lampX, y: 0, width: 1, height: 18, Palette.black)
            canvas.fill(x: lampX - 1, y: 18, width: 3, height: 3, Palette.window)
            canvas.fill(x: lampX - 1, y: 21, width: 3, height: 1, Palette.black)
        }
        return canvas.texture()
    }

    // MARK: - Backdrops: Burnside

    /// The underside of the bridge: huge columns and the deck overhead.
    static func bridgeUnderside(width: Int = 256, height: Int = 90) -> SKTexture {
        var canvas = PixelCanvas(width: width, height: height)
        let concrete = PixelColor(0x54545C), dark = PixelColor(0x3C3C44), light = PixelColor(0x6C6C74)
        // The deck and its beams.
        canvas.fill(x: 0, y: 34, width: width, height: height - 34, dark)
        canvas.fill(x: 0, y: 34, width: width, height: 3, light)
        for x in stride(from: 0, to: width, by: 32) { canvas.fill(x: x, y: 37, width: 4, height: height - 37, concrete) }
        // Columns.
        for x in stride(from: 20, to: width, by: 128) {
            canvas.fill(x: x, y: 0, width: 22, height: 34, concrete)
            canvas.fill(x: x + 18, y: 0, width: 4, height: 34, dark)
            canvas.fill(x: x - 4, y: 30, width: 30, height: 4, light)
        }
        return canvas.texture()
    }

    /// Concrete walls with graffiti, and the lip of a bowl.
    static func skateparkWalls(width: Int = 256, height: Int = 28) -> SKTexture {
        var canvas = PixelCanvas(width: width, height: height)
        var generator = SeededGenerator(seed: 17)
        canvas.fill(x: 0, y: 0, width: width, height: 18, PixelColor(0x7C7C84))
        canvas.fill(x: 0, y: 17, width: width, height: 1, Palette.lightGrey)
        let paints = [Palette.yellow, Palette.orange, PixelColor(0x00A8A8), PixelColor(0xF878B8), Palette.green, Palette.white]
        for tagX in stride(from: 6, to: width - 20, by: 30) {
            let paint = paints[Int.random(in: 0..<paints.count, using: &generator)]
            let w = Int.random(in: 12...20, using: &generator)
            for column in 0..<w {
                let h = Int.random(in: 3...8, using: &generator)
                canvas.fill(x: tagX + column, y: 4 + Int.random(in: 0...2, using: &generator), width: 1, height: h, paint)
            }
            canvas.fill(x: tagX, y: 3, width: w, height: 1, paint.darker())
        }
        // A quarter pipe rising at the back.
        for x in 0..<24 {
            let h = 18 + Int(Double(x * x) / 64)
            canvas.fill(x: 200 + x, y: 0, width: 1, height: min(h, height), PixelColor(0x8C8C94))
        }
        canvas.fill(x: 224, y: 0, width: 4, height: height, PixelColor(0x8C8C94))
        canvas.fill(x: 223, y: height - 1, width: 6, height: 1, Palette.lightGrey)
        return canvas.texture()
    }

    // MARK: - Backdrops: North Portland

    /// The St. Johns Bridge's green towers and cables, a rail bridge, and forested hills.
    static func stJohnsBridge(width: Int = 512, height: Int = 84) -> SKTexture {
        var canvas = PixelCanvas(width: width, height: height)
        let green = PixelColor(0x2C7C5C), darkGreen = PixelColor(0x1C5C44), hills = PixelColor(0x4C7C5C)
        // Forested hills along the bottom.
        for x in 0..<width {
            let h = 10 + Int(6 * sin(Double(x) / 40) + 4 * sin(Double(x) / 13))
            canvas.fill(x: x, y: 0, width: 1, height: h, hills)
        }
        // Deck, towers and cables.
        let deckY = 26
        canvas.fill(x: 40, y: deckY, width: 360, height: 3, darkGreen)
        for towerX in [110, 330] {
            canvas.fill(x: towerX, y: 0, width: 8, height: 80, green)
            canvas.fill(x: towerX + 2, y: 36, width: 4, height: 10, PixelColor(0x88B8F8))
            canvas.fill(x: towerX + 2, y: 54, width: 4, height: 10, PixelColor(0x88B8F8))
            canvas.fill(x: towerX + 3, y: 80, width: 2, height: 4, green)
        }
        func cable(from x0: Int, _ y0: Int, to x1: Int, _ y1: Int, sag: Double) {
            for x in min(x0, x1)...max(x0, x1) {
                let t = Double(x - x0) / Double(x1 - x0)
                let y = Double(y0) + (Double(y1 - y0)) * t - sag * 4 * t * (1 - t)
                canvas.set(x, Int(y), darkGreen)
                if (x - x0) % 6 == 0, Int(y) > deckY + 3 { canvas.fill(x: x, y: deckY + 3, width: 1, height: Int(y) - deckY - 3, darkGreen) }
            }
        }
        cable(from: 118, 78, to: 330, 78, sag: 46)
        cable(from: 40, deckY + 3, to: 110, 78, sag: -6)
        cable(from: 338, 78, to: 400, deckY + 3, sag: -6)
        // A rail bridge further along: a rusty truss.
        let rust = PixelColor(0x7C3C1C)
        canvas.fill(x: 420, y: 18, width: 92, height: 2, rust)
        canvas.fill(x: 420, y: 30, width: 92, height: 2, rust)
        for x in stride(from: 420, to: 510, by: 12) {
            for step in 0..<12 { canvas.set(x + step, 20 + step, rust); canvas.set(x + step, 31 - step, rust) }
        }
        for x in stride(from: 430, to: width, by: 40) { canvas.fill(x: x, y: 0, width: 3, height: 18, rust) }
        return canvas.texture()
    }

    /// Food carts and leafy trees.
    static func foodCartsAndTrees(width: Int = 320, height: Int = 36) -> SKTexture {
        var canvas = PixelCanvas(width: width, height: height)
        var generator = SeededGenerator(seed: 19)
        let carts = [PixelColor(0xF8B800), PixelColor(0xD82800), PixelColor(0x00A8A8), PixelColor(0xF878B8), PixelColor(0xFCFCFC), PixelColor(0x00A844)]
        var x = 4
        while x < width - 30 {
            if Int.random(in: 0..<3, using: &generator) == 0 {
                // A tree.
                canvas.fill(x: x + 6, y: 0, width: 3, height: 12, Palette.brown)
                for dy in 0..<16 {
                    let half = Int(8 * sin(Double(dy) / 16 * .pi)) + 1
                    canvas.fill(x: x + 7 - half, y: 10 + dy, width: half * 2, height: 1, dy % 5 == 0 ? Palette.darkGreen : Palette.green)
                }
                x += 18
            } else {
                // A cart: box, serving window, striped awning, wheels.
                let color = carts[Int.random(in: 0..<carts.count, using: &generator)]
                canvas.fill(x: x, y: 2, width: 22, height: 14, color)
                canvas.fill(x: x + 4, y: 7, width: 12, height: 5, Palette.black)
                canvas.fill(x: x + 5, y: 8, width: 2, height: 3, Palette.window)
                for stripe in 0..<24 { canvas.fill(x: x - 1 + stripe, y: 16, width: 1, height: 3, stripe % 4 < 2 ? Palette.white : color.darker()) }
                canvas.fill(x: x + 3, y: 0, width: 4, height: 3, Palette.black)
                canvas.fill(x: x + 15, y: 0, width: 4, height: 3, Palette.black)
                x += 26
            }
            x += Int.random(in: 2...10, using: &generator)
        }
        return canvas.texture()
    }

    // MARK: - Backdrops: waterfront

    /// Downtown across the river, with its bridges.
    static func cityAcrossTheRiver(width: Int = 448, height: Int = 60) -> SKTexture {
        var canvas = PixelCanvas(width: width, height: height)
        var generator = SeededGenerator(seed: 23)
        let towers = [PixelColor(0xA8B8D8), PixelColor(0x8C9CC0), PixelColor(0xC0C8E0)]
        var x = 0
        while x < width {
            let w = Int.random(in: 6...16, using: &generator)
            let h = Int.random(in: 6...44, using: &generator)
            let color = towers[Int.random(in: 0..<towers.count, using: &generator)]
            canvas.fill(x: x, y: 0, width: min(w, width - x), height: h, color)
            for wy in stride(from: 3, to: h - 2, by: 4) where Bool.random(using: &generator) { canvas.set(x + w / 2, wy, color.darker(0.8)) }
            x += w + Int.random(in: 0...3, using: &generator)
        }
        // A lift bridge with two towers, and a steel arch bridge.
        let steel = PixelColor(0x3C4C6C)
        canvas.fill(x: 60, y: 0, width: 110, height: 2, steel)
        for towerX in [80, 146] { canvas.fill(x: towerX, y: 0, width: 4, height: 22, steel) }
        canvas.fill(x: 80, y: 20, width: 70, height: 2, steel)
        canvas.fill(x: 270, y: 4, width: 120, height: 2, steel)
        for archX in 0..<120 {
            let t = Double(archX) / 120
            let y = 4 + Int(18 * 4 * t * (1 - t))
            canvas.set(270 + archX, y, steel)
            if archX % 8 == 0 { canvas.fill(x: 270 + archX, y: 6, width: 1, height: max(0, y - 6), steel) }
        }
        return canvas.texture()
    }

    /// The Willamette: a band of water with ripples.
    static func river(width: Int = 192, height: Int = 12) -> SKTexture {
        var canvas = PixelCanvas(width: width, height: height, fill: PixelColor(0x2C64B8))
        var generator = SeededGenerator(seed: 29)
        canvas.fill(x: 0, y: height - 1, width: width, height: 1, PixelColor(0x5C88D0))
        for _ in 0..<40 {
            let x = Int.random(in: 0..<width - 4, using: &generator)
            let y = Int.random(in: 0..<height - 1, using: &generator)
            canvas.fill(x: x, y: y, width: Int.random(in: 2...5, using: &generator), height: 1, PixelColor(0x88B0E8))
        }
        return canvas.texture()
    }

    // MARK: - Backdrops: Zoo Bomb

    /// Fir-covered ridges falling away downhill.
    static func forestedHills(width: Int = 512, height: Int = 80) -> SKTexture {
        var canvas = PixelCanvas(width: width, height: height)
        let far = PixelColor(0x6C9C8C), near = PixelColor(0x3C6C4C)
        for x in 0..<width {
            // Each ridge slopes down to the right, like the road.
            let ridge = 70 - (x % 256) / 5 + Int(3 * sin(Double(x) / 9))
            canvas.fill(x: x, y: 0, width: 1, height: max(10, ridge), far)
            let lower = 40 - (x % 192) / 6 + Int(2 * sin(Double(x) / 7))
            canvas.fill(x: x, y: 0, width: 1, height: max(6, lower), near)
        }
        var generator = SeededGenerator(seed: 37)
        for _ in 0..<60 {
            let x = Int.random(in: 0..<width, using: &generator)
            let base = max(6, 40 - (x % 192) / 6)
            for dy in 0..<6 { canvas.fill(x: x - (6 - dy) / 2, y: base + dy, width: 6 - dy, height: 1, near) }
        }
        return canvas.texture()
    }

    /// Big firs, and the zoo's fence with a giraffe looking over it.
    static func zooWoods(width: Int = 320, height: Int = 56) -> SKTexture {
        var canvas = PixelCanvas(width: width, height: height)
        var generator = SeededGenerator(seed: 41)
        let fir = PixelColor(0x1C5C34), firLight = PixelColor(0x2C7C44)
        // Fence.
        canvas.fill(x: 0, y: 10, width: width, height: 1, PixelColor(0x8C6C44))
        canvas.fill(x: 0, y: 5, width: width, height: 1, PixelColor(0x8C6C44))
        for x in stride(from: 0, to: width, by: 10) { canvas.fill(x: x, y: 0, width: 2, height: 12, PixelColor(0x6C4C2C)) }
        // A giraffe in its enclosure.
        let giraffe = PixelColor(0xE8B060), spot = PixelColor(0x8C5424)
        canvas.fill(x: 150, y: 6, width: 14, height: 8, giraffe)
        canvas.fill(x: 150, y: 0, width: 2, height: 6, giraffe)
        canvas.fill(x: 161, y: 0, width: 2, height: 6, giraffe)
        canvas.fill(x: 160, y: 14, width: 3, height: 18, giraffe)
        canvas.fill(x: 160, y: 31, width: 6, height: 3, giraffe)
        for (sx, sy) in [(152, 8), (156, 11), (158, 7), (161, 18), (161, 24)] { canvas.set(sx, sy, spot) }
        canvas.set(164, 33, Palette.black)
        // Firs.
        var x = 0
        while x < width {
            if !(140...172).contains(x) {
                let h = Int.random(in: 30...height, using: &generator)
                canvas.fill(x: x + 5, y: 0, width: 2, height: 6, Palette.brown)
                for dy in 0..<(h - 4) {
                    let half = max(1, (h - 4 - dy) / 3)
                    canvas.fill(x: x + 6 - half, y: 4 + dy, width: half * 2, height: 1, dy % 4 == 0 ? firLight : fir)
                }
            }
            x += Int.random(in: 10...20, using: &generator)
        }
        return canvas.texture()
    }
}
