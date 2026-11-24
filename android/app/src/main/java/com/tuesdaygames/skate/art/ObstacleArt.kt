//
//  ObstacleArt.kt
//
//  Everything on the street: things to grind, things in the way, manholes, the
//  city letters and the finish line. Moving things get two frames to walk,
//  pedal or waddle. Ported from skate/UI/ObstacleArt.swift.
//

package com.tuesdaygames.skate.art

import com.tuesdaygames.skate.rules.ColorChoice
import com.tuesdaygames.skate.rules.Feature
import com.tuesdaygames.skate.rules.FeatureStyle
import com.tuesdaygames.skate.rules.Outfit
import com.tuesdaygames.skate.rules.PixelFont
import com.tuesdaygames.skate.rules.SeededGenerator
import com.tuesdaygames.skate.rules.SkaterKind
import com.tuesdaygames.skate.rules.rounded
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/** How a feature is drawn: one or two frames, and where the picture sits relative
 *  to the feature's spot on its lane (holes sink a little into the ground). */
class FeatureLook(val frames: List<PixelCanvas>, val offsetX: Double = 0.0, val offsetY: Double = 0.0)

object FeatureArt {
    fun look(feature: Feature, seed: Int): FeatureLook {
        val width = feature.length.toInt()
        val height = feature.height.toInt()
        val generator = SeededGenerator((seed * 7919 + 17).toLong())
        fun one(canvas: PixelCanvas, x: Double = 0.0, y: Double = 0.0) = FeatureLook(listOf(canvas), x, y)
        fun two(x: Double = 0.0, make: (Int) -> PixelCanvas) = FeatureLook(listOf(make(0), make(1)), x, 0.0)

        return when (feature.style) {
            FeatureStyle.Rail -> one(rail(width, height, Palette.grey))
            FeatureStyle.Handrail -> one(rail(width, height, PixelColor(0x2C7C5C)))
            FeatureStyle.Ledge -> one(ledge(width, height))
            FeatureStyle.Bench -> one(bench(width))
            FeatureStyle.Curb -> one(curb(width, height))
            FeatureStyle.Fountain -> one(fountain(width))
            FeatureStyle.Tracks -> one(tracks(width))
            FeatureStyle.Funbox -> one(funbox(width, height))
            FeatureStyle.Barrier -> one(barrier(width, height))
            FeatureStyle.Cone -> one(cone(width, height))
            FeatureStyle.Planter -> one(planter(width, height))
            FeatureStyle.Pedestrian -> {
                val person = Person.random(generator)
                two(-4.0) { PeopleArt.walker(person, it, facingLeft = true) }
            }
            FeatureStyle.Runner -> {
                val person = Person.random(generator)
                two(-3.0) { PeopleArt.runner(person, it) }
            }
            FeatureStyle.Biker -> {
                val person = Person.random(generator)
                two(-1.0) { PeopleArt.biker(person, it) }
            }
            FeatureStyle.Skater -> {
                // In the same order as Swift evaluates its arguments.
                val kind = if (generator.bool()) SkaterKind.Pat else SkaterKind.Sammy
                val shirt = generator.element(ColorChoice.clothes)!!
                val pants = generator.element(ColorChoice.clothes)!!
                val hat = if (generator.bool()) generator.element(ColorChoice.clothes) else null
                val board = generator.element(ColorChoice.clothes)!!
                one(CharacterArt.standing(Outfit(kind, shirt, pants, hat, board)), x = -4.0)
            }
            FeatureStyle.Dog -> two { dog(it) }
            FeatureStyle.Cart -> one(cart())
            FeatureStyle.BrokenCar -> one(brokenCar())
            FeatureStyle.Car -> {
                val colors = listOf(PixelColor(0xD82800), PixelColor(0x0058F8), PixelColor(0xF0F0F0), PixelColor(0x00A844), PixelColor(0xF8B800))
                one(car(generator.element(colors)!!))
            }
            FeatureStyle.Train -> one(train(width))
            FeatureStyle.Penguin -> two { penguin(it) }
            FeatureStyle.Goat -> two { goat(it) }
            FeatureStyle.Hole -> one(manhole(width), y = -(manholeHeight / 2).toDouble())
            FeatureStyle.QuarterPipe -> one(quarterPipe(feature))
            FeatureStyle.Bubbler -> one(bubbler())
            FeatureStyle.MillEnds -> one(millEnds(), y = -2.0)
            FeatureStyle.ZooTrain -> two { zooTrain(it) }
            FeatureStyle.MiniBike -> {
                val person = Person.random(generator)
                two(-1.0) { PeopleArt.miniBiker(person, it) }
            }
        }
    }

