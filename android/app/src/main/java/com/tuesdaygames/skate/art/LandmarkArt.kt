//
//  LandmarkArt.kt
//
//  Portland landmarks for the backdrops, and the city's own street furniture:
//  Portlandia, Pioneer Courthouse Square, the Chinatown gate, Saturday Market,
//  the Burnside Bridge, Paul Bunyan, Cathedral Park, Tilikum Crossing, the
//  Hawthorne Bridge, OMSI and the Blueback, Pittock Mansion, Mount Hood and
//  Mount St. Helens. Each draws into a backdrop strip at an x and says how wide it was.
//  Ported from skate/UI/LandmarkArt.swift.
//

package com.tuesdaygames.skate.art

import com.tuesdaygames.skate.rules.SeededGenerator
import com.tuesdaygames.skate.rules.rounded
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.pow

object Landmarks {
    // Helpers

    fun line(canvas: PixelCanvas, from: Pair<Int, Int>, to: Pair<Int, Int>, color: PixelColor) {
        val steps = max(max(abs(to.first - from.first), abs(to.second - from.second)), 1)
        for (step in 0..steps) {
            val t = step.toDouble() / steps
            canvas[from.first + ((to.first - from.first) * t).rounded().toInt(), from.second + ((to.second - from.second) * t).rounded().toInt()] = color
        }
    }

    /** A mountain: slopes from `left` to `right`, its peak `height` up, snow on the top part. */
    fun mountain(
        canvas: PixelCanvas, left: Int, right: Int, height: Int, rock: PixelColor,
        snowLine: Double, flatTop: Int = 0, seed: Long,
    ) {
        val generator = SeededGenerator(seed)
        val middle = (left + right).toDouble() / 2
        val half = (right - left).toDouble() / 2
        for (x in left until right) {
            val along = 1 - abs(x.toDouble() - middle) / half
            var top = (along.pow(1.4) * height).rounded().toInt()
            // A blown-out top: cut the peak off, with a dip in the middle.
            if (flatTop > 0 && top > height - flatTop) {
                top = height - flatTop + if (abs(x.toDouble() - middle) < flatTop.toDouble()) -1 else 0
            }
            if (top <= 0) continue
            canvas.fill(x, 0, 1, top, rock)
            val snowFrom = (height * snowLine).toInt() + generator.int(-2, 2)
            if (top > snowFrom) canvas.fill(x, snowFrom, 1, top - snowFrom, Palette.white)
            // Gullies of rock streaking down through the snow.
            if (x % 5 == 0 && top > snowFrom + 2) canvas.fill(x, snowFrom, 1, (top - snowFrom) / 2, rock.darker(0.85))
        }
    }

    // Downtown

    /** Pioneer Courthouse Square: brick steps, the "you are here" signpost, and the old
     *  courthouse with its cupola behind. Returns its width. */
    fun pioneerSquare(canvas: PixelCanvas, x: Int): Int {
        val w = 96
        val cream = PixelColor(0xE8DCC0)
        val trim = PixelColor(0xB8AC90)
        val brick = PixelColor(0xA84C34)
        // The courthouse.
        val courtX = x + 30
        canvas.fill(courtX, 0, 54, 24, cream)
        canvas.fill(courtX, 22, 54, 2, trim)
        for (wx in courtX + 3 until courtX + 52 step 5) {
            canvas.fill(wx, 12, 2, 6, Palette.black)
            canvas.fill(wx, 3, 2, 6, Palette.black)
        }
        canvas.fill(courtX + 21, 24, 12, 4, cream)
        canvas.fill(courtX + 23, 28, 8, 3, PixelColor(0xD0D0D0))
        canvas.fill(courtX + 25, 31, 4, 2, PixelColor(0xD0D0D0))
        canvas.fill(courtX + 26, 33, 2, 3, Palette.grey)
        // The brick plaza and its steps.
        canvas.fill(x, 0, w, 2, brick)
        for (step in 0 until 5) {
            canvas.fill(x, step * 2, 34 - step * 6, 2, brick)
            canvas.fill(x, step * 2 + 1, 34 - step * 6, 1, brick.darker(0.8))
        }
        // The signpost, arrows pointing off to sister cities and faraway places.
        val postX = x + 20
        canvas.fill(postX, 0, 1, 24, Palette.darkGrey)
        for ((index, y) in listOf(9, 12, 15, 18, 21).withIndex()) {
            val color = if (index % 2 == 0) Palette.white else PixelColor(0xF8D878)
            if (index % 2 == 0) {
                canvas.fill(postX + 1, y, 6, 2, color)
                canvas[postX + 7, y] = color
            } else {
                canvas.fill(postX - 6, y, 6, 2, color)
                canvas[postX - 7, y + 1] = color
            }
        }
        return w
    }

