//
//  ParityTests.kt
//
//  Checks the port's art and sound against the iOS game. Every picture must
//  come out pixel for pixel the same, and every sound and song sample for
//  sample (to within rounding). The iOS fingerprints are in
//  src/test/resources/parity, written by android/tools/parity/make_fixtures.sh
//  from the Swift code itself. The lists here follow tools/parity/main.swift.
//

package com.tuesdaygames.skate

import com.tuesdaygames.skate.art.*
import com.tuesdaygames.skate.rules.City
import com.tuesdaygames.skate.rules.ColorChoice
import com.tuesdaygames.skate.rules.Level
import com.tuesdaygames.skate.rules.Outfit
import com.tuesdaygames.skate.rules.SkaterKind
import com.tuesdaygames.skate.rules.Theme
import com.tuesdaygames.skate.rules.tutorial
import com.tuesdaygames.skate.sound.Chiptune
import com.tuesdaygames.skate.sound.Songs
import com.tuesdaygames.skate.sound.Sound
import com.tuesdaygames.skate.sound.SoundSynth
import java.security.MessageDigest
import java.util.Locale
import kotlin.math.abs
import kotlin.math.max
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import kotlin.test.fail

class ParityTests {
    /** The canvas's pixels as iOS keeps them: RGBA bytes, premultiplied, top row first. */
    private fun fingerprint(canvas: PixelCanvas): String {
        val bytes = ByteArray(canvas.pixels.size * 4)
        for ((index, argb) in canvas.pixels.withIndex()) {
            val a = argb ushr 24
            bytes[index * 4] = ((argb shr 16 and 0xFF) * a / 255).toByte()
            bytes[index * 4 + 1] = ((argb shr 8 and 0xFF) * a / 255).toByte()
            bytes[index * 4 + 2] = ((argb and 0xFF) * a / 255).toByte()
            bytes[index * 4 + 3] = a.toByte()
        }
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
        return "${canvas.width}\t${canvas.height}\t" + digest.joinToString("") { "%02x".format(it) }
    }

    private fun lines(file: String): Map<String, String> =
        javaClass.getResource("/parity/$file")!!.readText().lines().filter { it.isNotBlank() }
            .associate { it.substringBefore('\t') to it.substringAfter('\t') }

    private fun sprite(sprite: PixelSprite) = sprite.canvas()

    /** Every picture, named as in main.swift. */
    private fun pictures(): List<Pair<String, String>> {
        val out = mutableListOf<Pair<String, String>>()
        fun record(name: String, canvas: PixelCanvas) {
            out += name to fingerprint(canvas)
        }
        fun records(name: String, canvases: List<PixelCanvas>) = canvases.forEachIndexed { i, c -> record("$name.$i", c) }

        val outfits = listOf(
            Outfit.standard,
            Outfit(SkaterKind.Sammy, ColorChoice.White, ColorChoice.Navy, null, ColorChoice.Pink),
            Outfit.standard.switchingSkater(SkaterKind.Angie),
            Outfit(SkaterKind.Pat, ColorChoice.Yellow, ColorChoice.Black, ColorChoice.Red, ColorChoice.Pdx),
            Outfit(SkaterKind.Angie, ColorChoice.Teal, ColorChoice.Khaki, ColorChoice.Green, ColorChoice.Pdx),
        )
        for ((o, outfit) in outfits.withIndex()) {
            val poses = CharacterArt.poses(outfit)
            for ((name, s) in listOf(
                "roll" to poses.roll, "crouch" to poses.crouch, "air" to poses.air, "grab" to poses.grab,
                "bail" to poses.bail, "slide0" to poses.slide[0], "slide1" to poses.slide[1],
            )) record("outfit$o.$name", sprite(s))
            val board = CharacterArt.board(outfit)
            for ((name, s) in listOf(
                "side" to board.side, "wheelsUp" to board.wheelsUp, "underside" to board.underside,
                "grip" to board.grip, "endOn" to board.endOn,
            )) record("outfit$o.board.$name", sprite(s))
            for (step in 0 until CharacterArt.spinSteps) {
                record("outfit$o.spin$step", CharacterArt.spin(outfit, step, graphicUp = false))
                record("outfit$o.spinUp$step", CharacterArt.spin(outfit, step, graphicUp = true))
            }
            record("outfit$o.standing", CharacterArt.standing(outfit))
        }

        for ((index, theme) in Theme.entries.withIndex()) {
            val look = ThemeArt.look(theme)
            records("theme$index", look.layers.map { it.canvas } + look.ground)
            out += "theme$index.sky" to "${look.sky.r}\t${look.sky.g}\t${look.sky.b}"
        }

        for (level in City.portland.levels + Level.tutorial) {
            for ((index, feature) in level.features.withIndex()) {
                val look = FeatureArt.look(feature, seed = index)
                records("feature.${level.id}.$index", look.frames)
                out += "feature.${level.id}.$index.offset" to "${look.offsetX.toInt()}\t${look.offsetY.toInt()}"
            }
        }

        for ((index, letter) in "PORTLAND".withIndex()) {
            records("token$index", listOf(LetterArt.token(letter, found = false), LetterArt.token(letter, found = true)))
        }

        records(
            "text",
            listOf(
                PixelText.canvas("SCORE 1234", Palette.white),
                PixelText.canvas("New best!", Palette.yellow),
                PixelText.canvas(listOf("P" to Palette.yellow, "ORTLAND" to PixelColor(0xA8A8A8))),
            ),
        )
        records(
            "ui",
            listOf(
                UIArt.tipJar(), UIArt.musicIcon(true), UIArt.musicIcon(false), UIArt.soundIcon(true), UIArt.soundIcon(false),
                UIArt.padlock(), UIArt.box(46, 13, PixelColor(0x00A844)), UIArt.panel(100, 50),
                StreetArt.shadow(), StreetArt.shadow(20), FeatureArt.finishLine(46),
            ),
        )
        record("menu.fountain", FeatureArt.fountain(64))
        record("menu.tracks", FeatureArt.tracks(60))
        return out
    }

