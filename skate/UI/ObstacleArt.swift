//
//  ObstacleArt.swift
//  skate
//
//  Everything on the street: things to grind, things in the way, holes, the
//  city letters and the finish line. Moving things get two frames to walk,
//  pedal or waddle.
//

import SpriteKit

/// How a feature is drawn: one or two frames, and where the picture sits relative
/// to the feature's spot on its lane (holes sink a little into the ground).
struct FeatureLook {
    var frames: [SKTexture]
    var offset: CGPoint = .zero
}

enum FeatureArt {
    static func look(for feature: Feature, seed: Int) -> FeatureLook {
        let width = Int(feature.length)
        let height = Int(feature.height)
        var generator = SeededGenerator(seed: UInt64(seed * 7919 + 17))
        func one(_ canvas: PixelCanvas, x: CGFloat = 0, y: CGFloat = 0) -> FeatureLook {
            FeatureLook(frames: [canvas.texture()], offset: CGPoint(x: x, y: y))
        }
        func two(_ make: (Int) -> PixelCanvas, x: CGFloat = 0) -> FeatureLook {
            FeatureLook(frames: [make(0).texture(), make(1).texture()], offset: CGPoint(x: x, y: 0))
        }

        switch feature.style {
        case .rail: return one(rail(width: width, height: height, post: Palette.grey))
        case .handrail: return one(rail(width: width, height: height, post: PixelColor(0x2C7C5C)))
        case .ledge: return one(ledge(width: width, height: height))
        case .bench: return one(bench(width: width))
        case .curb: return one(curb(width: width, height: height))
        case .fountain: return one(fountain(width: width))
        case .tracks: return one(tracks(width: width))
        case .funbox: return one(funbox(width: width, height: height))
        case .barrier: return one(barrier(width: width, height: height))
        case .cone: return one(cone(width: width, height: height))
        case .planter: return one(planter(width: width, height: height))
        case .pedestrian:
            let person = Person.random(&generator)
            return two({ walker(person, frame: $0, facingLeft: true) }, x: -1)
        case .runner:
            let person = Person.random(&generator)
            return two({ runner(person, frame: $0) })
        case .biker:
            let person = Person.random(&generator)
            return two({ biker(person, frame: $0) })
        case .skater:
            let outfit = Outfit(kind: Bool.random(using: &generator) ? .terry : .sam,
                                shirt: ColorChoice.allCases.randomElement(using: &generator)!,
                                pants: ColorChoice.allCases.randomElement(using: &generator)!,
                                hat: Bool.random(using: &generator) ? ColorChoice.allCases.randomElement(using: &generator) : nil,
                                board: ColorChoice.allCases.randomElement(using: &generator)!)
            return one(CharacterArt.canvasStanding(outfit: outfit), x: -4)
        case .dog: return two({ dog(frame: $0) })
        case .cart: return one(cart())
        case .brokenCar: return one(brokenCar())
        case .car:
            let colors = [PixelColor(0xD82800), PixelColor(0x0058F8), PixelColor(0xF0F0F0), PixelColor(0x00A844), PixelColor(0xF8B800)]
            return one(car(body: colors.randomElement(using: &generator)!))
        case .train: return one(train(width: width))
        case .penguin: return two({ penguin(frame: $0) })
        case .goat: return two({ goat(frame: $0) })
        case .hole: return one(hole(width: width, water: false), y: -4)
        case .waterHole: return one(hole(width: width, water: true), y: -4)
        }
    }

    // MARK: Things to grind

    static func rail(width: Int, height: Int, post: PixelColor) -> PixelCanvas {
        var canvas = PixelCanvas(width: width, height: height)
        var postX = 2
        while postX < width - 2 {
            canvas.fill(x: postX, y: 0, width: 2, height: height - 2, post)
            postX += 30
        }
        canvas.fill(x: width - 4, y: 0, width: 2, height: height - 2, post)
        canvas.fill(x: 0, y: height - 2, width: width, height: 1, Palette.steel)
        canvas.fill(x: 0, y: height - 1, width: width, height: 1, Palette.white)
        return canvas
    }

