//
//  CharacterArt.swift
//  skate
//
//  Pat, Sammy and Angie, drawn from little pixel templates. Some letters in the
//  templates stand for outfit colors (shirt, pants, hat, board), so one set of
//  drawings makes every outfit.
//
//  Template letters:
//    c hat   k hat brim (left out with no hat)   h hair   s skin   o outline   e eye
//    t shirt (Angie's bandana)   l print on the shirt   p pants   q pants in shadow
//    n shoes, or Angie's black fur   m Angie's grey fur   w soles, or a bright eye
//    r tongue
//

import SpriteKit

/// Every texture for one skater in one outfit.
struct SkaterLook {
    let roll: SKTexture
    let crouch: SKTexture
    let air: SKTexture
    let grab: SKTexture
    let bail: SKTexture
    let boardSide: SKTexture
    let boardWheelsUp: SKTexture
    let boardUnderside: SKTexture
    let boardGrip: SKTexture
    /// Boardsliding: arms out for balance (two frames, wobbling), and the board
    /// turned across the rail, seen end-on with its near wheels hanging down.
    let slide: [SKTexture]
    let boardEndOn: SKTexture
    /// One picture of them standing on their board, for menus.
    let standing: SKTexture
    /// The board seen a little from above, turned through a full circle in
    /// `CharacterArt.spinSteps` steps: grip tape up, then graphic up (wheels showing).
    let spinGripUp: [SKTexture]
    let spinGraphicUp: [SKTexture]

    init(outfit: Outfit) {
        let poses = CharacterArt.poses(for: outfit)
        let board = CharacterArt.board(for: outfit)
        roll = poses.roll.texture()
        crouch = poses.crouch.texture()
        air = poses.air.texture()
        grab = poses.grab.texture()
        bail = poses.bail.texture()
        boardSide = board.side.texture()
        boardWheelsUp = board.wheelsUp.texture()
        boardUnderside = board.underside.texture()
        boardGrip = board.grip.texture()
        slide = poses.slide.map { $0.texture() }
        boardEndOn = board.endOn.texture()
        standing = CharacterArt.standing(outfit: outfit)
        spinGripUp = (0..<CharacterArt.spinSteps).map { CharacterArt.spin(for: outfit, step: $0, graphicUp: false).texture() }
        spinGraphicUp = (0..<CharacterArt.spinSteps).map { CharacterArt.spin(for: outfit, step: $0, graphicUp: true).texture() }
    }
}

enum CharacterArt {
    struct Poses {
        var roll, crouch, air, grab, bail: PixelSprite
        /// Two frames of balancing on a boardslide.
        var slide: [PixelSprite]
    }

    struct Board {
        var side, wheelsUp, underside, grip: PixelSprite
        /// Turned 90 degrees, across a rail: short, with the near truck's wheels either side.
        var endOn: PixelSprite
    }

    // MARK: Colors

    static func colors(for outfit: Outfit) -> [Character: PixelColor] {
        let shirt = PixelColor(outfit.shirt)
        var colors: [Character: PixelColor] = [
            "e": Palette.black, "t": shirt, "l": outfit.shirt.isLight ? Palette.black : Palette.white,
            "p": PixelColor(outfit.pants), "q": PixelColor(outfit.pants).darker(),
            "n": PixelColor(0x1C1C1C), "w": Palette.white, "m": PixelColor(0x8C8C8C), "r": PixelColor(0xF878A0),
        ]
        switch outfit.kind {
        case .pat:
            colors["s"] = Palette.skin
            colors["h"] = Palette.hair
            colors["o"] = Palette.outline
        case .sammy:
            colors["s"] = PixelColor(0x9C5C34)
            colors["h"] = PixelColor(0x1C1008)
            colors["o"] = PixelColor(0x4C2410)
        case .angie:
            break
        }
        if let hat = outfit.hat {
            colors["c"] = PixelColor(hat)
            colors["k"] = PixelColor(hat).darker()
        } else if !outfit.kind.isDog {
            // No hat: the top of the head is hair, and there's no brim.
            colors["c"] = colors["h"]
        }
        return colors
    }

