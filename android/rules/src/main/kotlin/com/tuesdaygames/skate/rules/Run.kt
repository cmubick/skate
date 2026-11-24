//
//  Run.kt
//
//  One run down the street: the skater, what they're doing, the combo and the
//  score. Takes gestures and time, and reports what happened so the scene can
//  play sounds, haptics and animations. Has no drawing in it, so it can be tested.
//  Ported from skate/Rules/Run.swift: keep the two the same.
//

package com.tuesdaygames.skate.rules

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

sealed interface SkaterState {
    data object Rolling : SkaterState
    data object Airborne : SkaterState

    /** On a feature, by its index in the level. */
    data class Grinding(val feature: Int, val trick: Trick) : SkaterState

    /** Tumbling. Gets back up when the time runs out. */
    data class Bailed(val remaining: Double) : SkaterState
}

/** A flip or grab in progress. */
data class AirTrick(
    val trick: Trick,
    var elapsed: Double = 0.0,
    /** Grabs held by the finger have no set length until it lets go. */
    var duration: Double,
) {
    val progress: Double get() = if (duration.isFinite()) min(1.0, elapsed / max(duration, 0.001)) else 0.0
}

enum class BailReason {
    /** Landed before the board came back around. */
    MidTrick,

    /** Still holding a grab when the wheels touched. */
    HoldingGrab,

    /** Rolled or flew into something. */
    Crashed,

    /** Landed on top of something that can't be ground. */
    LandedOnBlock,

    /** Rolled or landed in a hole. */
    Fell,
}

sealed interface RunEvent {
    data class Ollie(val charged: Boolean) : RunEvent
    data object PopOff : RunEvent

    /** Flew off the lip of a quarter pipe. */
    data object Launched : RunEvent
    data class TrickStarted(val trick: Trick) : RunEvent
    data class GrindStarted(val trick: Trick) : RunEvent
    data class GrindSwitched(val trick: Trick) : RunEvent
    data object GrindEnded : RunEvent

    /** Wheels back on the ground, clean. The combo stays open for a moment (see `Run.comboLinkLeft`). */
    data class Landed(val perfect: Boolean) : RunEvent

    /** A trick done in the air was landed clean (on the ground or onto a rail). */
    data class LandedTrick(val trick: Trick) : RunEvent

    /** The combo was counted into the score. */
    data class Banked(val points: Int) : RunEvent
    data class Bail(val reason: BailReason) : RunEvent
    data class LaneSwitch(val lane: Lane) : RunEvent

    /** Picked up one of the city's letters. `index` is its place in the city's name. */
    data class Letter(val index: Int, val letter: Char) : RunEvent

    /** Got all the way over something in the air, doing a trick this hard (`Trick.clearStyle`).
     *  The points go on the combo. */
    data class Cleared(val style: FeatureStyle, val trickStyle: Double, val points: Int) : RunEvent

    /** Pulled off a named gap. The points go on the combo (Swift: `.gap`). */
    data class GapDone(val name: String, val points: Int) : RunEvent
    data class Finished(val score: Int) : RunEvent
}

class Run(val level: Level) {

    // Where the skater is.
    var x: Double = level.startX
        private set

    /** Height of the board above the lane's ground. */
    var height = 0.0
        private set
    var verticalSpeed = 0.0
        private set
    var speed = Tuning.startSpeed
        private set
    var lane: Lane = level.startLane
        private set

    /** The lane as drawn, gliding toward `lane` when you switch: 0 is the back lane, 2 the front. */
    var drawnLane: Double = level.startLane.raw.toDouble()
        private set

    // What the skater is doing.
    var state: SkaterState = SkaterState.Rolling
        private set
    var airTrick: AirTrick? = null
        private set

    /** True while a finger is holding a grab. */
    var isHoldingGrab = false
        private set

    /** Seconds since the last air trick finished, while it hasn't been followed by another. */
    private var sinceTrickEnded: Double? = null

    // The finger.
    /** What the finger that's down did when it went down: popped an ollie, pressed in
     *  the air (a grab, or an ollie if it's still down at touchdown), or pressed on a rail. */
    private enum class Press { None, Ollie, Air, Grind }

    private var press = Press.None

    /** When the last ollie popped, and the combo from just before, so an ollie that
     *  turns out to be the start of a lane swipe can be taken back. */
    private var poppedAt: Double? = null
    private var comboBeforePop = Combo()
    private var linkBeforePop: Double? = null