    static func ledge(width: Int, height: Int) -> PixelCanvas {
        var canvas = PixelCanvas(width: width, height: height, fill: Palette.grey)
        canvas.fill(x: 0, y: height - 2, width: width, height: 2, Palette.lightGrey)
        canvas.fill(x: 0, y: height - 1, width: width, height: 1, Palette.white)
        canvas.fill(x: 0, y: 0, width: width, height: 1, Palette.darkGrey)
        canvas.fill(x: 0, y: 0, width: 1, height: height, Palette.darkGrey)
        canvas.fill(x: width - 1, y: 0, width: 1, height: height, Palette.darkGrey)
        return canvas
    }

    /// A park bench: you grind the seat; the backrest is just for looks.
    static func bench(width: Int) -> PixelCanvas {
        var canvas = PixelCanvas(width: width, height: 17)
        let wood = PixelColor(0x9C6430), dark = PixelColor(0x6C4420), iron = PixelColor(0x2C2C2C)
        for legX in [2, width - 4] {
            canvas.fill(x: legX, y: 0, width: 2, height: 7, iron)
            canvas.fill(x: legX + 1, y: 9, width: 1, height: 8, iron)
        }
        canvas.fill(x: 0, y: 7, width: width, height: 2, wood)
        canvas.fill(x: 0, y: 7, width: width, height: 1, dark)
        canvas.fill(x: 1, y: 12, width: width - 2, height: 2, wood)
        canvas.fill(x: 1, y: 15, width: width - 2, height: 2, wood)
        return canvas
    }

    static func curb(width: Int, height: Int) -> PixelCanvas {
        var canvas = PixelCanvas(width: width, height: height, fill: PixelColor(0xC0C0C0))
        canvas.fill(x: 0, y: height - 1, width: width, height: 1, Palette.white)
        canvas.fill(x: 0, y: 0, width: width, height: 1, Palette.grey)
        for x in stride(from: 0, to: width, by: 24) { canvas.fill(x: x, y: 0, width: 1, height: height, Palette.grey) }
        return canvas
    }

    /// Skidmore Fountain: a stone basin to grind, with the fountain rising in the middle.
    static func fountain(width: Int) -> PixelCanvas {
        var canvas = PixelCanvas(width: width, height: 32)
        let stone = PixelColor(0xB8A888), light = PixelColor(0xD8CCAC), dark = PixelColor(0x8C7C60)
        let bronze = PixelColor(0x5C4C2C), water = PixelColor(0x88C8F8)
        let mid = width / 2
        // The column, bowl and figures, behind the basin's rim.
        canvas.fill(x: mid - 3, y: 12, width: 6, height: 9, stone)
        canvas.fill(x: mid - 8, y: 20, width: 16, height: 2, light)
        canvas.fill(x: mid - 6, y: 19, width: 12, height: 1, dark)
        canvas.fill(x: mid - 2, y: 22, width: 4, height: 7, bronze)
        canvas.fill(x: mid - 1, y: 29, width: 2, height: 3, bronze)
        // Water spilling from the bowl.
        for step in 0..<8 {
            canvas.set(mid - 9 - step / 3, 19 - step, water)
            canvas.set(mid + 8 + step / 3, 19 - step, water)
        }
        // The basin.
        canvas.fill(x: 0, y: 0, width: width, height: 12, stone)
        canvas.fill(x: 0, y: 10, width: width, height: 2, light)
        canvas.fill(x: 0, y: 0, width: width, height: 1, dark)
        for x in stride(from: 6, to: width - 4, by: 12) { canvas.fill(x: x, y: 2, width: 1, height: 7, dark) }
        return canvas
    }