    // MARK: Kids

    static let patHead = [
        "......cccccc......",
        ".....cccccccc.....",
        "..kkkccccccccc....",
        "....ohhhsssss.....",
        "....ohhssssess....",
        "....ohsossssss....",
        "....ossssssos.....",
        ".....sssssss......",
        ".......sss........",
    ]

    /// Sammy has longer hair, down to the collar at the back.
    static let sammyHead = [
        "......cccccc......",
        ".....cccccccc.....",
        "..kkkccccccccc....",
        "...hhhhhhssss.....",
        "...hhhhhssssess...",
        "...hhhhhossssss...",
        "...hhhhsssssos....",
        "....hhhssssss.....",
        ".......sss........",
    ]

    private static let kidRoll = [
        ".....tttttttt.....",
        "...tttttttttttt...",
        "..s.tttllttttt.s..",
        ".....tttttttt.....",
        ".....pppppppp.....",
        ".....ppppqppp.....",
        "....pppp..pppp....",
        "....ppp....ppp....",
        "...nnnn....nnnn...",
        "...wwww....wwww...",
    ]

    private static let kidCrouch = [
        ".....tttttttt.....",
        "...tttttttttttt...",
        "..s.tttllttttt.s..",
        ".....pppppppp.....",
        "....ppppppppqp....",
        "...ppp......ppp...",
        "..nnnn......nnnn..",
        "..wwww......wwww..",
    ]

    private static let kidAir = [
        ".s...tttttttt...s.",
        ".stttttttttttttts.",
        ".....tttllttt.....",
        ".....tttttttt.....",
        ".....pppppppp.....",
        "....ppppppppqp....",
        "...pppp....pppp...",
        "...nnnn....nnnn...",
        "...wwww....wwww...",
    ]

    private static let kidGrab = [
        ".s...tttttttt.....",
        ".sttttttttttttt...",
        ".....tttllttttt...",
        ".....tttttttt.s...",
        ".....pppppppp.s...",
        "....ppppppppqps...",
        "...pppp....pppps..",
        "...nnnn....nnnns..",
        "...wwww....wwww...",
    ]

    /// Boardsliding: knees out, feet together on the turned board, arms out level.
    private static let kidSlideLevel = [
        "ss...tttttttt...ss",
        ".sssttttttttttsss.",
        ".....tttllttt.....",
        ".....tttttttt.....",
        ".....pppppppp.....",
        "....ppppqppppp....",
        "....ppp....ppp....",
        ".....nnnnnnnn.....",
        ".....wwwwwwww.....",
    ]

    /// The wobble: the back arm up, the front one down.
    private static let kidSlideTilt = [
        "ss...tttttttt.....",
        ".sssttttttttttsss.",
        ".....tttllttt...ss",
        ".....tttttttt.....",
        ".....pppppppp.....",
        "....ppppqppppp....",
        "....ppp....ppp....",
        ".....nnnnnnnn.....",
        ".....wwwwwwww.....",
    ]

    private static let kidBail = [
        "...........kcccc..",
        "..........cccccccc",
        "nnppppppttttohssss",
        "nnppppppttttohsses",
        "wwpp..ppttttosssss",
        ".......ss..s.ssss.",
    ]

    // MARK: Angie

    /// A black and grey doodle with curly fur, riding with her head up front.
    private static let dogTop = [
        "...........ccc....",
        ".........kkcccc...",
        "..........nnmnnn..",
        ".........mnnnnwnn.",
        "m........mnnnnnnnn",
        "nm.......mnnnnnrr.",
        ".nm......ttttttt..",
        "..nnmnnnnnttttnn..",
        "..nmnnnmnnnnnmnn..",
        "..nnnnmnnnnmnnnn..",
        "...nnmnnnmnnnnn...",
    ]

    private static let dogLegs = ["...nn.nn...nn.nn.."]
    private static let dogPaws = ["...mm.mm...mm.mm.."]

