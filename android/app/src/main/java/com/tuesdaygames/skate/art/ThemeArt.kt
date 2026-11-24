//
//  ThemeArt.kt
//
//  Each spot's sky, backdrops and ground, drawn in code. Backdrops repeat
//  sideways and scroll slower than the street to give depth.
//  Ported from skate/UI/ThemeArt.swift.
//

package com.tuesdaygames.skate.art

import com.tuesdaygames.skate.rules.PixelFont
import com.tuesdaygames.skate.rules.SeededGenerator
import com.tuesdaygames.skate.rules.Theme
import com.tuesdaygames.skate.rules.Tuning
import com.tuesdaygames.skate.rules.rounded
import kotlin.math.PI
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/** One backdrop layer: a repeating picture, how fast it scrolls, and how high above
 *  the back sidewalk it sits. */
class BackdropLayer(val canvas: PixelCanvas, val factor: Double, val lift: Double = 0.0)

class ThemeLook(val sky: PixelColor, val layers: List<BackdropLayer>, val ground: PixelCanvas)

object StreetArt {
    /** Feet stand on these lines, in game pixels from the bottom of the screen. */
    fun baseline(lane: Double): Double = 15 + (2 - lane) * Tuning.laneSpacing

    /** The top of the back sidewalk, where the backdrops start. */
    const val groundTop = 54

    /** A soft oval shadow on the ground. */
    fun shadow(width: Int = 18): PixelCanvas {
        val canvas = PixelCanvas(width, 2)
        canvas.fill(1, 0, width - 2, 2, Palette.shadow)
        canvas.fill(0, 1, width, 1, Palette.shadow)
        return canvas
    }
}

object ThemeArt {
    fun look(theme: Theme): ThemeLook = when (theme) {
        Theme.Downtown -> ThemeLook(
            Palette.sky,
            listOf(BackdropLayer(skyline(), 0.2), BackdropLayer(buildings(), 0.5)),
            street(Sidewalk.Slabs),
        )
        Theme.Skidmore -> ThemeLook(
            PixelColor(0x7C98D8),
            listOf(BackdropLayer(overpass(), 0.3), BackdropLayer(oldTown(), 0.5)),
            street(Sidewalk.Bricks),
        )
        Theme.Burnside -> ThemeLook(
            PixelColor(0x24242C),
            listOf(BackdropLayer(bridgeUnderside(), 0.25), BackdropLayer(skateparkWalls(), 0.6)),
            skateparkConcrete(),
        )
        Theme.NorthPortland -> ThemeLook(
            PixelColor(0x88B8F8),
            listOf(BackdropLayer(stJohnsBridge(), 0.15), BackdropLayer(foodCartsAndTrees(), 0.5)),
            street(Sidewalk.GrassEdge),
        )
        Theme.Waterfront -> ThemeLook(
            PixelColor(0x78A8F0),
            listOf(
                BackdropLayer(mountHood(), 0.04, lift = 11.0),
                BackdropLayer(cityAcrossTheRiver(), 0.12, lift = 11.0),
                BackdropLayer(river(), 0.6),
            ),
            esplanade(),
        )
        Theme.ZooBomb -> ThemeLook(
            PixelColor(0xA4C8E8),
            listOf(BackdropLayer(forestedHills(), 0.15), BackdropLayer(zooWoods(), 0.55)),
            zooRoad(),
        )
    }

    // Grounds

    enum class Sidewalk { Slabs, Bricks, GrassEdge }

    /** Sidewalk, street and sidewalk. The front and middle lanes are in the street,
     *  the back lane on the far sidewalk. */
    fun street(sidewalk: Sidewalk, width: Int = 64): PixelCanvas {
        val top = StreetArt.groundTop
        val canvas = PixelCanvas(width, top)
        // Near sidewalk.
        canvas.fill(0, 0, width, 7, Palette.lightGrey)
        for (x in 0 until width step 16) canvas.fill(x, 0, 1, 7, Palette.grey)
        // Near curb and gutter.
        canvas.fill(0, 7, width, 2, Palette.white)
        canvas.fill(0, 9, width, 1, Palette.grey)
        // Street, with a dashed line between the front and middle lanes.
        canvas.fill(0, 10, width, 27, Palette.asphalt)
        for (x in 0 until width step 16) canvas.fill(x, 22, 8, 1, Palette.yellow)
        // Far curb and the back sidewalk.
        canvas.fill(0, 37, width, 1, Palette.grey)
        canvas.fill(0, 38, width, 2, Palette.white)
        when (sidewalk) {
            Sidewalk.Slabs -> {
                canvas.fill(0, 40, width, top - 40, Palette.lightGrey)
                for (x in 8 until width step 16) canvas.fill(x, 40, 1, top - 40, Palette.grey)
            }
            Sidewalk.Bricks -> {
                canvas.fill(0, 40, width, top - 40, PixelColor(0xA84C34))
                for (row in 0 until (top - 40) / 3) {
                    val y = 40 + row * 3
                    canvas.fill(0, y, width, 1, PixelColor(0x7C3020))
                    for (x in (if (row % 2 == 0) 0 else 4) until width step 8) {
                        canvas[x, y + 1] = PixelColor(0x7C3020)
                        canvas[x, y + 2] = PixelColor(0x7C3020)
                    }
                }
            }
            Sidewalk.GrassEdge -> {
                canvas.fill(0, 40, width, top - 44, Palette.lightGrey)
                for (x in 8 until width step 16) canvas.fill(x, 40, 1, top - 44, Palette.grey)
                canvas.fill(0, top - 4, width, 4, Palette.green)
                for (x in 1 until width step 3) canvas[x, top - 1] = Palette.darkGreen
            }
        }
        canvas.fill(0, top - 1, width, 1, if (sidewalk == Sidewalk.GrassEdge) Palette.darkGreen else Palette.grey)
        return canvas
    }

