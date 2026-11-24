//
//  CharacterArt.kt
//
//  Pat, Sammy and Angie, drawn from little pixel templates. Some letters in the
//  templates stand for outfit colors (shirt, pants, hat, board), so one set of
//  drawings makes every outfit. Ported from skate/UI/CharacterArt.swift.
//
//  Template letters:
//    c hat   k hat brim (left out with no hat)   h hair   s skin   o outline   e eye
//    t shirt (Angie's bandana)   l print on the shirt   p pants   q pants in shadow
//    n shoes, or Angie's black fur   m Angie's grey fur   w soles, or a bright eye
//    r tongue
//

package com.tuesdaygames.skate.art

import com.tuesdaygames.skate.rules.ColorChoice
import com.tuesdaygames.skate.rules.Outfit
import com.tuesdaygames.skate.rules.SkaterKind
import com.tuesdaygames.skate.rules.rounded
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.sin

object CharacterArt {
    class Poses(
        val roll: PixelSprite, val crouch: PixelSprite, val air: PixelSprite, val grab: PixelSprite, val bail: PixelSprite,
        /** Two frames of balancing on a boardslide. */
        val slide: List<PixelSprite>,
    )

    class Board(
        val side: PixelSprite, val wheelsUp: PixelSprite, val underside: PixelSprite, val grip: PixelSprite,
        /** Turned 90 degrees, across a rail: short, with the near truck's wheels either side. */
        val endOn: PixelSprite,
    )

    // Colors

    fun colors(outfit: Outfit): Map<Char, PixelColor> {
        val shirt = PixelColor(outfit.shirt)
        val colors = mutableMapOf(
            'e' to Palette.black, 't' to shirt, 'l' to (if (outfit.shirt.isLight) Palette.black else Palette.white),
            'p' to PixelColor(outfit.pants), 'q' to PixelColor(outfit.pants).darker(),
            'n' to PixelColor(0x1C1C1C), 'w' to Palette.white, 'm' to PixelColor(0x8C8C8C), 'r' to PixelColor(0xF878A0),
        )
        when (outfit.kind) {
            SkaterKind.Pat -> {
                colors['s'] = Palette.skin
                colors['h'] = Palette.hair
                colors['o'] = Palette.outline
            }
            SkaterKind.Sammy -> {
                colors['s'] = PixelColor(0x9C5C34)
                colors['h'] = PixelColor(0x1C1008)
                colors['o'] = PixelColor(0x4C2410)
            }
            SkaterKind.Angie -> {}
        }
        val hat = outfit.hat
        if (hat != null) {
            colors['c'] = PixelColor(hat)
            colors['k'] = PixelColor(hat).darker()
        } else if (!outfit.kind.isDog) {
            // No hat: the top of the head is hair, and there's no brim.
            colors['h']?.let { colors['c'] = it }
        }
        return colors
    }

    // Kids

    val patHead = listOf(
        "......cccccc......",
        ".....cccccccc.....",
        "..kkkccccccccc....",
        "....ohhhsssss.....",
        "....ohhssssess....",
        "....ohsossssss....",
        "....ossssssos.....",
        ".....sssssss......",
        ".......sss........",
    )

    /** Sammy has longer hair, down to the collar at the back. */
    val sammyHead = listOf(
        "......cccccc......",
        ".....cccccccc.....",
        "..kkkccccccccc....",
        "...hhhhhhssss.....",
        "...hhhhhssssess...",
        "...hhhhhossssss...",
        "...hhhhsssssos....",
        "....hhhssssss.....",
        ".......sss........",
    )

    private val kidRoll = listOf(
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
    )

    private val kidCrouch = listOf(
        ".....tttttttt.....",
        "...tttttttttttt...",
        "..s.tttllttttt.s..",
        ".....pppppppp.....",
        "....ppppppppqp....",
        "...ppp......ppp...",
        "..nnnn......nnnn..",
        "..wwww......wwww..",
    )

    private val kidAir = listOf(
        ".s...tttttttt...s.",
        ".stttttttttttttts.",
        ".....tttllttt.....",
        ".....tttttttt.....",
        ".....pppppppp.....",
        "....ppppppppqp....",
        "...pppp....pppp...",
        "...nnnn....nnnn...",
        "...wwww....wwww...",
    )

    private val kidGrab = listOf(
        ".s...tttttttt.....",
        ".sttttttttttttt...",
        ".....tttllttttt...",
        ".....tttttttt.s...",
        ".....pppppppp.s...",
        "....ppppppppqps...",
        "...pppp....pppps..",
        "...nnnn....nnnns..",
        "...wwww....wwww...",
    )

