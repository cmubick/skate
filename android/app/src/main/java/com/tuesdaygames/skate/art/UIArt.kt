//
//  UIArt.kt
//
//  The menus' little pictures: the tip jar, the music and sound icons, the
//  padlock, button boxes and panels. Ported from `UIArt` in skate/UI/Menus.swift.
//

package com.tuesdaygames.skate.art

object UIArt {
    /** A glass tip jar with coins in it. */
    fun tipJar(): PixelCanvas = PixelSprite(
        listOf(
            ".lllllll.",
            "..lllll..",
            ".g.....g.",
            "g.......g",
            "g...o...g",
            "g..ooo..g",
            "g.ooooo.g",
            "gooooooog",
            ".ggggggg.",
        ),
        mapOf('l' to Palette.lightGrey, 'g' to PixelColor(0x9CD0F8), 'o' to Palette.yellow),
    ).canvas()

    /** A music note, crossed out in red when music is off. */
    fun musicIcon(on: Boolean): PixelCanvas = icon(
        listOf(
            "....###",
            "....#.#",
            "....#.#",
            "....#..",
            "..###..",
            ".####..",
            "..##...",
        ),
        on,
    )

    /** A speaker with sound coming out, crossed out in red when sound is off. */
    fun soundIcon(on: Boolean): PixelCanvas = icon(
        if (on) listOf(
            "...#...",
            "..##.#.",
            "####..#",
            "####.##",
            "####..#",
            "..##.#.",
            "...#...",
        ) else listOf(
            "...#...",
            "..##...",
            "####...",
            "####...",
            "####...",
            "..##...",
            "...#...",
        ),
        on,
    )

    private fun icon(rows: List<String>, on: Boolean): PixelCanvas {
        val canvas = PixelCanvas(7, 7)
        canvas.draw(PixelSprite(rows, mapOf('#' to if (on) Palette.white else PixelColor(0x9C9C9C))), 0, 0)
        if (!on) {
            // A red slash from corner to corner.
            for (i in 0 until 7) canvas[i, 6 - i] = Palette.red
        }
        return canvas
    }

    /** A little padlock, for things in the full game. */
    fun padlock(): PixelCanvas = PixelSprite(
        listOf(
            "..###..",
            ".#...#.",
            ".#...#.",
            "#######",
            "###.###",
            "###.###",
            "#######",
        ),
        mapOf('#' to Palette.yellow),
    ).canvas()

    /** A rounded box with a light rim. */
    fun box(width: Int, height: Int, fill: PixelColor): PixelCanvas {
        val canvas = PixelCanvas(width, height)
        canvas.fill(1, 0, width - 2, height, Palette.black)
        canvas.fill(0, 1, width, height - 2, Palette.black)
        canvas.fill(1, 1, width - 2, height - 2, fill)
        canvas.fill(1, height - 2, width - 2, 1, PixelColor(0xFCFCFC, alpha = 90))
        return canvas
    }

    /** A see-through dark panel to sit text on. */
    fun panel(width: Int, height: Int): PixelCanvas {
        val canvas = PixelCanvas(width, height)
        canvas.fill(1, 0, width - 2, height, PixelColor(0x000000, alpha = 150))
        canvas.fill(0, 1, width, height - 2, PixelColor(0x000000, alpha = 150))
        return canvas
    }
}