    /** Under the bridge: concrete everywhere, with expansion joints and stains. */
    fun skateparkConcrete(width: Int = 64): PixelCanvas {
        val top = StreetArt.groundTop
        val canvas = PixelCanvas(width, top, fill = PixelColor(0x9C9C9C))
        val generator = SeededGenerator(21)
        for (x in 0 until width step 32) canvas.fill(x, 0, 1, top, PixelColor(0x7C7C7C))
        for (y in listOf(8, 22, 37)) canvas.fill(0, y, width, 1, PixelColor(0x848484))
        repeat(14) {
            val x = generator.intUntil(0, width)
            val y = generator.intUntil(0, top)
            canvas[x, y] = PixelColor(0x8C8C8C)
        }
        // A metal coping edge along the back.
        canvas.fill(0, top - 2, width, 1, Palette.lightGrey)
        canvas.fill(0, top - 1, width, 1, Palette.grey)
        return canvas
    }

    /** The Eastbank esplanade: a boardwalk with a railing along the river, then paths. */
    fun esplanade(width: Int = 64): PixelCanvas {
        val top = StreetArt.groundTop
        val canvas = PixelCanvas(width, top)
        // Grass at the near edge.
        canvas.fill(0, 0, width, 8, Palette.green)
        for (x in 2 until width step 5) canvas[x, 7] = Palette.darkGreen
        // The concrete path: front and middle lanes.
        canvas.fill(0, 8, width, 30, PixelColor(0xB4B0A8))
        for (x in 0 until width step 32) canvas.fill(x, 8, 1, 30, PixelColor(0x949088))
        canvas.fill(0, 22, width, 1, PixelColor(0x949088))
        // The boardwalk: planks.
        canvas.fill(0, 38, width, top - 38, PixelColor(0x9C6C3C))
        for (y in 38 until top step 3) canvas.fill(0, y, width, 1, PixelColor(0x6C4424))
        // The railing along the water.
        canvas.fill(0, top - 3, width, 1, Palette.lightGrey)
        for (x in 0 until width step 8) canvas.fill(x, top - 6, 1, 4, Palette.grey)
        return canvas
    }

    /** Down from the zoo: a park path at the back, then the road with a double yellow line. */
    fun zooRoad(width: Int = 64): PixelCanvas {
        val top = StreetArt.groundTop
        val canvas = PixelCanvas(width, top)
        // Forest floor at the near edge.
        canvas.fill(0, 0, width, 8, PixelColor(0x3C6C24))
        val generator = SeededGenerator(31)
        repeat(20) {
            val x = generator.intUntil(0, width)
            val y = generator.intUntil(0, 8)
            canvas[x, y] = PixelColor(0x5C4424)
        }
        canvas.fill(0, 8, width, 2, PixelColor(0x8C8478))
        // Road.
        canvas.fill(0, 10, width, 27, PixelColor(0x444448))
        canvas.fill(0, 22, width, 1, Palette.yellow)
        canvas.fill(0, 24, width, 1, Palette.yellow)
        canvas.fill(0, 36, width, 1, Palette.white)
        // Park path.
        canvas.fill(0, 37, width, top - 37, PixelColor(0xC8B080))
        repeat(16) {
            val x = generator.intUntil(0, width)
            val y = generator.intUntil(38, top)
            canvas[x, y] = PixelColor(0xA89060)
        }
        canvas.fill(0, top - 3, width, 3, Palette.green)
        return canvas
    }

    // Backdrops: downtown

    /** Far-off towers in haze. */
    fun skyline(width: Int = 384, height: Int = 100): PixelCanvas {
        val canvas = PixelCanvas(width, height)
        val generator = SeededGenerator(7)
        var x = 0
        while (x < width) {
            val w = generator.int(14, 34)
            val h = generator.int(24, height - 10)
            canvas.fill(x, 0, min(w, width - x), h, Palette.farCity)
            if (generator.bool()) canvas.fill(x + w / 2, h, 1, 6, Palette.farCity)
            for (wy in 6 until h - 4 step 6) {
                for (wx in x + 3 until min(x + w - 2, width) step 5) {
                    if (generator.intUntil(0, 4) == 0) canvas[wx, wy] = Palette.farCityLight
                }
            }
            x += w + generator.int(0, 6)
        }
        return canvas
    }

    /** The buildings across the street: plain brick and concrete blocks with lit windows,
     *  and three Portland landmarks among them: the White Stag sign on its rooftop,
     *  Big Pink (the US Bancorp Tower) and Montgomery Park with its red sign.
     *
     *  The landmarks come after a long run of plain buildings: this layer scrolls at half
     *  speed, so on Downtown they go by after the tips along the top have finished. */
    fun buildings(width: Int = 1700, height: Int = 70, landmarksAt: Int = 900): PixelCanvas {
        val canvas = PixelCanvas(width, height)
        val generator = SeededGenerator(11)
        var x = 0
        fun plain(count: Int = 1) {
            repeat(count) {
                if (x >= width) return@repeat
                var w = generator.int(40, 72)
                // Don't leave a sliver at the end.
                if (width - x - w < 30) w = width - x
                plainBuilding(canvas, x, w, generator.int(30, height), generator)
                x += w
            }
        }
        while (x < landmarksAt - 112) plain()
        if (x < landmarksAt) {
            plainBuilding(canvas, x, landmarksAt - x, generator.int(30, height), generator)
            x = landmarksAt
        }
        // Pioneer Courthouse Square and Portlandia come by while the tips are still up:
        // no lettering on them to get lost behind the tips.
        x += Landmarks.pioneerSquare(canvas, x)
        x += Landmarks.portlandBuilding(canvas, x)
        x += whiteStag(canvas, x)
        plain()
        x += bookstore(canvas, x, generator)
        x += bigPink(canvas, x, height)
        plain()
        x += montgomeryPark(canvas, x)
        plain(4)
        return canvas
    }

