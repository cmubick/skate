//
//  Tutorial.swift
//  skate
//
//  The tutorial: one move at a time on a practice street. Each step waits until
//  you've done it, then moves on to the next.
//

import CoreGraphics
import Foundation

nonisolated struct TutorialStep: Equatable, Sendable {
    enum Check: Equatable, Sendable {
        /// Pop an ollie and land it.
        case ollie
        /// Get the board this high off the ground.
        case height(CGFloat)
        case laneSwitch
        /// Land a kickflip or heelflip.
        case flip
        case grab
        /// Land a shove-it or 360 flip.
        case spin
        case grind
        /// Switch a grind into a boardslide.
        case boardslide
        case hopOff
        /// Get the combo multiplier this high.
        case combo(Int)
        /// Get all the way over something.
        case clear
    }

    var text: String
    var check: Check
}

nonisolated struct Tutorial: Sendable {
    static let steps: [TutorialStep] = [
        TutorialStep(text: "TAP TO OLLIE", check: .ollie),
        TutorialStep(text: "HOLD TO OLLIE HIGHER", check: .height(30)),
        TutorialStep(text: "SWIPE UP OR DOWN: LANES", check: .laneSwitch),
        TutorialStep(text: "SWIPE SIDEWAYS: KICKFLIP", check: .flip),
        TutorialStep(text: "OLLIE, TAP IN AIR: GRAB", check: .grab),
        TutorialStep(text: "AIR SWIPE UP/DOWN: SPIN", check: .spin),
        TutorialStep(text: "BACK LANE: LAND ON A RAIL", check: .grind),
        TutorialStep(text: "ON RAIL, SWIPE DOWN: SLIDE", check: .boardslide),
        TutorialStep(text: "ON A RAIL, TAP: HOP OFF", check: .hopOff),
        TutorialStep(text: "TRICK AGAIN SOON: COMBO X3", check: .combo(3)),
        TutorialStep(text: "FRONT LANE: JUMP A CONE", check: .clear),
    ]

    private(set) var index = 0
    private var poppedThisJump = false

    var current: TutorialStep? { index < Self.steps.count ? Self.steps[index] : nil }
    var isDone: Bool { index >= Self.steps.count }

    /// Call with everything the run reports. Returns the step just done, if one was.
    mutating func update(run: Run, events: [RunEvent]) -> TutorialStep? {
        guard let step = current else { return nil }
        var done = false
        for event in events {
            switch (step.check, event) {
            case (.ollie, .ollie): poppedThisJump = true
            case (.ollie, .landed): done = done || poppedThisJump
            case (.laneSwitch, .laneSwitch): done = true
            case (.flip, .landedTrick(let trick)): done = done || trick == .kickflip || trick == .heelflip
            case (.grab, .landedTrick(let trick)): done = done || trick == .grab
            case (.spin, .landedTrick(let trick)): done = done || trick == .shoveIt || trick == .threeSixtyFlip
            case (.grind, .grindStarted): done = true
            case (.boardslide, .grindSwitched(.boardslide)): done = true
            case (.hopOff, .popOff): done = true
            case (.clear, .cleared): done = true
            default: break
            }
        }
        switch step.check {
        case .height(let target): done = run.isAirborne && run.height >= target
        case .combo(let target): done = done || run.combo.multiplier >= target
        default: break
        }
        guard done else { return nil }
        index += 1
        poppedThisJump = false
        return step
    }
}

nonisolated extension Level {
    /// The practice street: nothing in the middle lane, rails along the back lane and
    /// cones along the front, over and over, so there's always one coming.
    static let tutorial: Level = {
        var features: [Feature] = []
        for repeatIndex in 0..<40 {
            let x = CGFloat(700 + repeatIndex * 360)
            features.append(.rail(.back, at: x, length: 90))
            features.append(.cone(.front, at: x + 180))
        }
        return Level(id: "tutorial", name: "TUTORIAL", theme: .downtown, length: 15_500, features: features)
    }()
}
