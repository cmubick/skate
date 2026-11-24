//
//  Cities.kt
//
//  The cities and their spots. Portland is the one you can skate; the rest are
//  coming soon. Each spot hides a couple of the city's letters.
//  Ported from skate/Rules/Cities.swift: keep the two the same.
//

package com.tuesdaygames.skate.rules

import com.tuesdaygames.skate.rules.Feature.Companion.barrier
import com.tuesdaygames.skate.rules.Feature.Companion.bench
import com.tuesdaygames.skate.rules.Feature.Companion.biker
import com.tuesdaygames.skate.rules.Feature.Companion.brokenCar
import com.tuesdaygames.skate.rules.Feature.Companion.bubbler
import com.tuesdaygames.skate.rules.Feature.Companion.car
import com.tuesdaygames.skate.rules.Feature.Companion.cart
import com.tuesdaygames.skate.rules.Feature.Companion.cone
import com.tuesdaygames.skate.rules.Feature.Companion.curb
import com.tuesdaygames.skate.rules.Feature.Companion.dog
import com.tuesdaygames.skate.rules.Feature.Companion.fountain
import com.tuesdaygames.skate.rules.Feature.Companion.funbox
import com.tuesdaygames.skate.rules.Feature.Companion.goat
import com.tuesdaygames.skate.rules.Feature.Companion.handrail
import com.tuesdaygames.skate.rules.Feature.Companion.hole
import com.tuesdaygames.skate.rules.Feature.Companion.ledge
import com.tuesdaygames.skate.rules.Feature.Companion.millEnds
import com.tuesdaygames.skate.rules.Feature.Companion.miniBike
import com.tuesdaygames.skate.rules.Feature.Companion.pedestrian
import com.tuesdaygames.skate.rules.Feature.Companion.penguin
import com.tuesdaygames.skate.rules.Feature.Companion.planter
import com.tuesdaygames.skate.rules.Feature.Companion.quarterPipe
import com.tuesdaygames.skate.rules.Feature.Companion.rail
import com.tuesdaygames.skate.rules.Feature.Companion.runner
import com.tuesdaygames.skate.rules.Feature.Companion.skater
import com.tuesdaygames.skate.rules.Feature.Companion.tracks
import com.tuesdaygames.skate.rules.Feature.Companion.train
import com.tuesdaygames.skate.rules.Feature.Companion.zooTrain
import com.tuesdaygames.skate.rules.Lane.Back
import com.tuesdaygames.skate.rules.Lane.Front
import com.tuesdaygames.skate.rules.Lane.Middle

data class City(
    val id: String,
    val name: String,
    val isOpen: Boolean,
    val levels: List<Level>,
) {
    /** The letters to find: the city's name without spaces. */
    val letters: List<Char> get() = name.filter { it != ' ' }.toList()

    companion object {
        val portland = City(
            "portland", "PORTLAND", isOpen = true,
            levels = listOf(
                Level.downtown, Level.skidmoreFountain, Level.burnsideSkatepark,
                Level.northPortland, Level.southeastWaterfront, Level.zooBomb,
            ),
        )

        val all: List<City> = listOf(
            portland,
            City("sanfrancisco", "SAN FRANCISCO", false, emptyList()),
            City("losangeles", "LOS ANGELES", false, emptyList()),
            City("newyork", "NEW YORK", false, emptyList()),
            City("fresno", "FRESNO", false, emptyList()),
            City("sacramento", "SACRAMENTO", false, emptyList()),
            City("austin", "AUSTIN", false, emptyList()),
            City("seattle", "SEATTLE", false, emptyList()),
            City("astoria", "ASTORIA", false, emptyList()),
        )
    }
}

private fun letter(index: Int, lane: Lane, x: Double, height: Double) =
    LetterPickup(index, "PORTLAND"[index], lane, x, height)

// Portland