    // Scoring.
    var combo = Combo()
        private set

    /** After a clean landing the combo stays open this much longer while you roll.
     *  Null when there's no combo, or you're in the air or on a rail. */
    var comboLinkLeft: Double? = null
        private set

    /** The combo's size at the last landing, to tell whether anything new has happened since. */
    private var comboAtLanding: Pair<Int, Double>? = null
    var score = 0
        private set

    /** The biggest combo banked on this run, and the tricks that made it (the last few). */
    var bestCombo = 0
        private set
    var bestComboTricks = ""
        private set
    var time = 0.0
        private set
    var isFinished = false
        private set

    /** Letters picked up on this run, by their place in the city's name. */
    private val _lettersFound = mutableSetOf<Int>()
    val lettersFound: Set<Int> get() = _lettersFound

    /** Features the skater is passing over right now, with the hardest trick's style so far.
     *  Touching down, grinding or bailing while over one spoils it. */
    private val passingOver = mutableMapOf<Int, Double>()
    private val spoiled = mutableSetOf<Int>()

    /** Everything cleared since leaving the ground, the gaps done on this jump, and the
     *  rail just left behind, for the named gaps. */
    private val clearedThisJump = mutableSetOf<Int>()
    private val gapsThisJump = mutableSetOf<Int>()
    private var leftGrind: Int? = null

    /** Each gap's features, by their place in the level. */
    private val gapFeatures: List<List<Int>> = level.gaps.map { it.features(level) }
    private val inGaps: Set<Int> = gapFeatures.flatten().toSet()

    /** Tricks done since leaving the ground, reported once they're landed. */
    private val tricksThisJump = mutableListOf<Trick>()

    /** When each moving feature came on screen and started moving. */
    private val startedMoving = arrayOfNulls<Double>(level.features.size)

    /** Where a feature starts right now. Moving things stay put until they come on screen. */
    fun position(feature: Int): Double {
        val f = level.features[feature]
        val start = startedMoving[feature] ?: return f.x
        return f.x + f.velocity * (time - start)
    }

    val isAirborne: Boolean get() = state == SkaterState.Airborne
    val isGrinding: Boolean get() = state is SkaterState.Grinding
    private val isBailed: Boolean get() = state is SkaterState.Bailed

    // Input

    fun handle(gesture: GestureEvent): List<RunEvent> {
        if (isFinished) return emptyList()
        val events = mutableListOf<RunEvent>()
        when (gesture) {
            GestureEvent.Press -> when (state) {
                SkaterState.Rolling -> {
                    // Pop straight away. Keeping the finger down carries the ollie higher.
                    press = Press.Ollie
                    ollie(events)
                }
                SkaterState.Airborne -> press = Press.Air
                is SkaterState.Grinding -> press = Press.Grind
                is SkaterState.Bailed -> press = Press.None
            }

            GestureEvent.Hold -> {
                // Holding in the air is a long grab.
                if (state == SkaterState.Airborne && press == Press.Air && airTrick == null) {
                    startAirTrick(Trick.Grab, Double.POSITIVE_INFINITY, events)
                    isHoldingGrab = true
                }
            }

            is GestureEvent.Release -> {
                val pressed = press
                press = Press.None
                when (state) {
                    // Any ollie this finger asked for has already happened.
                    SkaterState.Rolling -> {}
                    SkaterState.Airborne -> {
                        if (pressed == Press.Ollie) {
                            // Full gravity again from here: the ollie stops climbing soon.
                        } else if (isHoldingGrab) {
                            releaseGrab(gesture.held)
                        } else if (pressed == Press.Air && airTrick == null) {
                            startAirTrick(Trick.Grab, Trick.Grab.airTime, events)
                        }
                    }
                    is SkaterState.Grinding -> popOff(events)
                    is SkaterState.Bailed -> {}
                }
            }

            is GestureEvent.Swipe -> {
                val direction = gesture.direction
                val pressed = press
                press = Press.None
                val vertical = direction == SwipeDirection.Up || direction == SwipeDirection.Down
                if (pressed == Press.Ollie && vertical && takeBackOllie()) {
                    switchLane(if (direction == SwipeDirection.Up) lane.up else lane.down, events)
                    return events
                }
                when (val current = state) {
                    SkaterState.Rolling -> when (direction) {
                        SwipeDirection.Up -> switchLane(lane.up, events)
                        SwipeDirection.Down -> switchLane(lane.down, events)
                        SwipeDirection.Left, SwipeDirection.Right -> {
                            // A flip straight off the ground, in one swipe: pop and flip together.
                            ollie(events)
                            startAirTrick(Trick.flip(direction), null, events)
                        }
                    }
                    SkaterState.Airborne -> if (airTrick == null) startAirTrick(Trick.flip(direction), null, events)
                    is SkaterState.Grinding -> {
                        if (direction == SwipeDirection.Up) {
                            // Ollie out toward the lane above.
                            popOff(events)
                            lane.up?.let { up -> lane = up; events += RunEvent.LaneSwitch(up) }
                        } else {
                            val next = if (current.trick == Trick.FiftyFifty) Trick.Boardslide else Trick.FiftyFifty
                            state = SkaterState.Grinding(current.feature, next)
                            combo.add(next)
                            events += RunEvent.GrindSwitched(next)
                        }
                    }
                    is SkaterState.Bailed -> {
                        // Down on the ground: scramble into the next lane and get straight back up
                        // there, instead of lying under whatever you hit.
                        val next = if (direction == SwipeDirection.Up) lane.up else lane.down
                        if (height == 0.0 && vertical && next != null) {
                            lane = next
                            events += RunEvent.LaneSwitch(next)
                            if (blockingFeature(0.0) == null && !isOverHole) getUp()
                        }
                    }
                }
            }
        }
        return events
    }

