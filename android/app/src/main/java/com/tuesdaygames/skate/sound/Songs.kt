//
//  Songs.kt
//
//  The soundtrack, one song per spot, written for `Chiptune`. Portland's songs
//  are 90s skate punk played on an NES: fast, palm-muted verses, big open
//  choruses, a snotty lead. All original. Ported from skate/UI/Songs.swift:
//  keep the two the same.
//
//  Pitched parts: one token per eighth note, 8 a bar. Drums: one per sixteenth, 16 a bar.
//  The first section of each song is its intro, played once; the rest loops.
//

package com.tuesdaygames.skate.sound

import com.tuesdaygames.skate.sound.Chiptune.Section
import com.tuesdaygames.skate.sound.Chiptune.Song

object Songs {
    /** Eight eighth notes of the same power chord. */
    private fun chug(chord: String): String = List(8) { chord }.joinToString(" ")

    private fun repeated(text: String, count: Int) = List(count) { text }

    // Downtown: bright, bouncy skate punk in E

    val downtown: Song by lazy {
        val beat = "k h s h k h s h k h s h k k s h"
        val fill = "k h s h k h s h s s s s s s s s"
        val intro = Section(
            rhythm = listOf(". . . . . . . .", "E3* - - - - - - -"),
            bass = listOf(". . . . . . . .", "E3 - - - - - - -"),
            drums = listOf("s . s . s . s . s s s s s s s s", "c . . . . . . . s . s . s s s s"),
        )
        val verse = Section(
            lead = listOf(
                "B4 - G#4 - E4 - G#4 B4",
                "D#5 - C#5 B4 - - A4 B4",
                "C#5 - B4 - G#4 - E4 -",
                "F#4 - E4 - C#4 - . .",
                "B4 - G#4 - E4 - G#4 B4",
                "D#5 - E5 - F#5 - D#5 -",
                "E5 - D#5 - C#5 - B4 -",
                "C#5 - - - B4 - . .",
            ),
            rhythm = listOf("E3*", "B2*", "C#3*", "A2*", "E3*", "B2*", "C#3*", "A2*").map(::chug),
            bass = listOf("E3", "B2", "C#3", "A2", "E3", "B2", "C#3").map(::chug) + "A2 A2 A2 A2 B2 B2 B2 B2",
            drums = repeated(beat, 7) + fill,
            palmMuted = true,
        )
        val open = "A2* - A2* - A2* A2* A2* -"
        val chorus = Section(
            lead = listOf(
                "E5 E5 - C#5 E5 - F#5 -",
                "F#5 F#5 - D#5 F#5 - G#5 -",
                "G#5 - F#5 - E5 - C#5 -",
                "D#5 - - - F#5 - - -",
                "E5 E5 - C#5 E5 - F#5 -",
                "F#5 F#5 - D#5 F#5 - B5 -",
                "G#5 - - - E5 - - -",
                "- - - - . . . .",
            ),
            rhythm = listOf(
                open, open.replace("A2", "B2"), open.replace("A2", "C#3"),
                open.replace("A2", "B2"), open, open.replace("A2", "B2"),
                "E3* - E3* - E3* E3* E3* -", "E3* - - - B2* - - -",
            ),
            bass = listOf("A2", "B2", "C#3", "B2", "A2", "B2", "E3").map(::chug) + "E3 E3 E3 E3 B2 B2 B2 B2",
            drums = listOf("c h s h k h s h k h s h k h s h") + repeated("k h s h k h s h k k s h k h s o", 6) +
                "k h s h k h s h s . s . s s s s",
        )
        Song("Downtown", 184.0, listOf(intro, verse, chorus))
    }

    // Burnside: faster, darker, under the bridge, in E minor

