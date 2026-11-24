//
//  Tutorial.kt
//
//  The tutorial: one move at a time on a practice street. Each step waits until
//  you've done it, then moves on to the next. Ported from skate/Rules/Tutorial.swift.
//

package com.tuesdaygames.skate.rules

data class TutorialStep(val text: String, val check: Check) {
    sealed interface Check {
        /** Pop an ollie and land it. */
        data object Ollie : Check

        /** Get the board this high off the ground. */
        data class Height(val height: Double) : Check
        data object LaneSwitch : Check

        /** Land a kickflip or heelflip. */
        data object Flip : Check
        data object Grab : Check

        /** Land a shove-it or 360 flip. */
        data object Spin : Check
        data object Grind : Check

        /** Switch a grind into a boardslide. */
        data object Boardslide : Check
        data object HopOff : Check

        /** Get the combo multiplier this high. */
        data class Combo(val multiplier: Int) : Check

        /** Get all the way over something. */
        data object Clear : Check
    }
}

class Tutorial {
    var index = 0
        private set
    private var poppedThisJump = false

    val current: TutorialStep? get() = steps.getOrNull(index)
    val isDone: Boolean get() = index >= steps.size

    /** Call with everything the run reports. Returns the step just done, if one was. */
    fun update(run: Run, events: List<RunEvent>): TutorialStep? {
        val step = current ?: return null
        var done = false
        for (event in events) {
            when (step.check) {
                TutorialStep.Check.Ollie -> when (event) {
                    is RunEvent.Ollie -> poppedThisJump = true
                    is RunEvent.Landed -> done = done || poppedThisJump
                    else -> {}
                }
                TutorialStep.Check.LaneSwitch -> if (event is RunEvent.LaneSwitch) done = true
                TutorialStep.Check.Flip -> if (event is RunEvent.LandedTrick) {
                    done = done || event.trick == Trick.Kickflip || event.trick == Trick.Heelflip
                }
                TutorialStep.Check.Grab -> if (event is RunEvent.LandedTrick) done = done || event.trick == Trick.Grab
                TutorialStep.Check.Spin -> if (event is RunEvent.LandedTrick) {
                    done = done || event.trick == Trick.ShoveIt || event.trick == Trick.ThreeSixtyFlip
                }
                TutorialStep.Check.Grind -> if (event is RunEvent.GrindStarted) done = true
                TutorialStep.Check.Boardslide -> if (event == RunEvent.GrindSwitched(Trick.Boardslide)) done = true
                TutorialStep.Check.HopOff -> if (event == RunEvent.PopOff) done = true
                TutorialStep.Check.Clear -> if (event is RunEvent.Cleared) done = true
                else -> {}
            }
        }
        when (val check = step.check) {
            is TutorialStep.Check.Height -> done = run.isAirborne && run.height >= check.height
            is TutorialStep.Check.Combo -> done = done || run.combo.multiplier >= check.multiplier
            else -> {}
        }
        if (!done) return null
        index += 1
        poppedThisJump = false
        return step
    }

    companion object {
        val steps: List<TutorialStep> = listOf(
            TutorialStep("TAP TO OLLIE", TutorialStep.Check.Ollie),
            TutorialStep("HOLD TO OLLIE HIGHER", TutorialStep.Check.Height(30.0)),
            TutorialStep("SWIPE UP OR DOWN: LANES", TutorialStep.Check.LaneSwitch),
            TutorialStep("SWIPE SIDEWAYS: KICKFLIP", TutorialStep.Check.Flip),
            TutorialStep("OLLIE, TAP IN AIR: GRAB", TutorialStep.Check.Grab),
            TutorialStep("AIR SWIPE UP/DOWN: SPIN", TutorialStep.Check.Spin),
            TutorialStep("BACK LANE: LAND ON A RAIL", TutorialStep.Check.Grind),
            TutorialStep("ON RAIL, SWIPE DOWN: SLIDE", TutorialStep.Check.Boardslide),
            TutorialStep("ON A RAIL, TAP: HOP OFF", TutorialStep.Check.HopOff),
            TutorialStep("TRICK AGAIN SOON: COMBO X3", TutorialStep.Check.Combo(3)),
            TutorialStep("FRONT LANE: JUMP A CONE", TutorialStep.Check.Clear),
        )
    }
}

/** The practice street: nothing in the middle lane, rails along the back lane and
 *  cones along the front, over and over, so there's always one coming. */
val Level.Companion.tutorial: Level by lazy {
    val features = mutableListOf<Feature>()
    for (repeatIndex in 0 until 40) {
        val x = (700 + repeatIndex * 360).toDouble()
        features += Feature.rail(Lane.Back, x, length = 90.0)
        features += Feature.cone(Lane.Front, x + 180)
    }
    Level(id = "tutorial", name = "TUTORIAL", theme = Theme.Downtown, length = 15_500.0, features = features)
}
