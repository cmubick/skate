//
//  Level.kt
//
//  A run is one hand-built spot: things to ollie over, things to grind and
//  holes to clear, each in one of three lanes, the city's letters to find, and
//  a finish line. Ported from skate/Rules/Level.swift.
//

package com.tuesdaygames.skate.rules

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/** The three lanes, back to front. The back lane is highest on screen. */
enum class Lane(val raw: Int) {
    Back(0), Middle(1), Front(2);

    /** The lane one step toward the back (up on screen), if there is one. */
    val up: Lane? get() = entries.firstOrNull { it.raw == raw - 1 }

    /** The lane one step toward the front (down on screen), if there is one. */
    val down: Lane? get() = entries.firstOrNull { it.raw == raw + 1 }
}

/** How a feature looks. Each spot has its own. */
enum class FeatureStyle {
    // Things to grind.
    Rail, Handrail, Ledge, Bench, Curb, Fountain, Tracks, Funbox, Barrier,
    // Things in the way.
    Cone, Planter, Pedestrian, Runner, Biker, Skater, Dog, Cart, BrokenCar, Car, Train, Penguin, Goat,
    // Portland street furniture and the Zoo Bomb's own traffic.
    Bubbler, ZooTrain, MiniBike,
    // Just for looking at.
    MillEnds,
    // Open manholes.
    Hole,
    // Quarter pipes: roll up one and fly off the lip.
    QuarterPipe;

    /** What it's called when you clear it (Swift: `name`). */
    val displayName: String
        get() = when (this) {
            Rail -> "RAIL"
            Handrail -> "HANDRAIL"
            Ledge -> "LEDGE"
            Bench -> "BENCH"
            Curb -> "CURB"
            Fountain -> "FOUNTAIN"
            Tracks -> "TRACKS"
            Funbox -> "FUNBOX"
            Barrier -> "BARRIER"
            Cone -> "CONE"
            Planter -> "PLANTER"
            Pedestrian -> "WALKER"
            Runner -> "RUNNER"
            Biker -> "BIKE"
            Skater -> "SKATER"
            Dog -> "ANGIE"
            Cart -> "CART"
            BrokenCar, Car -> "CAR"
            Train -> "TRAIN"
            Penguin -> "PENGUIN"
            Goat -> "GOAT"
            Hole -> "MANHOLE"
            QuarterPipe -> "QUARTER PIPE"
            Bubbler -> "BUBBLER"
            ZooTrain -> "ZOO TRAIN"
            MiniBike -> "ZOOBOMBER"
            MillEnds -> "MILL ENDS PARK"
        }
}