/** The grey-box street from the feel prototype, now the tutorial spot. */
val Level.Companion.downtown: Level by lazy {
    Level(
        id = "downtown", name = "DOWNTOWN", theme = Theme.Downtown, length = 2960.0,
        features = listOf(
            cone(Middle, 240.0),
            cone(Front, 352.0),
            rail(Back, 448.0, length = 80.0),
            ledge(Middle, 608.0, length = 56.0),
            cone(Front, 720.0),
            // A Benson Bubbler on the sidewalk.
            bubbler(Back, 760.0),
            cone(Front, 768.0),
            rail(Middle, 864.0, length = 104.0),
            cone(Back, 896.0),
            ledge(Back, 1056.0, length = 80.0),
            cone(Front, 1072.0),
            // Mill Ends Park, the world's smallest: too small to trip over.
            millEnds(Middle, 1080.0),
            // A pair of cones close together: needs a charged ollie, or a lane switch.
            cone(Middle, 1216.0), cone(Middle, 1245.0),
            rail(Front, 1344.0, length = 128.0),
            // Two short rails with a gap: transfer from one to the other.
            rail(Back, 1536.0, length = 56.0),
            bubbler(Front, 1600.0),
            rail(Back, 1624.0, length = 56.0),
            planter(Middle, 1760.0),
            ledge(Middle, 1888.0, length = 104.0),
            cone(Back, 1904.0), cone(Front, 1928.0),
            rail(Back, 2096.0, length = 160.0),
            cone(Front, 2272.0), cone(Front, 2320.0),
            bubbler(Middle, 2350.0),
            cone(Front, 2368.0),
            rail(Middle, 2448.0, length = 80.0),
            ledge(Middle, 2576.0, length = 80.0),
            // Cones across every lane: no way round, ollie it.
            cone(Back, 2752.0), cone(Middle, 2768.0), cone(Front, 2784.0),
        ),
        letters = listOf(
            // P floats over the first rail: grind it to get it.
            letter(0, Back, 488.0, height = 28.0),
            letter(1, Middle, 1310.0, height = 6.0),
        ),
        showsHints = true,
        gaps = listOf(
            Gap("PIONEER GAP", 500, Gap.Kind.Transfer(Back, 1536.0, 1624.0), hint = "RAIL TO RAIL"),
            Gap("DOUBLE CONE", 300, Gap.Kind.Over(Middle, 1216.0, 1245.0), hint = "2 CONES 1 JUMP"),
        ),
        goals = listOf(
            Goal("downtown.score", "SCORE 2000", Goal.Kind.Score(2000)),
            Goal("downtown.letters", "FIND 2 LETTERS", Goal.Kind.Letters),
            Goal("downtown.gap", "PIONEER GAP", Goal.Kind.GapNamed("PIONEER GAP")),
            Goal("downtown.flip", "FLIP A CONE", Goal.Kind.Clear(FeatureStyle.Cone, trickStyle = 2.0)),
            Goal("downtown.clean", "NO BAILS", Goal.Kind.NoBails),
        ),
    )
}

/** Old Town: light rail trains down the tracks, people on the plaza, and the fountain. */
val Level.Companion.skidmoreFountain: Level by lazy {
    Level(
        id = "skidmore", name = "SKIDMORE FOUNTAIN", theme = Theme.Skidmore, length = 3050.0,
        features = listOf(
            tracks(Middle, 200.0, length = 260.0),
            pedestrian(Back, 420.0),
            // Short enough to clear with a held ollie: the FOUNTAIN GAP.
            fountain(Back, 560.0, length = 44.0),
            pedestrian(Front, 640.0),
            // The first train comes down the middle lane: get out of its way.
            train(Middle, 980.0),
            tracks(Middle, 1240.0, length = 280.0),
            pedestrian(Back, 1320.0),
            pedestrian(Front, 1420.0),
            // The long basin: room for the GRIND FOUNTAIN goal, with R floating over it.
            fountain(Back, 1600.0, length = 132.0),
            train(Middle, 2000.0),
            pedestrian(Front, 2050.0),
            tracks(Middle, 2250.0, length = 320.0),
            fountain(Front, 2650.0),
            pedestrian(Back, 2700.0),
            pedestrian(Middle, 2860.0),
        ),
        letters = listOf(
            letter(2, Back, 1640.0, height = 26.0),
            letter(3, Front, 2690.0, height = 26.0),
        ),
        gaps = listOf(
            Gap("FOUNTAIN GAP", 600, Gap.Kind.Over(Back, 560.0, 560.0), hint = "CLEAR FOUNTAIN"),
        ),
        goals = listOf(
            Goal("skidmore.score", "SCORE 3000", Goal.Kind.Score(3000)),
            Goal("skidmore.letters", "FIND 2 LETTERS", Goal.Kind.Letters),
            Goal("skidmore.gap", "FOUNTAIN GAP", Goal.Kind.GapNamed("FOUNTAIN GAP")),
            Goal("skidmore.grind", "GRIND FOUNTAIN", Goal.Kind.Grind(FeatureStyle.Fountain, seconds = 1.0)),
            Goal("skidmore.walker", "OLLIE A WALKER", Goal.Kind.Clear(FeatureStyle.Pedestrian)),
        ),
    )
}

