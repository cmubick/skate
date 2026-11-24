//
//  PixelArt.kt
//
//  The palette, and everything the game draws, made in code from little
//  strings of pixels. Ported from skate/UI/PixelArt.swift.
//
//  Plain Kotlin with no Android in it, so the tests can check every picture
//  against the iOS one. The game turns a canvas into something it can draw
//  with `Texture` (game/Scene.kt).
//

package com.tuesdaygames.skate.art

import com.tuesdaygames.skate.rules.ColorChoice
import com.tuesdaygames.skate.rules.PixelFont

// Colors

data class PixelColor(val r: Int, val g: Int, val b: Int, val a: Int = 255) {
    constructor(hex: Int, alpha: Int = 255) : this((hex shr 16) and 0xFF, (hex shr 8) and 0xFF, hex and 0xFF, alpha)
    constructor(choice: ColorChoice) : this(choice.hex)

    /** The same color in shadow. */
    fun darker(amount: Double = 0.65) = PixelColor((r * amount).toInt(), (g * amount).toInt(), (b * amount).toInt(), a)

    /** As Android stores it: alpha, red, green, blue in one Int. */
    val argb: Int get() = (a shl 24) or (r shl 16) or (g shl 8) or b

    companion object {
        val clear = PixelColor(0, alpha = 0)
    }
}

/** One fixed palette for the whole game, NES style. Shared with the Angie game later. */
object Palette {
    val black = PixelColor(0x101010)
    val white = PixelColor(0xFCFCFC)
    val lightGrey = PixelColor(0xBCBCBC)
    val grey = PixelColor(0x7C7C7C)
    val darkGrey = PixelColor(0x545454)
    val asphalt = PixelColor(0x3C3C3C)

    val sky = PixelColor(0x6888FC)
    val farCity = PixelColor(0x4C5CB8)
    val farCityLight = PixelColor(0x8CA4FC)
    val window = PixelColor(0xF8D878)
    val brick = PixelColor(0x883C24)
    val brickDark = PixelColor(0x5C2414)

    val yellow = PixelColor(0xF8B800)
    val gold = PixelColor(0xAC7C00)
    val orange = PixelColor(0xF83800)
    val red = PixelColor(0xD82800)
    val blue = PixelColor(0x0058F8)
    val denim = PixelColor(0x24489C)
    val green = PixelColor(0x00A844)
    val darkGreen = PixelColor(0x005800)
    val brown = PixelColor(0x7C3C00)
    val hair = PixelColor(0x503000)
    val skin = PixelColor(0xE4A06C)

    /** A dark brown line around faces, so heads read as heads. */
    val outline = PixelColor(0x6C2C10)
    val shirt = PixelColor(0x1C1C1C)
    val khaki = PixelColor(0xC8A870)
    val khakiDark = PixelColor(0x907444)
    val steel = PixelColor(0xA4E4FC)

    /** A see-through dark for shadows on the ground. */
    val shadow = PixelColor(0x000000, alpha = 90)
}

// Canvas

/**
 * A small picture. `y` counts up from the bottom, as in SpriteKit. Pixels are
 * kept top row first as Android ARGB Ints (not premultiplied), ready for a Bitmap.
 */
class PixelCanvas(width: Int, height: Int, fill: PixelColor = PixelColor.clear) {
    val width = maxOf(1, width)
    val height = maxOf(1, height)
    val pixels = IntArray(this.width * this.height)

    init {
        if (fill != PixelColor.clear) fill(0, 0, this.width, this.height, fill)
    }

    operator fun set(x: Int, y: Int, color: PixelColor) {
        if (x < 0 || x >= width || y < 0 || y >= height || color.a <= 0) return
        pixels[(height - 1 - y) * width + x] = color.argb
    }

    /** The pixel at (x, y), counting up from the bottom. */
    operator fun get(x: Int, y: Int): Int = pixels[(height - 1 - y) * width + x]

    fun fill(x: Int, y: Int, width: Int, height: Int, color: PixelColor) {
        for (row in y until y + maxOf(0, height)) {
            for (column in x until x + maxOf(0, width)) set(column, row, color)
        }
    }