    private fun plainBuilding(canvas: PixelCanvas, x: Int, w: Int, h: Int, generator: SeededGenerator) {
        val wall = if (generator.bool()) Palette.brick else Palette.grey
        val trim = if (wall == Palette.brick) Palette.brickDark else Palette.darkGrey
        canvas.fill(x, 0, w, h, wall)
        canvas.fill(x, h - 2, w, 2, trim)
        canvas.fill(x, 0, 1, h, trim)
        for (wy in 10 until h - 6 step 9) {
            for (wx in x + 5 until x + w - 6 step 9) {
                val lit = generator.intUntil(0, 3) == 0
                canvas.fill(wx, wy, 4, 5, if (lit) Palette.window else Palette.black)
            }
        }
        canvas.fill(x + w / 2 - 3, 0, 6, 8, Palette.black)
    }

    /** A low brick building in Old Town with the White Stag sign on the roof: PORTLAND
     *  OREGON in red on white, chaser bulbs round the edge, and the leaping stag on top.
     *  Returns its width. */
    fun whiteStag(canvas: PixelCanvas, x: Int): Int {
        // Low enough that the sign and stag pass under the score along the top of the screen.
        val w = 52
        val h = 8
        canvas.fill(x, 0, w, h, Palette.brick)
        canvas.fill(x, h - 2, w, 2, Palette.brickDark)
        canvas.fill(x, 0, 1, h, Palette.brickDark)
        for (wx in x + 4 until x + w - 4 step 6) canvas.fill(wx, 1, 3, 5, Palette.black)
        // The sign, on two legs.
        val signW = 38
        val signH = 15
        val signX = x + (w - signW) / 2
        val signY = h + 2
        canvas.fill(signX + 6, h, 2, 2, Palette.darkGrey)
        canvas.fill(signX + signW - 8, h, 2, 2, Palette.darkGrey)
        canvas.fill(signX, signY, signW, signH, Palette.white)
        for (bx in signX until signX + signW step 2) {
            canvas[bx, signY] = Palette.yellow
            canvas[bx, signY + signH - 1] = Palette.yellow
        }
        for (by in signY until signY + signH step 2) {
            canvas[signX, by] = Palette.yellow
            canvas[signX + signW - 1, by] = Palette.yellow
        }
        val red = PixelColor(0xD82818)
        SignFont.draw("PORTLAND", canvas, signX + signW / 2, signY + 8, red)
        SignFont.draw("OREGON", canvas, signX + signW / 2, signY + 2, red)
        // The stag, leaping across the top.
        val stagRows = listOf(
            "#.#..........",
            ".#...........",
            ".##..........",
            "###.......#..",
            "..#########..",
            "..########...",
            ".#.......##..",
            "#.........##.",
        )
        val stag = PixelSprite(stagRows, mapOf('#' to Palette.white))
        val outline = PixelSprite(stagRows, mapOf('#' to Palette.grey))
        val stagX = signX + (signW - stag.width) / 2
        val stagY = signY + signH - 1
        canvas.draw(outline, stagX + 1, stagY - 1)
        canvas.draw(stag, stagX, stagY)
        return w
    }

    /** A whole block of bookstore: concrete upper floors, shop windows full of books,
     *  and a big red-and-white BOOKS sign on the front. Returns its width. */
    private fun bookstore(canvas: PixelCanvas, x: Int, generator: SeededGenerator): Int {
        val w = 96
        val h = 30
        val concrete = PixelColor(0xA4A49C)
        val trim = PixelColor(0x74746C)
        val stone = PixelColor(0xD8C8A0)
        val glass = PixelColor(0x1C2430)
        canvas.fill(x, 0, w, h, concrete)
        canvas.fill(x, h - 2, w, 2, trim)
        canvas.fill(x, 0, 1, h, trim)
        // Upper floors.
        for (wy in 14 until h - 3 step 5) {
            for (wx in x + 4 until x + w - 4 step 6) canvas.fill(wx, wy, 4, 3, glass)
        }
        // The shop floor: stone, and big windows with rows of book spines inside.
        canvas.fill(x, 0, w, 12, stone)
        canvas.fill(x, 11, w, 1, PixelColor(0xB82818))
        val spines = listOf(
            PixelColor(0xD82800), PixelColor(0x0058F8), PixelColor(0xF8B800), PixelColor(0x00A844),
            PixelColor(0xF0F0F0), PixelColor(0x8C38C8), PixelColor(0xF87800),
        )
        for ((left, right) in listOf(x + 3 to x + 40, x + 56 to x + w - 3)) {
            canvas.fill(left, 2, right - left, 8, glass)
            for (shelfY in listOf(3, 6)) {
                for (bx in left + 1 until right - 1) {
                    if (generator.intUntil(0, 5) == 0) continue
                    val tall = generator.int(2, 3)
                    canvas.fill(bx, shelfY, 1, tall, generator.element(spines)!!)
                }
            }
        }
        // The door, under the sign.
        canvas.fill(x + 43, 0, 10, 10, glass)
        canvas.fill(x + 47, 0, 2, 10, trim)
        // The sign: white with a red border and red letters, on the front of the building.
        val text = "BOOKS"
        val signW = SignFont.width(text) + 8
        val signH = 9
        val signX = x + (w - signW) / 2
        val signY = 16
        canvas.fill(signX - 1, signY - 1, signW + 2, signH + 2, PixelColor(0xB82818))
        canvas.fill(signX, signY, signW, signH, Palette.white)
        SignFont.draw(text, canvas, signX + signW / 2, signY + 2, PixelColor(0xC81810))
        return w
    }