    // Time

    fun step(dt: Double): List<RunEvent> {
        if (isFinished || dt <= 0) return emptyList()
        val events = mutableListOf<RunEvent>()
        time += dt
        val seconds = dt

        val target = lane.raw.toDouble()
        val glide = seconds / Tuning.laneSwitchTime
        drawnLane += max(-glide, min(glide, target - drawnLane))

        trackClearing(events)

        // Moving things start moving once they're about to come on screen.
        for (index in level.features.indices) {
            if (startedMoving[index] == null && level.features[index].isMoving) {
                if (x + Tuning.movingStartDistance >= level.features[index].x) startedMoving[index] = time
            }
        }

        // Downhill spots keep speeding you up.
        if (level.acceleration > 0 && !isBailed) {
            speed = min(level.maxSpeed, speed + level.acceleration * seconds)
        }

        when (val current = state) {
            SkaterState.Rolling -> {
                val before = x
                x += speed * seconds
                rideRamps(before, events)
                if (state == SkaterState.Rolling) {
                    comboLinkLeft?.let { left ->
                        if (left - dt <= 0) bankCombo(events) else comboLinkLeft = left - dt
                    }
                }
                if (state != SkaterState.Rolling) {
                    // Launched off a ramp.
                } else if (blockingFeature(height) != null) {
                    bail(BailReason.Crashed, events)
                } else if (isOverHole) {
                    bail(BailReason.Fell, events)
                }
            }

            SkaterState.Airborne -> {
                val previousHeight = height
                val held = press == Press.Ollie && verticalSpeed > 0
                verticalSpeed -= Tuning.gravity * (if (held) Tuning.heldOllieGravityScale else 1.0) * seconds
                height += verticalSpeed * seconds
                x += speed * seconds
                advanceAirTrick(dt)

                val landing = if (verticalSpeed <= 0) landingFeature(previousHeight) else null
                if (landing != null) {
                    val feature = level.features[landing]
                    val reason = landingProblem()
                    if (!feature.isGrindable) {
                        bail(BailReason.LandedOnBlock, events)
                    } else if (reason != null) {
                        bail(reason, events)
                    } else {
                        height = feature.height
                        verticalSpeed = 0.0
                        finishAirTrick()
                        reportLandedTricks(events)
                        state = SkaterState.Grinding(landing, Trick.FiftyFifty)
                        combo.add(Trick.FiftyFifty)
                        events += RunEvent.GrindStarted(Trick.FiftyFifty)
                        checkTransfers(landing, events)
                    }
                } else if (blockingFeature(height) != null) {
                    bail(BailReason.Crashed, events)
                } else if (height <= 0 && isOverHole) {
                    height = 0.0
                    verticalSpeed = 0.0
                    bail(BailReason.Fell, events)
                } else if (height <= 0) {
                    land(events)
                }
            }

            is SkaterState.Grinding -> {
                x += speed * seconds
                combo.extendLast(current.trick.pointsPerSecond * dt)
                if (x - Tuning.skaterHalfWidth > level.features[current.feature].end) {
                    startJump()
                    leftGrind = current.feature
                    state = SkaterState.Airborne
                    verticalSpeed = Tuning.railEndVelocity
                    events += RunEvent.GrindEnded
                }
            }

            is SkaterState.Bailed -> {
                speed += (Tuning.bailSlideSpeed - speed) * min(1.0, seconds * 4)
                x += speed * seconds
                if (height > 0) {
                    verticalSpeed -= Tuning.gravity * seconds
                    height = max(0.0, height + verticalSpeed * seconds)
                }
                val left = current.remaining - dt
                // Don't get up in the middle of a cone, or in a hole.
                if (left <= 0 && height == 0.0 && blockingFeature(0.0) == null && !isOverHole) {
                    getUp()
                } else {
                    state = SkaterState.Bailed(left)
                }
            }
        }

        collectLetters(events)

        if (x >= level.length) {
            if (state == SkaterState.Rolling) bankCombo(events)
            isFinished = true
            events += RunEvent.Finished(score)
        }
        return events
    }