data class Feature(
    val kind: Kind,
    val style: FeatureStyle,
    val lane: Lane,
    /** Where it starts along the street. Moving things start here once they come on screen. */
    val x: Double,
    val length: Double,
    val height: Double,
    /** Pixels per second, once it's on screen. Negative comes toward you; positive goes
     *  the same way you do, only slower. */
    val velocity: Double = 0.0,
) {
    enum class Kind {
        /** A thin rail on posts. Grindable. */
        Rail,
        /** A solid ledge, bench or curb. Grindable. */
        Ledge,
        /** Anything to ollie over or go around. Landing on it is a bail. */
        Block,
        /** A gap in the ground. Rolling into it is a bail; ollie over it. */
        Hole,
        /** A ramp you roll up and launch off. */
        Ramp,
        /** Scenery on the street that nothing bumps into. */
        Decor,
    }

    val end: Double get() = x + length
    val isGrindable: Boolean get() = kind == Kind.Rail || kind == Kind.Ledge
    val isMoving: Boolean get() = velocity != 0.0
    /** Low things, like curbs and train tracks, don't stop you rolling; you can only grind them. */
    val isLow: Boolean get() = height <= Tuning.lowFeatureHeight

    /** Points for getting all the way over it in the air: more for bigger things, and
     *  more again for things on the move. Low curbs and tracks aren't worth anything.
     *  The trick you're doing on the way over multiplies this (see `Trick.clearStyle`). */
    val clearPoints: Double
        get() {
            if (kind == Kind.Ramp || kind == Kind.Decor || !(kind == Kind.Hole || !isLow)) return 0.0
            val size = Tuning.clearBase + height * Tuning.clearPerHeight + length * Tuning.clearPerLength
            val moving = if (isMoving) Tuning.clearMovingBase + abs(velocity) / Tuning.clearMovingSpeedPerStep else 1.0
            return ((size * moving) / 5).rounded() * 5
        }

    /** How high the ramp is this far along it. */
    fun rampHeight(position: Double, start: Double): Double {
        val along = max(0.0, min(1.0, (position - start) / length))
        return (height * along * along).rounded()
    }

    companion object {
        // Things to grind

        fun rail(lane: Lane, x: Double, length: Double, height: Double = 14.0) =
            Feature(Kind.Rail, FeatureStyle.Rail, lane, x, length, height)

        fun handrail(lane: Lane, x: Double, length: Double) =
            Feature(Kind.Rail, FeatureStyle.Handrail, lane, x, length, 14.0)

        fun ledge(lane: Lane, x: Double, length: Double, height: Double = 10.0) =
            Feature(Kind.Ledge, FeatureStyle.Ledge, lane, x, length, height)

        fun bench(lane: Lane, x: Double, length: Double = 36.0) =
            Feature(Kind.Ledge, FeatureStyle.Bench, lane, x, length, 9.0)

        fun curb(lane: Lane, x: Double, length: Double) =
            Feature(Kind.Ledge, FeatureStyle.Curb, lane, x, length, 5.0)

        fun fountain(lane: Lane, x: Double, length: Double = 72.0) =
            Feature(Kind.Ledge, FeatureStyle.Fountain, lane, x, length, 12.0)

        fun tracks(lane: Lane, x: Double, length: Double) =
            Feature(Kind.Rail, FeatureStyle.Tracks, lane, x, length, 3.0)

        fun funbox(lane: Lane, x: Double, length: Double = 64.0) =
            Feature(Kind.Ledge, FeatureStyle.Funbox, lane, x, length, 11.0)

        fun barrier(lane: Lane, x: Double, length: Double = 40.0) =
            Feature(Kind.Ledge, FeatureStyle.Barrier, lane, x, length, 11.0)

        // Things in the way

        fun cone(lane: Lane, x: Double) = Feature(Kind.Block, FeatureStyle.Cone, lane, x, 9.0, 12.0)

        fun planter(lane: Lane, x: Double, length: Double = 24.0, height: Double = 16.0) =
            Feature(Kind.Block, FeatureStyle.Planter, lane, x, length, height)

        /** Someone walking toward you. Too tall to ollie: go around. */
        fun pedestrian(lane: Lane, x: Double, speed: Double = 14.0) =
            Feature(Kind.Block, FeatureStyle.Pedestrian, lane, x, 10.0, 21.0, -speed)

        /** A jogger going your way, slower than you. */
        fun runner(lane: Lane, x: Double) = Feature(Kind.Block, FeatureStyle.Runner, lane, x, 12.0, 21.0, 30.0)

        /** A cyclist going your way, rider and all as tall as you: go around. */
        fun biker(lane: Lane, x: Double, speed: Double = 50.0) =
            Feature(Kind.Block, FeatureStyle.Biker, lane, x, 22.0, 22.0, speed)

        /** Another skater, cruising slower than you. */
        fun skater(lane: Lane, x: Double) = Feature(Kind.Block, FeatureStyle.Skater, lane, x, 12.0, 22.0, 40.0)

        /** Angie, out for a walk. */
        fun dog(lane: Lane, x: Double) = Feature(Kind.Block, FeatureStyle.Dog, lane, x, 15.0, 11.0, -10.0)

        fun cart(lane: Lane, x: Double) = Feature(Kind.Block, FeatureStyle.Cart, lane, x, 15.0, 13.0)

        fun brokenCar(lane: Lane, x: Double) = Feature(Kind.Block, FeatureStyle.BrokenCar, lane, x, 40.0, 17.0)

        /** A car coming up the street toward you. */
        fun car(lane: Lane, x: Double, speed: Double = 60.0) =
            Feature(Kind.Block, FeatureStyle.Car, lane, x, 40.0, 17.0, -speed)

        /** A light rail train. Far too big to ollie: get out of its lane. */
        fun train(lane: Lane, x: Double) = Feature(Kind.Block, FeatureStyle.Train, lane, x, 150.0, 40.0, -80.0)

        fun penguin(lane: Lane, x: Double) = Feature(Kind.Block, FeatureStyle.Penguin, lane, x, 8.0, 11.0, -8.0)

        fun goat(lane: Lane, x: Double) = Feature(Kind.Block, FeatureStyle.Goat, lane, x, 16.0, 13.0, -12.0)

        // Portland

        /** A Benson Bubbler: a bronze drinking fountain with four bowls. Ollie it. */
        fun bubbler(lane: Lane, x: Double) = Feature(Kind.Block, FeatureStyle.Bubbler, lane, x, 8.0, 11.0)

        /** Mill Ends Park, the smallest park in the world: a little circle of plants. Roll right past it. */
        fun millEnds(lane: Lane, x: Double) = Feature(Kind.Decor, FeatureStyle.MillEnds, lane, x, 10.0, 0.0)

        /** The Washington Park & Zoo Railway's little train, chugging up toward you. */
        fun zooTrain(lane: Lane, x: Double) = Feature(Kind.Block, FeatureStyle.ZooTrain, lane, x, 56.0, 16.0, -30.0)

        /** A Zoobomber on a little kids' bike, bombing the hill with you. */
        fun miniBike(lane: Lane, x: Double, speed: Double = 60.0) =
            Feature(Kind.Block, FeatureStyle.MiniBike, lane, x, 16.0, 20.0, speed)

        // Ramps

        /** A quarter pipe facing you: ride up it and you're launched high off the lip. */
        fun quarterPipe(lane: Lane, x: Double, length: Double = 36.0) =
            Feature(Kind.Ramp, FeatureStyle.QuarterPipe, lane, x, length, Tuning.quarterPipeLip)

        // Holes

        /** An open manhole, about two feet across next to the skater. */
        fun hole(lane: Lane, x: Double, length: Double = 14.0) = Feature(Kind.Hole, FeatureStyle.Hole, lane, x, length, 0.0)
    }
}