    /// Light rail tracks: ties and two steel rails, low enough to roll over.
    static func tracks(width: Int) -> PixelCanvas {
        var canvas = PixelCanvas(width: width, height: 3)
        for x in stride(from: 0, to: width, by: 6) { canvas.fill(x: x, y: 0, width: 3, height: 1, PixelColor(0x5C3C1C)) }
        canvas.fill(x: 0, y: 1, width: width, height: 1, Palette.grey)
        canvas.fill(x: 0, y: 2, width: width, height: 1, PixelColor(0xD8D8E0))
        return canvas
    }

    /// A box with a ramp at each end and metal coping on top.
    static func funbox(width: Int, height: Int) -> PixelCanvas {
        var canvas = PixelCanvas(width: width, height: height)
        let face = PixelColor(0x8C8C94), ramp = PixelColor(0xA4A4AC)
        let rampLength = 8
        for x in 0..<width {
            let fromEdge = min(x, width - 1 - x)
            let h = fromEdge < rampLength ? max(1, (fromEdge + 1) * height / rampLength) : height
            canvas.fill(x: x, y: 0, width: 1, height: h, fromEdge < rampLength ? ramp : face)
        }
        canvas.fill(x: rampLength, y: height - 1, width: width - rampLength * 2, height: 1, Palette.white)
        canvas.fill(x: rampLength, y: height - 2, width: width - rampLength * 2, height: 1, Palette.steel)
        return canvas
    }

    /// A concrete construction barrier with warning stripes.
    static func barrier(width: Int, height: Int) -> PixelCanvas {
        var canvas = PixelCanvas(width: width, height: height)
        let concrete = PixelColor(0xB8B8B8)
        canvas.fill(x: 0, y: 0, width: width, height: 4, concrete)
        canvas.fill(x: 2, y: 4, width: width - 4, height: height - 4, concrete)
        canvas.fill(x: 2, y: height - 1, width: width - 4, height: 1, Palette.white)
        for x in 2..<(width - 2) {
            for y in 5..<(height - 2) where (x + y) % 8 < 4 { canvas.set(x, y, Palette.orange) }
        }
        canvas.fill(x: 0, y: 0, width: width, height: 1, Palette.grey)
        return canvas
    }

    // MARK: Things in the way

    static func cone(width: Int, height: Int) -> PixelCanvas {
        var canvas = PixelCanvas(width: width, height: height)
        canvas.fill(x: 0, y: 0, width: width, height: 1, Palette.darkGrey)
        for y in 1..<height {
            let half = max(0, Int(Double(width) / 2 * (1 - Double(y - 1) / Double(height))))
            let color = (y == height / 2 || y == height / 2 + 1) ? Palette.white : Palette.orange
            canvas.fill(x: width / 2 - half, y: y, width: half * 2 + 1, height: 1, color)
        }
        return canvas
    }

    static func planter(width: Int, height: Int) -> PixelCanvas {
        var canvas = PixelCanvas(width: width, height: height)
        let boxHeight = height * 2 / 3
        canvas.fill(x: 0, y: 0, width: width, height: boxHeight, Palette.brick)
        canvas.fill(x: 0, y: boxHeight - 1, width: width, height: 1, Palette.lightGrey)
        canvas.fill(x: 0, y: 0, width: width, height: 1, Palette.brickDark)
        var generator = SeededGenerator(seed: UInt64(width * 31 + height))
        for x in 0..<width {
            let top = boxHeight + Int.random(in: 1...(height - boxHeight), using: &generator)
            canvas.fill(x: x, y: boxHeight, width: 1, height: top - boxHeight, Palette.green)
            canvas.set(x, top - 1, x % 3 == 0 ? Palette.darkGreen : Palette.green)
        }
        return canvas
    }

    /// Colors for a passer-by.
    struct Person {
        var skin, hair, shirt, pants: PixelColor

