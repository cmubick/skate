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
    /// Flew off the lip of a quarter pipe.
    case launched
    case trickStarted(Trick)
    case grindStarted(Trick)
    case grindSwitched(Trick)
    case grindEnded
    /// Wheels back on the ground, clean. The combo stays open for a moment (see `Run.comboLinkLeft`).
    case landed(perfect: Bool)
    /// A trick done in the air was landed clean (on the ground or onto a rail).
    case landedTrick(Trick)
    /// The combo was counted into the score.
    case banked(points: Int)
    case bail(BailReason)
    case laneSwitch(Lane)
    /// Picked up one of the city's letters. `index` is its place in the city's name.
    case letter(index: Int, letter: Character)
    /// Got all the way over something in the air, doing a trick this hard (`Trick.clearStyle`).
    /// The points go on the combo.
    case cleared(FeatureStyle, style: Double, points: Int)
    /// Pulled off a named gap. The points go on the combo.
    case gap(String, points: Int)
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
    /// What the finger that's down did when it went down: popped an ollie, pressed in
    /// the air (a grab, or an ollie if it's still down at touchdown), or pressed on a rail.
    private enum Press { case none, ollie, air, grind }
    private var press: Press = .none
    /// When the last ollie popped, and the combo from just before, so an ollie that
    /// turns out to be the start of a lane swipe can be taken back.
    private var poppedAt: TimeInterval?
    private var comboBeforePop = Combo()
    private var linkBeforePop: TimeInterval?

    // Scoring.
    private(set) var combo = Combo()
    /// After a clean landing the combo stays open this much longer while you roll.
    /// Nil when there's no combo, or you're in the air or on a rail.
    private(set) var comboLinkLeft: TimeInterval?
    /// The combo's size at the last landing, to tell whether anything new has happened since.
    private var comboAtLanding: (count: Int, bonus: Double)?
    private(set) var score = 0
    /// The biggest combo banked on this run, and the tricks that made it (the last few).
    private(set) var bestCombo = 0
    private(set) var bestComboTricks = ""
    private(set) var time: TimeInterval = 0
    private(set) var isFinished = false

    /// Letters picked up on this run, by their place in the city's name.
    private(set) var lettersFound: Set<Int> = []
    /// Features the skater is passing over right now, with the hardest trick's style so far.
    /// Touching down, grinding or bailing while over one spoils it.
    private var passingOver: [Int: Double] = [:]
    private var spoiled: Set<Int> = []
    /// Everything cleared since leaving the ground, the gaps done on this jump, and the
    /// rail just left behind, for the named gaps.
    private var clearedThisJump: Set<Int> = []
    private var gapsThisJump: Set<Int> = []
    private var leftGrind: Int?
    /// Each gap's features, by their place in the level.
    private let gapFeatures: [[Int]]
    private let inGaps: Set<Int>
    /// Tricks done since leaving the ground, reported once they're landed.
    private var tricksThisJump: [Trick] = []
    /// When each moving feature came on screen and started moving.
    private var startedMoving: [TimeInterval?]

    init(level: Level) {
        self.level = level
        x = level.startX
        lane = level.startLane
        drawnLane = CGFloat(level.startLane.rawValue)
        startedMoving = Array(repeating: nil, count: level.features.count)
        gapFeatures = level.gaps.map { $0.features(in: level) }
        inGaps = Set(gapFeatures.joined())
    }

    /// Where a feature starts right now. Moving things stay put until they come on screen.
    func position(ofFeature index: Int) -> CGFloat {
        let feature = level.features[index]
        guard let start = startedMoving[index] else { return feature.x }
        return feature.x + feature.velocity * CGFloat(time - start)
    }

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
            case .rolling:
                // Pop straight away. Keeping the finger down carries the ollie higher.
                press = .ollie
                ollie(events: &events)
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
                // Any ollie this finger asked for has already happened.
                break
            case .airborne:
                if pressed == .ollie {
                    // Full gravity again from here: the ollie stops climbing soon.
                    break
                } else if isHoldingGrab {
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
            let pressed = press
            press = .none
            if pressed == .ollie, direction == .up || direction == .down, takeBackOllie() {
                switchLane(to: direction == .up ? lane.up : lane.down, events: &events)
                return events
            }
            switch state {
            case .rolling:
                switch direction {
                case .up: switchLane(to: lane.up, events: &events)
                case .down: switchLane(to: lane.down, events: &events)
                case .left, .right:
                    // A flip straight off the ground, in one swipe: pop and flip together.
                    ollie(events: &events)
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
                // Down on the ground: scramble into the next lane and get straight back up
                // there, instead of lying under whatever you hit.
                guard height == 0, direction == .up || direction == .down,
                      let next = direction == .up ? lane.up : lane.down else { break }
                lane = next
                events.append(.laneSwitch(next))
                if blockingFeature(at: 0) == nil, !isOverHole { getUp() }
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

        trackClearing(events: &events)

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
            let before = x
            x += speed * seconds
            rideRamps(from: before, events: &events)
            if state == .rolling, let left = comboLinkLeft {
                if left - dt <= 0 { bankCombo(events: &events) } else { comboLinkLeft = left - dt }
            }
            if state != .rolling {
                break
            } else if blockingFeature(at: height) != nil {
                bail(.crashed, events: &events)
            } else if isOverHole {
                bail(.fell, events: &events)
            }

        case .airborne:
            let previousHeight = height
            let held = press == .ollie && verticalSpeed > 0
            verticalSpeed -= Tuning.gravity * (held ? Tuning.heldOllieGravityScale : 1) * seconds
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
                    reportLandedTricks(events: &events)
                    state = .grinding(feature: index, trick: .fiftyFifty)
                    combo.add(.fiftyFifty)
                    events.append(.grindStarted(.fiftyFifty))
                    checkTransfers(onto: index, events: &events)
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
                startJump()
                leftGrind = index
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
                getUp()
            } else {
                state = .bailed(remaining: left)
            }
        }

        collectLetters(events: &events)

        if x >= level.length {
            if state == .rolling { bankCombo(events: &events) }
            isFinished = true
            events.append(.finished(score: score))
        }
        return events
    }

    // MARK: Moves

    /// Pops with a tapped ollie's speed. Gravity goes easy while the finger stays down.
    private mutating func ollie(events: inout [RunEvent]) {
        comboBeforePop = combo
        linkBeforePop = comboLinkLeft
        poppedAt = time
        startJump()
        verticalSpeed = (2 * Tuning.gravity * Tuning.ollieHeight).squareRoot()
        state = .airborne
        sinceTrickEnded = nil
        // An ollie starts a combo, but doesn't keep one going: that needs a real trick.
        if comboLinkLeft != nil {
            comboLinkLeft = nil
        } else {
            combo.add(.ollie)
        }
        events.append(.ollie(charged: false))
    }

    /// Leaving the ground (or a rail): a fresh jump for gaps and landed tricks.
    private mutating func startJump() {
        clearedThisJump = []
        gapsThisJump = []
        tricksThisJump = []
    }

    /// Undoes an ollie that only just popped: no points for it, and the skater drops
    /// straight back down from wherever it got to. False if it's too late.
    private mutating func takeBackOllie() -> Bool {
        guard state == .airborne, airTrick == nil, verticalSpeed > 0,
              let poppedAt, time - poppedAt <= Tuning.ollieCancelWindow else { return false }
        self.poppedAt = nil
        combo = comboBeforePop
        comboLinkLeft = linkBeforePop
        verticalSpeed = 0
        return true
    }

    private mutating func popOff(events: inout [RunEvent]) {
        startJump()
        if case .grinding(let feature, _) = state {
            leftGrind = feature
            events.append(.grindEnded)
        }
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
        tricksThisJump.append(trick)
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
        sinceTrickEnded = nil
        reportLandedTricks(events: &events)
        leftGrind = nil
        state = .rolling
        // Did anything new go on the combo since the last landing?
        let grew = comboAtLanding.map { $0.count != combo.multiplier || $0.bonus != combo.bonus } ?? !combo.isEmpty
        if grew {
            if perfect { combo.addBonus(Double(combo.points) * Tuning.perfectBonus) }
            speed = min(level.maxSpeed, speed + (perfect ? Tuning.speedPerPerfectLanding : Tuning.speedPerLanding))
        }
        events.append(.landed(perfect: perfect && grew))
        if combo.isEmpty {
            comboLinkLeft = nil
            comboAtLanding = nil
        } else if grew {
            // Keep it open: another trick soon keeps it going.
            comboLinkLeft = Tuning.comboLinkTime
            comboAtLanding = (combo.multiplier, combo.bonus)
        } else {
            bankCombo(events: &events)
        }
        // A press made just before touchdown, still down, pops again right away,
        // so pressing a little early isn't punished.
        if press == .air {
            press = .ollie
            ollie(events: &events)
        }
    }

    /// Counts the combo into the score.
    private mutating func bankCombo(events: inout [RunEvent]) {
        comboLinkLeft = nil
        comboAtLanding = nil
        guard !combo.isEmpty else { return }
        let points = combo.total
        score += points
        if points > bestCombo {
            bestCombo = points
            bestComboTricks = combo.text(maxTricks: 2)
        }
        combo.clear()
        events.append(.banked(points: points))
    }

    private mutating func reportLandedTricks(events: inout [RunEvent]) {
        for trick in tricksThisJump { events.append(.landedTrick(trick)) }
        tricksThisJump = []
    }

    /// Riding up a quarter pipe: the board follows the ramp, and leaving the lip launches you.
    private mutating func rideRamps(from before: CGFloat, events: inout [RunEvent]) {
        var onRamp = false
        for index in level.features.indices where level.features[index].kind == .ramp && level.features[index].lane == lane {
            let ramp = level.features[index]
            let start = position(ofFeature: index)
            if x >= start, x < start + ramp.length {
                height = ramp.rampHeight(at: x, start: start)
                onRamp = true
            } else if before < start + ramp.length, x >= start + ramp.length {
                startJump()
                height = ramp.height
                state = .airborne
                verticalSpeed = (2 * Tuning.gravity * (Tuning.quarterPipeAir - ramp.height)).squareRoot()
                events.append(.launched)
                return
            }
        }
        if !onRamp { height = 0 }
    }

    private mutating func bail(_ reason: BailReason, events: inout [RunEvent]) {
        if case .grinding = state { events.append(.grindEnded) }
        state = .bailed(remaining: Tuning.bailTime)
        combo.clear()
        comboLinkLeft = nil
        comboAtLanding = nil
        leftGrind = nil
        tricksThisJump = []
        finishAirTrick()
        sinceTrickEnded = nil
        press = .none
        events.append(.bail(reason))
    }

    private mutating func getUp() {
        state = .rolling
        speed = Tuning.speedAfterBail
        verticalSpeed = 0
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

    // MARK: Clearing things

    /// Watches what the skater passes over. Getting all the way past something without
    /// touching down on it earns its clear points, times the hardest trick done over it.
    private mutating func trackClearing(events: inout [RunEvent]) {
        for index in level.features.indices {
            let feature = level.features[index]
            guard feature.clearPoints > 0 || inGaps.contains(index) else { continue }
            if overlaps(index) {
                let clean = state == .airborne && height >= feature.height - Tuning.grindSnapBelow
                if clean, !spoiled.contains(index) {
                    let style = airTrick?.trick.clearStyle ?? 1
                    passingOver[index] = max(passingOver[index] ?? 1, style)
                } else {
                    passingOver[index] = nil
                    spoiled.insert(index)
                }
                continue
            }
            spoiled.remove(index)
            guard let style = passingOver.removeValue(forKey: index) else { continue }
            // Only for going past it, not for it passing you.
            guard x - Tuning.skaterHalfWidth > position(ofFeature: index) + feature.length, !isBailed else { continue }
            clearedThisJump.insert(index)
            let points = Int(feature.clearPoints * style)
            if points > 0 {
                addBonus(points)
                events.append(.cleared(feature.style, style: style, points: points))
            }
        }
        checkOverGaps(events: &events)
    }

    /// Bonus points onto the combo; straight into the score if it has just been banked.
    private mutating func addBonus(_ points: Int) {
        if combo.isEmpty {
            score += points
        } else {
            combo.addBonus(Double(points))
        }
    }

    // MARK: Named gaps

    private mutating func checkOverGaps(events: inout [RunEvent]) {
        for (index, gap) in level.gaps.enumerated() where !gapsThisJump.contains(index) {
            guard case .over = gap.kind, !gapFeatures[index].isEmpty,
                  gapFeatures[index].allSatisfy(clearedThisJump.contains) else { continue }
            award(gap: index, events: &events)
        }
    }

    private mutating func checkTransfers(onto feature: Int, events: inout [RunEvent]) {
        defer { leftGrind = nil }
        guard let leftGrind else { return }
        for (index, gap) in level.gaps.enumerated() where !gapsThisJump.contains(index) {
            guard case .transfer = gap.kind, gapFeatures[index] == [leftGrind, feature] else { continue }
            award(gap: index, events: &events)
        }
    }

    private mutating func award(gap index: Int, events: inout [RunEvent]) {
        gapsThisJump.insert(index)
        let gap = level.gaps[index]
        addBonus(gap.points)
        events.append(.gap(gap.name, points: gap.points))
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
            guard feature.kind != .hole, feature.kind != .ramp, feature.kind != .decor, !feature.isLow else { return false }
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
            guard feature.kind != .hole, feature.kind != .ramp, feature.kind != .decor else { return false }
            // Rails pull you in from a little above. Cones only count if you really touch them.
            let snap = feature.isGrindable ? Tuning.grindSnap : 0
            return overlaps(index)
                && previousHeight >= feature.height - Tuning.grindSnapBelow
                && height <= feature.height + snap
        }
    }
}