    // Things to grind

    fun rail(width: Int, height: Int, post: PixelColor): PixelCanvas {
        val canvas = PixelCanvas(width, height)
        var postX = 2
        while (postX < width - 2) {
            canvas.fill(postX, 0, 2, height - 2, post)
            postX += 30
        }
        canvas.fill(width - 4, 0, 2, height - 2, post)
        canvas.fill(0, height - 2, width, 1, Palette.steel)
        canvas.fill(0, height - 1, width, 1, Palette.white)
        return canvas
    }

    fun ledge(width: Int, height: Int): PixelCanvas {
        val canvas = PixelCanvas(width, height, fill = Palette.grey)
        canvas.fill(0, height - 2, width, 2, Palette.lightGrey)
        canvas.fill(0, height - 1, width, 1, Palette.white)
        canvas.fill(0, 0, width, 1, Palette.darkGrey)
        canvas.fill(0, 0, 1, height, Palette.darkGrey)
        canvas.fill(width - 1, 0, 1, height, Palette.darkGrey)
        return canvas
    }

    /** A park bench: you grind the seat; the backrest is just for looks. */
    fun bench(width: Int): PixelCanvas {
        val canvas = PixelCanvas(width, 17)
        val wood = PixelColor(0x9C6430)
        val dark = PixelColor(0x6C4420)
        val iron = PixelColor(0x2C2C2C)
        for (legX in listOf(2, width - 4)) {
            canvas.fill(legX, 0, 2, 7, iron)
            canvas.fill(legX + 1, 9, 1, 8, iron)
        }
        canvas.fill(0, 7, width, 2, wood)
        canvas.fill(0, 7, width, 1, dark)
        canvas.fill(1, 12, width - 2, 2, wood)
        canvas.fill(1, 15, width - 2, 2, wood)
        return canvas
    }

    fun curb(width: Int, height: Int): PixelCanvas {
        val canvas = PixelCanvas(width, height, fill = PixelColor(0xC0C0C0))
        canvas.fill(0, height - 1, width, 1, Palette.white)
        canvas.fill(0, 0, width, 1, Palette.grey)
        for (x in 0 until width step 24) canvas.fill(x, 0, 1, height, Palette.grey)
        return canvas
    }

    /** Skidmore Fountain: a stone basin to grind, with the fountain rising in the middle. */
    fun fountain(width: Int): PixelCanvas {
        val canvas = PixelCanvas(width, 32)
        val stone = PixelColor(0xB8A888)
        val light = PixelColor(0xD8CCAC)
        val dark = PixelColor(0x8C7C60)
        val bronze = PixelColor(0x5C4C2C)
        val water = PixelColor(0x88C8F8)
        val mid = width / 2
        // The column, bowl and figures, behind the basin's rim.
        canvas.fill(mid - 3, 12, 6, 9, stone)
        canvas.fill(mid - 8, 20, 16, 2, light)
        canvas.fill(mid - 6, 19, 12, 1, dark)
        canvas.fill(mid - 2, 22, 4, 7, bronze)
        canvas.fill(mid - 1, 29, 2, 3, bronze)
        // Water spilling from the bowl.
        for (step in 0 until 8) {
            canvas[mid - 9 - step / 3, 19 - step] = water
            canvas[mid + 8 + step / 3, 19 - step] = water
        }
        // The basin.
        canvas.fill(0, 0, width, 12, stone)
        canvas.fill(0, 10, width, 2, light)
        canvas.fill(0, 0, width, 1, dark)
        for (x in 6 until width - 4 step 12) canvas.fill(x, 2, 1, 7, dark)
        return canvas
    }

    /** Light rail tracks: ties and two steel rails, low enough to roll over. */
    fun tracks(width: Int): PixelCanvas {
        val canvas = PixelCanvas(width, 3)
        for (x in 0 until width step 6) canvas.fill(x, 0, 3, 1, PixelColor(0x5C3C1C))
        canvas.fill(0, 1, width, 1, Palette.grey)
        canvas.fill(0, 2, width, 1, PixelColor(0xD8D8E0))
        return canvas
    }