        static func random(_ generator: inout SeededGenerator) -> Person {
            let skins = [Palette.skin, PixelColor(0x9C5C34), PixelColor(0xF0C098), PixelColor(0x6C3C1C)]
            let hairs = [Palette.hair, PixelColor(0x1C1008), PixelColor(0xD8A838), PixelColor(0x8C8C8C), PixelColor(0xA83C14)]
            let shirts = [PixelColor(0xD82800), PixelColor(0x0058F8), PixelColor(0x00A844), PixelColor(0xF8B800), PixelColor(0x8C38C8), PixelColor(0xF0F0F0), PixelColor(0x00A8A8)]
            let pants = [PixelColor(0x24489C), PixelColor(0x2C2C2C), PixelColor(0xC8A870), PixelColor(0x5C5C5C)]
            return Person(skin: skins.randomElement(using: &generator)!, hair: hairs.randomElement(using: &generator)!,
                          shirt: shirts.randomElement(using: &generator)!, pants: pants.randomElement(using: &generator)!)
        }
    }

    /// Someone walking, two frames of their stride.
    static func walker(_ person: Person, frame: Int, facingLeft: Bool) -> PixelCanvas {
        let rows: [String] = [
            "...hhhh...",
            "..hhhhhh..",
            "..hssssh..",
            "..essssh..",
            "..sssssh..",
            "...ssss...",
            "...tttt...",
            "..tttttt..",
            ".stttttts.",
            ".stttttts.",
            ".s.tttt.s.",
            "...tttt...",
            "...pppp...",
            "...pppp...",
        ] + (frame == 0 ? [
            "..pp..pp..",
            "..pp..pp..",
            ".pp....pp.",
            ".pp....pp.",
            ".pp....pp.",
            "pp......pp",
            "pp......pp",
            "nn......nn",
            "nn......nn",
        ] : [
            "...pppp...",
            "...pp.pp..",
            "...pp.pp..",
            "...pp.pp..",
            "...pp.pp..",
            "...pp.pp..",
            "...pp.pp..",
            "..nnn.nn..",
            "..nnn.nn..",
        ])
        let sprite = PixelSprite(rows, colors: [
            "h": person.hair, "s": person.skin, "e": Palette.black, "t": person.shirt, "p": person.pants, "n": Palette.black,
        ])
        var canvas = PixelCanvas(width: sprite.width, height: sprite.height)
        canvas.draw(sprite, x: 0, y: 0, mirrored: !facingLeft)
        return canvas
    }

    /// A jogger in shorts, leaning into it, going your way.
    static func runner(_ person: Person, frame: Int) -> PixelCanvas {
        let rows: [String] = [
            ".....hhhh.",
            "....hhhhhh",
            "....hsssss",
            "....hsssse",
            "....ssssss",
            ".....ssss.",
            "....tttt..",
            "...tttttt.",
            "..stttttts",
            "..s.tttt.s",
            "....tttt..",
            "....pppp..",
            "....pppp..",
        ] + (frame == 0 ? [
            "...pp..pp.",
            "..pp....pp",
            "..ss....ss",
            ".ss......s",
            ".ss.......",
            "ss........",
            "nn........",
            "nn....nn..",
            "......nn..",
        ] : [
            "....pppp..",
            "....pp.pp.",
            "....ss.ss.",
            "....ss.ss.",
            "...ss...ss",
            "...ss...ss",
            "...ss...nn",
            "..nnn.....",
            "..nnn.....",
        ])
        let sprite = PixelSprite(rows, colors: [
            "h": person.hair, "s": person.skin, "e": Palette.black, "t": person.shirt, "p": person.pants, "n": Palette.white,
        ])
        var canvas = PixelCanvas(width: sprite.width, height: 23)
        canvas.draw(sprite, x: 0, y: 23 - sprite.height)
        return canvas
    }

