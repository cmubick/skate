//
//  skateTests.swift
//  skateTests
//

import CoreGraphics
import Foundation
import Testing
@testable import skate

private let step: TimeInterval = 1.0 / 120

/// An empty street, or one with just the features given.
private func street(_ features: [Feature] = [], length: CGFloat = 5000) -> Level {
    Level(name: "TEST", length: length, features: features, startX: 0, startLane: .middle)
}

/// Steps the run until `done` is true, collecting what happened. Gives up after `limit` seconds.
@discardableResult
private func play(_ run: inout Run, for limit: TimeInterval = 5, until done: (Run) -> Bool) -> [RunEvent] {
    var events: [RunEvent] = []
    var time = 0.0
    while !done(run), time < limit {
        events += run.step(step)
        time += step
    }
    return events
}

/// Where a tapped ollie from x = 0 reaches its peak, so tests can put things just past it.
private var ollieTopX: CGFloat {
    let liftOff = (2 * Tuning.gravity * Tuning.ollieHeight).squareRoot()
    return (Tuning.startSpeed * liftOff / Tuning.gravity).rounded()
}

private func tap(_ run: inout Run) -> [RunEvent] {
    run.handle(.press) + run.handle(.release(held: 0.05))
}

private func isBail(_ event: RunEvent) -> Bool {
    if case .bail = event { return true }
    return false
}

@MainActor
struct GestureTests {
    @Test func quickTapIsPressThenRelease() {
        var reader = GestureReader()
        #expect(reader.began(at: .zero, time: 0) == [.press])
        #expect(reader.tick(time: 0.05) == [])
        #expect(reader.ended(at: CGPoint(x: 3, y: 2), time: 0.08) == [.release(held: 0.08)])
    }

    @Test func holdingStillSendsHoldOnce() {
        var reader = GestureReader()
        _ = reader.began(at: .zero, time: 0)
        #expect(reader.tick(time: 0.2) == [.hold])
        #expect(reader.tick(time: 0.3) == [])
        #expect(reader.ended(at: .zero, time: 0.4) == [.release(held: 0.4)])
    }

    @Test func swipesFireOnceAndUseScreenDirections() {
        var reader = GestureReader()
        _ = reader.began(at: CGPoint(x: 100, y: 100), time: 0)
        #expect(reader.moved(to: CGPoint(x: 100, y: 90), time: 0.02) == [])
        // UIKit's y grows downward, so moving the finger up the screen is a swipe up.
        #expect(reader.moved(to: CGPoint(x: 102, y: 60), time: 0.04) == [.swipe(.up)])
        #expect(reader.moved(to: CGPoint(x: 102, y: 20), time: 0.06) == [])
        #expect(reader.ended(at: CGPoint(x: 102, y: 20), time: 0.08) == [])

        _ = reader.began(at: CGPoint(x: 100, y: 100), time: 1)
        #expect(reader.moved(to: CGPoint(x: 60, y: 110), time: 1.03) == [.swipe(.left)])
    }

    @Test func pixelLayoutUsesWholePixels() {
        // An iPhone on its side: 874 x 402 points at 3x.
        let phone = PixelLayout(viewSize: CGSize(width: 874, height: 402), screenScale: 3)
        #expect(phone.scale == 12)
        #expect(phone.gameSize == CGSize(width: 218, height: 100))
        #expect(phone.frame.width * 3 == phone.gameSize.width * 12)

        // An iPad is squarer, so it shows more sky rather than less street.
        let pad = PixelLayout(viewSize: CGSize(width: 1376, height: 1032), screenScale: 2)
        #expect(pad.gameSize.width >= PixelLayout.minimumSize.width)
        #expect(pad.gameSize.height > PixelLayout.minimumSize.height)
    }
}

@MainActor
struct ComboTests {
    @Test func multiplierCountsTricks() {
        var combo = Combo()
        combo.add(.ollie)
        combo.add(.kickflip)
        #expect(combo.multiplier == 2)
        #expect(combo.total == (50 + 150) * 2)
        #expect(combo.text() == "OLLIE + KICKFLIP")
    }

    @Test func longCombosShowTheLatestTricks() {
        var combo = Combo()
        [Trick.ollie, .kickflip, .fiftyFifty, .heelflip].forEach { combo.add($0) }
        #expect(combo.text() == "... + KICKFLIP + 50-50 + HEELFLIP")
    }
}

@MainActor
struct RunTests {
    @Test func tapOllieLandsCleanAndBanks() {
        var run = Run(level: street())
        #expect(tap(&run) == [.ollie(charged: false)])
        #expect(run.isAirborne)
        let events = play(&run) { $0.state == .rolling }
        #expect(events.contains(.landed(points: 50, perfect: false)))
        #expect(run.score == 50)
        #expect(run.speed > Tuning.startSpeed)
    }

    @Test func chargedOllieGoesHigher() {
        func peak(held: TimeInterval) -> CGFloat {
            var run = Run(level: street())
            _ = run.handle(.press)
            _ = run.handle(.release(held: held))
            var highest: CGFloat = 0
            play(&run) { highest = max(highest, $0.height); return $0.state == .rolling }
            return highest
        }
        let tapped = peak(held: 0.05)
        let charged = peak(held: Tuning.maxCharge)
        #expect(abs(tapped - Tuning.ollieHeight) < 2)
        #expect(abs(charged - Tuning.chargedOllieHeight) < 2)
        #expect(peak(held: 5) == charged)
    }

    @Test func kickflipLandedCleanScoresTheCombo() {
        var run = Run(level: street())
        _ = tap(&run)
        _ = run.step(0.02)
        #expect(run.handle(.press) + run.handle(.swipe(.left)) == [.trickStarted(.kickflip)])
        let events = play(&run) { $0.state == .rolling }
        #expect(events.contains { if case .landed(let points, _) = $0 { points >= 400 } else { false } })
    }