    /** A box with a ramp at each end and metal coping on top. */
    fun funbox(width: Int, height: Int): PixelCanvas {
        val canvas = PixelCanvas(width, height)
        val face = PixelColor(0x8C8C94)
        val ramp = PixelColor(0xA4A4AC)
        val rampLength = 8
        for (x in 0 until width) {
            val fromEdge = min(x, width - 1 - x)
            val h = if (fromEdge < rampLength) max(1, (fromEdge + 1) * height / rampLength) else height
            canvas.fill(x, 0, 1, h, if (fromEdge < rampLength) ramp else face)
        }
        canvas.fill(rampLength, height - 1, width - rampLength * 2, 1, Palette.white)
        canvas.fill(rampLength, height - 2, width - rampLength * 2, 1, Palette.steel)
        return canvas
    }

    /** A concrete construction barrier with warning stripes. */
    fun barrier(width: Int, height: Int): PixelCanvas {
        val canvas = PixelCanvas(width, height)
        val concrete = PixelColor(0xB8B8B8)
        canvas.fill(0, 0, width, 4, concrete)
        canvas.fill(2, 4, width - 4, height - 4, concrete)
        canvas.fill(2, height - 1, width - 4, 1, Palette.white)
        for (x in 2 until width - 2) {
            for (y in 5 until height - 2) if ((x + y) % 8 < 4) canvas[x, y] = Palette.orange
        }
        canvas.fill(0, 0, width, 1, Palette.grey)
        return canvas
    }

    // Things in the way

    fun cone(width: Int, height: Int): PixelCanvas {
        val canvas = PixelCanvas(width, height)
        canvas.fill(0, 0, width, 1, Palette.darkGrey)
        for (y in 1 until height) {
            val half = max(0, (width.toDouble() / 2 * (1 - (y - 1).toDouble() / height)).toInt())
            val color = if (y == height / 2 || y == height / 2 + 1) Palette.white else Palette.orange
            canvas.fill(width / 2 - half, y, half * 2 + 1, 1, color)
        }
        return canvas
    }

    fun planter(width: Int, height: Int): PixelCanvas {
        val canvas = PixelCanvas(width, height)
        val boxHeight = height * 2 / 3
        canvas.fill(0, 0, width, boxHeight, Palette.brick)
        canvas.fill(0, boxHeight - 1, width, 1, Palette.lightGrey)
        canvas.fill(0, 0, width, 1, Palette.brickDark)
        val generator = SeededGenerator((width * 31 + height).toLong())
        for (x in 0 until width) {
            val top = boxHeight + generator.int(1, height - boxHeight)
            canvas.fill(x, boxHeight, 1, top - boxHeight, Palette.green)
            canvas[x, top - 1] = if (x % 3 == 0) Palette.darkGreen else Palette.green
        }
        return canvas
    }

    /** Angie on a walk, coming toward you. */
    fun dog(frame: Int): PixelCanvas = CharacterArt.walkingDog(frame).canvas(mirrored = true)

    fun cart(): PixelCanvas {
        val canvas = PixelCanvas(16, 13)
        val wire = PixelColor(0xA8A8B4)
        canvas.fill(3, 5, 13, 1, wire)
        canvas.fill(2, 12, 14, 1, wire)
        for (x in 3 until 16 step 2) canvas.fill(x, 5, 1, 7, wire)
        for (y in 7 until 12 step 2) canvas.fill(3, y, 13, 1, wire)
        canvas.fill(0, 12, 3, 1, Palette.red)
        canvas.fill(3, 3, 12, 1, Palette.grey)
        canvas.fill(3, 0, 2, 2, Palette.black)
        canvas.fill(13, 0, 2, 2, Palette.black)
        canvas.fill(4, 2, 1, 1, Palette.grey)
        canvas.fill(14, 2, 1, 1, Palette.grey)
        return canvas
    }