    /** Big Pink: the US Bancorp Tower, pink granite and rose glass in tall stripes,
     *  taller than the screen. Returns its width. */
    private fun bigPink(canvas: PixelCanvas, x: Int, height: Int): Int {
        val w = 44
        val granite = PixelColor(0xC8848C)
        val glass = PixelColor(0x84444C)
        val light = PixelColor(0xE0A4A8)
        canvas.fill(x, 0, w, height, granite)
        // Bevelled corners catch the light on one side and fall into shade on the other.
        canvas.fill(x, 0, 3, height, light)
        canvas.fill(x + w - 3, 0, 3, height, glass)
        for (wx in x + 5 until x + w - 5 step 4) canvas.fill(wx, 10, 2, height - 10, glass)
        for (wy in 13 until height step 4) canvas.fill(x + 4, wy, w - 8, 1, granite)
        // A tall glass lobby at street level.
        canvas.fill(x + 8, 0, w - 16, 8, glass)
        canvas.fill(x + 8, 8, w - 16, 1, light)
        return w
    }

    /** Montgomery Park: a long cream block with a tower in the middle, and the red
     *  MONTGOMERY PARK sign on a frame on the roof. Returns its width. */
    private fun montgomeryPark(canvas: PixelCanvas, x: Int): Int {
        // Low and long, so the sign passes under the score along the top of the screen.
        val w = 140
        val h = 18
        val cream = PixelColor(0xE8DCC0)
        val trim = PixelColor(0xB0A48C)
        val window = PixelColor(0x5C6C7C)
        canvas.fill(x, 0, w, h, cream)
        canvas.fill(x, h - 1, w, 1, trim)
        canvas.fill(x, 0, 1, h, trim)
        for (wy in 4 until h - 3 step 3) {
            for (wx in x + 3 until x + w - 3 step 3) canvas.fill(wx, wy, 2, 2, window)
        }
        // The tower.
        val towerW = 48
        val towerH = 6
        val towerX = x + (w - towerW) / 2
        canvas.fill(towerX, h, towerW, towerH, cream)
        canvas.fill(towerX, h + towerH - 1, towerW, 1, trim)
        for (wx in towerX + 3 until towerX + towerW - 3 step 3) canvas.fill(wx, h + 2, 2, 3, window)
        canvas.fill(x + w / 2 - 4, 0, 8, 6, Palette.black)
        // The sign: red letters on a steel frame.
        val text = "MONTGOMERY PARK"
        val signW = SignFont.width(text)
        val signX = x + (w - signW) / 2
        val signY = h + towerH + 2
        canvas.fill(signX, h + towerH, signW, 1, Palette.darkGrey)
        for (px in signX + 2 until signX + signW step 8) canvas[px, h + towerH + 1] = Palette.darkGrey
        SignFont.draw(text, canvas, x + w / 2, signY, PixelColor(0xE82818))
        return w
    }

    // Backdrops: Skidmore Fountain

    /** The bridge approach overhead: a concrete deck on tall columns. */
    fun overpass(width: Int = 384, height: Int = 64): PixelCanvas {
        val canvas = PixelCanvas(width, height)
        val concrete = PixelColor(0x8C8C98)
        val shade = PixelColor(0x6C6C78)
        // Low enough to show above Old Town's rooftops.
        val deck = 30
        canvas.fill(0, deck, width, 8, concrete)
        canvas.fill(0, deck, width, 2, shade)
        canvas.fill(0, deck + 8, width, 1, Palette.lightGrey)
        for (x in 0 until width step 6) canvas.fill(x, deck + 9, 1, 3, Palette.grey)
        canvas.fill(0, deck + 12, width, 1, Palette.grey)
        for (x in 40 until width step 128) {
            canvas.fill(x, 0, 10, deck, concrete)
            canvas.fill(x + 8, 0, 2, deck, shade)
            canvas.fill(x - 3, deck - 4, 16, 4, concrete)
        }
        return canvas
    }

    /** Old Town: low brick and cast-iron fronts with tall arched windows and old lamps,
     *  the Chinatown gate, Saturday Market's canopies, and the White Stag sign. */
    fun oldTown(width: Int = 480, height: Int = 36): PixelCanvas {
        val canvas = PixelCanvas(width, height)
        val generator = SeededGenerator(13)
        val walls = listOf(PixelColor(0xA84C34), PixelColor(0xE0D0A8), PixelColor(0x6C7C5C), PixelColor(0xB89C6C))
        fun building(x: Int, w: Int) {
            val h = generator.int(20, 30)
            val wall = walls[generator.intUntil(0, walls.size)]
            canvas.fill(x, 0, w, h, wall)
            canvas.fill(x, h - 3, w, 3, wall.darker(0.7))
            canvas.fill(x, 0, 1, h, wall.darker(0.7))
            // Tall arched windows, two floors.
            for (wy in 4 until h - 10 step 12) {
                for (wx in x + 4 until x + w - 6 step 8) {
                    canvas.fill(wx, wy, 4, 7, Palette.black)
                    canvas.fill(wx + 1, wy + 7, 2, 1, Palette.black)
                    if (generator.intUntil(0, 4) == 0) canvas.fill(wx + 1, wy + 1, 2, 5, Palette.window)
                }
            }
        }
        fun lamp(x: Int) {
            canvas.fill(x, 0, 1, 18, Palette.black)
            canvas.fill(x - 1, 18, 3, 3, Palette.window)
            canvas.fill(x - 1, 21, 3, 1, Palette.black)
        }
        var x = 0
        fun buildings(end: Int) {
            while (x < end) {
                val w = min(generator.int(36, 60), end - x)
                building(x, w)
                x += w
            }
        }
        buildings(70)
        x += Landmarks.chinatownGate(canvas, x + 4) + 8
        buildings(200)
        lamp(x + 3)
        x += Landmarks.saturdayMarket(canvas, x + 8, generator) + 16
        buildings(340)
        x += whiteStag(canvas, x)
        buildings(width)
        for (lampX in listOf(30, 160, 430)) lamp(lampX)
        return canvas
    }

