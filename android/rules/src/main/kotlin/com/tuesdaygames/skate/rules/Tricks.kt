//
//  Tricks.kt
//
//  The tricks, what they're worth, and the combo that chains them.
//  Ported from skate/Rules/Tricks.swift.
//

package com.tuesdaygames.skate.rules

enum class Trick {
    Ollie, Grab, Kickflip, Heelflip, ShoveIt, ThreeSixtyFlip, FiftyFifty, Boardslide;

    /** What the player sees (Swift: `name`). */
    val displayName: String
        get() = when (this) {
            Ollie -> "OLLIE"
            Grab -> "GRAB"
            Kickflip -> "KICKFLIP"
            Heelflip -> "HEELFLIP"
            ShoveIt -> "SHOVE-IT"
            ThreeSixtyFlip -> "360 FLIP"
            FiftyFifty -> "50-50"
            Boardslide -> "BOARDSLIDE"
        }

    val basePoints: Double
        get() = when (this) {
            Ollie -> 50.0
            Grab -> 100.0
            Kickflip, Heelflip, ShoveIt -> 150.0
            ThreeSixtyFlip -> 300.0
            FiftyFifty -> 100.0
            Boardslide -> 150.0
        }

    /** Extra points for each second a grind lasts, or a grab is held past the hold threshold. */
    val pointsPerSecond: Double
        get() = when (this) {
            Grab -> 250.0
            FiftyFifty -> 100.0
            Boardslide -> 150.0
            else -> 0.0
        }

    /** How long the trick takes in the air. The board has to be back under your
     *  feet before you land, or you bail. Grabs last as long as you hold them. */
    val airTime: Double
        get() = when (this) {
            Grab -> 0.22
            Kickflip, Heelflip -> 0.32
            ShoveIt -> 0.34
            ThreeSixtyFlip -> 0.46
            else -> 0.0
        }

    val isGrind: Boolean get() = this == FiftyFifty || this == Boardslide

    /** How much the trick multiplies the points for clearing something while you do it. */
    val clearStyle: Double
        get() = when (this) {
            Grab -> 1.5
            Kickflip, Heelflip, ShoveIt -> 2.0
            ThreeSixtyFlip -> 3.0
            else -> 1.0
        }

    companion object {
        /** The flip trick for a swipe in the air. */
        fun flip(direction: SwipeDirection): Trick = when (direction) {
            SwipeDirection.Left -> Kickflip
            SwipeDirection.Right -> Heelflip
            SwipeDirection.Down -> ShoveIt
            SwipeDirection.Up -> ThreeSixtyFlip
        }
    }
}

/**
 * The tricks done since you last touched flat ground. Each one adds 1 to the
 * multiplier. Landing clean banks it; bailing loses it.
 *
 * Swift's Combo is a struct, copied when assigned; here `copy()` makes the copy.
 */
class Combo {
    data class Entry(val trick: Trick, var points: Double)

    private val _entries = mutableListOf<Entry>()
    val entries: List<Entry> get() = _entries

    /** Points for things cleared along the way. They ride on the combo's multiplier too. */
    var bonus = 0.0
        private set

    val isEmpty: Boolean get() = _entries.isEmpty()
    val multiplier: Int get() = _entries.size
    val points: Int get() = _entries.fold(bonus) { sum, entry -> sum + entry.points }.toInt()
    val total: Int get() = points * multiplier

    fun add(trick: Trick) {
        _entries += Entry(trick, trick.basePoints)
    }

    /** Adds points to the latest trick, for a grind or grab that is still going. */
    fun extendLast(points: Double) {
        if (_entries.isEmpty()) return
        _entries.last().points += points
    }

    fun addBonus(points: Double) {
        bonus += points
    }

    fun clear() {
        _entries.clear()
        bonus = 0.0
    }

    fun copy(): Combo = Combo().also { copy ->
        _entries.forEach { copy._entries += it.copy() }
        copy.bonus = bonus
    }

    /** The combo as the player sees it, newest tricks last. */
    fun text(maxTricks: Int = 3): String {
        if (_entries.isEmpty()) return ""
        val names = _entries.takeLast(maxTricks).map { it.trick.displayName }
        val lead = if (_entries.size > maxTricks) "... + " else ""
        return lead + names.joinToString(" + ")
    }
}