    /// Someone on a bike, going your way.
    static func biker(_ person: Person, frame: Int) -> PixelCanvas {
        var canvas = PixelCanvas(width: 20, height: 20)
        let tire = Palette.black, frameColor = PixelColor(0xD82800)
        for (cx, cy) in [(4, 4), (15, 4)] {
            for angle in stride(from: 0.0, to: 2 * Double.pi, by: 0.2) {
                canvas.set(cx + Int((4 * cos(angle)).rounded()), cy + Int((4 * sin(angle)).rounded()), tire)
            }
            canvas.set(cx, cy, Palette.grey)
        }
        // Frame: from the back wheel to the seat, the pedals and the handlebars.
        for step in 0..<7 { canvas.set(4 + step, 4 + step / 2, frameColor); canvas.set(9 + step, 7 - step / 3 + 1, frameColor) }
        canvas.fill(x: 8, y: 7, width: 1, height: 4, frameColor)
        canvas.fill(x: 14, y: 7, width: 1, height: 4, frameColor)
        canvas.fill(x: 13, y: 11, width: 3, height: 1, Palette.darkGrey)
        canvas.fill(x: 6, y: 11, width: 4, height: 1, Palette.darkGrey)
        // Rider.
        canvas.fill(x: 7, y: 12, width: 5, height: 4, person.shirt)
        canvas.fill(x: 11, y: 12, width: 3, height: 1, person.skin)
        canvas.fill(x: 9, y: 16, width: 4, height: 3, person.skin)
        canvas.fill(x: 9, y: 18, width: 4, height: 2, person.hair)
        canvas.set(12, 17, Palette.black)
        // Legs on the pedals.
        let knee = frame == 0 ? (10, 10) : (9, 8)
        canvas.fill(x: 7, y: 9, width: 3, height: 3, person.pants)
        canvas.fill(x: knee.0, y: knee.1, width: 2, height: 2, person.pants)
        canvas.fill(x: frame == 0 ? 10 : 8, y: frame == 0 ? 6 : 5, width: 2, height: 2, Palette.black)
        return canvas
    }

    /// Angie on a walk, coming toward you.
    static func dog(frame: Int) -> PixelCanvas {
        let sprite = CharacterArt.walkingDog(frame: frame)
        var canvas = PixelCanvas(width: sprite.width, height: sprite.height)
        canvas.draw(sprite, x: 0, y: 0, mirrored: true)
        return canvas
    }

    static func cart() -> PixelCanvas {
        var canvas = PixelCanvas(width: 16, height: 13)
        let wire = PixelColor(0xA8A8B4)
        canvas.fill(x: 3, y: 5, width: 13, height: 1, wire)
        canvas.fill(x: 2, y: 12, width: 14, height: 1, wire)
        for x in stride(from: 3, to: 16, by: 2) { canvas.fill(x: x, y: 5, width: 1, height: 7, wire) }
        for y in stride(from: 7, to: 12, by: 2) { canvas.fill(x: 3, y: y, width: 13, height: 1, wire) }
        canvas.fill(x: 0, y: 12, width: 3, height: 1, Palette.red)
        canvas.fill(x: 3, y: 3, width: 12, height: 1, Palette.grey)
        canvas.fill(x: 3, y: 0, width: 2, height: 2, Palette.black)
        canvas.fill(x: 13, y: 0, width: 2, height: 2, Palette.black)
        canvas.fill(x: 4, y: 2, width: 1, height: 1, Palette.grey)
        canvas.fill(x: 14, y: 2, width: 1, height: 1, Palette.grey)
        return canvas
    }

    /// A car up on the curb with a flat tire, a smashed window and rust.
    static func brokenCar() -> PixelCanvas {
        var canvas = PixelCanvas(width: 40, height: 17)
        let body = PixelColor(0x8C6C4C), rust = PixelColor(0x7C3C1C)
        canvas.fill(x: 0, y: 3, width: 40, height: 7, body)
        canvas.fill(x: 8, y: 10, width: 22, height: 6, body)
        canvas.fill(x: 10, y: 11, width: 8, height: 4, Palette.darkGrey)
        canvas.fill(x: 20, y: 11, width: 8, height: 4, Palette.darkGrey)
        for (x, y) in [(21, 14), (22, 13), (23, 12), (24, 13), (25, 11)] { canvas.set(x, y, Palette.white) }
        for (x, y) in [(3, 5), (4, 6), (15, 4), (33, 7), (34, 6), (27, 5), (6, 8)] { canvas.fill(x: x, y: y, width: 2, height: 1, rust) }
        canvas.fill(x: 4, y: 0, width: 8, height: 2, Palette.black)
        canvas.fill(x: 28, y: 0, width: 7, height: 4, Palette.black)
        canvas.fill(x: 30, y: 1, width: 3, height: 2, Palette.grey)
        canvas.fill(x: 0, y: 9, width: 40, height: 1, body.darker())
        return canvas
    }

