//
//  CharacterArt.swift
//  skate
//
//  Terry, Sam and Angie, drawn from little pixel templates. Some letters in the
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
    /// One picture of them standing on their board, for menus.
    let standing: SKTexture

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
        standing = CharacterArt.standing(outfit: outfit)
    }
}

enum CharacterArt {
    struct Poses {
        var roll, crouch, air, grab, bail: PixelSprite
    }

    struct Board {
        var side, wheelsUp, underside, grip: PixelSprite
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
        case .terry:
            colors["s"] = Palette.skin
            colors["h"] = Palette.hair
            colors["o"] = Palette.outline
        case .sam:
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

    private static let terryHead = [
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

    /// Sam has longer hair, down to the collar at the back.
    private static let samHead = [
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
        case .terry, .sam:
            let head = outfit.kind == .sam ? samHead : terryHead
            return Poses(roll: sprite(head + kidRoll), crouch: sprite(head + kidCrouch), air: sprite(head + kidAir),
                         grab: sprite(head + kidGrab), bail: sprite(kidBail))
        case .angie:
            let standing = sprite(dogTop + dogLegs + dogPaws)
            let tucked = sprite(dogTop + dogPaws)
            return Poses(roll: standing, crouch: tucked, air: tucked, grab: tucked, bail: sprite(dogBail))
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
        [terryHead, samHead, kidRoll, kidCrouch, kidAir, kidGrab, kidBail, dogTop, dogLegs, dogPaws, dogBail]
    }

    // MARK: Boards

    static func board(for outfit: Outfit) -> Board {
        let deck = PixelColor(outfit.board)
        let colors: [Character: PixelColor] = [
            "d": deck, "o": deck, "y": outfit.board.isLight ? Palette.black : Palette.yellow,
            "m": Palette.grey, "w": Palette.white, "k": Palette.darkGrey,
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
            underside: PixelSprite([
                ".oooooooooooooooooo.",
                "oyyyoooooyyoooooyyyo",
                "oyyyooooyyyyooooyyyo",
                "oyyyoooooyyoooooyyyo",
                ".oooooooooooooooooo.",
            ], colors: colors),
            grip: PixelSprite([
                ".kkkkkkkkkkkkkkkkkk.",
                "kkkkkkkkkkkkkkkkkkkk",
                "kkkkkkkkkkkkkkkkkkkk",
                "kkkkkkkkkkkkkkkkkkkk",
                ".kkkkkkkkkkkkkkkkkk.",
            ], colors: colors)
        )
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
