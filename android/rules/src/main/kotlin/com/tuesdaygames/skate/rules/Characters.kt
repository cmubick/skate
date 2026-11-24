//
//  Characters.kt
//
//  Who skates and what they wear. The skater builder edits an `Outfit`; the
//  art in CharacterArt.kt draws it. Ported from skate/Rules/Characters.swift.
//

package com.tuesdaygames.skate.rules

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class SkaterKind {
    // The saved names are the skaters' old names, so outfits saved before the rename still load.
    @SerialName("terry") Pat,
    @SerialName("sam") Sammy,
    @SerialName("angie") Angie;

    /** Swift: `name`. */
    val displayName: String
        get() = when (this) {
            Pat -> "PAT"
            Sammy -> "SAMMY"
            Angie -> "ANGIE"
        }

    /** Angie is a dog: she wears a bandana instead of a shirt, and no pants. */
    val isDog: Boolean get() = this == Angie
    val wearsPants: Boolean get() = !isDog
}

/** The colors you can pick for clothes, hats and boards. */
@Serializable
enum class ColorChoice(val hex: Int) {
    @SerialName("black") Black(0x1C1C1C),
    @SerialName("white") White(0xF0F0F0),
    @SerialName("grey") Grey(0x8C8C8C),
    @SerialName("red") Red(0xD82800),
    @SerialName("orange") Orange(0xF87800),
    @SerialName("yellow") Yellow(0xF8B800),
    @SerialName("green") Green(0x00A844),
    @SerialName("teal") Teal(0x00A8A8),
    @SerialName("blue") Blue(0x0058F8),
    @SerialName("navy") Navy(0x24308C),
    @SerialName("purple") Purple(0x8C38C8),
    @SerialName("pink") Pink(0xF878B8),
    @SerialName("khaki") Khaki(0xC8A870),
    @SerialName("brown") Brown(0x7C3C00),

    /** The PDX airport carpet: teal with little bits of color. Boards only, and only once
     *  you've spelled PORTLAND. */
    @SerialName("pdx") Pdx(0x1C7470);

    /** Swift: `name`. */
    val displayName: String get() = if (this == Pdx) "PDX CARPET" else name.uppercase()

    /** Light colors get dark trim and prints, dark ones light. */
    val isLight: Boolean
        get() {
            val r = (hex shr 16) and 0xFF
            val g = (hex shr 8) and 0xFF
            val b = hex and 0xFF
            return (r * 30 + g * 59 + b * 11) / 100 > 140
        }

    companion object {
        /** The colors for shirts, pants and hats. */
        val clothes: List<ColorChoice> get() = entries.filter { it != Pdx }

        /** The boards you can pick: the reward board joins the list once it's won. */
        fun boards(pdxUnlocked: Boolean): List<ColorChoice> = if (pdxUnlocked) clothes + Pdx else clothes
    }
}

/**
 * Swift's Outfit is a struct; this is a data class, so `copy()` makes the changed one.
 * Saved as JSON in the same shape as on iOS.
 */
@Serializable
data class Outfit(
    val kind: SkaterKind = SkaterKind.Pat,
    val shirt: ColorChoice = ColorChoice.Black,
    val pants: ColorChoice = ColorChoice.Khaki,
    /** Null for no hat. */
    val hat: ColorChoice? = ColorChoice.Yellow,
    val board: ColorChoice = ColorChoice.Brown,
) {
    /** Changes skater. Angie starts out in her own look: a red bandana, no hat, a white board. */
    fun switchingSkater(kind: SkaterKind): Outfit =
        if (kind == SkaterKind.Angie) copy(kind = kind, shirt = ColorChoice.Red, hat = null, board = ColorChoice.White)
        else copy(kind = kind)

    companion object {
        val standard = Outfit()

        /** The next choice in a list, wrapping around. `step` is +1 or -1. */
        fun <T> cycle(value: T, all: List<T>, step: Int): T {
            val index = all.indexOf(value)
            if (index < 0) return all.firstOrNull() ?: value
            return all[(index + step + all.size) % all.size]
        }

        /** Hats include "no hat" at the end of the list. */
        val hatChoices: List<ColorChoice?> get() = ColorChoice.clothes + listOf(null)
    }
}