    /** Boardsliding: knees out, feet together on the turned board, arms out level. */
    private val kidSlideLevel = listOf(
        "ss...tttttttt...ss",
        ".sssttttttttttsss.",
        ".....tttllttt.....",
        ".....tttttttt.....",
        ".....pppppppp.....",
        "....ppppqppppp....",
        "....ppp....ppp....",
        ".....nnnnnnnn.....",
        ".....wwwwwwww.....",
    )

    /** The wobble: the back arm up, the front one down. */
    private val kidSlideTilt = listOf(
        "ss...tttttttt.....",
        ".sssttttttttttsss.",
        ".....tttllttt...ss",
        ".....tttttttt.....",
        ".....pppppppp.....",
        "....ppppqppppp....",
        "....ppp....ppp....",
        ".....nnnnnnnn.....",
        ".....wwwwwwww.....",
    )

    private val kidBail = listOf(
        "...........kcccc..",
        "..........cccccccc",
        "nnppppppttttohssss",
        "nnppppppttttohsses",
        "wwpp..ppttttosssss",
        ".......ss..s.ssss.",
    )

    // Angie

    /** A black and grey doodle with curly fur, riding with her head up front. */
    private val dogTop = listOf(
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
    )

    private val dogLegs = listOf("...nn.nn...nn.nn..")
    private val dogPaws = listOf("...mm.mm...mm.mm..")

    private val dogBail = listOf(
        "...mm.mm...mm.mm..",
        "...nn.nn...nn.nn..",
        "..nnnnmnnnnmnnnn..",
        "m.nmnnnmnnnnnmnnnn",
        "nnnnmnnnnnttttnnwn",
        "..........ccc.kk..",
    )

    fun poses(outfit: Outfit): Poses {
        val colors = colors(outfit)
        fun sprite(rows: List<String>) = PixelSprite(rows, colors)
        return when (outfit.kind) {
            SkaterKind.Pat, SkaterKind.Sammy -> {
                val head = if (outfit.kind == SkaterKind.Sammy) sammyHead else patHead
                Poses(
                    roll = sprite(head + kidRoll), crouch = sprite(head + kidCrouch), air = sprite(head + kidAir),
                    grab = sprite(head + kidGrab), bail = sprite(kidBail),
                    slide = listOf(sprite(head + kidSlideLevel), sprite(head + kidSlideTilt)),
                )
            }
            SkaterKind.Angie -> {
                val standing = sprite(dogTop + dogLegs + dogPaws)
                val tucked = sprite(dogTop + dogPaws)
                Poses(roll = standing, crouch = tucked, air = tucked, grab = tucked, bail = sprite(dogBail), slide = listOf(tucked, standing))
            }
        }
    }

    /** Angie on foot, without her board: two frames of a walk. */
    fun walkingDog(frame: Int): PixelSprite {
        val outfit = Outfit(kind = SkaterKind.Angie, shirt = ColorChoice.Red, pants = ColorChoice.Khaki, hat = null, board = ColorChoice.Brown)
        val legs = if (frame == 0) dogLegs + dogPaws else listOf("..nn..nn..nn..nn..", "..mm..mm..mm..mm..")
        return PixelSprite(dogTop + legs, colors(outfit))
    }

    /** Every template, for checking they're all the same width. */
    val allTemplates: List<List<String>>
        get() = listOf(
            patHead, sammyHead, kidRoll, kidCrouch, kidAir, kidGrab, kidBail, kidSlideLevel, kidSlideTilt,
            dogTop, dogLegs, dogPaws, dogBail,
        )

    // Boards

    fun board(outfit: Outfit): Board {
        val deck = PixelColor(outfit.board)
        val colors = mutableMapOf(
            'd' to deck, 'o' to deck, 'y' to (if (outfit.board.isLight) Palette.black else Palette.yellow),
            'm' to Palette.grey, 'w' to Palette.white, 'k' to Palette.darkGrey,
        )
        // The PDX carpet: little orange, purple and blue shapes scattered on teal.
        val carpet = outfit.board == ColorChoice.Pdx
        if (carpet) {
            colors['a'] = PixelColor(0xE86838)
            colors['b'] = PixelColor(0x7C48B8)
            colors['c'] = PixelColor(0x68C0F0)
        }
        val underside = if (carpet) listOf(
            ".oooooooooooooooooo.",
            "oaooocoobooaoocooboo",
            "ooboooaoocooboooaoco",
            "ocooboooaoocooboooao",
            ".oooooooooooooooooo.",
        ) else listOf(
            ".oooooooooooooooooo.",
            "oyyyoooooyyoooooyyyo",
            "oyyyooooyyyyooooyyyo",
            "oyyyoooooyyoooooyyyo",
            ".oooooooooooooooooo.",
        )
        return Board(
            side = PixelSprite(
                listOf(
                    "dd................dd",
                    ".dddddddddddddddddd.",
                    "...mmm........mmm...",
                    "...ww..........ww...",
                ),
                colors,
            ),
            wheelsUp = PixelSprite(
                listOf(
                    "...ww..........ww...",
                    "...mmm........mmm...",
                    ".dddddddddddddddddd.",
                    "dd................dd",
                ),
                colors,
            ),
            underside = PixelSprite(underside, colors),
            grip = PixelSprite(
                listOf(
                    ".kkkkkkkkkkkkkkkkkk.",
                    "kkkkkkkkkkkkkkkkkkkk",
                    "kkkkkkkkkkkkkkkkkkkk",
                    "kkkkkkkkkkkkkkkkkkkk",
                    ".kkkkkkkkkkkkkkkkkk.",
                ),
                colors,
            ),
            // Wider than the feet, so its curled-up edges show either side of the shoes.
            endOn = PixelSprite(
                listOf(
                    "dk..........kd",
                    ".dkkkkkkkkkkd.",
                    "..dddddddddd..",
                    ".....mmmm.....",
                    "...www..www...",
                ),
                colors,
            ),
        )
    }

