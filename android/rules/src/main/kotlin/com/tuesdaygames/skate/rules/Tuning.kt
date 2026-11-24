//
//  Tuning.kt
//
//  Every number that sets how the game feels, in one place. Ported from
//  skate/Rules/Tuning.swift: keep the two the same.
//
//  World units are game pixels (a phone shows about 218 x 100 of them) and seconds.
//

package com.tuesdaygames.skate.rules

object Tuning {
    // Input

    /** A touch held longer than this is a hold, not a tap. */
    const val holdThreshold = 0.12
    /** How far a finger has to move, in points (dp on Android), to count as a swipe. */
    const val swipeDistance = 30.0
    /** An up or down swipe this soon after an ollie popped, by the same finger, takes the
     *  ollie back and changes lanes instead: the swipe started with a press, which popped. */
    const val ollieCancelWindow = 0.15

    // Jumping

    const val gravity = 440.0
    /** How high a tapped ollie goes. */
    const val ollieHeight = 20.0
    /** How high an ollie goes with the finger kept down until the top. */
    const val chargedOllieHeight = 38.0
    /** Gravity is this much lighter while the finger that popped an ollie stays down and
     *  the board is still rising, so holding carries it up to `chargedOllieHeight`. */
    val heldOllieGravityScale: Double get() = ollieHeight / chargedOllieHeight
    /** The little hop when you pop off a rail or ledge. */
    const val popOffHeight = 14.0
    /** The bump up when you roll off the end of a rail. */
    const val railEndVelocity = 45.0

    // Speed

    const val startSpeed = 85.0
    const val maxSpeed = 120.0
    /** The speed you get up again at after a bail. */
    const val speedAfterBail = 70.0
    const val speedPerLanding = 3.0
    const val speedPerPerfectLanding = 5.0

    // Lanes

    /** Height on screen between one lane and the next. */
    const val laneSpacing = 15.0
    const val laneSwitchTime = 0.12

    // Landing and grinding

    /** Half the skater's width, for bumping into things. */
    const val skaterHalfWidth = 7.0
    /** How far above a rail you can be when coming down and still lock onto it. */
    const val grindSnap = 8.0
    /** A little give below a rail's top, so landing a frame late still grinds. */
    const val grindSnapBelow = 3.0
    /** Finishing a trick this close to touching down is a perfect landing. */
    const val perfectWindow = 0.08
    /** A perfect landing adds this share of the combo on top. */
    const val perfectBonus = 0.2

    /** Things this low (curbs, train tracks) don't stop you rolling; you can only grind them. */
    const val lowFeatureHeight = 5.0
    /** Moving things start moving when you're this close, just before they come on screen. */
    const val movingStartDistance = 200.0

    // Letters

    /** How close along the street you have to be to pick up a letter. */
    const val letterReachX = 8.0
    /** How far above your board you can reach a letter. Higher letters need an ollie. */
    const val letterReachUp = 16.0
    const val letterPoints = 100

    // Combos

    /** After a clean landing the combo stays open this long while you roll. Another trick
     *  keeps it going; run out of time, or land with nothing new, and it banks. */
    const val comboLinkTime = 1.2

    // Quarter pipes

    /** How high the lip of a quarter pipe is. */
    const val quarterPipeLip = 10.0
    /** How high above the ground you fly off a quarter pipe. */
    const val quarterPipeAir = 46.0

    // Clearing things

    /** Points for getting over something in the air: a base, plus some for every pixel
     *  of height and length. A cone is worth about 65, a car about 110. */
    const val clearBase = 20.0
    const val clearPerHeight = 3.0
    const val clearPerLength = 1.0
    /** Moving things are worth at least this many times more... */
    const val clearMovingBase = 1.5
    /** ...and another 1x for every this many pixels per second they're going. */
    const val clearMovingSpeedPerStep = 100.0

    // Bails

    const val bailTime = 0.9
    const val bailSlideSpeed = 40.0
}
