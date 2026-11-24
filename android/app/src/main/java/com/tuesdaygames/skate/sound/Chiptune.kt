//
//  Chiptune.kt
//
//  The music: a little NES-style sound chip and a sequencer, so every song is
//  written as text in code and rendered when it's needed. No audio files.
//  Ported from skate/UI/Chiptune.swift.
//
//  Four voices, like the NES:
//  - lead: a narrow pulse wave, with vibrato on long notes
//  - rhythm: power chords on pulse waves, clipped hard for a punk crunch,
//    palm-muted (short) or left ringing
//  - bass: the stepped NES triangle
//  - drums: noise and a falling triangle for the kick
//
//  Songs are written a bar at a time. Pitched parts use one token per eighth note
//  (`E4`, `C#5`; a `*` makes it a power chord: root, fifth and octave), `-` holds
//  the note before, `.` is silence. Drum parts use one token per sixteenth:
//  `k` kick, `s` snare, `h` hi-hat, `o` open hat, `c` crash (with a kick), `.` rest.
//  No Android in here, so it renders the same anywhere.
//

package com.tuesdaygames.skate.sound

import com.tuesdaygames.skate.rules.rounded
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.tanh

object Chiptune {
    const val sampleRate = 32_000.0

    data class Section(
        val lead: List<String> = emptyList(),
        val rhythm: List<String> = emptyList(),
        val bass: List<String> = emptyList(),
        val drums: List<String> = emptyList(),
        /** Short, choked power chords (verses) instead of ringing ones (choruses). */
        val palmMuted: Boolean = false,
        /** How many times the section plays in a row. */
        val repeats: Int = 1,
    )

    data class Song(val name: String, val bpm: Double, val sections: List<Section>)

    // Reading the notes

    private class Note(val step: Int, var length: Int, val frequencies: DoubleArray)

    private val names = mapOf("C" to 0, "D" to 2, "E" to 4, "F" to 5, "G" to 7, "A" to 9, "B" to 11)

    fun frequency(name: String): Double? {
        var text = name
        val base = text.firstOrNull()?.let { names[it.toString()] } ?: return null
        text = text.drop(1)
        var semitone = base
        if (text.firstOrNull() == '#') {
            semitone += 1
            text = text.drop(1)
        }
        if (text.firstOrNull() == 'b') {
            semitone -= 1
            text = text.drop(1)
        }
        // Swift's Int("") is nil, and so is Int("+4"), which Kotlin would read.
        if (text.isEmpty() || !text.all { it.isDigit() || it == '-' }) return null
        val octave = text.toIntOrNull() ?: return null
        val midi = 12 * (octave + 1) + semitone
        return 440 * 2.0.pow((midi - 69).toDouble() / 12)
    }

    private fun tokens(bars: List<String>): List<String> =
        bars.joinToString(" ").split(" ").filter { it.isNotEmpty() }

    /** Pitched tokens (one per eighth note) into notes, in sixteenths. */
    private fun notes(bars: List<String>, start: Int): List<Note> {
        val notes = mutableListOf<Note>()
        var step = start
        for (token in tokens(bars)) {
            when (token) {
                "-" -> if (notes.isNotEmpty()) notes.last().length += 2
                "." -> {}
                else -> {
                    val chord = token.endsWith("*")
                    val root = frequency(if (chord) token.dropLast(1) else token)
                    if (root != null) {
                        notes += Note(step, 2, if (chord) doubleArrayOf(root, root * 1.4983, root * 2) else doubleArrayOf(root))
                    }
                }
            }
            step += 2
        }
        return notes
    }

    // Rendering

    /** The song's intro (its first section), played once. */
    fun renderIntro(song: Song): FloatArray = render(song.copy(sections = song.sections.take(1)))

    /** The rest of the song, which loops. */
    fun renderLoop(song: Song): FloatArray = render(song.copy(sections = song.sections.drop(1)))

    /** Anything wrong with how a song is written: a bar with the wrong number of
     *  tokens, a note that doesn't read, or parts of different lengths. */
    fun problems(song: Song): List<String> {
        val problems = mutableListOf<String>()
        for ((number, section) in song.sections.withIndex()) {
            val parts = listOf(
                Triple("lead", section.lead, 8), Triple("rhythm", section.rhythm, 8),
                Triple("bass", section.bass, 8), Triple("drums", section.drums, 16),
            )
            val lengths = parts.map { it.second.size }.filter { it > 0 }.toSet()
            if (lengths.size > 1) problems += "${song.name} section $number: parts have ${lengths.sorted()} bars"
            for ((part, bars, perBar) in parts) {
                for ((bar, text) in bars.withIndex()) {
                    val tokens = text.split(" ").filter { it.isNotEmpty() }
                    if (tokens.size != perBar) {
                        problems += "${song.name} section $number $part bar ${bar + 1}: ${tokens.size} tokens, not $perBar"
                    }
                    for (token in tokens) {
                        if (token == "-" || token == ".") continue
                        if (part == "drums") {
                            if (!token.all { it in "kshoc" }) problems += "${song.name}: unknown drum $token"
                        } else if (frequency(if (token.endsWith("*")) token.dropLast(1) else token) == null) {
                            problems += "${song.name}: unknown note $token"
                        }
                    }
                }
            }
        }
        return problems
    }