    /** The Portland Building: cream walls with little square windows, giant maroon
     *  keystones, a teal base, and Portlandia kneeling over the door with her trident. */
    fun portlandBuilding(canvas: PixelCanvas, x: Int): Int {
        val w = 64
        val h = 40
        val cream = PixelColor(0xE8DCC0)
        val teal = PixelColor(0x3C8C84)
        val maroon = PixelColor(0x8C3C2C)
        val glass = PixelColor(0x2C3C5C)
        canvas.fill(x, 0, w, h, cream)
        for (wy in 10 until h - 3 step 4) {
            for (wx in x + 2 until x + w - 2 step 4) canvas.fill(wx, wy, 2, 2, glass)
        }
        // The big dark window band down the middle, between maroon pilasters, under keystones.
        val middle = x + 36
        canvas.fill(middle - 8, 8, 16, 26, glass)
        canvas.fill(middle - 12, 8, 4, 24, maroon)
        canvas.fill(middle + 8, 8, 4, 24, maroon)
        for (row in 0 until 4) {
            canvas.fill(middle - 13 - row, 30 + row, 6 + row * 2, 1, maroon)
            canvas.fill(middle + 7 - row, 30 + row, 6 + row * 2, 1, maroon)
        }
        canvas.fill(x, 0, w, 8, teal)
        canvas.fill(x, h - 2, w, 2, teal)
        canvas.fill(x + 8, 0, 8, 6, glass)
        // Portlandia, hammered copper, kneeling over the door.
        val statue = PixelSprite(
            listOf(
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
            ),
            mapOf('c' to PixelColor(0xB8743C), 'd' to PixelColor(0x7C4C24), 'w' to PixelColor(0xD8A060)),
        )
        canvas.fill(x + 5, 8, 16, 1, PixelColor(0x9C9C94))
        canvas.draw(statue, x + 6, 9)
        return w
    }

    // Old Town

    /** The Old Town Chinatown gate: red pillars, a gold panel, and green tiled roofs
     *  with their eaves turned up. Returns its width. */
    fun chinatownGate(canvas: PixelCanvas, x: Int): Int {
        val w = 46
        val red = PixelColor(0xC82818)
        val green = PixelColor(0x2C8C5C)
        val gold = PixelColor(0xE8B830)
        // Outer pillars with their own small roofs.
        for (px in listOf(x + 1, x + w - 4)) {
            canvas.fill(px, 0, 3, 13, red)
            canvas.fill(px - 2, 13, 7, 2, green)
            canvas[px - 3, 15] = green
            canvas[px + 5, 15] = green
        }
        // Main pillars, beams and the panel.
        for (px in listOf(x + 9, x + w - 12)) canvas.fill(px, 0, 3, 23, red)
        canvas.fill(x + 4, 11, w - 8, 2, red)
        canvas.fill(x + 7, 21, w - 14, 2, red)
        canvas.fill(x + 17, 16, w - 34, 5, gold)
        canvas.fill(x + 18, 17, w - 36, 3, red)
        // The main roof.
        canvas.fill(x + 3, 23, w - 6, 3, green)
        canvas.fill(x + 6, 26, w - 12, 1, green.darker(0.7))
        canvas.fill(x + 2, 26, 2, 1, green)
        canvas.fill(x + w - 4, 26, 2, 1, green)
        canvas[x + 1, 27] = green
        canvas[x + w - 2, 27] = green
        canvas.fill(x + 10, 27, w - 20, 1, gold)
        return w
    }

