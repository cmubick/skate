//
//  Tuning.swift
//  skate
//
//  Every number that sets how the game feels, in one place. These are starting
//  guesses from the design doc, to be tuned on a real phone.
//
//  World units are game pixels (a phone shows about 218 x 100 of them) and seconds.
//

import CoreGraphics
import Foundation

nonisolated enum Tuning {
    // MARK: Input

    /// A touch held longer than this is a hold, not a tap.
    static let holdThreshold: TimeInterval = 0.12
    /// How far a finger has to move, in points, to count as a swipe.
    static let swipeDistance: CGFloat = 30
    /// Holding longer than this before letting go doesn't make an ollie any higher.
    static let maxCharge: TimeInterval = 0.5

    // MARK: Jumping

    static let gravity: CGFloat = 440
    /// How high a tapped ollie goes.
    static let ollieHeight: CGFloat = 20
    /// How high a fully charged ollie goes.
    static let chargedOllieHeight: CGFloat = 38
    /// The little hop when you pop off a rail or ledge.
    static let popOffHeight: CGFloat = 14
    /// The bump up when you roll off the end of a rail.
    static let railEndVelocity: CGFloat = 45

    // MARK: Speed

    static let startSpeed: CGFloat = 85
    static let maxSpeed: CGFloat = 120
    /// The speed you get up again at after a bail.
    static let speedAfterBail: CGFloat = 70
    static let speedPerLanding: CGFloat = 3
    static let speedPerPerfectLanding: CGFloat = 5

    // MARK: Lanes

    /// Height on screen between one lane and the next.
    static let laneSpacing: CGFloat = 15
    static let laneSwitchTime: TimeInterval = 0.12

    // MARK: Landing and grinding

    /// Half the skater's width, for bumping into things.
    static let skaterHalfWidth: CGFloat = 7
    /// How far above a rail you can be when coming down and still lock onto it.
    static let grindSnap: CGFloat = 8
    /// A little give below a rail's top, so landing a frame late still grinds.
    static let grindSnapBelow: CGFloat = 3
    /// Finishing a trick this close to touching down is a perfect landing.
    static let perfectWindow: TimeInterval = 0.08
    /// A perfect landing adds this share of the combo on top.
    static let perfectBonus = 0.2

    /// Things this low (curbs, train tracks) don't stop you rolling; you can only grind them.
    static let lowFeatureHeight: CGFloat = 5
    /// Moving things start moving when you're this close, just before they come on screen.
    static let movingStartDistance: CGFloat = 200

    // MARK: Letters

    /// How close along the street you have to be to pick up a letter.
    static let letterReachX: CGFloat = 8
    /// How far above your board you can reach a letter. Higher letters need an ollie.
    static let letterReachUp: CGFloat = 16
    static let letterPoints = 100

    // MARK: Bails

    static let bailTime: TimeInterval = 0.9
    static let bailSlideSpeed: CGFloat = 40
}