    // Moves

    /** Pops with a tapped ollie's speed. Gravity goes easy while the finger stays down. */
    private fun ollie(events: MutableList<RunEvent>) {
        comboBeforePop = combo.copy()
        linkBeforePop = comboLinkLeft
        poppedAt = time
        startJump()
        verticalSpeed = sqrt(2 * Tuning.gravity * Tuning.ollieHeight)
        state = SkaterState.Airborne
        sinceTrickEnded = null
        // An ollie starts a combo, but doesn't keep one going: that needs a real trick.
        if (comboLinkLeft != null) {
            comboLinkLeft = null
        } else {
            combo.add(Trick.Ollie)
        }
        events += RunEvent.Ollie(charged = false)
    }

    /** Leaving the ground (or a rail): a fresh jump for gaps and landed tricks. */
    private fun startJump() {
        clearedThisJump.clear()
        gapsThisJump.clear()
        tricksThisJump.clear()
    }

    /** Undoes an ollie that only just popped: no points for it, and the skater drops
     *  straight back down from wherever it got to. False if it's too late. */
    private fun takeBackOllie(): Boolean {
        val poppedAt = poppedAt
        if (state != SkaterState.Airborne || airTrick != null || verticalSpeed <= 0 ||
            poppedAt == null || time - poppedAt > Tuning.ollieCancelWindow
        ) return false
        this.poppedAt = null
        combo = comboBeforePop.copy()
        comboLinkLeft = linkBeforePop
        verticalSpeed = 0.0
        return true
    }

    private fun popOff(events: MutableList<RunEvent>) {
        startJump()
        val current = state
        if (current is SkaterState.Grinding) {
            leftGrind = current.feature
            events += RunEvent.GrindEnded
        }
        verticalSpeed = sqrt(2 * Tuning.gravity * Tuning.popOffHeight)
        state = SkaterState.Airborne
        sinceTrickEnded = null
        events += RunEvent.PopOff
    }

    private fun switchLane(next: Lane?, events: MutableList<RunEvent>) {
        if (next == null) return
        lane = next
        events += RunEvent.LaneSwitch(next)
    }

    private fun startAirTrick(trick: Trick, duration: Double?, events: MutableList<RunEvent>) {
        airTrick = AirTrick(trick, duration = duration ?: trick.airTime)
        tricksThisJump += trick
        sinceTrickEnded = null
        combo.add(trick)
        events += RunEvent.TrickStarted(trick)
    }

    private fun releaseGrab(held: Double) {
        isHoldingGrab = false
        val trick = airTrick ?: return
        combo.extendLast(Trick.Grab.pointsPerSecond * max(0.0, held - Tuning.holdThreshold))
        // Let go of the board: a short moment to get the feet back on.
        trick.duration = max(trick.elapsed + 0.06, Trick.Grab.airTime)
    }

    private fun advanceAirTrick(dt: Double) {
        val trick = airTrick
        if (trick != null) {
            trick.elapsed += dt
            if (trick.elapsed >= trick.duration) {
                airTrick = null
                sinceTrickEnded = 0.0
            }
        } else {
            sinceTrickEnded?.let { sinceTrickEnded = it + dt }
        }
    }

