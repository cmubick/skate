//
//  Run.swift
//  skate
//
//  One run down the street: the skater, what they're doing, the combo and the
//  score. Takes gestures and time, and reports what happened so the scene can
//  play sounds, haptics and animations. Has no drawing in it, so it can be tested.
//

import CoreGraphics
import Foundation

nonisolated enum SkaterState: Equatable, Sendable {
    case rolling
    case airborne
    /// On a feature, by its index in the level.
    case grinding(feature: Int, trick: Trick)
    /// Tumbling. Gets back up when the time runs out.
    case bailed(remaining: TimeInterval)
}

/// A flip or grab in progress.
nonisolated struct AirTrick: Equatable, Sendable {
    var trick: Trick
    var elapsed: TimeInterval = 0
    /// Grabs held by the finger have no set length until it lets go.
    var duration: TimeInterval

    var progress: Double { duration.isFinite ? min(1, elapsed / max(duration, 0.001)) : 0 }
}

nonisolated enum BailReason: Equatable, Sendable {
    /// Landed before the board came back around.
    case midTrick
    /// Still holding a grab when the wheels touched.
    case holdingGrab
    /// Rolled or flew into something.
    case crashed
    /// Landed on top of something that can't be ground.
    case landedOnBlock
    /// Rolled or landed in a hole.
    case fell
}

nonisolated enum RunEvent: Equatable, Sendable {
    case ollie(charged: Bool)
    case popOff
    case trickStarted(Trick)
    case grindStarted(Trick)
    case grindSwitched(Trick)
    case grindEnded
    case landed(points: Int, perfect: Bool)
    case bail(BailReason)
    case laneSwitch(Lane)
    /// Picked up one of the city's letters. `index` is its place in the city's name.
    case letter(index: Int, letter: Character)
    case finished(score: Int)
}