    // Backdrops: Burnside

    /** The underside of the Burnside Bridge: arched concrete spans on thick piers, and
     *  through one arch, the river and the bridge's two towers far off. */
    fun bridgeUnderside(width: Int = 384, height: Int = 90): PixelCanvas {
        val canvas = PixelCanvas(width, height)
        val concrete = PixelColor(0x54545C)
        val dark = PixelColor(0x3C3C44)
        val light = PixelColor(0x6C6C74)
        val deck = 50
        val span = 96
        val pier = 14
        fun archTop(x: Int): Int {
            val along = (x % span - pier).toDouble() / (span - pier)
            // Low at the piers, rising to the crown in the middle.
            return deck - 18 + (18 * sin(along * PI)).rounded().toInt()
        }
        // Through the second arch: the open river and the towers.
        Landmarks.burnsideTowers(canvas, span + pier, 2 * span, ::archTop)
        for (x in 0 until width) {
            val inPier = x % span < pier
            val bottom = if (inPier) 0 else archTop(x)
            canvas.fill(x, bottom, 1, height - bottom, if (inPier) concrete else dark)
            if (!inPier) canvas[x, bottom] = light
            if (x % span == pier - 3) canvas.fill(x, 0, 3, deck, dark)
        }
        // Beams along the deck.
        for (x in 0 until width step 24) canvas.fill(x, deck + 4, 3, height - deck - 4, concrete)
        canvas.fill(0, deck, width, 2, light)
        return canvas
    }

    /** Concrete walls with graffiti, and the lip of a bowl. */
    fun skateparkWalls(width: Int = 320, height: Int = 28): PixelCanvas {
        val canvas = PixelCanvas(width, height)
        val generator = SeededGenerator(17)
        canvas.fill(0, 0, width, 18, PixelColor(0x7C7C84))
        canvas.fill(0, 17, width, 1, Palette.lightGrey)
        val pink = PixelColor(0xF878B8)
        val teal = PixelColor(0x00A8A8)
        val red = PixelColor(0xD82818)
        // Burnside's walls: words, anarchy signs and skulls, all in spray paint.
        Graffiti.words("SK8 OR DIE", canvas, 4, 6, pink, generator)
        Graffiti.skull(canvas, 70, 4, crossbones = false)
        Graffiti.anarchy(canvas, 84, 3, red)
        Graffiti.words("PDX", canvas, 102, 7, Palette.yellow, generator)
        Graffiti.scribble(canvas, 125, teal, generator)
        Graffiti.skull(canvas, 146, 3, crossbones = true)
        Graffiti.words("DIY", canvas, 164, 6, Palette.green, generator)
        Graffiti.anarchy(canvas, 186, 4, Palette.black)
        Graffiti.words("THRASH", canvas, 203, 7, Palette.orange, generator)
        Graffiti.skull(canvas, 300, 4, crossbones = false)
        // A quarter pipe rising at the back.
        val pipe = 252
        for (x in 0 until 24) {
            val h = 18 + (x * x).toDouble().div(64).toInt()
            canvas.fill(pipe + x, 0, 1, min(h, height), PixelColor(0x8C8C94))
        }
        canvas.fill(pipe + 24, 0, 4, height, PixelColor(0x8C8C94))
        canvas.fill(pipe + 23, height - 1, 6, 1, Palette.lightGrey)
        Graffiti.anarchy(canvas, pipe + 6, 4, red)
        return canvas
    }

    // Backdrops: North Portland

