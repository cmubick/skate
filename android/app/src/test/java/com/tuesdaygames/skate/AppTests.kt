//
//  AppTests.kt
//
//  The tests from skateTests/skateTests.swift that are about drawing, sound,
//  music and the store, which live in the app here. (The rules' tests are in
//  rules/src/test.)
//

package com.tuesdaygames.skate

import com.tuesdaygames.skate.art.CharacterArt
import com.tuesdaygames.skate.art.PeopleArt
import com.tuesdaygames.skate.art.SignFont
import com.tuesdaygames.skate.art.ThemeArt
import com.tuesdaygames.skate.rules.City
import com.tuesdaygames.skate.rules.ColorChoice
import com.tuesdaygames.skate.rules.Level
import com.tuesdaygames.skate.rules.Outfit
import com.tuesdaygames.skate.rules.SkaterKind
import com.tuesdaygames.skate.rules.tutorial
import com.tuesdaygames.skate.sound.Chiptune
import com.tuesdaygames.skate.sound.Music
import com.tuesdaygames.skate.sound.Songs
import com.tuesdaygames.skate.store.Store
import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class CharacterArtTests {
    @Test fun artIsRectangular() {
        for (template in CharacterArt.allTemplates + PeopleArt.allTemplates) {
            assertEquals(setOf(18), template.map { it.length }.toSet())
        }
        for (kind in SkaterKind.entries) {
            for (hat in listOf(ColorChoice.Yellow, null)) {
                val poses = CharacterArt.poses(Outfit(kind = kind, hat = hat))
                for (sprite in listOf(poses.roll, poses.crouch, poses.air, poses.grab, poses.bail)) {
                    assertEquals(18, sprite.width)
                }
            }
        }
        val board = CharacterArt.board(Outfit.standard)
        for (sprite in listOf(board.side, board.wheelsUp, board.underside, board.grip)) {
            assertTrue(sprite.rows.all { it.length == 20 })
        }
    }
}

class FoodCartTests {
    @Test fun everyFoodCartSignFitsAndHasItsLetters() {
        for (sign in ThemeArt.foodCartSigns) {
            assertTrue(SignFont.width(sign) <= 24, sign)
            assertTrue(sign.all { SignFont.allGlyphs[it] != null }, sign)
        }
    }
}

class StoreTests {
    @Test fun onlyTipsAreForSaleUntilTheOtherCitiesAreReady() {
        assertFalse(Store.fullGameOnSale)
        assertEquals(Store.tipIDs, Store.productIDs)
        assertEquals(listOf("skate.tip.small", "skate.tip.medium", "skate.tip.large"), Store.tipIDs)
        assertEquals(8, City.all.count { !it.isOpen })
    }
}

class MusicTests {
    @Test fun everySongIsWrittenRight() {
        for (song in Songs.all) {
            assertTrue(Chiptune.problems(song).isEmpty(), Chiptune.problems(song).toString())
            assertTrue(song.sections.size >= 2, "${song.name} needs an intro and a loop")
        }
    }

    @Test fun everyPortlandSpotHasItsOwnSong() {
        val songs = City.portland.levels.mapNotNull { Music.song(it)?.name }
        assertEquals(City.portland.levels.size, songs.size)
        assertEquals(songs.size, songs.toSet().size)
        assertNotNull(Music.song(Level.tutorial))
    }

    @Test fun notesHaveTheRightPitch() {
        assertTrue(abs(Chiptune.frequency("A4")!! - 440) < 0.01)
        assertTrue(abs(Chiptune.frequency("C#5")!! - 554.37) < 0.01)
        assertNull(Chiptune.frequency("H2"))
    }
}