    private static let dogBail = [
        "...mm.mm...mm.mm..",
        "...nn.nn...nn.nn..",
        "..nnnnmnnnnmnnnn..",
        "m.nmnnnmnnnnnmnnnn",
        "nnnnmnnnnnttttnnwn",
        "..........ccc.kk..",
    ]

    static func poses(for outfit: Outfit) -> Poses {
        let colors = colors(for: outfit)
        func sprite(_ rows: [String]) -> PixelSprite { PixelSprite(rows, colors: colors) }
        switch outfit.kind {
        case .pat, .sammy:
            let head = outfit.kind == .sammy ? sammyHead : patHead
            return Poses(roll: sprite(head + kidRoll), crouch: sprite(head + kidCrouch), air: sprite(head + kidAir),
                         grab: sprite(head + kidGrab), bail: sprite(kidBail),
                         slide: [sprite(head + kidSlideLevel), sprite(head + kidSlideTilt)])
        case .angie:
            let standing = sprite(dogTop + dogLegs + dogPaws)
            let tucked = sprite(dogTop + dogPaws)
            return Poses(roll: standing, crouch: tucked, air: tucked, grab: tucked, bail: sprite(dogBail),
                         slide: [tucked, standing])
        }
    }

    /// Angie on foot, without her board: two frames of a walk.
    static func walkingDog(frame: Int) -> PixelSprite {
        let outfit = Outfit(kind: .angie, shirt: .red, pants: .khaki, hat: nil, board: .brown)
        let legs = frame == 0 ? dogLegs + dogPaws : ["..nn..nn..nn..nn..", "..mm..mm..mm..mm.."]
        return PixelSprite(dogTop + legs, colors: colors(for: outfit))
    }

    /// Every template, for checking they're all the same width.
    static var allTemplates: [[String]] {
        [patHead, sammyHead, kidRoll, kidCrouch, kidAir, kidGrab, kidBail, kidSlideLevel, kidSlideTilt,
         dogTop, dogLegs, dogPaws, dogBail]
    }

    // MARK: Boards

    static func board(for outfit: Outfit) -> Board {
        let deck = PixelColor(outfit.board)
        var colors: [Character: PixelColor] = [
            "d": deck, "o": deck, "y": outfit.board.isLight ? Palette.black : Palette.yellow,
            "m": Palette.grey, "w": Palette.white, "k": Palette.darkGrey,
        ]
        // The PDX carpet: little orange, purple and blue shapes scattered on teal.
        let carpet = outfit.board == .pdx
        if carpet {
            colors["a"] = PixelColor(0xE86838)
            colors["b"] = PixelColor(0x7C48B8)
            colors["c"] = PixelColor(0x68C0F0)
        }
        let underside = carpet ? [
            ".oooooooooooooooooo.",
            "oaooocoobooaoocooboo",
            "ooboooaoocooboooaoco",
            "ocooboooaoocooboooao",
            ".oooooooooooooooooo.",
        ] : [
            ".oooooooooooooooooo.",
            "oyyyoooooyyoooooyyyo",
            "oyyyooooyyyyooooyyyo",
            "oyyyoooooyyoooooyyyo",
            ".oooooooooooooooooo.",
        ]
        return Board(
            side: PixelSprite([
                "dd................dd",
                ".dddddddddddddddddd.",
                "...mmm........mmm...",
                "...ww..........ww...",
            ], colors: colors),
            wheelsUp: PixelSprite([
                "...ww..........ww...",
                "...mmm........mmm...",
                ".dddddddddddddddddd.",
                "dd................dd",
            ], colors: colors),
            underside: PixelSprite(underside, colors: colors),
            grip: PixelSprite([
                ".kkkkkkkkkkkkkkkkkk.",
                "kkkkkkkkkkkkkkkkkkkk",
                "kkkkkkkkkkkkkkkkkkkk",
                "kkkkkkkkkkkkkkkkkkkk",
                ".kkkkkkkkkkkkkkkkkk.",
            ], colors: colors),
            // Wider than the feet, so its curled-up edges show either side of the shoes.
            endOn: PixelSprite([
                "dk..........kd",
                ".dkkkkkkkkkkd.",
                "..dddddddddd..",
                ".....mmmm.....",
                "...www..www...",
            ], colors: colors)
        )
    }

