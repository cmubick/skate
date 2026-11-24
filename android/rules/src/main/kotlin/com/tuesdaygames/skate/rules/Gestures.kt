//
//  Gestures.kt
//
//  Turns one finger's touches into the game's four inputs: press, hold,
//  release and swipe. Knows nothing about skating. Ported from skate/Rules/Gestures.swift.
//

package com.tuesdaygames.skate.rules

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.sqrt

enum class SwipeDirection { Up, Down, Left, Right }

sealed interface GestureEvent {
    /** A finger went down. It may turn into a tap, a hold or a swipe. */
    data object Press : GestureEvent

    /** The finger has stayed down past the hold threshold without swiping. */
    data object Hold : GestureEvent

    /** The finger came up without swiping. `held` is how long it was down. */
    data class Release(val held: Double) : GestureEvent

    /** The finger moved far enough to be a swipe. It fires as soon as the finger has
     *  moved far enough, not when it comes up, and nothing else follows for that touch. */
    data class Swipe(val direction: SwipeDirection) : GestureEvent
}

/** A point on the screen. Gestures use points (dp), with y growing downward. */
data class Point(val x: Double, val y: Double)

/** Follows one touch at a time. Times are in seconds. */
class GestureReader {
    private var start: Point? = null
    private var startTime = 0.0
    private var swiped = false
    private var holdSent = false

    val isTouching: Boolean get() = start != null

    fun began(point: Point, time: Double): List<GestureEvent> {
        start = point
        startTime = time
        swiped = false
        holdSent = false
        return listOf(GestureEvent.Press)
    }

    fun moved(point: Point, time: Double): List<GestureEvent> {
        val start = start ?: return emptyList()
        if (swiped) return emptyList()
        val dx = point.x - start.x
        val dy = point.y - start.y
        if (sqrt(dx * dx + dy * dy) < Tuning.swipeDistance) return emptyList()
        swiped = true
        if (abs(dx) > abs(dy)) {
            return listOf(GestureEvent.Swipe(if (dx > 0) SwipeDirection.Right else SwipeDirection.Left))
        }
        return listOf(GestureEvent.Swipe(if (dy < 0) SwipeDirection.Up else SwipeDirection.Down))
    }

    /** Call every frame so a hold is noticed while the finger stays still. */
    fun tick(time: Double): List<GestureEvent> {
        if (start == null || swiped || holdSent || time - startTime < Tuning.holdThreshold) return emptyList()
        holdSent = true
        return listOf(GestureEvent.Hold)
    }

    fun ended(point: Point, time: Double): List<GestureEvent> {
        if (start == null) return emptyList()
        val events = moved(point, time).toMutableList()
        if (!swiped) {
            events += tick(time)
            events += GestureEvent.Release(max(0.0, time - startTime))
        }
        start = null
        return events
    }

    /** The system took the touch away (a call came in, say). Treat it as a release. */
    fun cancelled(time: Double): List<GestureEvent> {
        if (start == null) return emptyList()
        val events = if (swiped) emptyList() else listOf(GestureEvent.Release(max(0.0, time - startTime)))
        start = null
        return events
    }
}
