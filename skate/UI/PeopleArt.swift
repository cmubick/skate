//
//  PeopleArt.swift
//  skate
//
//  Everyone else on the street: walkers, joggers and people on bikes. They're
//  drawn in the same blocky style and at the same size as the skaters (the same
//  heads, the same 18-pixel-wide templates), just a couple of pixels taller,
//  so a grown-up's head lines up with a kid's on a board.
//
//  Template letters are the skaters' (see CharacterArt), and face right.
//

import SpriteKit

/// Colors and hair for a passer-by.
struct Person {
    var skin, hair, shirt, pants, shoes: PixelColor
    var hat: PixelColor?
    var longHair: Bool

    static func random(_ generator: inout SeededGenerator) -> Person {
        let skins = [Palette.skin, PixelColor(0x9C5C34), PixelColor(0xF0C098), PixelColor(0x6C3C1C)]
        let hairs = [Palette.hair, PixelColor(0x1C1008), PixelColor(0xD8A838), PixelColor(0x8C8C8C), PixelColor(0xA83C14)]
        let shirts = [PixelColor(0xD82800), PixelColor(0x0058F8), PixelColor(0x00A844), PixelColor(0xF8B800),
                      PixelColor(0x8C38C8), PixelColor(0xF0F0F0), PixelColor(0x00A8A8)]
        let pants = [PixelColor(0x24489C), PixelColor(0x2C2C2C), PixelColor(0xC8A870), PixelColor(0x5C5C5C)]
        let hats = [PixelColor(0xD82800), PixelColor(0x0058F8), PixelColor(0x2C2C2C), PixelColor(0x00A844)]
        return Person(skin: skins.randomElement(using: &generator)!,
                      hair: hairs.randomElement(using: &generator)!,
                      shirt: shirts.randomElement(using: &generator)!,
                      pants: pants.randomElement(using: &generator)!,
                      shoes: Palette.black,
                      hat: Int.random(in: 0..<3, using: &generator) == 0 ? hats.randomElement(using: &generator)! : nil,
                      longHair: Bool.random(using: &generator))
    }

    var colors: [Character: PixelColor] {
        var colors: [Character: PixelColor] = [
            "s": skin, "h": hair, "o": skin.darker(0.5), "e": Palette.black,
            "t": shirt, "l": shirt, "p": pants, "q": pants.darker(), "n": shoes, "w": Palette.white,
        ]
        if let hat {
            colors["c"] = hat
            colors["k"] = hat.darker()
        } else {
            colors["c"] = hair
        }
        return colors
    }

    var head: [String] { longHair ? CharacterArt.samHead : CharacterArt.terryHead }
}

enum PeopleArt {
    /// Someone walking, two frames of their stride. Head plus body: 21 pixels tall.
    static func walker(_ person: Person, frame: Int, facingLeft: Bool) -> PixelCanvas {
        let body = frame == 0 ? walkStride : walkPassing
        let sprite = PixelSprite(person.head + body, colors: person.colors)
        var canvas = PixelCanvas(width: sprite.width, height: sprite.height)
        canvas.draw(sprite, x: 0, y: 0, mirrored: facingLeft)
        return canvas
    }

    /// A jogger in shorts, arms pumping, going your way.
    static func runner(_ person: Person, frame: Int) -> PixelCanvas {
        var runner = person
        runner.shoes = PixelColor(0xF0F0F0)
        let body = frame == 0 ? runStride : runPassing
        // Shorts: the legs below the hem are skin.
        let sprite = PixelSprite(person.head + body, colors: runner.colors.merging(["w": PixelColor(0x8C8C8C)]) { $1 })
        var canvas = PixelCanvas(width: sprite.width, height: sprite.height)
        canvas.draw(sprite, x: 0, y: 0)
        return canvas
    }

    /// Someone on a bike, going your way. 24 x 22: the bike, then a rider the size of a skater.
    static let bikeSize = (width: 24, height: 22)

