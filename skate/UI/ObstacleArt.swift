//
//  ObstacleArt.swift
//  skate
//
//  Everything on the street: things to grind, things in the way, manholes, the
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
            return two({ PeopleArt.walker(person, frame: $0, facingLeft: true) }, x: -4)
        case .runner:
            let person = Person.random(&generator)
            return two({ PeopleArt.runner(person, frame: $0) }, x: -3)
        case .biker:
            let person = Person.random(&generator)
            return two({ PeopleArt.biker(person, frame: $0) }, x: -1)
        case .skater:
            let outfit = Outfit(kind: Bool.random(using: &generator) ? .terry : .sam,
                                shirt: ColorChoice.clothes.randomElement(using: &generator)!,
                                pants: ColorChoice.clothes.randomElement(using: &generator)!,
                                hat: Bool.random(using: &generator) ? ColorChoice.clothes.randomElement(using: &generator) : nil,
                                board: ColorChoice.clothes.randomElement(using: &generator)!)
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
        case .hole: return one(manhole(width: width), y: -CGFloat(manholeHeight / 2))
        case .quarterPipe: return one(quarterPipe(feature))
        case .bubbler: return one(bubbler())
        case .millEnds: return one(millEnds(), y: -2)
        case .zooTrain: return two({ zooTrain(frame: $0) })
        case .miniBike:
            let person = Person.random(&generator)
            return two({ PeopleArt.miniBiker(person, frame: $0) }, x: -1)
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
    /// An open manhole: an iron rim round a dark shaft with a ladder rung, and the cover
    /// slid off to the side. The opening is the hole you fall in; the cover is just lying there.
    static func manhole(width: Int) -> PixelCanvas {
        // Seen at an angle, so a flat oval; the cover is the same disc, lying just behind.
        let height = manholeHeight
        let coverX = width - 2
        var canvas = PixelCanvas(width: coverX + width, height: height + 2)
        let iron = PixelColor(0x5C5C64), ironDark = PixelColor(0x3C3C44), ironLight = PixelColor(0x8C8C94)
        ellipse(&canvas, x: coverX, y: 2, width: width, height: height, ironDark)
        ellipse(&canvas, x: coverX + 1, y: 3, width: width - 2, height: height - 2, iron)
        for gx in stride(from: coverX + 3, to: coverX + width - 3, by: 2) { canvas.set(gx, 3 + (gx / 2) % 2, ironLight) }
        // The opening: dark rim, a lighter iron ring, the shaft and a ladder rung.
        ellipse(&canvas, x: 0, y: 0, width: width, height: height, ironDark)
        ellipse(&canvas, x: 1, y: 1, width: width - 2, height: height - 1, ironLight)
        ellipse(&canvas, x: 2, y: 1, width: width - 4, height: height - 2, PixelColor(0x0C0C0C))
        canvas.fill(x: width / 2 - 2, y: height / 2, width: 4, height: 1, Palette.grey)
        return canvas
    }

    /// How tall a manhole's oval is, in game pixels.
    static let manholeHeight = 5

    /// A concrete quarter pipe facing you, curving up to steel coping at the lip.
    static func quarterPipe(_ feature: Feature) -> PixelCanvas {
        let width = Int(feature.length)
        var canvas = PixelCanvas(width: width + 3, height: Int(feature.height) + 2)
        let concrete = PixelColor(0x9C9CA4), shade = PixelColor(0x7C7C84), face = PixelColor(0xB4B4BC)
        for column in 0..<width {
            let h = Int(feature.rampHeight(at: CGFloat(column) + 0.5, start: 0))
            canvas.fill(x: column, y: 0, width: 1, height: h + 1, concrete)
            // A light riding surface, with a shadow just under it.
            canvas.set(column, h, face)
            if h > 1 { canvas.set(column, h - 1, shade) }
        }
        // The deck behind the lip, and the coping on it.
        canvas.fill(x: width, y: 0, width: 3, height: Int(feature.height) + 1, shade)
        canvas.fill(x: width - 2, y: Int(feature.height) + 1, width: 5, height: 1, Palette.steel)
        return canvas
    }

    /// A Benson Bubbler: a bronze column with four bowls, water bubbling up from each.
    static func bubbler() -> PixelCanvas {
        var canvas = PixelCanvas(width: 10, height: 12)
        let bronze = PixelColor(0x8C6C34), light = PixelColor(0xB8944C), water = PixelColor(0x9CD0F8)
        canvas.fill(x: 2, y: 0, width: 6, height: 2, bronze)
        canvas.fill(x: 4, y: 2, width: 2, height: 6, bronze)
        canvas.fill(x: 3, y: 4, width: 1, height: 2, light)
        canvas.fill(x: 0, y: 8, width: 10, height: 2, bronze)
        canvas.fill(x: 0, y: 9, width: 10, height: 1, light)
        for bowl in [1, 4, 8] { canvas.set(bowl, 10, water) }
        canvas.set(4, 11, water)
        canvas.set(8, 11, water)
        return canvas
    }

    /// Mill Ends Park: a ring of curb the size of a dinner plate, a tiny tree, a tiny sign.
    static func millEnds() -> PixelCanvas {
        var canvas = PixelCanvas(width: 10, height: 9)
        ellipse(&canvas, x: 0, y: 0, width: 10, height: 4, PixelColor(0xA8A8A0))
        ellipse(&canvas, x: 1, y: 1, width: 8, height: 2, PixelColor(0x4C7C2C))
        canvas.fill(x: 4, y: 2, width: 1, height: 3, Palette.brown)
        canvas.fill(x: 3, y: 5, width: 3, height: 3, Palette.green)
        canvas.set(4, 8, Palette.darkGreen)
        canvas.fill(x: 7, y: 2, width: 1, height: 3, Palette.darkGrey)
        canvas.fill(x: 7, y: 5, width: 2, height: 1, Palette.white)
        return canvas
    }

    /// The zoo train: a little green steam engine pulling open cars full of kids.
    static func zooTrain(frame: Int) -> PixelCanvas {
        var canvas = PixelCanvas(width: 56, height: 18)
        let green = PixelColor(0x2C7C3C), red = PixelColor(0xC82818), gold = PixelColor(0xE8B830)
        let wheel = Palette.black
        // The engine, at the front (left, coming toward you).
        canvas.fill(x: 2, y: 4, width: 12, height: 6, green)
        canvas.fill(x: 2, y: 6, width: 12, height: 1, gold)
        canvas.fill(x: 12, y: 4, width: 6, height: 11, green)
        canvas.fill(x: 13, y: 10, width: 4, height: 3, PixelColor(0x88B8F8))
        canvas.fill(x: 11, y: 15, width: 8, height: 1, red)
        canvas.fill(x: 4, y: 10, width: 2, height: 4, Palette.black)
        canvas.fill(x: 3, y: 14, width: 4, height: 1, Palette.black)
        canvas.fill(x: 0, y: 2, width: 3, height: 2, red)
        canvas.set(0, 4, red)
        // A puff of smoke that drifts with the frames.
        canvas.fill(x: 3 + frame, y: 15, width: 3, height: 2, Palette.lightGrey)
        // Two open cars.
        for car in 0..<2 {
            let cx = 20 + car * 18
            canvas.fill(x: cx, y: 4, width: 16, height: 5, red)
            canvas.fill(x: cx, y: 8, width: 16, height: 1, gold)
            for (index, kid) in [cx + 2, cx + 7, cx + 12].enumerated() {
                let colors = [Palette.skin, PixelColor(0x9C5C34), PixelColor(0xF0C098)]
                canvas.fill(x: kid, y: 9, width: 2, height: 2, colors[(index + car) % 3])
                canvas.fill(x: kid, y: 11, width: 2, height: 1, [Palette.hair, Palette.yellow, PixelColor(0x1C1008)][(index + car + frame) % 3])
            }
            canvas.fill(x: cx - 2, y: 4, width: 2, height: 1, Palette.darkGrey)
        }
        for wx in [4, 9, 14, 22, 31, 40, 49] {
            canvas.fill(x: wx, y: 0, width: 3, height: 3, wheel)
            canvas.set(wx + 1, 1, frame == 0 ? Palette.grey : wheel)
        }
        return canvas
    }

    /// A filled ellipse inside the given box.
    private static func ellipse(_ canvas: inout PixelCanvas, x: Int, y: Int, width: Int, height: Int, _ color: PixelColor) {
        let a = Double(width) / 2, b = Double(height) / 2
        for row in 0..<height {
            let dy = (Double(row) + 0.5 - b) / b
            let half = a * (1 - dy * dy).squareRoot()
            let left = Int((a - half).rounded())
            let right = Int((a + half).rounded())
            canvas.fill(x: x + left, y: y + row, width: max(0, right - left), height: 1, color)
        }
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