    val burnside: Song by lazy {
        val stomp = "k h h h s h h h k h k h s h h h"
        val polka = "k h s h k h s h k h s h k h s h"
        val intro = Section(
            rhythm = listOf("E3* E3* . E3* E3* . E3* E3*", "E3* E3* . E3* G3* - A3* -"),
            bass = listOf(". . . . . . . .", "E3 E3 . E3 G3 - A3 -"),
            drums = listOf(". . . . . . . . . . . . s s s s", "c . . . k . . . k . k . s s s s"),
            palmMuted = true,
        )
        val riff1 = "E3* E3* . E3* G3* - A3* -"
        val riff2 = "E3* E3* . E3* A#3* - A3* -"
        val riff3 = "C3* C3* . C3* C3* - D3* -"
        val riff4 = "D3* D3* . D3* D3* . D3* D3*"
        val bassOf = { riff: String -> riff.replace("*", "") }
        val verse = Section(
            lead = listOf(
                ". . . . . . . .", ". . . . . . B4 -",
                ". . . . . . . .", "D5 E5 F#5 G5 F#5 E5 D5 B4",
                ". . . . . . . .", ". . . . . . B4 -",
                ". . . . . . . .", "G5 F#5 E5 D5 E5 - B4 -",
            ),
            rhythm = listOf(riff1, riff2, riff3, riff4, riff1, riff2, riff3, riff4),
            bass = listOf(riff1, riff2, riff3, riff4, riff1, riff2, riff3, riff4).map(bassOf),
            drums = repeated(stomp, 7) + "k h s h k h s h s s s s k . k .",
            palmMuted = true,
        )
        val strum = { chord: String -> "$chord - $chord - $chord - $chord -" }
        val chorus = Section(
            lead = listOf(
                "B4 - D5 - G5 - - -",
                "F#5 - E5 - D5 - A4 -",
                "B4 - E5 - G5 - E5 -",
                "G5 - - - E5 - - -",
                "B4 - D5 - G5 - - -",
                "A5 - G5 - F#5 - D5 -",
                "E5 - - - B4 - E5 -",
                "E5 - - - - - . .",
            ),
            rhythm = listOf("G3*", "D3*", "E3*", "C3*", "G3*", "D3*", "E3*", "C3*").map(strum),
            bass = listOf("G2", "D3", "E3", "C3", "G2", "D3", "E3", "C3").map(::chug),
            drums = listOf("c h s h k h s h k h s h k h s h") + repeated(polka, 6) + "s s s s s s s s c . . . s s s s",
        )
        Song("Burnside", 200.0, listOf(intro, verse, chorus))
    }

    // Skidmore Fountain: ska-punk, upstrokes in the verse, punk in the chorus

    val skidmore: Song by lazy {
        val ska = "k . h . s . h . k . h . s . h ."
        val skank = { chord: String -> ". $chord . $chord . $chord . $chord" }
        val walk = { a: String, b: String, c: String -> "$a - $b - $c - $b -" }
        val intro = Section(
            rhythm = listOf(skank("A3*"), ". E4* . E4* . E4* E4* E4*"),
            bass = listOf(walk("A2", "C#3", "E3"), "E3 - E3 - B2 - B2 -"),
            drums = listOf(ska, "k . h . s . h . s s s s s . s ."),
            palmMuted = true,
        )
        val verse = Section(
            lead = listOf(
                "E5 - C#5 - E5 - F#5 E5",
                "D5 - - - F#5 - - -",
                "E5 - B4 - G#4 - B4 -",
                "A4 - - - . . . .",
                "E5 - C#5 - E5 - F#5 E5",
                "F#5 - A5 - F#5 - D5 -",
                "E5 - D5 - C#5 - B4 -",
                "A4 - - - - - . .",
            ),
            rhythm = listOf("A3*", "D4*", "E4*", "D4*", "A3*", "D4*", "E4*", "E4*").map(skank),
            bass = listOf(
                walk("A2", "C#3", "E3"), walk("D3", "F#3", "A3"), walk("E3", "G#3", "B3"), walk("D3", "F#3", "A3"),
                walk("A2", "C#3", "E3"), walk("D3", "F#3", "A3"), walk("E3", "G#3", "B3"), "E3 - E3 - E3 E3 E3 E3",
            ),
            drums = repeated(ska, 7) + "k . h . s . h . s s s s s s s s",
            palmMuted = true,
        )
        val strum = { chord: String -> "$chord - $chord $chord - $chord $chord -" }
        val chorus = Section(
            lead = listOf(
                "A5 - - - E5 - C#5 -",
                "B4 - C#5 - E5 - - -",
                "F#5 - E5 - C#5 - A4 -",
                "A4 - B4 - C#5 - D5 -",
                "A5 - - - E5 - C#5 -",
                "B4 - C#5 - E5 - G#5 -",
                "A5 - G#5 - F#5 - E5 -",
                "D5 - - - C#5 - - -",
            ),
            rhythm = listOf("A2*", "E3*", "F#3*", "D3*", "A2*", "E3*", "F#3*", "D3*").map(strum),
            bass = listOf("A2", "E3", "F#3", "D3", "A2", "E3", "F#3", "D3").map(::chug),
            drums = listOf("c h s h k h s h k h s h k h s h") + repeated("k h s h k h s h k h s h k h s h", 6) +
                "k h s h k h s h s s s s s s s s",
        )
        Song("Skidmore", 152.0, listOf(intro, verse, chorus))
    }