    /** The whole song once through, as samples from -1 to 1. */
    fun render(song: Song): FloatArray {
        val stepSeconds = 60 / song.bpm / 4
        val stepSamples = stepSeconds * sampleRate
        val lead = mutableListOf<Note>()
        val bass = mutableListOf<Note>()
        val rhythm = mutableListOf<Pair<Note, Boolean>>()
        val drums = mutableListOf<Pair<Int, Char>>()
        var step = 0
        for (section in song.sections) {
            repeat(section.repeats) {
                val bars = maxOf(section.lead.size, section.rhythm.size, section.bass.size, section.drums.size)
                lead += notes(section.lead, step)
                bass += notes(section.bass, step)
                rhythm += notes(section.rhythm, step).map { it to section.palmMuted }
                var drumStep = step
                for (token in tokens(section.drums)) {
                    for (hit in token) if (hit != '.') drums += drumStep to hit
                    drumStep += 1
                }
                step += bars * 16
            }
        }
        val total = (step * stepSamples).toInt()
        val mix = FloatArray(total)
        val crunch = FloatArray(total)

        fun samples(note: Note): IntRange {
            val start = (note.step * stepSamples).toInt()
            val end = min(total, ((note.step + note.length) * stepSamples).toInt())
            return start until max(start, end)
        }

        // Lead: 25% pulse, a little punch at the start, vibrato once a note is held.
        for (note in lead) {
            val range = samples(note)
            val upper = range.last + 1
            var phase = 0.0
            for (index in range) {
                val t = (index - range.first) / sampleRate
                val left = (upper - index) / sampleRate
                val vibrato = if (t > 0.16) 1 + 0.006 * sin(2 * PI * 6 * t) else 1.0
                phase += note.frequencies[0] * vibrato / sampleRate
                val wave = if (phase % 1 < 0.25) 1.0 else -1.0
                val level = (if (t < 0.03) 1.0 else 0.75 + 0.25 * exp(-(t - 0.03) / 0.1)) * min(1.0, left / 0.01)
                mix[index] += (wave * level * 0.15).toFloat()
            }
        }

        // Rhythm: power chords on 50% pulses, summed then clipped for the crunch.
        for ((note, muted) in rhythm) {
            val range = samples(note)
            val upper = range.last + 1
            val phases = DoubleArray(note.frequencies.size)
            for (index in range) {
                val t = (index - range.first) / sampleRate
                val left = (upper - index) / sampleRate
                var sum = 0.0
                for ((voice, frequency) in note.frequencies.withIndex()) {
                    // A hair out of tune with each other, like two guitars.
                    phases[voice] += frequency * (1 + voice * 0.0015) / sampleRate
                    sum += if (phases[voice] % 1 < 0.5) 1.0 else -1.0
                }
                val level = (if (muted) exp(-t / 0.07) else 0.55 + 0.45 * exp(-t / 0.25)) * min(1.0, left / 0.008)
                crunch[index] += (sum * level).toFloat()
            }
        }
        for (index in 0 until total) mix[index] += tanh(crunch[index] * 0.9f) * 0.16f

        // Bass: the NES triangle, 16 steps a cycle.
        for (note in bass) {
            val range = samples(note)
            val upper = range.last + 1
            var phase = 0.0
            for (index in range) {
                val left = (upper - index) / sampleRate
                phase += note.frequencies[0] / sampleRate
                val p = phase % 1
                val smooth = if (p < 0.5) 4 * p - 1 else 3 - 4 * p
                val stepped = (smooth * 7.5).rounded() / 7.5
                mix[index] += (stepped * 0.3 * min(1.0, left / 0.006)).toFloat()
            }
        }

        // Drums: a 15-bit noise register like the NES's, and a falling triangle kick.
        var lfsr = 1
        fun noise(short: Boolean): Double {
            val tap = if (short) 6 else 1
            val bit = (lfsr xor (lfsr shr tap)) and 1
            lfsr = ((lfsr shr 1) or (bit shl 14)) and 0xFFFF
            return if (lfsr and 1 == 0) 1.0 else -1.0
        }
        fun kick(start: Int) {
            var phase = 0.0
            for (index in start until min(total, start + (0.16 * sampleRate).toInt())) {
                val t = (index - start) / sampleRate
                phase += (45 + 110 * exp(-t / 0.025)) / sampleRate
                val p = phase % 1
                mix[index] += ((if (p < 0.5) 4 * p - 1 else 3 - 4 * p) * 0.5 * exp(-t / 0.07)).toFloat()
            }
        }
        fun crash(start: Int) {
            var held = 0.0
            for (index in start until min(total, start + (0.9 * sampleRate).toInt())) {
                val t = (index - start) / sampleRate
                if (index % 2 == 0) held = noise(short = false)
                mix[index] += (held * 0.13 * exp(-t / 0.3)).toFloat()
            }
        }
        fun snare(start: Int) {
            var held = 0.0
            var phase = 0.0
            for (index in start until min(total, start + (0.2 * sampleRate).toInt())) {
                val t = (index - start) / sampleRate
                if (index % 3 == 0) held = noise(short = false)
                phase += 185 / sampleRate
                val p = phase % 1
                val body = (if (p < 0.5) 4 * p - 1 else 3 - 4 * p) * exp(-t / 0.03)
                mix[index] += (held * 0.3 * exp(-t / 0.07) + body * 0.15).toFloat()
            }
        }
        fun hat(start: Int, open: Boolean) {
            val length = if (open) 0.14 else 0.035
            for (index in start until min(total, start + (length * sampleRate).toInt())) {
                val t = (index - start) / sampleRate
                mix[index] += (noise(short = true) * 0.07 * exp(-t / (length / 3))).toFloat()
            }
        }
        for ((hitStep, hit) in drums) {
            val start = (hitStep * stepSamples).toInt()
            when (hit) {
                'k' -> kick(start)
                'c' -> {
                    kick(start)
                    crash(start)
                }
                's' -> snare(start)
                'h' -> hat(start, open = false)
                'o' -> hat(start, open = true)
            }
        }

        // Keep it under full scale without squashing it.
        return FloatArray(total) { tanh(mix[it] * 1.1f) * 0.92f }
    }
}
