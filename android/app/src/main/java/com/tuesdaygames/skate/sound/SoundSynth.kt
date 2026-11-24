//
//  SoundSynth.kt
//
//  Chip-style sound effects, generated in code so the app ships no audio files.
//  Square waves and noise, like a 4-voice NES sound chip. Ported from the first
//  half of skate/UI/Sounds.swift. Plain Kotlin, so the tests can check it.
//

package com.tuesdaygames.skate.sound

import com.tuesdaygames.skate.rules.SeededGenerator
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.sin

enum class Sound {
    /** The board popping off the ground. */
    Pop,
    /** A flip or grab: a quick swish. */
    Trick,
    /** Wheels back down. */
    Land,
    /** A perfect landing: a bright two-note blip. */
    Perfect,
    /** Metal under the board. Loops for as long as the grind lasts. */
    Grind,
    /** Switching lanes. */
    Lane,
    /** A tumble. */
    Bail,
    /** Crossing the finish line. */
    Finish,
    /** Picking up one of the city's letters. */
    Letter,
    /** Wheels on pavement, with a clack over the cracks. Loops while rolling. */
    Roll,
    /** Concrete and wood under the trucks: ledges, benches, curbs. Loops. */
    Scrape,
    /** A boardslide: the deck scraping across. Loops. */
    Slide,
    /** Locking onto a rail or ledge. */
    Lock,
    /** A kickflip or heelflip: a flick and the board whirring round. */
    Flip,
    /** A shove-it or 360 flip: a whoosh. */
    Spin,
    /** A grab. */
    Grab,
    /** Flying off the lip of a quarter pipe. */
    Launch,
    /** Getting all the way over something. */
    Clear,
    /** A combo counted into the score. */
    Bank,
    /** A named gap. */
    Gap,
    /** A goal done. */
    Goal,
    /** Dropping into a manhole. */
    Fall,
    /** A firework going off. */
    Burst;

    companion object {
        /** The sounds that loop for as long as something lasts. */
        val loops: Set<Sound> = setOf(Grind, Scrape, Slide, Roll)
    }
}

/** Builds each sound's samples, from -1 to 1. */
object SoundSynth {
    const val sampleRate = 22_050.0

    /** A square wave that glides from one pitch to another and fades out. */
    fun square(from: Double, to: Double, seconds: Double, level: Double, duty: Double = 0.5): DoubleArray {
        val count = (seconds * sampleRate).toInt()
        var phase = 0.0
        return DoubleArray(count) { index ->
            val progress = index.toDouble() / max(count, 1)
            phase += (from + (to - from) * progress) / sampleRate
            val wave = if (phase % 1 < duty) 1.0 else -1.0
            wave * level * (1 - progress)
        }
    }

    /** A triangle wave, the NES's bass voice. */
    fun triangle(frequency: Double, seconds: Double, level: Double): DoubleArray {
        val count = (seconds * sampleRate).toInt()
        return DoubleArray(count) { index ->
            val t = index / sampleRate
            val phase = (t * frequency) % 1
            val wave = if (phase < 0.5) 4 * phase - 1 else 3 - 4 * phase
            wave * level * (1 - index.toDouble() / max(count, 1))
        }
    }

    /** Noise, held for `hold` samples at a time: long holds sound low and crunchy. */
    fun noise(seconds: Double, hold: Int, level: Double, decay: Double, seed: Long): DoubleArray {
        val generator = SeededGenerator(seed)
        val count = (seconds * sampleRate).toInt()
        var value = 0.0
        return DoubleArray(count) { index ->
            if (index % max(1, hold) == 0) value = if (generator.bool()) 1.0 else -1.0
            val t = index / sampleRate
            value * level * exp(-t / decay)
        }
    }

    fun mix(a: DoubleArray, b: DoubleArray): DoubleArray =
        DoubleArray(max(a.size, b.size)) { index -> (if (index < a.size) a[index] else 0.0) + (if (index < b.size) b[index] else 0.0) }

    fun silence(seconds: Double) = DoubleArray((seconds * sampleRate).toInt())

    private fun notes(frequencies: List<Double>, seconds: Double, level: Double, duty: Double): DoubleArray =
        frequencies.map { square(it, it, seconds, level, duty) }.reduce(DoubleArray::plus)