    /** Makes pixels see-through again. */
    fun erase(x: Int, y: Int, width: Int, height: Int) {
        for (row in maxOf(0, y) until minOf(this.height, y + maxOf(0, height))) {
            for (column in maxOf(0, x) until minOf(this.width, x + maxOf(0, width))) {
                pixels[(this.height - 1 - row) * this.width + column] = 0
            }
        }
    }

    /** Draws another canvas with its bottom-left corner at (x, y). See-through pixels are skipped. */
    fun draw(other: PixelCanvas, x: Int, y: Int) {
        for (row in 0 until other.height) {
            for (column in 0 until other.width) {
                val px = x + column
                val py = y + row
                if (px < 0 || px >= width || py < 0 || py >= height) continue
                val color = other.pixels[(other.height - 1 - row) * other.width + column]
                if (color ushr 24 == 0) continue
                pixels[(height - 1 - py) * width + px] = color
            }
        }
    }

    /** Draws a sprite with its bottom-left corner at (x, y). */
    fun draw(sprite: PixelSprite, x: Int, y: Int, mirrored: Boolean = false) {
        for ((rowIndex, row) in sprite.rows.withIndex()) {
            val py = y + sprite.height - 1 - rowIndex
            for ((columnIndex, key) in row.withIndex()) {
                val color = sprite.colors[key] ?: continue
                val px = if (mirrored) x + sprite.width - 1 - columnIndex else x + columnIndex
                set(px, py, color)
            }
        }
    }
}

/** A sprite drawn as rows of characters, top row first. Each character is looked up
 *  in `colors`; anything not in it (like ".") is see-through. Short rows are padded. */
class PixelSprite(rows: List<String>, val colors: Map<Char, PixelColor>) {
    val width: Int = rows.maxOfOrNull { it.length } ?: 0
    val rows: List<String> = rows.map { it.padEnd(width, '.') }
    val height: Int get() = rows.size

    fun canvas(mirrored: Boolean = false): PixelCanvas {
        val canvas = PixelCanvas(width, height)
        canvas.draw(this, 0, 0, mirrored)
        return canvas
    }
}

// Text

object PixelText {
    private fun glyphSprite(character: Char, ink: PixelColor) =
        PixelSprite(PixelFont.glyph(character).map { it.replace('#', 'x') }, mapOf('x' to ink))

    /** The text drawn in `color` with a dark drop shadow, so it reads over anything. */
    fun canvas(text: String, color: PixelColor = Palette.white): PixelCanvas {
        val upper = text.uppercase()
        // The shadow sits straight below each letter, so it never fills the gap between them.
        val canvas = PixelCanvas(PixelFont.width(upper), PixelFont.glyphHeight + 1)
        for ((pass, ink) in listOf(1 to Palette.black, 0 to color)) {
            var x = 0
            for (character in upper) {
                canvas.draw(glyphSprite(character, ink), x, 1 - pass)
                x += PixelFont.glyph(character)[0].length + PixelFont.gap
            }
        }
        return canvas
    }

    /** Draws text into a canvas, with no shadow. */
    fun draw(text: String, canvas: PixelCanvas, x: Int, y: Int, color: PixelColor) {
        var cursor = x
        for (character in text.uppercase()) {
            canvas.draw(glyphSprite(character, color), cursor, y)
            cursor += PixelFont.glyph(character)[0].length + PixelFont.gap
        }
    }

    /** Text in several colors side by side, each with the drop shadow: say, found
     *  letters in gold and missing ones in grey. */
    fun canvas(runs: List<Pair<String, PixelColor>>): PixelCanvas {
        val text = runs.joinToString("") { it.first }
        val canvas = PixelCanvas(PixelFont.width(text), PixelFont.glyphHeight + 1)
        for (pass in listOf(1, 0)) {
            var x = 0
            for ((part, color) in runs) {
                draw(part, canvas, x, 1 - pass, if (pass == 1) Palette.black else color)
                x += PixelFont.width(part) + PixelFont.gap
            }
        }
        return canvas
    }
}