    /** Saturday Market under the bridge: a row of striped canopies over stalls. */
    fun saturdayMarket(canvas: PixelCanvas, x: Int, generator: SeededGenerator): Int {
        val w = 92
        val canopies = listOf(PixelColor(0xD82800), PixelColor(0x0058F8), PixelColor(0xF8B800), PixelColor(0x00A844), PixelColor(0x8C38C8))
        val goods = listOf(Palette.white, Palette.yellow, PixelColor(0xF878B8), PixelColor(0x00A8A8), Palette.orange)
        for (tent in 0 until 4) {
            val tx = x + tent * 23
            val color = canopies[(tent + generator.intUntil(0, canopies.size)) % canopies.size]
            canvas.fill(tx, 0, 1, 10, Palette.grey)
            canvas.fill(tx + 20, 0, 1, 10, Palette.grey)
            // A table of things for sale.
            canvas.fill(tx + 2, 4, 17, 1, Palette.brown)
            canvas.fill(tx + 3, 0, 1, 4, Palette.brown)
            canvas.fill(tx + 17, 0, 1, 4, Palette.brown)
            for (gx in tx + 3 until tx + 18 step 2) canvas[gx, 5] = generator.element(goods)!!
            // A peaked canopy in stripes.
            for (row in 0 until 6) {
                val inset = row * 2
                for (column in (tx - 1 + inset) until (tx + 22 - inset)) {
                    canvas[column, 10 + row] = if ((column / 3) % 2 == 0) color else Palette.white
                }
            }
        }
        return w
    }

    // Burnside Bridge

    /** Through an arch of the bridge: the river, and the bascule span's two towers far off. */
    fun burnsideTowers(canvas: PixelCanvas, left: Int, right: Int, archTop: (Int) -> Int) {
        val dusk = PixelColor(0x4C5C84)
        val water = PixelColor(0x2C4C7C)
        val tower = PixelColor(0x9C8C6C)
        val roof = PixelColor(0x5C5C64)
        for (x in left until right) {
            canvas.fill(x, 0, 1, archTop(x), dusk)
            canvas.fill(x, 0, 1, 6, water)
        }
        val middle = (left + right) / 2
        canvas.fill(left, 6, right - left, 2, PixelColor(0x6C6C74))
        for (towerX in listOf(middle - 14, middle + 6)) {
            canvas.fill(towerX, 8, 8, 16, tower)
            for (row in 0 until 4) canvas.fill(towerX + row, 24 + row, 8 - row * 2, 1, roof)
            canvas.fill(towerX + 2, 16, 1, 3, Palette.window)
            canvas.fill(towerX + 5, 16, 1, 3, Palette.window)
            canvas.fill(towerX + 3, 10, 2, 3, Palette.black)
        }
    }

    // North Portland

    /** The gothic arches of the bridge's approach over Cathedral Park. */
    fun cathedralArches(canvas: PixelCanvas, x: Int, count: Int, deckY: Int) {
        val concrete = PixelColor(0x8C948C)
        val shade = PixelColor(0x6C746C)
        val span = 16
        for (arch in 0 until count) {
            val ax = x + arch * span
            canvas.fill(ax, 0, 3, deckY, concrete)
            canvas.fill(ax + 2, 0, 1, deckY, shade)
            // A pointed arch: concrete from the arch's curve up to the deck.
            for (column in 3 until span) {
                val fromMiddle = abs(column.toDouble() - (span + 3).toDouble() / 2) / ((span - 3).toDouble() / 2)
                val top = ((deckY - 4).toDouble() * (1 - fromMiddle * fromMiddle * 0.9)).rounded().toInt()
                canvas.fill(ax + column, top, 1, max(0, deckY - top), concrete)
            }
        }
        canvas.fill(x + count * span, 0, 3, deckY, concrete)
    }

    /** Paul Bunyan in Kenton, thirty-one feet of him, axe at his side. Returns his width. */
    fun paulBunyan(canvas: PixelCanvas, x: Int): Int {
        val rows = listOf(
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
        )
        val sprite = PixelSprite(
            rows,
            mapOf(
                'h' to PixelColor(0x1C1008), 's' to Palette.skin, 'e' to Palette.black, 'b' to PixelColor(0x1C1008),
                'm' to PixelColor(0xB84838), 'r' to PixelColor(0xC82818), 'k' to PixelColor(0x1C1C1C), 'l' to Palette.brown,
                'p' to PixelColor(0x24489C), 'n' to PixelColor(0x1C1C1C), 'a' to PixelColor(0x8C5C2C), 'x' to PixelColor(0xA8A8B0),
            ),
        )
        val w = sprite.width + 4
        // His pedestal.
        canvas.fill(x, 0, w, 4, PixelColor(0x9C9C94))
        canvas.fill(x, 3, w, 1, PixelColor(0xBCBCB4))
        canvas.draw(sprite, x + 2, 4)
        return w
    }