nonisolated struct Run: Sendable {
    let level: Level

    // Where the skater is.
    private(set) var x: CGFloat
    /// Height of the board above the lane's ground.
    private(set) var height: CGFloat = 0
    private(set) var verticalSpeed: CGFloat = 0
    private(set) var speed: CGFloat = Tuning.startSpeed
    private(set) var lane: Lane
    /// The lane as drawn, gliding toward `lane` when you switch: 0 is the back lane, 2 the front.
    private(set) var drawnLane: CGFloat

    // What the skater is doing.
    private(set) var state: SkaterState = .rolling
    private(set) var airTrick: AirTrick?
    /// True while a finger is holding a grab.
    private(set) var isHoldingGrab = false
    /// Seconds since the last air trick finished, while it hasn't been followed by another.
    private var sinceTrickEnded: TimeInterval?

    // The finger.
    private enum Press { case none, ground, air, grind }
    private var press: Press = .none

    // Scoring.
    private(set) var combo = Combo()
    private(set) var score = 0
    private(set) var bestCombo = 0
    private(set) var time: TimeInterval = 0
    private(set) var isFinished = false

    /// Letters picked up on this run, by their place in the city's name.
    private(set) var lettersFound: Set<Int> = []
    /// When each moving feature came on screen and started moving.
    private var startedMoving: [TimeInterval?]

    init(level: Level) {
        self.level = level
        x = level.startX
        lane = level.startLane
        drawnLane = CGFloat(level.startLane.rawValue)
        startedMoving = Array(repeating: nil, count: level.features.count)
    }

    /// Where a feature starts right now. Moving things stay put until they come on screen.
    func position(ofFeature index: Int) -> CGFloat {
        let feature = level.features[index]
        guard let start = startedMoving[index] else { return feature.x }
        return feature.x + feature.velocity * CGFloat(time - start)
    }

    /// True while the finger is down on the ground, winding up an ollie.
    var isCharging: Bool { press == .ground && state == .rolling }

    var isAirborne: Bool { state == .airborne }

    var isGrinding: Bool {
        if case .grinding = state { return true }
        return false
    }

    // MARK: Input

    mutating func handle(_ gesture: GestureEvent) -> [RunEvent] {
        guard !isFinished else { return [] }
        var events: [RunEvent] = []
        switch gesture {
        case .press:
            switch state {
            case .rolling: press = .ground
            case .airborne: press = .air
            case .grinding: press = .grind
            case .bailed: press = .none
            }

        case .hold:
            // Holding in the air is a long grab.
            if state == .airborne, press == .air, airTrick == nil {
                startAirTrick(.grab, duration: .infinity, events: &events)
                isHoldingGrab = true
            }

        case .release(let held):
            let pressed = press
            press = .none
            switch state {
            case .rolling:
                // A press that started in the air and lifted after landing still ollies,
                // so tapping a little early isn't punished.
                let charge = pressed == .ground ? held : 0
                ollie(charge: charge, events: &events)
            case .airborne:
                if isHoldingGrab {
                    releaseGrab(held: held)
                } else if pressed == .air, airTrick == nil {
                    startAirTrick(.grab, duration: Trick.grab.airTime, events: &events)
                }
            case .grinding:
                popOff(events: &events)
            case .bailed:
                break
            }

        case .swipe(let direction):
            press = .none
            switch state {
            case .rolling:
                switch direction {
                case .up: switchLane(to: lane.up, events: &events)
                case .down: switchLane(to: lane.down, events: &events)
                case .left, .right:
                    // A flip straight off the ground, in one swipe: pop and flip together.
                    ollie(charge: 0, events: &events)
                    startAirTrick(Trick.flip(for: direction), events: &events)
                }
            case .airborne:
                if airTrick == nil {
                    startAirTrick(Trick.flip(for: direction), events: &events)
                }
            case .grinding(let feature, let trick):
                if direction == .up {
                    // Ollie out toward the lane above.
                    popOff(events: &events)
                    if let up = lane.up { lane = up; events.append(.laneSwitch(up)) }
                } else {
                    let next: Trick = trick == .fiftyFifty ? .boardslide : .fiftyFifty
                    state = .grinding(feature: feature, trick: next)
                    combo.add(next)
                    events.append(.grindSwitched(next))
                }
            case .bailed:
                break
            }
        }
        return events
    }

    // MARK: Time

    mutating func step(_ dt: TimeInterval) -> [RunEvent] {
        guard !isFinished, dt > 0 else { return [] }
        var events: [RunEvent] = []
        time += dt
        let seconds = CGFloat(dt)

        let target = CGFloat(lane.rawValue)
        let glide = seconds / CGFloat(Tuning.laneSwitchTime)
        drawnLane += max(-glide, min(glide, target - drawnLane))

        // Moving things start moving once they're about to come on screen.
        for index in level.features.indices where startedMoving[index] == nil && level.features[index].isMoving {
            if x + Tuning.movingStartDistance >= level.features[index].x { startedMoving[index] = time }
        }

        // Downhill spots keep speeding you up.
        if level.acceleration > 0, !isBailed {
            speed = min(level.maxSpeed, speed + level.acceleration * seconds)
        }

        switch state {
        case .rolling:
            x += speed * seconds
            if blockingFeature(at: height) != nil {
                bail(.crashed, events: &events)
            } else if isOverHole {
                bail(.fell, events: &events)
            }

        case .airborne:
            let previousHeight = height
            verticalSpeed -= Tuning.gravity * seconds
            height += verticalSpeed * seconds
            x += speed * seconds
            advanceAirTrick(dt)

            if verticalSpeed <= 0, let index = landingFeature(previousHeight: previousHeight) {
                let feature = level.features[index]
                if !feature.isGrindable {
                    bail(.landedOnBlock, events: &events)
                } else if let reason = landingProblem() {
                    bail(reason, events: &events)
                } else {
                    height = feature.height
                    verticalSpeed = 0
                    finishAirTrick()
                    state = .grinding(feature: index, trick: .fiftyFifty)
                    combo.add(.fiftyFifty)
                    events.append(.grindStarted(.fiftyFifty))
                }
            } else if blockingFeature(at: height) != nil {
                bail(.crashed, events: &events)
            } else if height <= 0, isOverHole {
                height = 0
                verticalSpeed = 0
                bail(.fell, events: &events)
            } else if height <= 0 {
                land(events: &events)
            }

        case .grinding(let index, let trick):
            x += speed * seconds
            combo.extendLast(by: trick.pointsPerSecond * dt)
            if x - Tuning.skaterHalfWidth > level.features[index].end {
                state = .airborne
                verticalSpeed = Tuning.railEndVelocity
                events.append(.grindEnded)
            }

        case .bailed(let remaining):
            speed += (Tuning.bailSlideSpeed - speed) * min(1, seconds * 4)
            x += speed * seconds
            if height > 0 {
                verticalSpeed -= Tuning.gravity * seconds
                height = max(0, height + verticalSpeed * seconds)
            }
            let left = remaining - dt
            // Don't get up in the middle of a cone, or in a hole.
            if left <= 0, height == 0, blockingFeature(at: 0) == nil, !isOverHole {
                state = .rolling
                speed = Tuning.speedAfterBail
                verticalSpeed = 0
            } else {
                state = .bailed(remaining: left)
            }
        }

        collectLetters(events: &events)

        if x >= level.length {
            if state == .rolling { bank(perfect: false) }
            isFinished = true
            events.append(.finished(score: score))
        }
        return events
    }

    // MARK: Moves

    private mutating func ollie(charge: TimeInterval, events: inout [RunEvent]) {
        let span = Tuning.maxCharge - Tuning.holdThreshold
        let amount = CGFloat(max(0, min(1, (charge - Tuning.holdThreshold) / span)))
        let jump = Tuning.ollieHeight + (Tuning.chargedOllieHeight - Tuning.ollieHeight) * amount
        verticalSpeed = (2 * Tuning.gravity * jump).squareRoot()
        state = .airborne
        sinceTrickEnded = nil
        combo.add(.ollie)
        events.append(.ollie(charged: amount > 0))
    }

    private mutating func popOff(events: inout [RunEvent]) {
        if case .grinding = state { events.append(.grindEnded) }
        verticalSpeed = (2 * Tuning.gravity * Tuning.popOffHeight).squareRoot()
        state = .airborne
        sinceTrickEnded = nil
        events.append(.popOff)
    }

    private mutating func switchLane(to next: Lane?, events: inout [RunEvent]) {
        guard let next else { return }
        lane = next
        events.append(.laneSwitch(next))
    }

    private mutating func startAirTrick(_ trick: Trick, duration: TimeInterval? = nil, events: inout [RunEvent]) {
        airTrick = AirTrick(trick: trick, duration: duration ?? trick.airTime)
        sinceTrickEnded = nil
        combo.add(trick)
        events.append(.trickStarted(trick))
    }

    private mutating func releaseGrab(held: TimeInterval) {
        isHoldingGrab = false
        guard var trick = airTrick else { return }
        combo.extendLast(by: Trick.grab.pointsPerSecond * max(0, held - Tuning.holdThreshold))
        // Let go of the board: a short moment to get the feet back on.
        trick.duration = max(trick.elapsed + 0.06, Trick.grab.airTime)
        airTrick = trick
    }

    private mutating func advanceAirTrick(_ dt: TimeInterval) {
        if var trick = airTrick {
            trick.elapsed += dt
            if trick.elapsed >= trick.duration {
                airTrick = nil
                sinceTrickEnded = 0
            } else {
                airTrick = trick
            }
        } else if let since = sinceTrickEnded {
            sinceTrickEnded = since + dt
        }
    }

    private mutating func finishAirTrick() {
        airTrick = nil
        isHoldingGrab = false
    }

    /// Why touching down now would be a bail, if it would.
    private func landingProblem() -> BailReason? {
        if isHoldingGrab { return .holdingGrab }
        if airTrick != nil { return .midTrick }
        return nil
    }

    private mutating func land(events: inout [RunEvent]) {
        height = 0
        verticalSpeed = 0
        if let reason = landingProblem() {
            bail(reason, events: &events)
            return
        }
        let perfect = sinceTrickEnded.map { $0 <= Tuning.perfectWindow } ?? false
        let points = bank(perfect: perfect)
        state = .rolling
        speed = min(level.maxSpeed, speed + (perfect ? Tuning.speedPerPerfectLanding : Tuning.speedPerLanding))
        events.append(.landed(points: points, perfect: perfect))
    }

    @discardableResult
    private mutating func bank(perfect: Bool) -> Int {
        let total = combo.total
        let points = total + (perfect ? Int(Double(total) * Tuning.perfectBonus) : 0)
        score += points
        bestCombo = max(bestCombo, points)
        combo.clear()
        sinceTrickEnded = nil
        return points
    }

    private mutating func bail(_ reason: BailReason, events: inout [RunEvent]) {
        if case .grinding = state { events.append(.grindEnded) }
        state = .bailed(remaining: Tuning.bailTime)
        combo.clear()
        finishAirTrick()
        sinceTrickEnded = nil
        press = .none
        events.append(.bail(reason))
    }

    private var isBailed: Bool {
        if case .bailed = state { return true }
        return false
    }

    // MARK: Letters

    private mutating func collectLetters(events: inout [RunEvent]) {
        for pickup in level.letters where !lettersFound.contains(pickup.index) {
            guard pickup.lane == lane, !isBailed,
                  abs(pickup.x - x) <= Tuning.letterReachX,
                  pickup.height >= height - 4, pickup.height <= height + Tuning.letterReachUp else { continue }
            lettersFound.insert(pickup.index)
            score += Tuning.letterPoints
            events.append(.letter(index: pickup.index, letter: pickup.letter))
        }
    }

    // MARK: Collisions

    private func overlaps(_ index: Int) -> Bool {
        let feature = level.features[index]
        let start = position(ofFeature: index)
        return feature.lane == lane
            && x + Tuning.skaterHalfWidth >= start
            && x - Tuning.skaterHalfWidth <= start + feature.length
    }

    /// Something in the way at this height, if there is. Holes and low curbs never are.
    private func blockingFeature(at height: CGFloat) -> Int? {
        level.features.indices.first { index in
            let feature = level.features[index]
            guard feature.kind != .hole, !feature.isLow else { return false }
            return overlaps(index) && height < feature.height - Tuning.grindSnapBelow
        }
    }

    /// True when the skater's wheels are over a hole in their lane.
    private var isOverHole: Bool {
        level.features.indices.contains { index in
            let feature = level.features[index]
            let start = position(ofFeature: index)
            return feature.kind == .hole && feature.lane == lane
                && x >= start + 3 && x <= start + feature.length - 3
        }
    }

    /// The feature the skater is coming down onto, if any.
    private func landingFeature(previousHeight: CGFloat) -> Int? {
        level.features.indices.first { index in
            let feature = level.features[index]
            guard feature.kind != .hole else { return false }
            // Rails pull you in from a little above. Cones only count if you really touch them.
            let snap = feature.isGrindable ? Tuning.grindSnap : 0
            return overlaps(index)
                && previousHeight >= feature.height - Tuning.grindSnapBelow
                && height <= feature.height + snap
        }
    }
}