    /// A car driving toward you.
    static func car(body: PixelColor) -> PixelCanvas {
        var canvas = PixelCanvas(width: 40, height: 17)
        canvas.fill(x: 0, y: 3, width: 40, height: 7, body)
        canvas.fill(x: 9, y: 10, width: 22, height: 6, body)
        canvas.fill(x: 11, y: 11, width: 8, height: 4, PixelColor(0xA4E4FC))
        canvas.fill(x: 21, y: 11, width: 8, height: 4, PixelColor(0xA4E4FC))
        canvas.fill(x: 0, y: 6, width: 2, height: 2, Palette.window)
        canvas.fill(x: 38, y: 6, width: 2, height: 2, Palette.red)
        canvas.fill(x: 0, y: 9, width: 40, height: 1, body.darker())
        for wheelX in [5, 28] {
            canvas.fill(x: wheelX, y: 0, width: 7, height: 4, Palette.black)
            canvas.fill(x: wheelX + 2, y: 1, width: 3, height: 2, Palette.grey)
        }
        return canvas
    }

    /// A light rail train coming down the tracks.
    static func train(width: Int) -> PixelCanvas {
        var canvas = PixelCanvas(width: width, height: 46)
        let shell = PixelColor(0xE4E4EC), roof = PixelColor(0xA8A8B4), band = PixelColor(0x1C58B8)
        canvas.fill(x: 0, y: 4, width: width, height: 32, shell)
        canvas.fill(x: 0, y: 36, width: width, height: 3, roof)
        canvas.fill(x: 0, y: 12, width: width, height: 4, band)
        canvas.fill(x: 0, y: 16, width: width, height: 1, Palette.yellow)
        // The cab's sloped nose at the front (left), and its headlight.
        for y in 26..<39 { canvas.erase(x: 0, y: y, width: (y - 26) / 2, height: 1) }
        canvas.fill(x: 1, y: 7, width: 3, height: 3, Palette.window)
        canvas.fill(x: 6, y: 20, width: 10, height: 10, Palette.darkGrey)
        // Windows and doors along the side.
        for x in stride(from: 22, to: width - 10, by: 14) {
            canvas.fill(x: x, y: 20, width: 10, height: 10, Palette.black)
            canvas.fill(x: x + 1, y: 27, width: 3, height: 2, PixelColor(0x88B8F8))
        }
        for x in stride(from: 50, to: width - 20, by: 56) {
            canvas.fill(x: x, y: 4, width: 8, height: 26, Palette.grey)
            canvas.fill(x: x + 4, y: 4, width: 1, height: 26, Palette.darkGrey)
        }
        // Bogies and wheels.
        for x in [16, width - 40] { canvas.fill(x: x, y: 0, width: 24, height: 4, Palette.darkGrey) }
        // The pantograph up to the wires.
        let pantographX = width / 2
        for step in 0..<6 { canvas.set(pantographX + step, 39 + step, Palette.black); canvas.set(pantographX + 11 - step, 39 + step, Palette.black) }
        canvas.fill(x: pantographX - 2, y: 45, width: 16, height: 1, Palette.black)
        return canvas
    }