/** One of the city's letters, floating somewhere along a run. */
data class LetterPickup(
    /** Its place in the city's name (P is 0 in Portland). */
    val index: Int,
    val letter: Char,
    val lane: Lane,
    val x: Double,
    /** How high its bottom is above the lane. Up to 16 can be reached rolling; higher needs an ollie. */
    val height: Double,
)

/** The look of a spot: its sky, backdrops and ground. */
enum class Theme { Downtown, Skidmore, Burnside, NorthPortland, Waterfront, ZooBomb }

data class Level(
    val id: String,
    val name: String,
    val theme: Theme,
    /** Where the finish line is. */
    val length: Double,
    val features: List<Feature>,
    val letters: List<LetterPickup> = emptyList(),
    val startX: Double = 40.0,
    val startLane: Lane = Lane.Middle,
    /** Speed gained every second, for downhill runs. */
    val acceleration: Double = 0.0,
    val maxSpeed: Double = Tuning.maxSpeed,
    /** Show the how-to-play hints along the way. */
    val showsHints: Boolean = false,
    /** Named jumps worth a bonus. */
    val gaps: List<Gap> = emptyList(),
    /** Things to do here, kept once done. */
    val goals: List<Goal> = emptyList(),
) {
    companion object
}

/** A named jump. Pull it off for a fat bonus on the combo. */
data class Gap(
    val name: String,
    val points: Int,
    val kind: Kind,
    /** What to do, in a few words, shown beside the gap's goal before it's done:
     *  "BENCH+MANHOLE". It has to fit beside the name on the narrowest screen (a test checks). */
    val hint: String = "",
) {
    sealed interface Kind {
        val lane: Lane
        val from: Double
        val to: Double

        /** Get over everything that starts in `lane` from `from` to `to`, in one jump. */
        data class Over(override val lane: Lane, override val from: Double, override val to: Double) : Kind

        /** Grind the thing starting at `from`, then land a grind on the one starting at `to`,
         *  without touching the ground in between. */
        data class Transfer(override val lane: Lane, override val from: Double, override val to: Double) : Kind
    }

    /** The features this gap is made of, by their place in the level. */
    fun features(level: Level): List<Int> = when (kind) {
        is Kind.Over -> level.features.indices.filter {
            val feature = level.features[it]
            feature.lane == kind.lane && feature.x >= kind.from && feature.x <= kind.to
        }
        is Kind.Transfer -> {
            val start = level.features.indices.firstOrNull { level.features[it].lane == kind.lane && level.features[it].x == kind.from }
            val end = level.features.indices.firstOrNull { level.features[it].lane == kind.lane && level.features[it].x == kind.to }
            if (start == null || end == null) emptyList() else listOf(start, end)
        }
    }
}