/** Under the bridge: rails, funboxes, holes, and other skaters in the way. */
val Level.Companion.burnsideSkatepark: Level by lazy {
    Level(
        id = "burnside", name = "BURNSIDE SKATEPARK", theme = Theme.Burnside, length = 3000.0,
        features = listOf(
            funbox(Middle, 220.0),
            skater(Front, 300.0),
            rail(Back, 420.0, length = 96.0),
            hole(Middle, 560.0),
            funbox(Back, 700.0),
            rail(Middle, 860.0, length = 120.0),
            skater(Back, 1000.0),
            quarterPipe(Middle, 1010.0),
            hole(Front, 1080.0),
            ledge(Front, 1250.0, length = 80.0),
            funbox(Middle, 1420.0, length = 72.0),
            // Two rails with a gap: L hangs over the gap.
            rail(Back, 1560.0, length = 64.0), rail(Back, 1660.0, length = 64.0),
            hole(Middle, 1800.0),
            skater(Middle, 1900.0),
            quarterPipe(Front, 1960.0),
            funbox(Front, 2100.0),
            rail(Middle, 2300.0, length = 140.0),
            hole(Back, 2350.0),
            skater(Front, 2500.0),
            funbox(Back, 2600.0, length = 72.0),
            hole(Middle, 2780.0), hole(Front, 2800.0),
        ),
        letters = listOf(
            letter(4, Back, 1642.0, height = 30.0),
        ),
        gaps = listOf(
            Gap("BURNSIDE GAP", 500, Gap.Kind.Transfer(Back, 1560.0, 1660.0), hint = "RAIL TO RAIL"),
        ),
        goals = listOf(
            Goal("burnside.score", "SCORE 4000", Goal.Kind.Score(4000)),
            Goal("burnside.letters", "FIND THE LETTER", Goal.Kind.Letters),
            Goal("burnside.gap", "BURNSIDE GAP", Goal.Kind.GapNamed("BURNSIDE GAP")),
            Goal("burnside.manholes", "3 MANHOLES", Goal.Kind.Clears(FeatureStyle.Hole, count = 3)),
            Goal("burnside.360", "LAND A 360 FLIP", Goal.Kind.Land(Trick.ThreeSixtyFlip)),
        ),
    )
}

/** Shopping carts and broken-down cars; curbs and park benches to grind. */
val Level.Companion.northPortland: Level by lazy {
    Level(
        id = "northportland", name = "NORTH PORTLAND", theme = Theme.NorthPortland, length = 3100.0,
        features = listOf(
            curb(Back, 200.0, length = 200.0),
            cart(Middle, 330.0),
            bench(Back, 520.0),
            brokenCar(Front, 600.0),
            cart(Back, 760.0),
            bench(Back, 1000.0),
            cart(Middle, 1040.0),
            brokenCar(Middle, 1250.0),
            curb(Front, 1300.0, length = 220.0),
            bench(Back, 1480.0, length = 44.0),
            cart(Front, 1650.0),
            cart(Middle, 1700.0),
            brokenCar(Front, 1900.0),
            bench(Back, 2050.0),
            bench(Back, 2120.0),
            curb(Middle, 2300.0, length = 200.0),
            cart(Back, 2450.0),
            brokenCar(Middle, 2600.0),
            bench(Front, 2750.0),
            cart(Back, 2850.0),
            cart(Middle, 2880.0),
        ),
        letters = listOf(
            letter(5, Back, 1500.0, height = 24.0),
        ),
        gaps = listOf(
            Gap("ST JOHNS GAP", 500, Gap.Kind.Transfer(Back, 2050.0, 2120.0), hint = "BENCH TO BENCH"),
        ),
        goals = listOf(
            Goal("north.score", "SCORE 3000", Goal.Kind.Score(3000)),
            Goal("north.letters", "FIND THE LETTER", Goal.Kind.Letters),
            Goal("north.gap", "ST JOHNS GAP", Goal.Kind.GapNamed("ST JOHNS GAP")),
            Goal("north.cart", "FLIP A CART", Goal.Kind.Clear(FeatureStyle.Cart, trickStyle = 2.0)),
            Goal("north.curb", "GRIND A CURB", Goal.Kind.Grind(FeatureStyle.Curb, seconds = 1.5)),
        ),
    )
}