    /** How many pictures make a full turn of a spinning board. */
    const val spinSteps = 16

    /** The board spinning flat, as if seen from a little above: a long thin board side-on,
     *  a short fat one end-on, and everything between. `step` 0 is side-on, nose right. */
    fun spin(outfit: Outfit, step: Int, graphicUp: Boolean): PixelCanvas {
        val width = 22
        val height = 12
        val length = 20.0
        val deckWidth = 6.0
        val squash = 0.45
        val angle = step.toDouble() / spinSteps * 2 * PI
        val deck = PixelColor(outfit.board)
        val edge = deck.darker()
        val top = if (graphicUp) deck else PixelColor(0x2C2C2C)
        val stripe = if (outfit.board.isLight) Palette.black else Palette.yellow
        val canvas = PixelCanvas(width, height)
        val centerX = width.toDouble() / 2
        val centerY = 6.0

        // Where a canvas pixel lands on the board: along it, and across it.
        fun boardPoint(px: Int, py: Int, lift: Double): Pair<Double, Double> {
            val dx = px + 0.5 - centerX
            val dy = (py + 0.5 - centerY - lift) / squash
            return (dx * cos(angle) + dy * sin(angle)) to (-dx * sin(angle) + dy * cos(angle))
        }
        fun inside(u: Double, v: Double, inset: Double = 0.0): Boolean {
            val half = length / 2 - inset
            val side = deckWidth / 2 - inset
            val straight = half - side
            if (abs(u) <= straight) return abs(v) <= side
            val du = abs(u) - straight
            return du * du + v * v <= side * side
        }
        // The deck's edge, a pixel thick, then the top surface on it.
        for (py in 0 until height) {
            for (px in 0 until width) {
                val below = boardPoint(px, py, 0.0)
                val onTop = boardPoint(px, py, 1.0)
                if (inside(onTop.first, onTop.second)) {
                    val rim = !inside(onTop.first, onTop.second, inset = 0.9)
                    var color = if (rim) deck else top
                    if (graphicUp && !rim) {
                        if (outfit.board == ColorChoice.Pdx) {
                            // The carpet's little shapes, scattered across the deck.
                            val cell = ((onTop.first + 20).rounded().toInt() * 3 + (onTop.second + 10).rounded().toInt() * 5) % 9
                            if (cell == 0) color = PixelColor(0xE86838)
                            if (cell == 4) color = PixelColor(0x7C48B8)
                            if (cell == 7) color = PixelColor(0x68C0F0)
                        } else if (abs(onTop.first) < 1.2) {
                            color = stripe
                        }
                    }
                    canvas[px, py] = color
                } else if (inside(below.first, below.second)) {
                    canvas[px, py] = edge
                }
            }
        }
        // Graphic up means wheels up: four of them over the trucks.
        if (graphicUp) {
            for ((u, v) in listOf(-6.0 to -2.5, -6.0 to 2.5, 6.0 to -2.5, 6.0 to 2.5)) {
                val dx = u * cos(angle) - v * sin(angle)
                val dy = (u * sin(angle) + v * cos(angle)) * squash
                canvas[floor(centerX + dx).toInt(), floor(centerY + 1 + dy + 1).toInt()] = Palette.white
            }
        }
        return canvas
    }

    /** The skater standing on their board, as one picture. */
    fun standing(outfit: Outfit, mirrored: Boolean = false): PixelCanvas {
        val body = poses(outfit).roll
        val board = board(outfit).side
        val canvas = PixelCanvas(board.width, body.height + 3)
        canvas.draw(board, 0, 0, mirrored)
        canvas.draw(body, 1, 3, mirrored)
        return canvas
    }
}