    static func biker(_ person: Person, frame: Int) -> PixelCanvas {
        var canvas = PixelCanvas(width: bikeSize.width, height: bikeSize.height)
        let tire = Palette.black, frameColor = PixelColor(0xD82800), metal = Palette.darkGrey
        // Wheels.
        for (cx, cy) in [(4, 4), (19, 4)] {
            for angle in stride(from: 0.0, to: 2 * Double.pi, by: 0.15) {
                canvas.set(cx + Int((4 * cos(angle)).rounded()), cy + Int((4 * sin(angle)).rounded()), tire)
            }
            canvas.set(cx, cy, Palette.grey)
        }
        // Frame: rear axle, crank, seat, handlebars, front axle.
        let rear = (4, 4), crank = (12, 4), seat = (8, 7), head = (17, 9), front = (19, 4)
        line(&canvas, rear, crank, frameColor)
        line(&canvas, rear, seat, frameColor)
        line(&canvas, seat, crank, frameColor)
        line(&canvas, seat, head, frameColor)
        line(&canvas, head, crank, frameColor)
        line(&canvas, head, front, frameColor)
        canvas.fill(x: 17, y: 10, width: 3, height: 1, metal)
        canvas.fill(x: 6, y: 7, width: 4, height: 1, metal)
        // The rider, sitting on the seat with their hands on the bars.
        let sprite = PixelSprite(person.head + (frame == 0 ? pedalDown : pedalUp), colors: person.colors)
        canvas.draw(sprite, x: 1, y: 3)
        return canvas
    }

    private static func line(_ canvas: inout PixelCanvas, _ from: (Int, Int), _ to: (Int, Int), _ color: PixelColor) {
        let steps = max(abs(to.0 - from.0), abs(to.1 - from.1), 1)
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            canvas.set(from.0 + Int((Double(to.0 - from.0) * t).rounded()),
                       from.1 + Int((Double(to.1 - from.1) * t).rounded()), color)
        }
    }

    // MARK: Bodies (12 rows standing, 10 on a bike), all 18 wide

    private static let walkStride = [
        ".....tttttttt.....",
        "...tttttttttttt...",
        "..s.tttttttttt.s..",
        "..s.tttttttttt.s..",
        ".....tttttttt.....",
        ".....pppppppp.....",
        "....pppppppppp....",
        "....pppp..pppp....",
        "...pppp....pppp...",
        "..pppp......pppp..",
        "..nnnn......nnnn..",
        "..wwww......wwww..",
    ]

    private static let walkPassing = [
        ".....tttttttt.....",
        "...tttttttttttt...",
        "...stttttttttts...",
        "...stttttttttts...",
        ".....tttttttt.....",
        ".....pppppppp.....",
        ".....ppppqppp.....",
        "......pppppp......",
        "......ppqppp......",
        "......pppppp......",
        ".....nnnnnnnn.....",
        ".....wwwwwwww.....",
    ]

    private static let runStride = [
        ".....tttttttt.....",
        "..stttttttttttt...",
        "..s.tttttttttt.ss.",
        "....tttttttttt..s.",
        ".....tttttttt.....",
        ".....pppppppp.....",
        "....pppppppppp....",
        "....sss....sss....",
        "...sss......sss...",
        "..sss........sss..",
        ".nnnn.........nnnn",
        ".wwww.........wwww",
    ]

    private static let runPassing = [
        ".....tttttttt.....",
        "...tttttttttttss..",
        "..sstttttttttt.s..",
        "..s.tttttttttt....",
        ".....tttttttt.....",
        ".....pppppppp.....",
        ".....pppppppp.....",
        "......sss.sss.....",
        "......sss.sss.....",
        ".....sss...sss....",
        "....nnnn...nnnn...",
        "....wwww...wwww...",
    ]

    /// Near foot forward, far foot back (the far leg is in shadow).
    private static let pedalDown = [
        ".....tttttttt.....",
        "...tttttttttttss..",
        "....tttttttttt..s.",
        ".....tttttttt.....",
        ".....pppppppppp...",
        "..........qq.pp...",
        ".........qq..pp...",
        ".........qq..pp...",
        "........nnn..nnn..",
        "..................",
    ]

    /// Near foot up, far foot down.
    private static let pedalUp = [
        ".....tttttttt.....",
        "...tttttttttttss..",
        "....tttttttttt..s.",
        ".....tttttttt.....",
        ".....ppppppppppp..",
        "..........qq.pp...",
        "..........qnnn....",
        "...........qq.....",
        "...........qq.....",
        "..........nnn.....",
    ]

    /// Every template, for checking they're all the same width.
    static var allTemplates: [[String]] {
        [walkStride, walkPassing, runStride, runPassing, pedalDown, pedalUp]
    }
}