    /** The St. Johns Bridge's green towers and cables, a rail bridge, and forested hills. */
    fun stJohnsBridge(width: Int = 512, height: Int = 84): PixelCanvas {
        val canvas = PixelCanvas(width, height)
        val green = PixelColor(0x2C7C5C)
        val darkGreen = PixelColor(0x1C5C44)
        val hills = PixelColor(0x4C7C5C)
        // Mount St. Helens far off, with the top blown off.
        Landmarks.mountain(canvas, 160, 300, 34, PixelColor(0x8CA0C0), snowLine = 0.7, flatTop = 8, seed = 43)
        // Forested hills along the bottom.
        for (x in 0 until width) {
            val h = 10 + (6 * sin(x.toDouble() / 40) + 4 * sin(x.toDouble() / 13)).toInt()
            canvas.fill(x, 0, 1, h, hills)
        }
        // Deck, towers and cables, over Cathedral Park's gothic arches.
        val deckY = 26
        Landmarks.cathedralArches(canvas, 42, 4, deckY)
        canvas.fill(40, deckY, 360, 3, darkGreen)
        for (towerX in listOf(110, 330)) {
            canvas.fill(towerX, 0, 8, 80, green)
            canvas.fill(towerX + 2, 36, 4, 10, PixelColor(0x88B8F8))
            canvas.fill(towerX + 2, 54, 4, 10, PixelColor(0x88B8F8))
            canvas.fill(towerX + 3, 80, 2, 4, green)
        }
        fun cable(x0: Int, y0: Int, x1: Int, y1: Int, sag: Double) {
            for (x in min(x0, x1)..max(x0, x1)) {
                val t = (x - x0).toDouble() / (x1 - x0)
                val y = y0.toDouble() + (y1 - y0).toDouble() * t - sag * 4 * t * (1 - t)
                canvas[x, y.toInt()] = darkGreen
                if ((x - x0) % 6 == 0 && y.toInt() > deckY + 3) canvas.fill(x, deckY + 3, 1, y.toInt() - deckY - 3, darkGreen)
            }
        }
        cable(118, 78, 330, 78, sag = 46.0)
        cable(40, deckY + 3, 110, 78, sag = -6.0)
        cable(338, 78, 400, deckY + 3, sag = -6.0)
        // A rail bridge further along: a rusty truss.
        val rust = PixelColor(0x7C3C1C)
        canvas.fill(420, 18, 92, 2, rust)
        canvas.fill(420, 30, 92, 2, rust)
        for (x in 420 until 510 step 12) {
            for (step in 0 until 12) {
                canvas[x + step, 20 + step] = rust
                canvas[x + step, 31 - step] = rust
            }
        }
        for (x in 430 until width step 40) canvas.fill(x, 0, 3, 18, rust)
        return canvas
    }

    /** What the food carts sell, one per cart in turn. Each fits a cart's sign
     *  (24 pixels of `SignFont` at most; a test checks). */
    val foodCartSigns = listOf("PIZZA", "TACOS", "SANDOS", "THAI", "BURGER", "RAMEN", "PHO", "CREPES", "CURRY")

    /** Food carts and leafy trees, and Paul Bunyan towering over them. */
    fun foodCartsAndTrees(width: Int = 320, height: Int = 48): PixelCanvas {
        val canvas = PixelCanvas(width, height)
        val generator = SeededGenerator(19)
        val carts = listOf(
            PixelColor(0xF8B800), PixelColor(0xD82800), PixelColor(0x00A8A8), PixelColor(0xF878B8),
            PixelColor(0xFCFCFC), PixelColor(0x00A844),
        )
        var x = 4
        var bunyanDone = false
        var cartCount = 0
        while (x < width - 30) {
            if (!bunyanDone && x > 140) {
                bunyanDone = true
                x += Landmarks.paulBunyan(canvas, x) + 4
                continue
            }
            if (generator.intUntil(0, 3) == 0) {
                // A tree.
                canvas.fill(x + 6, 0, 3, 12, Palette.brown)
                for (dy in 0 until 16) {
                    val half = (8 * sin(dy.toDouble() / 16 * PI)).toInt() + 1
                    canvas.fill(x + 7 - half, 10 + dy, half * 2, 1, if (dy % 5 == 0) Palette.darkGreen else Palette.green)
                }
                x += 18
            } else {
                // A cart: box, serving window, striped awning, wheels.
                val color = carts[generator.intUntil(0, carts.size)]
                canvas.fill(x, 2, 22, 14, color)
                canvas.fill(x + 4, 7, 12, 5, Palette.black)
                canvas.fill(x + 5, 8, 2, 3, Palette.window)
                for (stripe in 0 until 24) {
                    canvas.fill(x - 1 + stripe, 16, 1, 3, if (stripe % 4 < 2) Palette.white else color.darker())
                }
                canvas.fill(x + 3, 0, 4, 3, Palette.black)
                canvas.fill(x + 15, 0, 4, 3, Palette.black)
                // A sign on the roof saying what it sells, edged in the cart's color.
                val sign = foodCartSigns[cartCount % foodCartSigns.size]
                cartCount += 1
                canvas.fill(x - 3, 19, 28, 9, color)
                canvas.fill(x - 2, 20, 26, 7, PixelColor(0x241C14))
                SignFont.draw(sign, canvas, x + 11, 21, Palette.white)
                x += 26
            }
            x += generator.int(2, 10)
        }
        return canvas
    }

    // Backdrops: waterfront

    /** Downtown across the river, with its bridges. */
    fun cityAcrossTheRiver(width: Int = 448, height: Int = 60): PixelCanvas {
        val canvas = PixelCanvas(width, height)
        val generator = SeededGenerator(23)
        val towers = listOf(PixelColor(0xA8B8D8), PixelColor(0x8C9CC0), PixelColor(0xC0C8E0))
        var x = 0
        while (x < width) {
            val w = generator.int(6, 16)
            val h = generator.int(6, 44)
            val color = towers[generator.intUntil(0, towers.size)]
            canvas.fill(x, 0, min(w, width - x), h, color)
            for (wy in 3 until h - 2 step 4) if (generator.bool()) canvas[x + w / 2, wy] = color.darker(0.8)
            x += w + generator.int(0, 3)
        }
        // Big Pink, standing up over the rest.
        canvas.fill(320, 0, 10, 50, PixelColor(0xC8848C))
        canvas.fill(320, 0, 2, 50, PixelColor(0xE0A4A8))
        for (wy in 4 until 48 step 3) canvas.fill(323, wy, 5, 1, PixelColor(0x84444C))
        // The Hawthorne Bridge, Tilikum Crossing, a steel arch bridge, and OMSI.
        Landmarks.hawthorne(canvas, 50)
        Landmarks.tilikum(canvas, 172)
        Landmarks.omsi(canvas, 400)
        val steel = PixelColor(0x3C4C6C)
        canvas.fill(270, 4, 120, 2, steel)
        for (archX in 0 until 120) {
            val t = archX.toDouble() / 120
            val y = 4 + (18 * 4 * t * (1 - t)).toInt()
            canvas[270 + archX, y] = steel
            if (archX % 8 == 0) canvas.fill(270 + archX, 6, 1, max(0, y - 6), steel)
        }
        return canvas
    }