    @Test fun everyPictureMatchesIOSPixelForPixel() {
        val expected = lines("art.txt")
        val ours = pictures()
        assertEquals(expected.keys.toList(), ours.map { it.first }, "the same pictures, in the same order")
        val wrong = ours.filter { (name, value) -> expected[name] != value }.map { it.first }
        if (wrong.isNotEmpty()) fail("${wrong.size} pictures differ from iOS: ${wrong.take(40)}")
    }

    private fun summary(samples: List<Double>, probes: Int): String {
        var sum = 0.0
        var squares = 0.0
        for (sample in samples) {
            sum += sample
            squares += sample * sample
        }
        val stride = max(1, samples.size / probes)
        val picked = (samples.indices step stride).map { String.format(Locale.ROOT, "%.9f", samples[it]) }
        return "${samples.size}\t${"%.9f".format(Locale.ROOT, sum)}\t${"%.9f".format(Locale.ROOT, squares)}\t" + picked.joinToString(" ")
    }

    /** Same length and fingerprints, with numbers allowed to differ in the last few places. */
    private fun assertClose(name: String, expected: String, actual: String, tolerance: Double) {
        val e = expected.split('\t', ' ')
        val a = actual.split('\t', ' ')
        assertEquals(e.size, a.size, "$name: number of fingerprints")
        assertEquals(e[0], a[0], "$name: number of samples")
        for (i in 1 until e.size) {
            val x = e[i].toDouble()
            val y = a[i].toDouble()
            // The sums are over many samples, so allow for more drift there.
            val allowed = if (i <= 2) tolerance * max(1.0, abs(x)) * 10 else tolerance
            assertTrue(abs(x - y) <= allowed, "$name: fingerprint $i is $y, iOS has $x")
        }
    }

    @Test fun everySoundMatchesIOS() {
        val expected = lines("sounds.txt")
        for (sound in Sound.entries) {
            val name = "sound." + sound.name.replaceFirstChar { it.lowercase() }
            val line = expected[name] ?: fail("no iOS fingerprint for $name")
            assertClose(name, line, summary(SoundSynth.samples(sound).toList(), 16), 1e-9)
        }
    }

    @Test fun everySongMatchesIOS() {
        val expected = lines("sounds.txt")
        for (song in Songs.all) {
            for ((part, samples) in listOf("intro" to Chiptune.renderIntro(song), "loop" to Chiptune.renderLoop(song))) {
                val name = "song.${song.name}.$part"
                val line = expected[name] ?: fail("no iOS fingerprint for $name")
                assertClose(name, line, summary(samples.map { it.toDouble() }, 32), 1e-4)
            }
        }
    }
}