    /** A car up on the curb with a flat tire, a smashed window and rust. */
    fun brokenCar(): PixelCanvas {
        val canvas = PixelCanvas(40, 17)
        val body = PixelColor(0x8C6C4C)
        val rust = PixelColor(0x7C3C1C)
        canvas.fill(0, 3, 40, 7, body)
        canvas.fill(8, 10, 22, 6, body)
        canvas.fill(10, 11, 8, 4, Palette.darkGrey)
        canvas.fill(20, 11, 8, 4, Palette.darkGrey)
        for ((x, y) in listOf(21 to 14, 22 to 13, 23 to 12, 24 to 13, 25 to 11)) canvas[x, y] = Palette.white
        for ((x, y) in listOf(3 to 5, 4 to 6, 15 to 4, 33 to 7, 34 to 6, 27 to 5, 6 to 8)) canvas.fill(x, y, 2, 1, rust)
        canvas.fill(4, 0, 8, 2, Palette.black)
        canvas.fill(28, 0, 7, 4, Palette.black)
        canvas.fill(30, 1, 3, 2, Palette.grey)
        canvas.fill(0, 9, 40, 1, body.darker())
        return canvas
    }

    /** A car driving toward you. */
    fun car(body: PixelColor): PixelCanvas {
        val canvas = PixelCanvas(40, 17)
        canvas.fill(0, 3, 40, 7, body)
        canvas.fill(9, 10, 22, 6, body)
        canvas.fill(11, 11, 8, 4, PixelColor(0xA4E4FC))
        canvas.fill(21, 11, 8, 4, PixelColor(0xA4E4FC))
        canvas.fill(0, 6, 2, 2, Palette.window)
        canvas.fill(38, 6, 2, 2, Palette.red)
        canvas.fill(0, 9, 40, 1, body.darker())
        for (wheelX in listOf(5, 28)) {
            canvas.fill(wheelX, 0, 7, 4, Palette.black)
            canvas.fill(wheelX + 2, 1, 3, 2, Palette.grey)
        }
        return canvas
    }

    /** A light rail train coming down the tracks. */
    fun train(width: Int): PixelCanvas {
        val canvas = PixelCanvas(width, 46)
        val shell = PixelColor(0xE4E4EC)
        val roof = PixelColor(0xA8A8B4)
        val band = PixelColor(0x1C58B8)
        canvas.fill(0, 4, width, 32, shell)
        canvas.fill(0, 36, width, 3, roof)
        canvas.fill(0, 12, width, 4, band)
        canvas.fill(0, 16, width, 1, Palette.yellow)
        // The cab's sloped nose at the front (left), and its headlight.
        for (y in 26 until 39) canvas.erase(0, y, (y - 26) / 2, 1)
        canvas.fill(1, 7, 3, 3, Palette.window)
        canvas.fill(6, 20, 10, 10, Palette.darkGrey)
        // Windows and doors along the side.
        for (x in 22 until width - 10 step 14) {
            canvas.fill(x, 20, 10, 10, Palette.black)
            canvas.fill(x + 1, 27, 3, 2, PixelColor(0x88B8F8))
        }
        for (x in 50 until width - 20 step 56) {
            canvas.fill(x, 4, 8, 26, Palette.grey)
            canvas.fill(x + 4, 4, 1, 26, Palette.darkGrey)
        }
        // Bogies and wheels.
        for (x in listOf(16, width - 40)) canvas.fill(x, 0, 24, 4, Palette.darkGrey)
        // The pantograph up to the wires.
        val pantographX = width / 2
        for (step in 0 until 6) {
            canvas[pantographX + step, 39 + step] = Palette.black
            canvas[pantographX + 11 - step, 39 + step] = Palette.black
        }
        canvas.fill(pantographX - 2, 45, 16, 1, Palette.black)
        return canvas
    }

    fun penguin(frame: Int): PixelCanvas {
        val rows = listOf(
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
            if (frame == 0) ".yy..yy." else "..yy.yy.",
        )
        return PixelSprite(rows, mapOf('n' to Palette.black, 'w' to Palette.white, 'y' to Palette.orange)).canvas()
    }