    static func penguin(frame: Int) -> PixelCanvas {
        let rows = [
            "..nnnn..",
            ".nnnnnn.",
            ".nwnnnn.",
            "ynnnnnn.",
            ".wwnnnn.",
            "wwwwnnnn",
            "wwwwnnnn",
            "wwwwnnn.",
            ".wwwnnn.",
            ".wwwnn..",
            frame == 0 ? ".yy..yy." : "..yy.yy.",
        ]
        let sprite = PixelSprite(rows, colors: ["n": Palette.black, "w": Palette.white, "y": Palette.orange])
        var canvas = PixelCanvas(width: sprite.width, height: sprite.height)
        canvas.draw(sprite, x: 0, y: 0)
        return canvas
    }

    static func goat(frame: Int) -> PixelCanvas {
        let rows = [
            ".kk.............",
            "kk.k............",
            ".wwww...........",
            "ewwww...........",
            ".wwwwwwwwwwwwww.",
            "..kwwwwwwwwwwwwk",
            "...wwwwwwwwwwww.",
            "...wwwwwwwwwwww.",
            "....wwwwwwwwww..",
        ] + (frame == 0 ? [
            "....w.w....w.w..",
            "....w.w....w.w..",
            "...w...w..w...w.",
            "...k...k..k...k.",
        ] : [
            "....w.w....w.w..",
            "....w.w....w.w..",
            "....w.w....w.w..",
            "....k.k....k.k..",
        ])
        let sprite = PixelSprite(rows, colors: ["w": PixelColor(0xE8E0D0), "k": PixelColor(0x6C5C44), "e": Palette.black])
        var canvas = PixelCanvas(width: sprite.width, height: sprite.height)
        canvas.draw(sprite, x: 0, y: 0)
        return canvas
    }

    /// A hole in the lane: dark asphalt, or a gap down to the river.
    static func hole(width: Int, water: Bool) -> PixelCanvas {
        var canvas = PixelCanvas(width: width, height: 8)
        let rim = water ? PixelColor(0x6C4424) : PixelColor(0x2C2C2C)
        canvas.fill(x: 1, y: 0, width: width - 2, height: 8, rim)
        canvas.fill(x: 0, y: 1, width: width, height: 6, rim)
        let inside = water ? PixelColor(0x2C64B8) : PixelColor(0x0C0C0C)
        canvas.fill(x: 2, y: 1, width: width - 4, height: 6, inside)
        if water {
            for x in stride(from: 4, to: width - 6, by: 7) { canvas.fill(x: x, y: 3, width: 3, height: 1, PixelColor(0x88B0E8)) }
        } else {
            canvas.fill(x: 2, y: 6, width: width - 4, height: 1, PixelColor(0x1C1C1C))
        }
        return canvas
    }

    static func finishLine(height: Int) -> SKTexture {
        var canvas = PixelCanvas(width: 6, height: height)
        for y in 0..<height {
            for x in 0..<6 { canvas.set(x, y, ((x / 3) + (y / 3)) % 2 == 0 ? Palette.white : Palette.black) }
        }
        return canvas.texture()
    }
}

enum LetterArt {
    /// A round gold token with the letter on it. Letters already found are faded.
    static func token(_ letter: Character, found: Bool) -> SKTexture {
        var canvas = PixelCanvas(width: 11, height: 11)
        let fill = found ? PixelColor(0xFCFCFC, alpha: 110) : Palette.yellow
        let rim = found ? PixelColor(0x7C7C7C, alpha: 110) : Palette.gold
        for y in 0..<11 {
            let inset = [3, 1, 1, 0, 0, 0, 0, 0, 1, 1, 3][y]
            canvas.fill(x: inset, y: y, width: 11 - inset * 2, height: 1, rim)
            if y > 0, y < 10 { canvas.fill(x: inset + 1, y: y, width: 9 - inset * 2, height: 1, fill) }
        }
        PixelFont.draw(String(letter), into: &canvas, x: (11 - PixelFont.width(of: String(letter))) / 2, y: 2,
                       color: found ? PixelColor(0x545454, alpha: 140) : Palette.black)
        return canvas.texture()
    }
}