    /** Mount Hood on the horizon, snow all the way down its upper slopes. */
    fun mountHood(width: Int = 600, height: Int = 34): PixelCanvas {
        val canvas = PixelCanvas(width, height)
        Landmarks.mountain(canvas, 30, 250, height, PixelColor(0x7C90B8), snowLine = 0.45, seed = 47)
        return canvas
    }

    /** The Willamette: a band of water with ripples, and the Blueback moored in it. */
    fun river(width: Int = 960, height: Int = 12): PixelCanvas {
        val canvas = PixelCanvas(width, height, fill = PixelColor(0x2C64B8))
        val generator = SeededGenerator(29)
        canvas.fill(0, height - 1, width, 1, PixelColor(0x5C88D0))
        Landmarks.blueback(canvas, 420, waterline = 2)
        repeat(200) {
            val x = generator.intUntil(0, width - 4)
            val y = generator.intUntil(0, height - 1)
            canvas.fill(x, y, generator.int(2, 5), 1, PixelColor(0x88B0E8))
        }
        return canvas
    }

    // Backdrops: Zoo Bomb

    /** Fir-covered ridges falling away downhill. */
    fun forestedHills(width: Int = 512, height: Int = 80): PixelCanvas {
        val canvas = PixelCanvas(width, height)
        val far = PixelColor(0x6C9C8C)
        val near = PixelColor(0x3C6C4C)
        // Mount Hood, rising over the far ridges.
        Landmarks.mountain(canvas, 340, 512, 76, PixelColor(0x8CA0C0), snowLine = 0.6, seed = 53)
        for (x in 0 until width) {
            // Each ridge slopes down to the right, like the road.
            val ridge = 70 - (x % 256) / 5 + (3 * sin(x.toDouble() / 9)).toInt()
            canvas.fill(x, 0, 1, max(10, ridge), far)
            val lower = 40 - (x % 192) / 6 + (2 * sin(x.toDouble() / 7)).toInt()
            canvas.fill(x, 0, 1, max(6, lower), near)
        }
        val generator = SeededGenerator(37)
        repeat(60) {
            val x = generator.intUntil(0, width)
            val base = max(6, 40 - (x % 192) / 6)
            for (dy in 0 until 6) canvas.fill(x - (6 - dy) / 2, base + dy, 6 - dy, 1, near)
        }
        // Pittock Mansion up on the near ridge.
        Landmarks.pittock(canvas, 84, max(6, 40 - 96 / 6) - 1)
        return canvas
    }

    /** Big firs, and the zoo's fence with a giraffe looking over it. */
    fun zooWoods(width: Int = 320, height: Int = 56): PixelCanvas {
        val canvas = PixelCanvas(width, height)
        val generator = SeededGenerator(41)
        val fir = PixelColor(0x1C5C34)
        val firLight = PixelColor(0x2C7C44)
        // Fence.
        canvas.fill(0, 10, width, 1, PixelColor(0x8C6C44))
        canvas.fill(0, 5, width, 1, PixelColor(0x8C6C44))
        for (x in 0 until width step 10) canvas.fill(x, 0, 2, 12, PixelColor(0x6C4C2C))
        // A giraffe in its enclosure.
        val giraffe = PixelColor(0xE8B060)
        val spot = PixelColor(0x8C5424)
        canvas.fill(150, 6, 14, 8, giraffe)
        canvas.fill(150, 0, 2, 6, giraffe)
        canvas.fill(161, 0, 2, 6, giraffe)
        canvas.fill(160, 14, 3, 18, giraffe)
        canvas.fill(160, 31, 6, 3, giraffe)
        for ((sx, sy) in listOf(152 to 8, 156 to 11, 158 to 7, 161 to 18, 161 to 24)) canvas[sx, sy] = spot
        canvas[164, 33] = Palette.black
        // Firs.
        var x = 0
        while (x < width) {
            if (x !in 140..172) {
                val h = generator.int(30, height)
                canvas.fill(x + 5, 0, 2, 6, Palette.brown)
                for (dy in 0 until h - 4) {
                    val half = max(1, (h - 4 - dy) / 3)
                    canvas.fill(x + 6 - half, 4 + dy, half * 2, 1, if (dy % 4 == 0) firLight else fir)
                }
            }
            x += generator.int(10, 20)
        }
        return canvas
    }
}

