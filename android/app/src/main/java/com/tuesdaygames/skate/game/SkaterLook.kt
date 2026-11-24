//
//  SkaterLook.kt
//
//  Every picture for one skater in one outfit, ready to draw. Ported from
//  `SkaterLook` in skate/UI/CharacterArt.swift.
//

package com.tuesdaygames.skate.game

import com.tuesdaygames.skate.art.CharacterArt
import com.tuesdaygames.skate.rules.Outfit

class SkaterLook(outfit: Outfit) {
    private val poses = CharacterArt.poses(outfit)
    private val board = CharacterArt.board(outfit)

    val roll = poses.roll.canvas().texture()
    val crouch = poses.crouch.canvas().texture()
    val air = poses.air.canvas().texture()
    val grab = poses.grab.canvas().texture()
    val bail = poses.bail.canvas().texture()
    val boardSide = board.side.canvas().texture()
    val boardWheelsUp = board.wheelsUp.canvas().texture()
    val boardUnderside = board.underside.canvas().texture()
    val boardGrip = board.grip.canvas().texture()

    /** Boardsliding: arms out for balance (two frames, wobbling), and the board
     *  turned across the rail, seen end-on with its near wheels hanging down. */
    val slide = poses.slide.map { it.canvas().texture() }
    val boardEndOn = board.endOn.canvas().texture()

    /** One picture of them standing on their board, for menus. */
    val standing = CharacterArt.standing(outfit).texture()

    /** The board seen a little from above, turned through a full circle in
     *  `CharacterArt.spinSteps` steps: grip tape up, then graphic up (wheels showing). */
    val spinGripUp = (0 until CharacterArt.spinSteps).map { CharacterArt.spin(outfit, it, graphicUp = false).texture() }
    val spinGraphicUp = (0 until CharacterArt.spinSteps).map { CharacterArt.spin(outfit, it, graphicUp = true).texture() }
}
