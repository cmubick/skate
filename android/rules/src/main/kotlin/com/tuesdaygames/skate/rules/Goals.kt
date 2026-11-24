//
//  Goals.kt
//
//  Each spot has a handful of goals. They're listed before a run, announced the
//  moment you get one, and crossed off at the end. Once done they stay done.
//  Ported from skate/Rules/Goals.swift.
//

package com.tuesdaygames.skate.rules

import kotlin.math.max

data class Goal(
    /** Saved once done, so it must stay the same. */
    val id: String,
    /** Short enough to fit half the screen (checked in the tests). */
    val text: String,
    val kind: Kind,
) {
    sealed interface Kind {
        /** Reach this score in one run. */
        data class Score(val target: Int) : Kind

        /** Bank a single combo worth this much. */
        data class Combo(val target: Int) : Kind

        /** Find every letter hidden at this spot. Letters found on earlier runs count:
         *  you never have to find one again. */
        data object Letters : Kind

        /** Get all the way over one of these, doing at least this hard a trick
         *  (see `Trick.clearStyle`: 1 is any jump, 2 a flip, 3 a 360 flip). */
        data class Clear(val style: FeatureStyle, val trickStyle: Double = 1.0) : Kind

        /** Get over this many of these in one run. */
        data class Clears(val style: FeatureStyle, val count: Int) : Kind

        /** Keep one grind on one of these going this long. */
        data class Grind(val style: FeatureStyle, val seconds: Double) : Kind

        /** Pull off the gap with this name (Swift: `.gap`). */
        data class GapNamed(val name: String) : Kind

        /** Land this trick clean. */
        data class Land(val trick: Trick) : Kind

        /** Get to the finish without bailing. */
        data object NoBails : Kind
    }
}

/**
 * Watches a run and says when each of the spot's goals is met.
 *
 * `alreadyMet`: goals done on earlier runs, which don't need announcing again.
 * `lettersFoundBefore`: the city's letters found on earlier runs.
 */
class GoalTracker(
    val goals: List<Goal>,
    alreadyMet: Set<String> = emptySet(),
    /** The city's letters found on earlier runs, by their place in its name. */
    private val lettersFoundBefore: Set<Int> = emptySet(),
) {
    private val _met = alreadyMet.toMutableSet()
    val met: Set<String> get() = _met
    private val clearCounts = mutableMapOf<FeatureStyle, Int>()
    private var grinding: Pair<Int, Double>? = null
    private var bailed = false

    /** Call after every step of the run, with what happened in it. Returns goals just met. */
    fun update(run: Run, events: List<RunEvent>, dt: Double): List<Goal> {
        var bankedCombo = 0
        val landed = mutableSetOf<String>()
        val gaps = mutableSetOf<String>()
        val clears = mutableListOf<Pair<FeatureStyle, Double>>()
        var finished = false
        for (event in events) {
            when (event) {
                is RunEvent.Banked -> bankedCombo = max(bankedCombo, event.points)
                is RunEvent.LandedTrick -> landed += event.trick.displayName
                is RunEvent.GapDone -> gaps += event.name
                is RunEvent.Cleared -> {
                    clears += event.style to event.trickStyle
                    clearCounts[event.style] = (clearCounts[event.style] ?: 0) + 1
                }
                is RunEvent.Bail -> bailed = true
                is RunEvent.Finished -> finished = true
                else -> {}
            }
        }
        val state = run.state
        grinding = if (state is SkaterState.Grinding) {
            val seconds = (if (grinding?.first == state.feature) grinding?.second ?: 0.0 else 0.0) + dt
            state.feature to seconds
        } else {
            null
        }

        val newlyMet = mutableListOf<Goal>()
        for (goal in goals) {
            if (goal.id in _met) continue
            val done = when (val kind = goal.kind) {
                is Goal.Kind.Score -> run.score >= kind.target
                is Goal.Kind.Combo -> bankedCombo >= kind.target
                Goal.Kind.Letters -> allLettersFound(run.level, lettersFoundBefore + run.lettersFound)
                is Goal.Kind.Clear -> clears.any { it.first == kind.style && it.second >= kind.trickStyle }
                is Goal.Kind.Clears -> (clearCounts[kind.style] ?: 0) >= kind.count
                is Goal.Kind.Grind -> {
                    val grinding = grinding
                    if (grinding != null && run.level.features[grinding.first].style == kind.style) {
                        grinding.second >= kind.seconds
                    } else {
                        false
                    }
                }
                is Goal.Kind.GapNamed -> kind.name in gaps
                is Goal.Kind.Land -> kind.trick.displayName in landed
                Goal.Kind.NoBails -> finished && !bailed
            }
            if (done) {
                _met += goal.id
                newlyMet += goal
            }
        }
        return newlyMet
    }

    companion object {
        /** True if every letter at this spot has been found, on this run or any before. */
        fun allLettersFound(level: Level, found: Set<Int>): Boolean {
            val here = level.letters.map { it.index }.toSet()
            return here.isNotEmpty() && found.containsAll(here)
        }
    }
}