/** Tiny 3 x 5 capitals for signs in the backdrops (M and N are wider so they read). */
object SignFont {
    private val glyphs: Map<Char, List<String>> = mapOf(
        'A' to listOf(".#.", "#.#", "###", "#.#", "#.#"),
        'B' to listOf("##.", "#.#", "##.", "#.#", "##."),
        'C' to listOf("###", "#..", "#..", "#..", "###"),
        'H' to listOf("#.#", "#.#", "###", "#.#", "#.#"),
        'I' to listOf("###", ".#.", ".#.", ".#.", "###"),
        'U' to listOf("#.#", "#.#", "#.#", "#.#", "###"),
        'Z' to listOf("###", "..#", ".#.", "#..", "###"),
        'S' to listOf("###", "#..", "###", "..#", "###"),
        'D' to listOf("##.", "#.#", "#.#", "#.#", "##."),
        'E' to listOf("###", "#..", "##.", "#..", "###"),
        'G' to listOf("###", "#..", "#.#", "#.#", "###"),
        'K' to listOf("#.#", "#.#", "##.", "#.#", "#.#"),
        'L' to listOf("#..", "#..", "#..", "#..", "###"),
        'M' to listOf("#...#", "##.##", "#.#.#", "#...#", "#...#"),
        'N' to listOf("#..#", "##.#", "#.##", "#..#", "#..#"),
        'O' to listOf("###", "#.#", "#.#", "#.#", "###"),
        'P' to listOf("##.", "#.#", "##.", "#..", "#.."),
        'R' to listOf("##.", "#.#", "##.", "#.#", "#.#"),
        'T' to listOf("###", ".#.", ".#.", ".#.", ".#."),
        'Y' to listOf("#.#", "#.#", ".#.", ".#.", ".#."),
        ' ' to listOf("..", "..", "..", "..", ".."),
    )

    fun width(text: String): Int {
        val widths = text.map { glyphs[it]?.first()?.length ?: 3 }
        return widths.sum() + max(0, widths.size - 1)
    }

    /** Draws `text` centered on `centerX`, with its bottom at `y`. */
    fun draw(text: String, canvas: PixelCanvas, centerX: Int, y: Int, color: PixelColor) {
        var x = centerX - width(text) / 2
        for (character in text) {
            val rows = glyphs[character]
            if (rows == null) {
                x += 4
                continue
            }
            canvas.draw(PixelSprite(rows, mapOf('#' to color)), x, y)
            x += rows[0].length + 1
        }
    }

    val allGlyphs: Map<Char, List<String>> get() = glyphs
}

/** Spray paint for the skatepark walls. */
object Graffiti {
    /** Words in the big pixel font, outlined in black, with a few drips. */
    fun words(text: String, canvas: PixelCanvas, x: Int, y: Int, paint: PixelColor, generator: SeededGenerator) {
        for ((dx, dy) in listOf(-1 to 0, 1 to 0, 0 to -1, 0 to 1, 1 to -1)) {
            PixelText.draw(text, canvas, x + dx, y + dy, Palette.black)
        }
        PixelText.draw(text, canvas, x, y, paint)
        // Drips run down from the bottom of a few letters.
        var cursor = x
        for (character in text.uppercase()) {
            val rows = PixelFont.glyph(character)
            val width = rows.firstOrNull()?.length ?: 3
            val bottom = rows.last()
            if (generator.intUntil(0, 2) == 0) {
                val columns = bottom.withIndex().filter { it.value == '#' }.map { it.index }
                val column = generator.element(columns)
                if (column != null) {
                    val length = generator.int(1, 3)
                    canvas.fill(cursor + column, y - length, 1, length, paint)
                }
            }
            cursor += width + PixelFont.gap
        }
    }

    /** The circled A, with the A's legs breaking out of the bottom of the circle. */
    fun anarchy(canvas: PixelCanvas, x: Int, y: Int, paint: PixelColor) {
        val centerX = x + 6
        val centerY = y + 6
        for (step in 0 until 64) {
            val angle = step.toDouble() / 64 * 2 * PI
            canvas[centerX + (5 * kotlin.math.cos(angle)).rounded().toInt(), centerY + (5 * sin(angle)).rounded().toInt()] = paint
        }
        Landmarks.line(canvas, x + 6 to y + 12, x + 1 to y, paint)
        Landmarks.line(canvas, x + 6 to y + 12, x + 11 to y, paint)
        Landmarks.line(canvas, x to y + 5, x + 12 to y + 5, paint)
    }

    /** A white skull with black eyes and teeth, outlined; crossbones behind if asked. */
    fun skull(canvas: PixelCanvas, x: Int, y: Int, crossbones: Boolean) {
        if (crossbones) {
            val bone = Palette.white
            Landmarks.line(canvas, x - 1 to y, x + 10 to y + 9, bone)
            Landmarks.line(canvas, x - 1 to y + 9, x + 10 to y, bone)
            for ((bx, by) in listOf(x - 2 to y, x - 2 to y + 9, x + 10 to y, x + 10 to y + 9)) {
                canvas.fill(bx, by - 1, 2, 2, bone)
            }
        }
        val rows = listOf(
            "..wwwww..",
            ".wwwwwww.",
            "wwwwwwwww",
            "wkkwwwkkw",
            "wkkwwwkkw",
            "wwwwkwwww",
            ".wwwwwww.",
            "..wkwkw..",
            "..wwwww..",
        )
        val outline = PixelSprite(rows, mapOf('w' to Palette.black, 'k' to Palette.black))
        for ((dx, dy) in listOf(-1 to 0, 1 to 0, 0 to -1, 0 to 1)) canvas.draw(outline, x + dx, y + dy)
        canvas.draw(PixelSprite(rows, mapOf('w' to Palette.white, 'k' to Palette.black)), x, y)
    }

    /** A quick tag: a wiggly scrawl of paint. */
    fun scribble(canvas: PixelCanvas, x: Int, paint: PixelColor, generator: SeededGenerator) {
        val w = generator.int(14, 18)
        for (column in 0 until w) {
            val h = generator.int(3, 8)
            val lift = generator.int(0, 2)
            canvas.fill(x + column, 4 + lift, 1, h, paint)
        }
        canvas.fill(x, 3, w, 1, paint.darker())
    }
}
