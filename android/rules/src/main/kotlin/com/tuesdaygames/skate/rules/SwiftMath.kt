//
//  SwiftMath.kt
//
//  Small pieces of arithmetic that Swift and Kotlin do differently. The iOS
//  code relies on Swift's versions, so the port uses these to come out the same.
//

package com.tuesdaygames.skate.rules

import kotlin.math.abs
import kotlin.math.sign
import kotlin.math.truncate

/**
 * Swift's `rounded()`: halves round away from zero (2.5 is 3, -2.5 is -3).
 * Kotlin's `round` rounds halves to even, which would move some pixels.
 */
fun Double.rounded(): Double {
    val whole = truncate(this)
    return if (abs(this - whole) >= 0.5) whole + sign(this) else whole
}

/**
 * Swift's `stride(from:to:by:)` and `stride(from:through:by:)` for decimals:
 * each value is `start + n * step`, worked out afresh rather than added up, so
 * small errors don't build.
 */
fun strideDoubles(from: Double, to: Double, by: Double, through: Boolean = false): Sequence<Double> = sequence {
    var n = 0
    while (true) {
        val value = from + n * by
        val more = if (by > 0) (if (through) value <= to else value < to) else (if (through) value >= to else value > to)
        if (!more) break
        yield(value)
        n += 1
    }
}