    /// How many pictures make a full turn of a spinning board.
    static let spinSteps = 16

    /// The board spinning flat, as if seen from a little above: a long thin board side-on,
    /// a short fat one end-on, and everything between. `step` 0 is side-on, nose right.
    static func spin(for outfit: Outfit, step: Int, graphicUp: Bool) -> PixelCanvas {
        let width = 22, height = 12
        let length = 20.0, deckWidth = 6.0, squash = 0.45
        let angle = Double(step) / Double(spinSteps) * 2 * Double.pi
        let deck = PixelColor(outfit.board)
        let edge = deck.darker()
        let top = graphicUp ? deck : PixelColor(0x2C2C2C)
        let stripe = outfit.board.isLight ? Palette.black : Palette.yellow
        var canvas = PixelCanvas(width: width, height: height)
        let center = (x: Double(width) / 2, y: 6.0)

        /// Where a canvas pixel lands on the board: along it, and across it.
        func boardPoint(_ px: Int, _ py: Int, lift: Double) -> (u: Double, v: Double) {
            let dx = Double(px) + 0.5 - center.x
            let dy = (Double(py) + 0.5 - center.y - lift) / squash
            return (dx * cos(angle) + dy * sin(angle), -dx * sin(angle) + dy * cos(angle))
        }
        func inside(_ u: Double, _ v: Double, inset: Double = 0) -> Bool {
            let half = length / 2 - inset, side = deckWidth / 2 - inset
            let straight = half - side
            if abs(u) <= straight { return abs(v) <= side }
            let du = abs(u) - straight
            return du * du + v * v <= side * side
        }
        // The deck's edge, a pixel thick, then the top surface on it.
        for py in 0..<height {
            for px in 0..<width {
                let below = boardPoint(px, py, lift: 0)
                let onTop = boardPoint(px, py, lift: 1)
                if inside(onTop.u, onTop.v) {
                    let rim = !inside(onTop.u, onTop.v, inset: 0.9)
                    var color = rim ? deck : top
                    if graphicUp, !rim {
                        if outfit.board == .pdx {
                            // The carpet's little shapes, scattered across the deck.
                            let cell = (Int((onTop.u + 20).rounded()) * 3 + Int((onTop.v + 10).rounded()) * 5) % 9
                            if cell == 0 { color = PixelColor(0xE86838) }
                            if cell == 4 { color = PixelColor(0x7C48B8) }
                            if cell == 7 { color = PixelColor(0x68C0F0) }
                        } else if abs(onTop.u) < 1.2 {
                            color = stripe
                        }
                    }
                    canvas.set(px, py, color)
                } else if inside(below.u, below.v) {
                    canvas.set(px, py, edge)
                }
            }
        }
        // Graphic up means wheels up: four of them over the trucks.
        if graphicUp {
            for (u, v) in [(-6.0, -2.5), (-6.0, 2.5), (6.0, -2.5), (6.0, 2.5)] {
                let dx = u * cos(angle) - v * sin(angle)
                let dy = (u * sin(angle) + v * cos(angle)) * squash
                canvas.set(Int((center.x + dx).rounded(.down)), Int((center.y + 1 + dy + 1).rounded(.down)), Palette.white)
            }
        }
        return canvas
    }

    /// The skater standing on their board, as one picture.
    static func standing(outfit: Outfit) -> SKTexture {
        canvasStanding(outfit: outfit).texture()
    }

    static func canvasStanding(outfit: Outfit, mirrored: Bool = false) -> PixelCanvas {
        let body = poses(for: outfit).roll
        let board = board(for: outfit).side
        var canvas = PixelCanvas(width: board.width, height: body.height + 3)
        canvas.draw(board, x: 0, y: 0, mirrored: mirrored)
        canvas.draw(body, x: 1, y: 3, mirrored: mirrored)
        return canvas
    }
}