    // North Portland: a pop-punk anthem in D

    val northPortland: Song by lazy {
        val beat = "k h s h k h s h k h s h k k s h"
        val intro = Section(
            rhythm = listOf("D3* - - D3* - - D3* -", "A2* - - A2* - - A2* A2*"),
            bass = listOf("D3 - - D3 - - D3 -", "A2 - - A2 - - A2 A2"),
            drums = listOf("c . . . . . s . . . s . . . . .", "k . . . . . s . . . s . s s s s"),
        )
        val verse = Section(
            lead = listOf(
                "F#4 - F#4 - A4 - F#4 -",
                "E4 - E4 - A4 - E4 -",
                "D4 - F#4 - B4 - A4 -",
                "G4 - - - . . . .",
                "F#4 - F#4 - A4 - F#4 -",
                "E4 - A4 - C#5 - A4 -",
                "B4 - A4 - F#4 - D4 -",
                "E4 - - - F#4 G4 A4 -",
            ),
            rhythm = listOf("D3*", "A2*", "B2*", "G2*", "D3*", "A2*", "B2*", "G2*").map(::chug),
            bass = listOf("D3", "A2", "B2", "G2", "D3", "A2", "B2", "G2").map(::chug),
            drums = repeated(beat, 7) + "k h s h k h s h s s s s s s s s",
            palmMuted = true,
        )
        val anthem = { chord: String -> "$chord - - $chord - - $chord -" }
        val chorus = Section(
            lead = listOf(
                "B4 - D5 - D5 - B4 -",
                "A4 - D5 - F#5 - - -",
                "E5 - - - C#5 - A4 -",
                "B4 - D5 - F#5 - E5 -",
                "D5 - B4 - D5 - G5 -",
                "F#5 - - - D5 - A4 -",
                "E5 - - - - - C#5 -",
                "D5 - - - - - . .",
            ),
            rhythm = listOf("G2*", "D3*", "A2*", "B2*", "G2*", "D3*", "A2*", "A2*").map(anthem),
            bass = listOf("G2", "D3", "A2", "B2", "G2", "D3", "A2", "A2").map(anthem),
            drums = listOf("c h s h k k s h k h s h k k s o") + repeated("k h s h k k s h k h s h k k s o", 6) +
                "k h s h k h s h s . s . s s s s",
        )
        Song("North Portland", 168.0, listOf(intro, verse, chorus))
    }

    // SE Waterfront: slow and melodic, arpeggios by the river