    // Waterfront

    /** Tilikum Crossing: two white pylons with cables fanning down to the deck. */
    fun tilikum(canvas: PixelCanvas, x: Int) {
        val white = PixelColor(0xE8E8F0)
        val cable = PixelColor(0xC8C8D8)
        canvas.fill(x, 4, 92, 2, white)
        for (pylon in listOf(x + 26, x + 66)) {
            for (row in 0 until 36) canvas.fill(pylon - if (row < 10) 1 else 0, row, if (row < 10) 3 else 2, 1, white)
            for (step in 1..5) {
                line(canvas, pylon to 35 - step * 3, pylon - step * 5 to 6, cable)
                line(canvas, pylon + 1 to 35 - step * 3, pylon + 1 + step * 5 to 6, cable)
            }
        }
    }

    /** The Hawthorne Bridge: green truss towers with the lift span between them. */
    fun hawthorne(canvas: PixelCanvas, x: Int) {
        val green = PixelColor(0x2C6C4C)
        val red = PixelColor(0x9C3C2C)
        canvas.fill(x, 0, 110, 2, green)
        canvas.fill(x, 2, 110, 1, red)
        for (towerX in listOf(x + 20, x + 84)) {
            canvas.fill(towerX, 0, 6, 26, green)
            for (y in 2 until 24 step 4) line(canvas, towerX to y, towerX + 5 to y + 3, PixelColor(0x78A8F0))
            canvas.fill(towerX - 1, 26, 8, 2, green)
            canvas.fill(towerX + 2, 28, 2, 2, red)
        }
        canvas.fill(x + 20, 20, 70, 2, green)
        for (truss in x + 26 until x + 84 step 6) line(canvas, truss to 3, truss + 6 to 8, green)
        canvas.fill(x + 26, 8, 58, 1, green)
    }

    /** OMSI on the far bank: a long brick building with its tall smokestack. */
    fun omsi(canvas: PixelCanvas, x: Int) {
        val brick = PixelColor(0xA8543C)
        val glass = PixelColor(0x88B0D8)
        canvas.fill(x, 0, 40, 11, brick)
        for (wx in x + 2 until x + 38 step 4) canvas.fill(wx, 5, 2, 3, glass)
        canvas.fill(x + 14, 11, 10, 4, glass)
        canvas.fill(x + 30, 0, 4, 34, brick)
        canvas.fill(x + 30, 32, 4, 2, brick.darker(0.7))
    }

    /** The USS Blueback, moored by OMSI: hull low in the water, sail standing up. */
    fun blueback(canvas: PixelCanvas, x: Int, waterline: Int) {
        val hull = PixelColor(0x3C4048)
        val light = PixelColor(0x5C6068)
        for (column in 0 until 54) {
            val along = column.toDouble() / 53
            val h = (3.5 * (1 - (2 * along - 1).pow(6))).rounded().toInt()
            if (h <= 0) continue
            canvas.fill(x + column, waterline, 1, h, hull)
            canvas[x + column, waterline + h - 1] = light
        }
        canvas.fill(x + 16, waterline + 3, 8, 6, hull)
        canvas.fill(x + 16, waterline + 8, 8, 1, light)
        canvas.fill(x + 14, waterline + 6, 12, 1, hull)
        canvas.fill(x + 19, waterline + 9, 1, 2, light)
    }

    // Zoo Bomb

    /** Pittock Mansion up on the ridge: stone walls, steep slate roofs and chimneys. */
    fun pittock(canvas: PixelCanvas, x: Int, y: Int) {
        val stone = PixelColor(0xD8C8A8)
        val slate = PixelColor(0x5C6470)
        canvas.fill(x, y, 24, 8, stone)
        for (wx in x + 2 until x + 22 step 4) canvas.fill(wx, y + 2, 2, 3, Palette.black)
        for (row in 0 until 5) canvas.fill(x + row, y + 8 + row, 24 - row * 2, 1, slate)
        // The tower in the middle, with its pointed roof.
        canvas.fill(x + 9, y + 8, 6, 8, stone)
        for (row in 0 until 4) canvas.fill(x + 9 + row, y + 16 + row, 6 - row * 2, 1, slate)
        canvas.fill(x + 3, y + 12, 2, 4, stone)
        canvas.fill(x + 19, y + 12, 2, 4, stone)
    }
}
