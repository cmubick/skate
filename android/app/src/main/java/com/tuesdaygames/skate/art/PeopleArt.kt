//
//  PeopleArt.kt
//
//  Everyone else on the street: walkers, joggers and people on bikes. They're
//  drawn in the same blocky style and at the same size as the skaters (the same
//  heads, the same 18-pixel-wide templates), just a couple of pixels taller,
//  so a grown-up's head lines up with a kid's on a board. Ported from skate/UI/PeopleArt.swift.
//
//  Template letters are the skaters' (see CharacterArt), and face right.
//

package com.tuesdaygames.skate.art

import com.tuesdaygames.skate.rules.SeededGenerator
import com.tuesdaygames.skate.rules.rounded
import com.tuesdaygames.skate.rules.strideDoubles
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

/** Colors and hair for a passer-by. */
data class Person(
    val skin: PixelColor, val hair: PixelColor, val shirt: PixelColor, val pants: PixelColor, val shoes: PixelColor,
    val hat: PixelColor?,
    val longHair: Boolean,
) {
    val colors: Map<Char, PixelColor>
        get() {
            val colors = mutableMapOf(
                's' to skin, 'h' to hair, 'o' to skin.darker(0.5), 'e' to Palette.black,
                't' to shirt, 'l' to shirt, 'p' to pants, 'q' to pants.darker(), 'n' to shoes, 'w' to Palette.white,
            )
            if (hat != null) {
                colors['c'] = hat
                colors['k'] = hat.darker()
            } else {
                colors['c'] = hair
            }
            return colors
        }

    val head: List<String> get() = if (longHair) CharacterArt.sammyHead else CharacterArt.patHead

    companion object {
        fun random(generator: SeededGenerator): Person {
            val skins = listOf(Palette.skin, PixelColor(0x9C5C34), PixelColor(0xF0C098), PixelColor(0x6C3C1C))
            val hairs = listOf(Palette.hair, PixelColor(0x1C1008), PixelColor(0xD8A838), PixelColor(0x8C8C8C), PixelColor(0xA83C14))
            val shirts = listOf(
                PixelColor(0xD82800), PixelColor(0x0058F8), PixelColor(0x00A844), PixelColor(0xF8B800),
                PixelColor(0x8C38C8), PixelColor(0xF0F0F0), PixelColor(0x00A8A8),
            )
            val pants = listOf(PixelColor(0x24489C), PixelColor(0x2C2C2C), PixelColor(0xC8A870), PixelColor(0x5C5C5C))
            val hats = listOf(PixelColor(0xD82800), PixelColor(0x0058F8), PixelColor(0x2C2C2C), PixelColor(0x00A844))
            // In the same order as Swift evaluates its arguments.
            val skin = generator.element(skins)!!
            val hair = generator.element(hairs)!!
            val shirt = generator.element(shirts)!!
            val trousers = generator.element(pants)!!
            val hat = if (generator.intUntil(0, 3) == 0) generator.element(hats)!! else null
            val longHair = generator.bool()
            return Person(skin, hair, shirt, trousers, Palette.black, hat, longHair)
        }
    }
}

object PeopleArt {
    /** Someone walking, two frames of their stride. Head plus body: 21 pixels tall. */
    fun walker(person: Person, frame: Int, facingLeft: Boolean): PixelCanvas {
        val body = if (frame == 0) walkStride else walkPassing
        return PixelSprite(person.head + body, person.colors).canvas(mirrored = facingLeft)
    }

    /** A jogger in shorts, arms pumping, going your way. */
    fun runner(person: Person, frame: Int): PixelCanvas {
        val runner = person.copy(shoes = PixelColor(0xF0F0F0))
        val body = if (frame == 0) runStride else runPassing
        // Shorts: the legs below the hem are skin.
        return PixelSprite(person.head + body, runner.colors + ('w' to PixelColor(0x8C8C8C))).canvas()
    }

    /** Someone on a bike, going your way. 24 x 22: the bike, then a rider the size of a skater. */
    const val bikeWidth = 24
    const val bikeHeight = 22