    @Test func flippingTooLateIsABail() {
        var run = Run(level: street())
        _ = tap(&run)
        // Wait until just before touchdown, then flip.
        play(&run) { $0.verticalSpeed < 0 && $0.height < 3 }
        _ = run.handle(.press)
        _ = run.handle(.swipe(.up))
        let events = play(&run) { $0.state != .airborne }
        #expect(events.contains(.bail(.midTrick)))
        #expect(run.score == 0)
        #expect(run.combo.isEmpty)
    }

    @Test func holdingAGrabThroughLandingIsABail() {
        var run = Run(level: street())
        _ = tap(&run)
        _ = run.handle(.press)
        _ = run.handle(.hold)
        #expect(run.isHoldingGrab)
        let events = play(&run) { $0.state != .airborne }
        #expect(events.contains(.bail(.holdingGrab)))
    }

    @Test func rollingIntoAConeIsABail() {
        var run = Run(level: street([.cone(.middle, at: 60)]))
        let events = play(&run) { if case .bailed = $0.state { true } else { false } }
        #expect(events.contains(.bail(.crashed)))
        // Gets back up past the cone.
        play(&run) { $0.state == .rolling }
        #expect(run.state == .rolling)
        #expect(run.x > 60 + 7)
    }

    @Test func conesInOtherLanesDontMatter() {
        var run = Run(level: street([.cone(.front, at: 60), .cone(.back, at: 80)]))
        let events = play(&run, for: 2) { $0.x > 200 }
        #expect(!events.contains(where: isBail))
    }

    @Test func switchingLanesStopsAtTheEdges() {
        var run = Run(level: street())
        #expect(run.handle(.swipe(.down)) == [.laneSwitch(.front)])
        #expect(run.handle(.swipe(.down)) == [])
        #expect(run.lane == .front)
        _ = run.handle(.swipe(.up))
        _ = run.handle(.swipe(.up))
        #expect(run.lane == .back)
        play(&run, for: 1) { $0.drawnLane == 0 }
        #expect(run.drawnLane == 0)
    }

    @Test func landingOnARailGrindsAndRunningOffTheEndBanks() {
        // A rail that starts just past the top of the ollie, so the board comes down on it.
        var run = Run(level: street([.rail(.middle, at: ollieTopX + Tuning.skaterHalfWidth, length: 100)]))
        _ = tap(&run)
        let toRail = play(&run) { if case .grinding = $0.state { true } else { false } }
        #expect(toRail.contains(.grindStarted(.fiftyFifty)))
        let rest = play(&run) { $0.state == .rolling }
        #expect(rest.contains(.grindEnded))
        let landed = rest.compactMap { event -> Int? in
            if case .landed(let points, _) = event { return points }
            return nil
        }
        // Ollie plus the grind's base and per-second points, times two.
        #expect((landed.first ?? 0) > (50 + 100) * 2)
    }

    @Test func tappingOnARailPopsOffAndKeepsTheCombo() {
        var run = Run(level: street([.rail(.middle, at: ollieTopX + Tuning.skaterHalfWidth, length: 300)]))
        _ = tap(&run)
        play(&run) { if case .grinding = $0.state { true } else { false } }
        // Hopping off ends the grind, so the rumble and grind sound stop.
        #expect(tap(&run) == [.grindEnded, .popOff])
        #expect(run.isAirborne)
        #expect(run.combo.multiplier == 2)
    }

    @Test func comingDownOnAPlanterIsABail() {
        // Low enough to clear on the way up, right where the ollie comes down.
        var run = Run(level: street([.planter(.middle, at: ollieTopX, length: 60, height: Tuning.ollieHeight - 6)]))
        _ = tap(&run)
        let events = play(&run) { $0.state != .airborne }
        #expect(events.contains(.bail(.landedOnBlock)))
    }

    @Test func crossingTheFinishEndsTheRun() {
        var run = Run(level: street(length: 100))
        let events = play(&run) { $0.isFinished }
        #expect(events.contains(.finished(score: 0)))
        #expect(run.step(step) == [])
        #expect(tap(&run) == [])
    }

    @Test func feelStreetIsInOrderAndInsideTheRun() {
        let level = Level.feelStreet
        #expect(level.features.allSatisfy { $0.end < level.length })
        #expect(zip(level.features, level.features.dropFirst()).allSatisfy { $0.x <= $1.x })
    }

    @Test func spritesAreRectangular() {
        for sprite in [SkaterArt.roll, SkaterArt.crouch, SkaterArt.air, SkaterArt.grab, SkaterArt.bail] {
            #expect(sprite.width == 22)
            #expect(sprite.rows.allSatisfy { $0.count == 22 })
        }
        for sprite in [BoardArt.side, BoardArt.wheelsUp, BoardArt.underside, BoardArt.grip] {
            #expect(sprite.width == 20)
            #expect(sprite.rows.allSatisfy { $0.count == 20 })
        }
        for glyph in PixelFont.allGlyphs {
            #expect(glyph.count == PixelFont.glyphHeight)
            #expect(Set(glyph.map(\.count)).count == 1)
        }
    }

    @Test func swipingSidewaysOnTheGroundKickflips() {
        var run = Run(level: street())
        _ = run.handle(.press)
        #expect(run.handle(.swipe(.left)) == [.ollie(charged: false), .trickStarted(.kickflip)])
        let events = play(&run) { $0.state == .rolling }
        #expect(events.contains(.landed(points: (50 + 150) * 2, perfect: false)))

        var other = Run(level: street())
        #expect(other.handle(.swipe(.right)) == [.ollie(charged: false), .trickStarted(.heelflip)])
    }
}