    private fun finishAirTrick() {
        airTrick = null
        isHoldingGrab = false
    }

    /** Why touching down now would be a bail, if it would. */
    private fun landingProblem(): BailReason? {
        if (isHoldingGrab) return BailReason.HoldingGrab
        if (airTrick != null) return BailReason.MidTrick
        return null
    }

    private fun land(events: MutableList<RunEvent>) {
        height = 0.0
        verticalSpeed = 0.0
        landingProblem()?.let { reason ->
            bail(reason, events)
            return
        }
        val perfect = sinceTrickEnded?.let { it <= Tuning.perfectWindow } ?: false
        sinceTrickEnded = null
        reportLandedTricks(events)
        leftGrind = null
        state = SkaterState.Rolling
        // Did anything new go on the combo since the last landing?
        val grew = comboAtLanding?.let { it.first != combo.multiplier || it.second != combo.bonus } ?: !combo.isEmpty
        if (grew) {
            if (perfect) combo.addBonus(combo.points * Tuning.perfectBonus)
            speed = min(level.maxSpeed, speed + if (perfect) Tuning.speedPerPerfectLanding else Tuning.speedPerLanding)
        }
        events += RunEvent.Landed(perfect = perfect && grew)
        if (combo.isEmpty) {
            comboLinkLeft = null
            comboAtLanding = null
        } else if (grew) {
            // Keep it open: another trick soon keeps it going.
            comboLinkLeft = Tuning.comboLinkTime
            comboAtLanding = combo.multiplier to combo.bonus
        } else {
            bankCombo(events)
        }
        // A press made just before touchdown, still down, pops again right away,
        // so pressing a little early isn't punished.
        if (press == Press.Air) {
            press = Press.Ollie
            ollie(events)
        }
    }

    /** Counts the combo into the score. */
    private fun bankCombo(events: MutableList<RunEvent>) {
        comboLinkLeft = null
        comboAtLanding = null
        if (combo.isEmpty) return
        val points = combo.total
        score += points
        if (points > bestCombo) {
            bestCombo = points
            bestComboTricks = combo.text(maxTricks = 2)
        }
        combo.clear()
        events += RunEvent.Banked(points)
    }

    private fun reportLandedTricks(events: MutableList<RunEvent>) {
        for (trick in tricksThisJump) events += RunEvent.LandedTrick(trick)
        tricksThisJump.clear()
    }

    /** Riding up a quarter pipe: the board follows the ramp, and leaving the lip launches you. */
    private fun rideRamps(before: Double, events: MutableList<RunEvent>) {
        var onRamp = false
        for (index in level.features.indices) {
            val ramp = level.features[index]
            if (ramp.kind != Feature.Kind.Ramp || ramp.lane != lane) continue
            val start = position(index)
            if (x >= start && x < start + ramp.length) {
                height = ramp.rampHeight(x, start)
                onRamp = true
            } else if (before < start + ramp.length && x >= start + ramp.length) {
                startJump()
                height = ramp.height
                state = SkaterState.Airborne
                verticalSpeed = sqrt(2 * Tuning.gravity * (Tuning.quarterPipeAir - ramp.height))
                events += RunEvent.Launched
                return
            }
        }
        if (!onRamp) height = 0.0
    }

    private fun bail(reason: BailReason, events: MutableList<RunEvent>) {
        if (state is SkaterState.Grinding) events += RunEvent.GrindEnded
        state = SkaterState.Bailed(Tuning.bailTime)
        combo.clear()
        comboLinkLeft = null
        comboAtLanding = null
        leftGrind = null
        tricksThisJump.clear()
        finishAirTrick()
        sinceTrickEnded = null
        press = Press.None
        events += RunEvent.Bail(reason)
    }

    private fun getUp() {
        state = SkaterState.Rolling
        speed = Tuning.speedAfterBail
        verticalSpeed = 0.0
    }

    // Letters

    private fun collectLetters(events: MutableList<RunEvent>) {
        for (pickup in level.letters) {
            if (pickup.index in _lettersFound) continue
            if (pickup.lane != lane || isBailed ||
                abs(pickup.x - x) > Tuning.letterReachX ||
                pickup.height < height - 4 || pickup.height > height + Tuning.letterReachUp
            ) continue
            _lettersFound += pickup.index
            score += Tuning.letterPoints
            events += RunEvent.Letter(pickup.index, pickup.letter)
        }
    }