    fun biker(person: Person, frame: Int): PixelCanvas {
        val canvas = PixelCanvas(bikeWidth, bikeHeight)
        val tire = Palette.black
        val frameColor = PixelColor(0xD82800)
        val metal = Palette.darkGrey
        // Wheels.
        for ((cx, cy) in listOf(4 to 4, 19 to 4)) {
            for (angle in strideDoubles(0.0, 2 * PI, 0.15)) {
                canvas[cx + (4 * cos(angle)).rounded().toInt(), cy + (4 * sin(angle)).rounded().toInt()] = tire
            }
            canvas[cx, cy] = Palette.grey
        }
        // Frame: rear axle, crank, seat, handlebars, front axle.
        val rear = 4 to 4
        val crank = 12 to 4
        val seat = 8 to 7
        val head = 17 to 9
        val front = 19 to 4
        line(canvas, rear, crank, frameColor)
        line(canvas, rear, seat, frameColor)
        line(canvas, seat, crank, frameColor)
        line(canvas, seat, head, frameColor)
        line(canvas, head, crank, frameColor)
        line(canvas, head, front, frameColor)
        canvas.fill(17, 10, 3, 1, metal)
        canvas.fill(6, 7, 4, 1, metal)
        // The rider, sitting on the seat with their hands on the bars.
        canvas.draw(PixelSprite(person.head + (if (frame == 0) pedalDown else pedalUp), person.colors), 1, 3)
        return canvas
    }

    /** A Zoobomber: a grown-up hunched over a little kids' bike, knees up by the handlebars. */
    fun miniBiker(person: Person, frame: Int): PixelCanvas {
        val canvas = PixelCanvas(20, 21)
        val tire = Palette.black
        val frameColor = PixelColor(0xF878B8)
        for ((cx, cy) in listOf(4 to 3, 15 to 3)) {
            for (angle in strideDoubles(0.0, 2 * PI, 0.3)) {
                canvas[cx + (3 * cos(angle)).rounded().toInt(), cy + (3 * sin(angle)).rounded().toInt()] = tire
            }
        }
        line(canvas, 4 to 3, 10 to 3, frameColor)
        line(canvas, 4 to 3, 7 to 7, frameColor)
        line(canvas, 7 to 7, 14 to 6, frameColor)
        line(canvas, 10 to 3, 14 to 6, frameColor)
        line(canvas, 14 to 6, 15 to 3, frameColor)
        line(canvas, 14 to 6, 14 to 9, Palette.darkGrey)
        canvas.fill(13, 9, 3, 1, Palette.darkGrey)
        canvas.fill(6, 7, 3, 1, Palette.darkGrey)
        // The rider: knees high, leaning over the bars.
        val body = if (frame == 0) listOf(
            ".....tttttttt.....",
            "...tttttttttttss..",
            ".....tttttttt..s..",
            ".....pppppppppp...",
            "......ppppppppp...",
            "...........nnn....",
        ) else listOf(
            ".....tttttttt.....",
            "...tttttttttttss..",
            ".....tttttttt..s..",
            ".....ppppppppp....",
            "......pppppppqq...",
            "..........nnnq....",
        )
        canvas.draw(PixelSprite(person.head + body, person.colors), 1, 6)
        return canvas
    }

    private fun line(canvas: PixelCanvas, from: Pair<Int, Int>, to: Pair<Int, Int>, color: PixelColor) {
        val steps = max(max(abs(to.first - from.first), abs(to.second - from.second)), 1)
        for (step in 0..steps) {
            val t = step.toDouble() / steps
            canvas[from.first + ((to.first - from.first) * t).rounded().toInt(), from.second + ((to.second - from.second) * t).rounded().toInt()] = color
        }
    }

    // Bodies (12 rows standing, 10 on a bike), all 18 wide

    private val walkStride = listOf(
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
    )

    private val walkPassing = listOf(
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
    )

    private val runStride = listOf(
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
    )

    private val runPassing = listOf(
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
    )

    /** Near foot forward, far foot back (the far leg is in shadow). */
    private val pedalDown = listOf(
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
    )

    /** Near foot up, far foot down. */
    private val pedalUp = listOf(
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
    )

    /** Every template, for checking they're all the same width. */
    val allTemplates: List<List<String>> get() = listOf(walkStride, walkPassing, runStride, runPassing, pedalDown, pedalUp)
}
