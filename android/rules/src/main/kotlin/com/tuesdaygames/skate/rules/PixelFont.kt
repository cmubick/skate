//
//  PixelFont.kt
//
//  A 7-pixel-high font, 5 pixels wide for most letters: capitals, digits and a
//  little punctuation. Big enough to read at a glance mid-run. Ported from the
//  text part of skate/UI/PixelArt.swift.
//
//  Only the letter shapes and their sizes live here, so the rules' tests can
//  check that goal names fit the screen. The app draws them (art/PixelArt.kt).
//

package com.tuesdaygames.skate.rules

import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

object PixelFont {
    const val glyphHeight = 7

    /** Space between letters. */
    const val gap = 1

    /** Two bars, for the pause button. */
    const val pauseSymbol = "⏸"

    /** The biggest scale, up to `maxScale`, that fits text `width` game pixels wide into
     *  `available` game pixels. Only scales where each font pixel is a whole number of
     *  screen pixels, so the letters stay sharp (1.5x is 18 screen pixels at 12x). */
    fun fittingScale(width: Int, available: Double, maxScale: Double, screenPixelsPerPixel: Int): Double {
        val steps = max(1, screenPixelsPerPixel).toDouble()
        if (width <= 0) return maxScale
        val fit = floor(available * steps / width)
        return max(1.0, min(maxScale * steps, fit)) / steps
    }

    private val glyphs: Map<Char, List<String>> = mapOf(
        'A' to listOf(".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"),
        'B' to listOf("####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."),
        'C' to listOf(".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."),
        'D' to listOf("####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."),
        'E' to listOf("#####", "#....", "#....", "####.", "#....", "#....", "#####"),
        'F' to listOf("#####", "#....", "#....", "####.", "#....", "#....", "#...."),
        'G' to listOf(".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"),
        'H' to listOf("#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"),
        'I' to listOf("###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"),
        'J' to listOf("..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."),
        'K' to listOf("#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"),
        'L' to listOf("#....", "#....", "#....", "#....", "#....", "#....", "#####"),
        'M' to listOf("#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"),
        'N' to listOf("#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"),
        'O' to listOf(".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."),
        'P' to listOf("####.", "#...#", "#...#", "####.", "#....", "#....", "#...."),
        'Q' to listOf(".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"),
        'R' to listOf("####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"),
        'S' to listOf(".####", "#....", "#....", ".###.", "....#", "....#", "####."),
        'T' to listOf("#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."),
        'U' to listOf("#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."),
        'V' to listOf("#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."),
        'W' to listOf("#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."),
        'X' to listOf("#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"),
        'Y' to listOf("#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."),
        'Z' to listOf("#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"),
        '0' to listOf(".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."),
        '1' to listOf("..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."),
        '2' to listOf(".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"),
        '3' to listOf("#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."),
        '4' to listOf("...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."),
        '5' to listOf("#####", "#....", "####.", "....#", "....#", "#...#", ".###."),
        '6' to listOf("..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."),
        '7' to listOf("#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."),
        '8' to listOf(".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."),
        '9' to listOf(".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."),
        '+' to listOf(".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."),
        '-' to listOf("...", "...", "...", "###", "...", "...", "..."),
        '!' to listOf("#", "#", "#", "#", "#", ".", "#"),
        '\'' to listOf("#", "#", ".", ".", ".", ".", "."),
        ',' to listOf("..", "..", "..", "..", "..", ".#", "#."),
        '$' to listOf("..#..", ".####", "#.#..", ".###.", "..#.#", "####.", "..#.."),
        ':' to listOf(".", ".", "#", ".", ".", "#", "."),
        '.' to listOf(".", ".", ".", ".", ".", ".", "#"),
        '/' to listOf("....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."),
        '?' to listOf(".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."),
        '<' to listOf("...#", "..#.", ".#..", "#...", ".#..", "..#.", "...#"),
        '>' to listOf("#...", ".#..", "..#.", "...#", "..#.", ".#..", "#..."),
        // The pause symbol: two solid bars.
        '⏸' to listOf("##.##", "##.##", "##.##", "##.##", "##.##", "##.##", "##.##"),
        ' ' to listOf("...", "...", "...", "...", "...", "...", "..."),
    )

    fun glyph(character: Char): List<String> = glyphs[character] ?: glyphs.getValue('?')

    fun width(text: String): Int = max(1, text.fold(0) { sum, c -> sum + glyph(c)[0].length + gap } - gap)

    /** Every glyph, for checking they're all the right size. */
    val allGlyphs: Collection<List<String>> get() = glyphs.values
}