    // Clearing things

    /** Watches what the skater passes over. Getting all the way past something without
     *  touching down on it earns its clear points, times the hardest trick done over it. */
    private fun trackClearing(events: MutableList<RunEvent>) {
        for (index in level.features.indices) {
            val feature = level.features[index]
            if (!(feature.clearPoints > 0 || index in inGaps)) continue
            if (overlaps(index)) {
                val clean = state == SkaterState.Airborne && height >= feature.height - Tuning.grindSnapBelow
                if (clean && index !in spoiled) {
                    val style = airTrick?.trick?.clearStyle ?: 1.0
                    passingOver[index] = max(passingOver[index] ?: 1.0, style)
                } else {
                    passingOver.remove(index)
                    spoiled += index
                }
                continue
            }
            spoiled -= index
            val style = passingOver.remove(index) ?: continue
            // Only for going past it, not for it passing you.
            if (!(x - Tuning.skaterHalfWidth > position(index) + feature.length) || isBailed) continue
            clearedThisJump += index
            val points = (feature.clearPoints * style).toInt()
            if (points > 0) {
                addBonus(points)
                events += RunEvent.Cleared(feature.style, style, points)
            }
        }
        checkOverGaps(events)
    }

    /** Bonus points onto the combo; straight into the score if it has just been banked. */
    private fun addBonus(points: Int) {
        if (combo.isEmpty) {
            score += points
        } else {
            combo.addBonus(points.toDouble())
        }
    }

    // Named gaps

    private fun checkOverGaps(events: MutableList<RunEvent>) {
        for ((index, gap) in level.gaps.withIndex()) {
            if (index in gapsThisJump) continue
            if (gap.kind !is Gap.Kind.Over || gapFeatures[index].isEmpty() ||
                !gapFeatures[index].all { it in clearedThisJump }
            ) continue
            award(index, events)
        }
    }

    private fun checkTransfers(feature: Int, events: MutableList<RunEvent>) {
        val leftGrind = leftGrind
        try {
            if (leftGrind == null) return
            for ((index, gap) in level.gaps.withIndex()) {
                if (index in gapsThisJump) continue
                if (gap.kind !is Gap.Kind.Transfer || gapFeatures[index] != listOf(leftGrind, feature)) continue
                award(index, events)
            }
        } finally {
            this.leftGrind = null
        }
    }

    private fun award(index: Int, events: MutableList<RunEvent>) {
        gapsThisJump += index
        val gap = level.gaps[index]
        addBonus(gap.points)
        events += RunEvent.GapDone(gap.name, gap.points)
    }

    // Collisions

    private fun overlaps(index: Int): Boolean {
        val feature = level.features[index]
        val start = position(index)
        return feature.lane == lane &&
            x + Tuning.skaterHalfWidth >= start &&
            x - Tuning.skaterHalfWidth <= start + feature.length
    }

    /** Something in the way at this height, if there is. Holes and low curbs never are. */
    private fun blockingFeature(height: Double): Int? = level.features.indices.firstOrNull { index ->
        val feature = level.features[index]
        if (feature.kind == Feature.Kind.Hole || feature.kind == Feature.Kind.Ramp ||
            feature.kind == Feature.Kind.Decor || feature.isLow
        ) {
            false
        } else {
            overlaps(index) && height < feature.height - Tuning.grindSnapBelow
        }
    }

    /** True when the skater's wheels are over a hole in their lane. */
    private val isOverHole: Boolean
        get() = level.features.indices.any { index ->
            val feature = level.features[index]
            val start = position(index)
            feature.kind == Feature.Kind.Hole && feature.lane == lane &&
                x >= start + 3 && x <= start + feature.length - 3
        }

    /** The feature the skater is coming down onto, if any. */
    private fun landingFeature(previousHeight: Double): Int? = level.features.indices.firstOrNull { index ->
        val feature = level.features[index]
        if (feature.kind == Feature.Kind.Hole || feature.kind == Feature.Kind.Ramp || feature.kind == Feature.Kind.Decor) {
            false
        } else {
            // Rails pull you in from a little above. Cones only count if you really touch them.
            val snap = if (feature.isGrindable) Tuning.grindSnap else 0.0
            overlaps(index) &&
                previousHeight >= feature.height - Tuning.grindSnapBelow &&
                height <= feature.height + snap
        }
    }
}