    fun samples(sound: Sound): DoubleArray = when (sound) {
        Sound.Pop -> mix(
            square(220.0, 660.0, 0.07, 0.25, duty = 0.25),
            noise(0.05, hold = 2, level = 0.25, decay = 0.012, seed = 1),
        )
        Sound.Trick -> noise(0.12, hold = 1, level = 0.18, decay = 0.05, seed = 2)
        Sound.Land -> mix(noise(0.08, hold = 6, level = 0.4, decay = 0.02, seed = 3), triangle(110.0, 0.08, 0.4))
        Sound.Perfect -> mix(
            samples(Sound.Land),
            square(1320.0, 1320.0, 0.06, 0.16, duty = 0.25) + square(1760.0, 1760.0, 0.1, 0.16, duty = 0.25),
        )
        Sound.Grind -> {
            // Exactly one loop's worth: a gritty hum with a little wobble.
            val count = (0.4 * sampleRate).toInt()
            val generator = SeededGenerator(4)
            var value = 0.0
            DoubleArray(count) { index ->
                if (index % 3 == 0) value = generator.double(-1.0, 1.0)
                val hum = if ((index * 180 / sampleRate) % 1 < 0.5) 1.0 else -1.0
                value * 0.12 + hum * 0.05
            }
        }
        Sound.Lane -> square(880.0, 990.0, 0.03, 0.12, duty = 0.125)
        Sound.Bail -> mix(noise(0.35, hold = 12, level = 0.45, decay = 0.12, seed = 5), square(300.0, 60.0, 0.3, 0.2))
        Sound.Letter -> notes(listOf(988.0, 1319.0, 1976.0), 0.05, 0.16, 0.25)
        Sound.Finish -> notes(listOf(523.0, 659.0, 784.0, 1047.0), 0.1, 0.18, 0.25) + square(1047.0, 1047.0, 0.3, 0.18, duty = 0.5)
        Sound.Roll -> {
            // Half a second: a low rumble, and two clacks over the sidewalk joints.
            val count = (0.5 * sampleRate).toInt()
            val generator = SeededGenerator(10)
            var value = 0.0
            val out = DoubleArray(count) { index ->
                if (index % 14 == 0) value = generator.double(-1.0, 1.0)
                value * 0.09
            }
            val clack = mix(noise(0.03, hold = 2, level = 0.2, decay = 0.008, seed = 11), triangle(95.0, 0.03, 0.2))
            for (start in listOf(0, count / 2)) {
                for ((offset, sample) in clack.withIndex()) if (start + offset < count) out[start + offset] += sample
            }
            out
        }
        Sound.Scrape -> {
            val count = (0.4 * sampleRate).toInt()
            val generator = SeededGenerator(12)
            var value = 0.0
            DoubleArray(count) { index ->
                if (index % 2 == 0) value = generator.double(-1.0, 1.0)
                // A gritty rasp that wobbles as the trucks chatter (whole cycles, so it loops cleanly).
                val wobble = 0.7 + 0.3 * sin(2 * PI * 15 * index.toDouble() / count * 0.4)
                value * 0.15 * wobble
            }
        }
        Sound.Slide -> {
            val count = (0.4 * sampleRate).toInt()
            val generator = SeededGenerator(13)
            var value = 0.0
            DoubleArray(count) { index ->
                if (index % 4 == 0) value = generator.double(-1.0, 1.0)
                val buzz = if ((index * 95 / sampleRate) % 1 < 0.25) 1.0 else -1.0
                val wobble = 0.75 + 0.25 * sin(2 * PI * 10 * index.toDouble() / count * 0.4)
                (value * 0.13 + buzz * 0.04) * wobble
            }
        }
        Sound.Lock -> mix(
            mix(square(1180.0, 1180.0, 0.09, 0.12, duty = 0.25), square(1770.0, 1770.0, 0.07, 0.08, duty = 0.5)),
            noise(0.04, hold = 2, level = 0.2, decay = 0.01, seed = 14),
        )
        Sound.Flip -> {
            // A flick, then the board whirring: a rising tone that flutters.
            val whir = square(500.0, 1400.0, 0.12, 0.11, duty = 0.125)
            for (index in whir.indices) whir[index] *= if ((index / 220) % 2 == 0) 1.0 else 0.35
            mix(whir, noise(0.05, hold = 1, level = 0.16, decay = 0.015, seed = 15))
        }
        Sound.Spin -> {
            // A whoosh that swells and fades.
            val count = (0.2 * sampleRate).toInt()
            val generator = SeededGenerator(16)
            var value = 0.0
            DoubleArray(count) { index ->
                if (index % 2 == 0) value = generator.double(-1.0, 1.0)
                val progress = index.toDouble() / count
                value * 0.18 * sin(PI * progress)
            }
        }
        Sound.Grab -> mix(noise(0.08, hold = 3, level = 0.16, decay = 0.03, seed = 17), square(320.0, 260.0, 0.05, 0.08, duty = 0.25))
        Sound.Launch -> mix(square(180.0, 900.0, 0.22, 0.18, duty = 0.25), noise(0.15, hold = 2, level = 0.15, decay = 0.05, seed = 18))
        Sound.Clear -> square(880.0, 880.0, 0.04, 0.13, duty = 0.25) + square(1175.0, 1175.0, 0.06, 0.13, duty = 0.25)
        Sound.Bank -> square(1319.0, 1319.0, 0.05, 0.14, duty = 0.5) + square(1976.0, 1976.0, 0.16, 0.14, duty = 0.5)
        Sound.Gap -> notes(listOf(659.0, 784.0, 988.0, 1319.0), 0.05, 0.15, 0.25) + square(1568.0, 1568.0, 0.16, 0.15, duty = 0.25)
        Sound.Goal -> {
            val fanfare = notes(listOf(784.0, 988.0, 1175.0), 0.08, 0.15, 0.5) + square(1568.0, 1568.0, 0.28, 0.15, duty = 0.5)
            mix(fanfare, silence(0.24) + triangle(196.0, 0.28, 0.3))
        }
        Sound.Fall -> {
            val whistle = square(1200.0, 150.0, 0.45, 0.16, duty = 0.5)
            val thud = mix(triangle(60.0, 0.15, 0.45), noise(0.12, hold = 8, level = 0.3, decay = 0.04, seed = 19))
            whistle + thud
        }
        Sound.Burst -> mix(noise(0.45, hold = 2, level = 0.22, decay = 0.12, seed = 20), noise(0.06, hold = 6, level = 0.3, decay = 0.02, seed = 21))
    }
}