    fun goat(frame: Int): PixelCanvas {
        val rows = listOf(
            ".kk.............",
            "kk.k............",
            ".wwww...........",
            "ewwww...........",
            ".wwwwwwwwwwwwww.",
            "..kwwwwwwwwwwwwk",
            "...wwwwwwwwwwww.",
            "...wwwwwwwwwwww.",
            "....wwwwwwwwww..",
        ) + if (frame == 0) listOf(
            "....w.w....w.w..",
            "....w.w....w.w..",
            "...w...w..w...w.",
            "...k...k..k...k.",
        ) else listOf(
            "....w.w....w.w..",
            "....w.w....w.w..",
            "....w.w....w.w..",
            "....k.k....k.k..",
        )
        return PixelSprite(rows, mapOf('w' to PixelColor(0xE8E0D0), 'k' to PixelColor(0x6C5C44), 'e' to Palette.black)).canvas()
    }

    /** An open manhole: an iron rim round a dark shaft with a ladder rung, and the cover
     *  slid off to the side. The opening is the hole you fall in; the cover is just lying there. */
    fun manhole(width: Int): PixelCanvas {
        // Seen at an angle, so a flat oval; the cover is the same disc, lying just behind.
        val height = manholeHeight
        val coverX = width - 2
        val canvas = PixelCanvas(coverX + width, height + 2)
        val iron = PixelColor(0x5C5C64)
        val ironDark = PixelColor(0x3C3C44)
        val ironLight = PixelColor(0x8C8C94)
        ellipse(canvas, coverX, 2, width, height, ironDark)
        ellipse(canvas, coverX + 1, 3, width - 2, height - 2, iron)
        for (gx in coverX + 3 until coverX + width - 3 step 2) canvas[gx, 3 + (gx / 2) % 2] = ironLight
        // The opening: dark rim, a lighter iron ring, the shaft and a ladder rung.
        ellipse(canvas, 0, 0, width, height, ironDark)
        ellipse(canvas, 1, 1, width - 2, height - 1, ironLight)
        ellipse(canvas, 2, 1, width - 4, height - 2, PixelColor(0x0C0C0C))
        canvas.fill(width / 2 - 2, height / 2, 4, 1, Palette.grey)
        return canvas
    }

    /** How tall a manhole's oval is, in game pixels. */
    const val manholeHeight = 5

    /** A concrete quarter pipe facing you, curving up to steel coping at the lip. */
    fun quarterPipe(feature: Feature): PixelCanvas {
        val width = feature.length.toInt()
        val canvas = PixelCanvas(width + 3, feature.height.toInt() + 2)
        val concrete = PixelColor(0x9C9CA4)
        val shade = PixelColor(0x7C7C84)
        val face = PixelColor(0xB4B4BC)
        for (column in 0 until width) {
            val h = feature.rampHeight(column + 0.5, 0.0).toInt()
            canvas.fill(column, 0, 1, h + 1, concrete)
            // A light riding surface, with a shadow just under it.
            canvas[column, h] = face
            if (h > 1) canvas[column, h - 1] = shade
        }
        // The deck behind the lip, and the coping on it.
        canvas.fill(width, 0, 3, feature.height.toInt() + 1, shade)
        canvas.fill(width - 2, feature.height.toInt() + 1, 5, 1, Palette.steel)
        return canvas
    }

    /** A Benson Bubbler: a bronze column with four bowls, water bubbling up from each. */
    fun bubbler(): PixelCanvas {
        val canvas = PixelCanvas(10, 12)
        val bronze = PixelColor(0x8C6C34)
        val light = PixelColor(0xB8944C)
        val water = PixelColor(0x9CD0F8)
        canvas.fill(2, 0, 6, 2, bronze)
        canvas.fill(4, 2, 2, 6, bronze)
        canvas.fill(3, 4, 1, 2, light)
        canvas.fill(0, 8, 10, 2, bronze)
        canvas.fill(0, 9, 10, 1, light)
        for (bowl in listOf(1, 4, 8)) canvas[bowl, 10] = water
        canvas[4, 11] = water
        canvas[8, 11] = water
        return canvas
    }

    /** Mill Ends Park: a ring of curb the size of a dinner plate, a tiny tree, a tiny sign. */
    fun millEnds(): PixelCanvas {
        val canvas = PixelCanvas(10, 9)
        ellipse(canvas, 0, 0, 10, 4, PixelColor(0xA8A8A0))
        ellipse(canvas, 1, 1, 8, 2, PixelColor(0x4C7C2C))
        canvas.fill(4, 2, 1, 3, Palette.brown)
        canvas.fill(3, 5, 3, 3, Palette.green)
        canvas[4, 8] = Palette.darkGreen
        canvas.fill(7, 2, 1, 3, Palette.darkGrey)
        canvas.fill(7, 5, 2, 1, Palette.white)
        return canvas
    }