/** The esplanade along the river: runners, bikes, dogs, and open manholes. */
val Level.Companion.southeastWaterfront: Level by lazy {
    Level(
        id = "waterfront", name = "SE WATERFRONT", theme = Theme.Waterfront, length = 3150.0,
        features = listOf(
            handrail(Back, 220.0, length = 120.0),
            runner(Middle, 300.0),
            bench(Front, 520.0),
            hole(Back, 600.0),
            dog(Middle, 700.0),
            biker(Front, 760.0),
            handrail(Back, 900.0, length = 160.0),
            hole(Middle, 1150.0),
            runner(Back, 1200.0),
            bench(Middle, 1380.0),
            hole(Back, 1500.0),
            biker(Middle, 1550.0),
            handrail(Back, 1700.0, length = 200.0),
            dog(Front, 1900.0),
            hole(Front, 2050.0),
            runner(Middle, 2200.0),
            // The ESPLANADE GAP: the bench and the manhole right after it, in one held ollie.
            bench(Back, 2300.0),
            hole(Back, 2338.0),
            biker(Front, 2500.0),
            handrail(Back, 2600.0, length = 140.0),
            dog(Middle, 2800.0),
            hole(Middle, 2900.0),
        ),
        letters = listOf(
            letter(6, Back, 1800.0, height = 30.0),
        ),
        gaps = listOf(
            Gap("ESPLANADE GAP", 400, Gap.Kind.Over(Back, 2300.0, 2338.0), hint = "BENCH+MANHOLE"),
        ),
        goals = listOf(
            Goal("waterfront.score", "SCORE 4000", Goal.Kind.Score(4000)),
            Goal("waterfront.letters", "FIND THE LETTER", Goal.Kind.Letters),
            Goal("waterfront.gap", "ESPLANADE GAP", Goal.Kind.GapNamed("ESPLANADE GAP")),
            Goal("waterfront.angie", "OLLIE ANGIE", Goal.Kind.Clear(FeatureStyle.Dog)),
            Goal("waterfront.rail", "GRIND HANDRAIL", Goal.Kind.Grind(FeatureStyle.Handrail, seconds = 1.5)),
        ),
    )
}

/** Down the hill from the zoo, with Zoobombers on little bikes and the zoo train.
 *  You keep speeding up the whole way: the hardest spot. */
val Level.Companion.zooBomb: Level by lazy {
    Level(
        id = "zoobomb", name = "ZOO BOMB", theme = Theme.ZooBomb, length = 3500.0,
        features = listOf(
            curb(Back, 240.0, length = 200.0),
            miniBike(Front, 360.0, speed = 45.0),
            penguin(Middle, 520.0),
            barrier(Back, 640.0),
            car(Front, 860.0),
            goat(Middle, 900.0),
            curb(Front, 1050.0, length = 240.0),
            zooTrain(Back, 1150.0),
            barrier(Middle, 1200.0),
            // In the front lane: in the back it rode through the SUNSET GAP just as you got there.
            miniBike(Front, 1300.0),
            penguin(Front, 1500.0),
            goat(Back, 1560.0),
            barrier(Back, 1750.0, length = 48.0),
            barrier(Back, 1830.0),
            car(Middle, 1900.0),
            curb(Back, 2050.0, length = 260.0),
            miniBike(Front, 2150.0),
            goat(Middle, 2400.0),
            barrier(Front, 2500.0),
            car(Middle, 2700.0),
            penguin(Back, 2800.0),
            zooTrain(Middle, 2950.0),
            cone(Back, 3000.0), cone(Front, 3020.0),
            barrier(Middle, 3160.0, length = 48.0),
            goat(Front, 3300.0),
        ),
        letters = listOf(
            letter(7, Middle, 3190.0, height = 26.0),
        ),
        acceleration = 4.0, maxSpeed = 170.0,
        gaps = listOf(
            Gap("SUNSET GAP", 600, Gap.Kind.Transfer(Back, 1750.0, 1830.0), hint = "GRIND 2 BARRIERS"),
        ),
        goals = listOf(
            Goal("zoobomb.score", "SCORE 5000", Goal.Kind.Score(5000)),
            Goal("zoobomb.letters", "FIND THE LETTER", Goal.Kind.Letters),
            Goal("zoobomb.gap", "SUNSET GAP", Goal.Kind.GapNamed("SUNSET GAP")),
            Goal("zoobomb.car", "FLIP A CAR", Goal.Kind.Clear(FeatureStyle.Car, trickStyle = 2.0)),
            Goal("zoobomb.penguin", "OLLIE A PENGUIN", Goal.Kind.Clear(FeatureStyle.Penguin)),
        ),
    )
}
