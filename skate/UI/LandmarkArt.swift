//
//  LandmarkArt.swift
//  skate
//
//  Portland landmarks for the backdrops, and the city's own street furniture:
//  Portlandia, Pioneer Courthouse Square, the Chinatown gate, Saturday Market,
//  the Burnside Bridge, Paul Bunyan, Cathedral Park, Tilikum Crossing, the
//  Hawthorne Bridge, OMSI and the Blueback, Pittock Mansion, Mount Hood and
//  Mount St. Helens. Each draws into a backdrop strip at an x and says how wide it was.
//

import SpriteKit

enum Landmarks {
    // MARK: Helpers

    static func line(_ canvas: inout PixelCanvas, from: (Int, Int), to: (Int, Int), _ color: PixelColor) {
        let steps = max(abs(to.0 - from.0), abs(to.1 - from.1), 1)
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            canvas.set(from.0 + Int((Double(to.0 - from.0) * t).rounded()),
                       from.1 + Int((Double(to.1 - from.1) * t).rounded()), color)
        }
    }

    /// A mountain: slopes from `left` to `right`, its peak `height` up, snow on the top part.
    static func mountain(_ canvas: inout PixelCanvas, left: Int, right: Int, height: Int, rock: PixelColor,
                         snowLine: Double, flatTop: Int = 0, seed: UInt64) {
        var generator = SeededGenerator(seed: seed)
        let middle = Double(left + right) / 2, half = Double(right - left) / 2
        for x in left..<right {
            let along = 1 - abs(Double(x) - middle) / half
            var top = Int((pow(along, 1.4) * Double(height)).rounded())
            // A blown-out top: cut the peak off, with a dip in the middle.
            if flatTop > 0, top > height - flatTop {
                top = height - flatTop + (abs(Double(x) - middle) < Double(flatTop) ? -1 : 0)
            }
            guard top > 0 else { continue }
            canvas.fill(x: x, y: 0, width: 1, height: top, rock)
            let snowFrom = Int(Double(height) * snowLine) + Int.random(in: -2...2, using: &generator)
            if top > snowFrom { canvas.fill(x: x, y: snowFrom, width: 1, height: top - snowFrom, Palette.white) }
            // Gullies of rock streaking down through the snow.
            if x % 5 == 0, top > snowFrom + 2 { canvas.fill(x: x, y: snowFrom, width: 1, height: (top - snowFrom) / 2, rock.darker(0.85)) }
        }
    }

    // MARK: Downtown

    /// Pioneer Courthouse Square: brick steps, the "you are here" signpost, and the old
    /// courthouse with its cupola behind. Returns its width.
    static func pioneerSquare(_ canvas: inout PixelCanvas, x: Int) -> Int {
        let w = 96
        let cream = PixelColor(0xE8DCC0), trim = PixelColor(0xB8AC90), brick = PixelColor(0xA84C34)
        // The courthouse.
        let courtX = x + 30
        canvas.fill(x: courtX, y: 0, width: 54, height: 24, cream)
        canvas.fill(x: courtX, y: 22, width: 54, height: 2, trim)
        for wx in stride(from: courtX + 3, to: courtX + 52, by: 5) {
            canvas.fill(x: wx, y: 12, width: 2, height: 6, Palette.black)
            canvas.fill(x: wx, y: 3, width: 2, height: 6, Palette.black)
        }
        canvas.fill(x: courtX + 21, y: 24, width: 12, height: 4, cream)
        canvas.fill(x: courtX + 23, y: 28, width: 8, height: 3, PixelColor(0xD0D0D0))
        canvas.fill(x: courtX + 25, y: 31, width: 4, height: 2, PixelColor(0xD0D0D0))
        canvas.fill(x: courtX + 26, y: 33, width: 2, height: 3, Palette.grey)
        // The brick plaza and its steps.
        canvas.fill(x: x, y: 0, width: w, height: 2, brick)
        for step in 0..<5 {
            canvas.fill(x: x, y: step * 2, width: 34 - step * 6, height: 2, brick)
            canvas.fill(x: x, y: step * 2 + 1, width: 34 - step * 6, height: 1, brick.darker(0.8))
        }
        // The signpost, arrows pointing off to sister cities and faraway places.
        let postX = x + 20
        canvas.fill(x: postX, y: 0, width: 1, height: 24, Palette.darkGrey)
        for (index, y) in [9, 12, 15, 18, 21].enumerated() {
            let color = index % 2 == 0 ? Palette.white : PixelColor(0xF8D878)
            if index % 2 == 0 {
                canvas.fill(x: postX + 1, y: y, width: 6, height: 2, color)
                canvas.set(postX + 7, y, color)
            } else {
                canvas.fill(x: postX - 6, y: y, width: 6, height: 2, color)
                canvas.set(postX - 7, y + 1, color)
            }
        }
        return w
    }

    /// The Portland Building: cream walls with little square windows, giant maroon
    /// keystones, a teal base, and Portlandia kneeling over the door with her trident.
    static func portlandBuilding(_ canvas: inout PixelCanvas, x: Int) -> Int {
        let w = 64, h = 40
        let cream = PixelColor(0xE8DCC0), teal = PixelColor(0x3C8C84), maroon = PixelColor(0x8C3C2C), glass = PixelColor(0x2C3C5C)
        canvas.fill(x: x, y: 0, width: w, height: h, cream)
        for wy in stride(from: 10, to: h - 3, by: 4) {
            for wx in stride(from: x + 2, to: x + w - 2, by: 4) { canvas.fill(x: wx, y: wy, width: 2, height: 2, glass) }
        }
        // The big dark window band down the middle, between maroon pilasters, under keystones.
        let middle = x + 36
        canvas.fill(x: middle - 8, y: 8, width: 16, height: 26, glass)
        canvas.fill(x: middle - 12, y: 8, width: 4, height: 24, maroon)
        canvas.fill(x: middle + 8, y: 8, width: 4, height: 24, maroon)
        for row in 0..<4 {
            canvas.fill(x: middle - 13 - row, y: 30 + row, width: 6 + row * 2, height: 1, maroon)
            canvas.fill(x: middle + 7 - row, y: 30 + row, width: 6 + row * 2, height: 1, maroon)
        }
        canvas.fill(x: x, y: 0, width: w, height: 8, teal)
        canvas.fill(x: x, y: h - 2, width: w, height: 2, teal)
        canvas.fill(x: x + 8, y: 0, width: 8, height: 6, glass)
        // Portlandia, hammered copper, kneeling over the door.
        let statue = PixelSprite([
            "...........w.",
            "..........www",
            "...........d.",
            ".....cc....d.",
            ".....cc....d.",
            "....cccc..cd.",
            "...cccccccd..",
            "..c.cccc.....",
            ".c..cccc.....",
            "c...ccccc....",
            "...cccccc....",
            "..ccccdccc...",
            "..ccc..ccc...",
            ".cccc...cc...",
            "cccc....dd...",
        ], colors: ["c": PixelColor(0xB8743C), "d": PixelColor(0x7C4C24), "w": PixelColor(0xD8A060)])
        canvas.fill(x: x + 5, y: 8, width: 16, height: 1, PixelColor(0x9C9C94))
        canvas.draw(statue, x: x + 6, y: 9)
        return w
    }

    // MARK: Old Town

    /// The Old Town Chinatown gate: red pillars, a gold panel, and green tiled roofs
    /// with their eaves turned up. Returns its width.
    static func chinatownGate(_ canvas: inout PixelCanvas, x: Int) -> Int {
        let w = 46
        let red = PixelColor(0xC82818), green = PixelColor(0x2C8C5C), gold = PixelColor(0xE8B830)
        // Outer pillars with their own small roofs.
        for px in [x + 1, x + w - 4] {
            canvas.fill(x: px, y: 0, width: 3, height: 13, red)
            canvas.fill(x: px - 2, y: 13, width: 7, height: 2, green)
            canvas.set(px - 3, 15, green)
            canvas.set(px + 5, 15, green)
        }
        // Main pillars, beams and the panel.
        for px in [x + 9, x + w - 12] { canvas.fill(x: px, y: 0, width: 3, height: 23, red) }
        canvas.fill(x: x + 4, y: 11, width: w - 8, height: 2, red)
        canvas.fill(x: x + 7, y: 21, width: w - 14, height: 2, red)
        canvas.fill(x: x + 17, y: 16, width: w - 34, height: 5, gold)
        canvas.fill(x: x + 18, y: 17, width: w - 36, height: 3, red)
        // The main roof.
        canvas.fill(x: x + 3, y: 23, width: w - 6, height: 3, green)
        canvas.fill(x: x + 6, y: 26, width: w - 12, height: 1, green.darker(0.7))
        canvas.fill(x: x + 2, y: 26, width: 2, height: 1, green)
        canvas.fill(x: x + w - 4, y: 26, width: 2, height: 1, green)
        canvas.set(x + 1, 27, green)
        canvas.set(x + w - 2, 27, green)
        canvas.fill(x: x + 10, y: 27, width: w - 20, height: 1, gold)
        return w
    }

    /// Saturday Market under the bridge: a row of striped canopies over stalls.
    static func saturdayMarket(_ canvas: inout PixelCanvas, x: Int, generator: inout SeededGenerator) -> Int {
        let w = 92
        let canopies = [PixelColor(0xD82800), PixelColor(0x0058F8), PixelColor(0xF8B800), PixelColor(0x00A844), PixelColor(0x8C38C8)]
        let goods = [Palette.white, Palette.yellow, PixelColor(0xF878B8), PixelColor(0x00A8A8), Palette.orange]
        for tent in 0..<4 {
            let tx = x + tent * 23
            let color = canopies[(tent + Int.random(in: 0..<canopies.count, using: &generator)) % canopies.count]
            canvas.fill(x: tx, y: 0, width: 1, height: 10, Palette.grey)
            canvas.fill(x: tx + 20, y: 0, width: 1, height: 10, Palette.grey)
            // A table of things for sale.
            canvas.fill(x: tx + 2, y: 4, width: 17, height: 1, Palette.brown)
            canvas.fill(x: tx + 3, y: 0, width: 1, height: 4, Palette.brown)
            canvas.fill(x: tx + 17, y: 0, width: 1, height: 4, Palette.brown)
            for gx in stride(from: tx + 3, to: tx + 18, by: 2) {
                canvas.set(gx, 5, goods.randomElement(using: &generator)!)
            }
            // A peaked canopy in stripes.
            for row in 0..<6 {
                let inset = row * 2
                for column in (tx - 1 + inset)..<(tx + 22 - inset) {
                    canvas.set(column, 10 + row, (column / 3) % 2 == 0 ? color : Palette.white)
                }
            }
        }
        return w
    }

    // MARK: Burnside Bridge

    /// Through an arch of the bridge: the river, and the bascule span's two towers far off.
    static func burnsideTowers(_ canvas: inout PixelCanvas, left: Int, right: Int, archTop: (Int) -> Int) {
        let dusk = PixelColor(0x4C5C84), water = PixelColor(0x2C4C7C), tower = PixelColor(0x9C8C6C), roof = PixelColor(0x5C5C64)
        for x in left..<right {
            canvas.fill(x: x, y: 0, width: 1, height: archTop(x), dusk)
            canvas.fill(x: x, y: 0, width: 1, height: 6, water)
        }
        let middle = (left + right) / 2
        canvas.fill(x: left, y: 6, width: right - left, height: 2, PixelColor(0x6C6C74))
        for towerX in [middle - 14, middle + 6] {
            canvas.fill(x: towerX, y: 8, width: 8, height: 16, tower)
            for row in 0..<4 { canvas.fill(x: towerX + row, y: 24 + row, width: 8 - row * 2, height: 1, roof) }
            canvas.fill(x: towerX + 2, y: 16, width: 1, height: 3, Palette.window)
            canvas.fill(x: towerX + 5, y: 16, width: 1, height: 3, Palette.window)
            canvas.fill(x: towerX + 3, y: 10, width: 2, height: 3, Palette.black)
        }
    }

    // MARK: North Portland

    /// The gothic arches of the bridge's approach over Cathedral Park.
    static func cathedralArches(_ canvas: inout PixelCanvas, x: Int, count: Int, deckY: Int) {
        let concrete = PixelColor(0x8C948C), shade = PixelColor(0x6C746C)
        let span = 16
        for arch in 0..<count {
            let ax = x + arch * span
            canvas.fill(x: ax, y: 0, width: 3, height: deckY, concrete)
            canvas.fill(x: ax + 2, y: 0, width: 1, height: deckY, shade)
            // A pointed arch: concrete from the arch's curve up to the deck.
            for column in 3..<span {
                let fromMiddle = abs(Double(column) - Double(span + 3) / 2) / (Double(span - 3) / 2)
                let top = Int((Double(deckY - 4) * (1 - fromMiddle * fromMiddle * 0.9)).rounded())
                canvas.fill(x: ax + column, y: top, width: 1, height: max(0, deckY - top), concrete)
            }
        }
        canvas.fill(x: x + count * span, y: 0, width: 3, height: deckY, concrete)
    }

    /// Paul Bunyan in Kenton, thirty-one feet of him, axe at his side. Returns his width.
    static func paulBunyan(_ canvas: inout PixelCanvas, x: Int) -> Int {
        let rows = [
            "......hhhhhh......",
            ".....hhhhhhhh.....",
            ".....hssssssh.....",
            ".....sseesses.....",
            ".....ssssssss.....",
            ".....bbbbbbbb.....",
            ".....bbbmmbbb.....",
            "......bbbbbb......",
            "...rrrrkrrkrrrr...",
            "..rrkrrrrkrrrrkrr.",
            "..rrrrkrrrrkrrrrr.",
            ".rrkrrrrkrrrrkrrr.",
            ".rr.rrkrrrrkrr.rr.",
            ".rr.rrrrkrrrrr.rr.",
            ".rr.rkrrrrkrrr.rr.",
            ".rr.rrrrkrrrrr.rr.",
            ".rr.rrkrrrrkrr.rr.",
            ".ss.rrrrrrrrrr.ss.",
            ".ss.llllllllll.ssa",
            "....pppppppppp...a",
            "....pppppppppp...a",
            "....pppp..pppp...a",
            "....pppp..pppp...a",
            "....pppp..pppp...a",
            "....pppp..pppp...a",
            "....pppp..pppp...a",
            "....pppp..pppp...a",
            "....pppp..pppp..xx",
            "....pppp..pppp..xx",
            "....pppp..pppp..xx",
            "....pppp..pppp....",
            "...nnnnn..nnnnn...",
            "...nnnnn..nnnnn...",
        ]
        let sprite = PixelSprite(rows, colors: [
            "h": PixelColor(0x1C1008), "s": Palette.skin, "e": Palette.black, "b": PixelColor(0x1C1008), "m": PixelColor(0xB84838),
            "r": PixelColor(0xC82818), "k": PixelColor(0x1C1C1C), "l": Palette.brown, "p": PixelColor(0x24489C),
            "n": PixelColor(0x1C1C1C), "a": PixelColor(0x8C5C2C), "x": PixelColor(0xA8A8B0),
        ])
        let w = sprite.width + 4
        // His pedestal.
        canvas.fill(x: x, y: 0, width: w, height: 4, PixelColor(0x9C9C94))
        canvas.fill(x: x, y: 3, width: w, height: 1, PixelColor(0xBCBCB4))
        canvas.draw(sprite, x: x + 2, y: 4)
        return w
    }

    // MARK: Waterfront

    /// Tilikum Crossing: two white pylons with cables fanning down to the deck.
    static func tilikum(_ canvas: inout PixelCanvas, x: Int) {
        let white = PixelColor(0xE8E8F0), cable = PixelColor(0xC8C8D8)
        canvas.fill(x: x, y: 4, width: 92, height: 2, white)
        for pylon in [x + 26, x + 66] {
            for row in 0..<36 { canvas.fill(x: pylon - (row < 10 ? 1 : 0), y: row, width: row < 10 ? 3 : 2, height: 1, white) }
            for step in 1...5 {
                line(&canvas, from: (pylon, 35 - step * 3), to: (pylon - step * 5, 6), cable)
                line(&canvas, from: (pylon + 1, 35 - step * 3), to: (pylon + 1 + step * 5, 6), cable)
            }
        }
    }

    /// The Hawthorne Bridge: green truss towers with the lift span between them.
    static func hawthorne(_ canvas: inout PixelCanvas, x: Int) {
        let green = PixelColor(0x2C6C4C), red = PixelColor(0x9C3C2C)
        canvas.fill(x: x, y: 0, width: 110, height: 2, green)
        canvas.fill(x: x, y: 2, width: 110, height: 1, red)
        for towerX in [x + 20, x + 84] {
            canvas.fill(x: towerX, y: 0, width: 6, height: 26, green)
            for y in stride(from: 2, to: 24, by: 4) {
                line(&canvas, from: (towerX, y), to: (towerX + 5, y + 3), PixelColor(0x78A8F0))
            }
            canvas.fill(x: towerX - 1, y: 26, width: 8, height: 2, green)
            canvas.fill(x: towerX + 2, y: 28, width: 2, height: 2, red)
        }
        canvas.fill(x: x + 20, y: 20, width: 70, height: 2, green)
        for truss in stride(from: x + 26, to: x + 84, by: 6) { line(&canvas, from: (truss, 3), to: (truss + 6, 8), green) }
        canvas.fill(x: x + 26, y: 8, width: 58, height: 1, green)
    }

    /// OMSI on the far bank: a long brick building with its tall smokestack.
    static func omsi(_ canvas: inout PixelCanvas, x: Int) {
        let brick = PixelColor(0xA8543C), glass = PixelColor(0x88B0D8)
        canvas.fill(x: x, y: 0, width: 40, height: 11, brick)
        for wx in stride(from: x + 2, to: x + 38, by: 4) { canvas.fill(x: wx, y: 5, width: 2, height: 3, glass) }
        canvas.fill(x: x + 14, y: 11, width: 10, height: 4, glass)
        canvas.fill(x: x + 30, y: 0, width: 4, height: 34, brick)
        canvas.fill(x: x + 30, y: 32, width: 4, height: 2, brick.darker(0.7))
    }

    /// The USS Blueback, moored by OMSI: hull low in the water, sail standing up.
    static func blueback(_ canvas: inout PixelCanvas, x: Int, waterline: Int) {
        let hull = PixelColor(0x3C4048), light = PixelColor(0x5C6068)
        for column in 0..<54 {
            let along = Double(column) / 53
            let h = Int((3.5 * (1 - pow(2 * along - 1, 6))).rounded())
            guard h > 0 else { continue }
            canvas.fill(x: x + column, y: waterline, width: 1, height: h, hull)
            canvas.set(x + column, waterline + h - 1, light)
        }
        canvas.fill(x: x + 16, y: waterline + 3, width: 8, height: 6, hull)
        canvas.fill(x: x + 16, y: waterline + 8, width: 8, height: 1, light)
        canvas.fill(x: x + 14, y: waterline + 6, width: 12, height: 1, hull)
        canvas.fill(x: x + 19, y: waterline + 9, width: 1, height: 2, light)
    }

    // MARK: Zoo Bomb

    /// Pittock Mansion up on the ridge: stone walls, steep slate roofs and chimneys.
    static func pittock(_ canvas: inout PixelCanvas, x: Int, y: Int) {
        let stone = PixelColor(0xD8C8A8), slate = PixelColor(0x5C6470)
        canvas.fill(x: x, y: y, width: 24, height: 8, stone)
        for wx in stride(from: x + 2, to: x + 22, by: 4) { canvas.fill(x: wx, y: y + 2, width: 2, height: 3, Palette.black) }
        for row in 0..<5 { canvas.fill(x: x + row, y: y + 8 + row, width: 24 - row * 2, height: 1, slate) }
        // The tower in the middle, with its pointed roof.
        canvas.fill(x: x + 9, y: y + 8, width: 6, height: 8, stone)
        for row in 0..<4 { canvas.fill(x: x + 9 + row, y: y + 16 + row, width: 6 - row * 2, height: 1, slate) }
        canvas.fill(x: x + 3, y: y + 12, width: 2, height: 4, stone)
        canvas.fill(x: x + 19, y: y + 12, width: 2, height: 4, stone)
    }
}