    val waterfront: Song by lazy {
        val easy = "k . h . s . h . k . h . s . h ."
        val arp = { a: String, b: String, c: String -> "$a $b $c $b $a $b $c $b" }
        val pulse = { chord: String -> "$chord . $chord . $chord . $chord ." }
        val intro = Section(
            lead = listOf(arp("G4", "B4", "D5"), arp("D4", "F#4", "A4")),
            bass = listOf("G2 - - - - - - -", "D3 - - - - - - -"),
            drums = listOf("k . . . . . . . k . . . . . . .", "k . . . s . . . k . . . s . s s"),
        )
        val verse = Section(
            lead = listOf(
                arp("G4", "B4", "D5"), arp("E4", "G4", "B4"), arp("C4", "E4", "G4"), arp("D4", "F#4", "A4"),
                arp("G4", "B4", "D5"), arp("E4", "G4", "B4"), arp("C4", "E4", "G4"), "D4 F#4 A4 D5 C5 B4 A4 F#4",
            ),
            rhythm = listOf("G3*", "E3*", "C3*", "D3*", "G3*", "E3*", "C3*", "D3*").map(pulse),
            bass = listOf(
                "G2 - G2 - G2 - D3 -", "E3 - E3 - E3 - B2 -", "C3 - C3 - C3 - G2 -", "D3 - D3 - D3 - A2 -",
                "G2 - G2 - G2 - D3 -", "E3 - E3 - E3 - B2 -", "C3 - C3 - C3 - G2 -", "D3 - D3 - D3 D3 D3 D3",
            ),
            drums = repeated(easy, 7) + "k . h . s . h . s . s . s s s s",
            palmMuted = true,
        )
        val ring = { chord: String -> "$chord - $chord - $chord - $chord -" }
        val chorus = Section(
            lead = listOf(
                "E5 - - - G5 - - -",
                "D5 - - - B4 - - -",
                "A4 - B4 - D5 - - -",
                "B4 - - - . . . .",
                "E5 - - - G5 - A5 -",
                "B5 - - - A5 - G5 -",
                "F#5 - - - A5 - - -",
                "F#5 - - - E5 - D5 -",
            ),
            rhythm = listOf("C3*", "G2*", "D3*", "E3*", "C3*", "G2*", "D3*", "D3*").map(ring),
            bass = listOf("C3", "G2", "D3", "E3", "C3", "G2", "D3", "D3").map(::chug),
            drums = listOf("c h s h k h s h k h s h k h s h") + repeated("k h s h k h s h k h s h k h s h", 6) +
                "k h s h k h s h s . s . s s s s",
        )
        Song("SE Waterfront", 124.0, listOf(intro, verse, chorus))
    }

    // Zoo Bomb: the fastest, hardcore punk all the way down the hill

    val zooBomb: Song by lazy {
        val dbeat = "k . s k k . s . k . s k k . s ."
        val intro = Section(
            lead = listOf("B5 - - - A#5 - - -", "B5 - - - . . . ."),
            rhythm = listOf(". . . . . . . .", "B2* . B2* . B2* B2* B2* B2*"),
            bass = listOf(". . . . . . . .", "B2 . B2 . B2 B2 B2 B2"),
            drums = listOf("s . . . s . . . s . s . s s s s", "c . . . c . . . s s s s s s s s"),
        )
        val riff1 = "B2* B2* B2* B2* D3* D3* C#3* C#3*"
        val riff2 = "B2* B2* B2* B2* E3* E3* F3* F#3*"
        val bassOf = { riff: String -> riff.replace("*", "") }
        val verse = Section(
            lead = listOf(
                ". . . . . . . .", ". . . . . . . .", ". . . . . . . .", ". . . . . . . .",
                ". . F#5 - . . F#5 -", ". . G5 - . . A5 -", ". . F#5 - . . F#5 -", "B5 - A5 - G5 - F#5 -",
            ),
            rhythm = listOf(riff1, riff2, riff1, riff2, riff1, riff2, riff1, riff2),
            bass = listOf(riff1, riff2, riff1, riff2, riff1, riff2, riff1, riff2).map(bassOf),
            drums = repeated(dbeat, 7) + "s s s s s s s s s s s s s s s s",
            palmMuted = true,
        )
        val chorus = Section(
            lead = listOf(
                "B5 - - - A5 - - -",
                "C#6 - - - B5 - A5 -",
                "B5 - - - - - - -",
                "F#5 - - - D5 - - -",
                "B5 - - - A5 - - -",
                "C#6 - - - E6 - - -",
                "D6 - C#6 - B5 - A5 -",
                "B5 - - - - - . .",
            ),
            rhythm = listOf("G3*", "A3*", "B2*", "B2*", "G3*", "A3*", "B2*", "B2*").map(::chug),
            bass = listOf("G2", "A2", "B2", "B2", "G2", "A2", "B2", "B2").map(::chug),
            drums = listOf("c h s h k h s h k h s h k h s h") + repeated("k h s h k h s h k h s h k h s h", 6) +
                "c . c . s s s s s s s s s s s s",
        )
        Song("Zoo Bomb", 232.0, listOf(intro, verse, chorus))
    }

    /** Every song, for the tests and the preview renderer. */
    val all: List<Song> get() = listOf(downtown, skidmore, burnside, northPortland, waterfront, zooBomb)
}