    /** The zoo train: a little green steam engine pulling open cars full of kids. */
    fun zooTrain(frame: Int): PixelCanvas {
        val canvas = PixelCanvas(56, 18)
        val green = PixelColor(0x2C7C3C)
        val red = PixelColor(0xC82818)
        val gold = PixelColor(0xE8B830)
        val wheel = Palette.black
        // The engine, at the front (left, coming toward you).
        canvas.fill(2, 4, 12, 6, green)
        canvas.fill(2, 6, 12, 1, gold)
        canvas.fill(12, 4, 6, 11, green)
        canvas.fill(13, 10, 4, 3, PixelColor(0x88B8F8))
        canvas.fill(11, 15, 8, 1, red)
        canvas.fill(4, 10, 2, 4, Palette.black)
        canvas.fill(3, 14, 4, 1, Palette.black)
        canvas.fill(0, 2, 3, 2, red)
        canvas[0, 4] = red
        // A puff of smoke that drifts with the frames.
        canvas.fill(3 + frame, 15, 3, 2, Palette.lightGrey)
        // Two open cars.
        for (car in 0 until 2) {
            val cx = 20 + car * 18
            canvas.fill(cx, 4, 16, 5, red)
            canvas.fill(cx, 8, 16, 1, gold)
            for ((index, kid) in listOf(cx + 2, cx + 7, cx + 12).withIndex()) {
                val colors = listOf(Palette.skin, PixelColor(0x9C5C34), PixelColor(0xF0C098))
                canvas.fill(kid, 9, 2, 2, colors[(index + car) % 3])
                canvas.fill(kid, 11, 2, 1, listOf(Palette.hair, Palette.yellow, PixelColor(0x1C1008))[(index + car + frame) % 3])
            }
            canvas.fill(cx - 2, 4, 2, 1, Palette.darkGrey)
        }
        for (wx in listOf(4, 9, 14, 22, 31, 40, 49)) {
            canvas.fill(wx, 0, 3, 3, wheel)
            canvas[wx + 1, 1] = if (frame == 0) Palette.grey else wheel
        }
        return canvas
    }

    /** A filled ellipse inside the given box. */
    private fun ellipse(canvas: PixelCanvas, x: Int, y: Int, width: Int, height: Int, color: PixelColor) {
        val a = width.toDouble() / 2
        val b = height.toDouble() / 2
        for (row in 0 until height) {
            val dy = (row + 0.5 - b) / b
            val half = a * sqrt(1 - dy * dy)
            val left = (a - half).rounded().toInt()
            val right = (a + half).rounded().toInt()
            canvas.fill(x + left, y + row, max(0, right - left), 1, color)
        }
    }

    fun finishLine(height: Int): PixelCanvas {
        val canvas = PixelCanvas(6, height)
        for (y in 0 until height) {
            for (x in 0 until 6) canvas[x, y] = if (((x / 3) + (y / 3)) % 2 == 0) Palette.white else Palette.black
        }
        return canvas
    }
}

object LetterArt {
    /** A round gold token with the letter on it. Letters already found are faded. */
    fun token(letter: Char, found: Boolean): PixelCanvas {
        val canvas = PixelCanvas(11, 11)
        val fill = if (found) PixelColor(0xFCFCFC, alpha = 110) else Palette.yellow
        val rim = if (found) PixelColor(0x7C7C7C, alpha = 110) else Palette.gold
        val insets = listOf(3, 1, 1, 0, 0, 0, 0, 0, 1, 1, 3)
        for (y in 0 until 11) {
            val inset = insets[y]
            canvas.fill(inset, y, 11 - inset * 2, 1, rim)
            if (y in 1..9) canvas.fill(inset + 1, y, 9 - inset * 2, 1, fill)
        }
        PixelText.draw(
            letter.toString(), canvas, (11 - PixelFont.width(letter.toString())) / 2, 2,
            if (found) PixelColor(0x545454, alpha = 140) else Palette.black,
        )
        return canvas
    }
}
