//
//  SeededGenerator.kt
//
//  The same "random" numbers every launch, so generated art and sounds don't
//  change. Ported from the bottom of skate/UI/PixelArt.swift.
//
//  The art asks for random numbers the way Swift's standard library hands them
//  out (`Int.random(in:using:)`, `Bool.random(using:)`, `randomElement(using:)`),
//  so this copies those methods exactly. Then the same seed draws the same
//  buildings, people and drips as on iOS (ParityTests checks).
//

package com.tuesdaygames.skate.rules

class SeededGenerator(seed: Long) {
    private var state: ULong = seed.toULong() + GOLDEN

    constructor(seed: Int) : this(seed.toLong())

    /** SplitMix64, as on iOS. */
    fun next(): ULong {
        state += GOLDEN
        var z = state
        z = (z xor (z shr 30)) * 0xBF58_476D_1CE4_E5B9uL
        z = (z xor (z shr 27)) * 0x94D0_49BB_1331_11EBuL
        return z xor (z shr 31)
    }

    /** Swift's `next(upperBound:)`: Lemire's nearly divisionless method. */
    fun next(upperBound: ULong): ULong {
        require(upperBound != 0uL)
        var random = next()
        var (high, low) = multiplyFull(random, upperBound)
        if (low < upperBound) {
            val threshold = (0uL - upperBound) % upperBound
            while (low < threshold) {
                random = next()
                val product = multiplyFull(random, upperBound)
                high = product.first
                low = product.second
            }
        }
        return high
    }

    /** `Int.random(in: lower..<upper, using:)`. */
    fun intUntil(lower: Int, upper: Int): Int {
        require(lower < upper)
        val delta = (upper.toLong() - lower.toLong()).toULong()
        return (lower.toLong() + next(delta).toLong()).toInt()
    }

    /** `Int.random(in: lower...upper, using:)`. */
    fun int(lower: Int, upper: Int): Int {
        require(lower <= upper)
        val delta = (upper.toLong() - lower.toLong()).toULong()
        return (lower.toLong() + next(delta + 1uL).toLong()).toInt()
    }

    fun int(range: IntRange): Int = int(range.first, range.last)

    /** `Bool.random(using:)`. */
    fun bool(): Boolean = ((next() shr 17) and 1uL) == 0uL

    /** `Double.random(in: lower...upper, using:)`. */
    fun double(lower: Double, upper: Double): Double {
        val maxSignificand = 1uL shl 53
        val random = next(maxSignificand + 1uL)
        if (random == maxSignificand) return upper
        val unit = random.toDouble() * (Math.ulp(1.0) / 2)
        return (upper - lower) * unit + lower
    }

    /** `randomElement(using:)`: null for an empty list, without drawing a number. */
    fun <T> element(list: List<T>): T? = if (list.isEmpty()) null else list[intUntil(0, list.size)]

    private companion object {
        const val GOLDEN = 0x9E37_79B9_7F4A_7C15uL

        /** The full 128-bit product, as (high, low): Swift's `multipliedFullWidth(by:)`. */
        fun multiplyFull(a: ULong, b: ULong): Pair<ULong, ULong> {
            val mask = 0xFFFF_FFFFuL
            val aLow = a and mask
            val aHigh = a shr 32
            val bLow = b and mask
            val bHigh = b shr 32
            val lowLow = aLow * bLow
            val highLow = aHigh * bLow
            val lowHigh = aLow * bHigh
            val highHigh = aHigh * bHigh
            val cross = (lowLow shr 32) + (highLow and mask) + lowHigh
            val high = highHigh + (highLow shr 32) + (cross shr 32)
            val low = (cross shl 32) or (lowLow and mask)
            return high to low
        }
    }
}
