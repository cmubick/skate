//
//  skateTests.swift
//  skateTests
//

import CoreGraphics
import Foundation
import Testing
@testable import skate

private let step: TimeInterval = 1.0 / 120

/// An empty street, or one with just the features (and letters) given.
private func street(_ features: [Feature] = [], letters: [LetterPickup] = [], length: CGFloat = 5000,
                    acceleration: CGFloat = 0, maxSpeed: CGFloat = Tuning.maxSpeed) -> Level {
    Level(id: "test", name: "TEST", theme: .downtown, length: length, features: features, letters: letters,
          startX: 0, startLane: .middle, acceleration: acceleration, maxSpeed: maxSpeed)
}

/// Steps the run until `done` is true, collecting what happened. Gives up after `limit` seconds.
@discardableResult
private func play(_ run: inout Run, for limit: TimeInterval = 5, until done: (Run) -> Bool,
                  onStep: (inout Run, TimeInterval) -> Void = { _, _ in }) -> [RunEvent] {
    var events: [RunEvent] = []
    var time = 0.0
    while !done(run), time < limit {
        events += run.step(step)
        time += step
        onStep(&run, time)
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

/// Plays on until the skater is rolling and the combo has banked.
@discardableResult
private func rollUntilBanked(_ run: inout Run) -> [RunEvent] {
    play(&run) { $0.state == .rolling && $0.comboLinkLeft == nil }
}

private func banked(_ events: [RunEvent]) -> [Int] {
    events.compactMap { if case .banked(let points) = $0 { points } else { nil } }
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
        let events = rollUntilBanked(&run)
        #expect(events.contains(.landed(perfect: false)))
        #expect(banked(events) == [50])
        #expect(run.score == 50)
        #expect(run.speed > Tuning.startSpeed)
    }

    @Test func theOlliePopsTheMomentTheFingerGoesDown() {
        var run = Run(level: street())
        #expect(run.handle(.press) == [.ollie(charged: false)])
        #expect(run.isAirborne)
    }

    @Test func keepingTheFingerDownGoesHigher() {
        func peak(held: TimeInterval) -> CGFloat {
            var run = Run(level: street())
            _ = run.handle(.press)
            var highest: CGFloat = 0
            var released = false
            play(&run) { run in
                highest = max(highest, run.height)
                return run.state == .rolling
            } onStep: { run, time in
                if !released, time >= held { released = true; _ = run.handle(.release(held: held)) }
            }
            return highest
        }
        let tapped = peak(held: 0)
        let half = peak(held: 0.2)
        let full = peak(held: 1)
        #expect(abs(tapped - Tuning.ollieHeight) < 2)
        #expect(half > tapped + 5 && half < full - 5)
        #expect(abs(full - Tuning.chargedOllieHeight) < 2)
    }

    @Test func aQuickUpSwipeChangesLanesInsteadOfOllieing() {
        var run = Run(level: street())
        _ = run.handle(.press)
        _ = run.step(0.05)
        #expect(run.handle(.swipe(.up)) == [.laneSwitch(.back)])
        #expect(run.combo.isEmpty)
        let events = play(&run) { $0.state == .rolling }
        #expect(run.lane == .back)
        #expect(run.score == 0)
        #expect(run.speed == Tuning.startSpeed)
        #expect(banked(events).isEmpty)
    }

    @Test func aLateUpSwipeIsAFlipNotALaneChange() {
        var run = Run(level: street())
        _ = run.handle(.press)
        _ = run.step(0.3)
        #expect(run.handle(.swipe(.up)) == [.trickStarted(Trick.flip(for: .up))])
        #expect(run.lane == .middle)
    }

    @Test func pressingJustBeforeTouchdownPopsAgainOnLanding() {
        var run = Run(level: street())
        _ = tap(&run)
        play(&run) { $0.verticalSpeed < 0 && $0.height < 3 }
        _ = run.handle(.press)
        let events = play(&run) { $0.verticalSpeed > 0 && $0.height > 1 }
        let landed = events.firstIndex(of: .landed(perfect: false))
        let popped = events.firstIndex(of: .ollie(charged: false))
        #expect(landed != nil && popped != nil && landed! < popped!)
        #expect(run.isAirborne)
    }

    @Test func theRunRemembersItsBestCombo() {
        var run = Run(level: street())
        _ = run.handle(.swipe(.left))
        rollUntilBanked(&run)
        let kickflipCombo = run.bestCombo
        #expect(kickflipCombo == (50 + 150) * 2)
        #expect(run.bestComboTricks == "OLLIE + KICKFLIP")
        // A smaller one after doesn't replace it.
        _ = tap(&run)
        rollUntilBanked(&run)
        #expect(run.score == kickflipCombo + 50)
        #expect(run.bestCombo == kickflipCombo)
        #expect(run.bestComboTricks == "OLLIE + KICKFLIP")
    }

    @Test func kickflipLandedCleanScoresTheCombo() {
        var run = Run(level: street())
        _ = tap(&run)
        _ = run.step(0.02)
        #expect(run.handle(.press) + run.handle(.swipe(.left)) == [.trickStarted(.kickflip)])
        let events = play(&run) { $0.state == .rolling }
        #expect((banked(events + rollUntilBanked(&run)).first ?? 0) >= 400)
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
        let rest = rollUntilBanked(&run)
        #expect(rest.contains(.grindEnded))
        // Ollie plus the grind's base and per-second points, times two.
        #expect((banked(rest).first ?? 0) > (50 + 100) * 2)
    }

    @Test func swipingDownOnARailSwitchesToABoardslideAndBack() {
        var run = Run(level: street([.rail(.middle, at: ollieTopX + Tuning.skaterHalfWidth, length: 300)]))
        _ = tap(&run)
        play(&run) { $0.isGrinding }
        #expect(run.handle(.swipe(.down)) == [.grindSwitched(.boardslide)])
        #expect(run.state == .grinding(feature: 0, trick: .boardslide))
        #expect(run.handle(.swipe(.down)) == [.grindSwitched(.fiftyFifty)])
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

    @Test func swipingSidewaysOnTheGroundKickflips() {
        var run = Run(level: street())
        #expect(run.handle(.press) + run.handle(.swipe(.left)) == [.ollie(charged: false), .trickStarted(.kickflip)])
        let events = rollUntilBanked(&run)
        #expect(banked(events) == [(50 + 150) * 2])

        var other = Run(level: street())
        #expect(other.handle(.swipe(.right)) == [.ollie(charged: false), .trickStarted(.heelflip)])
    }

    // MARK: Clearing things

    @Test func ollieingOverAConeEarnsItsPoints() {
        let cone = Feature.cone(.middle, at: 20)
        var run = Run(level: street([cone]))
        _ = tap(&run)
        let events = rollUntilBanked(&run)
        #expect(events.contains(.cleared(.cone, style: 1, points: Int(cone.clearPoints))))
        #expect(run.score == 50 + Int(cone.clearPoints))
    }

    @Test func biggerAndMovingThingsAndHarderTricksAreWorthMore() {
        let cone = Feature.cone(.middle, at: 0)
        let planter = Feature.planter(.middle, at: 0)
        let walker = Feature.pedestrian(.middle, at: 0)
        let car = Feature.car(.middle, at: 0)
        let parkedCar = Feature.brokenCar(.middle, at: 0)
        #expect(planter.clearPoints > cone.clearPoints)
        #expect(walker.clearPoints > planter.clearPoints)
        #expect(car.clearPoints > parkedCar.clearPoints * 1.5)
        #expect(Trick.grab.clearStyle > Trick.ollie.clearStyle)
        #expect(Trick.kickflip.clearStyle > Trick.grab.clearStyle)
        #expect(Trick.threeSixtyFlip.clearStyle > Trick.kickflip.clearStyle)
        // Low curbs and tracks aren't worth anything; manholes are, a little.
        #expect(Feature.curb(.middle, at: 0, length: 50).clearPoints == 0)
        #expect(Feature.hole(.middle, at: 0).clearPoints > 0)
        #expect(Feature.hole(.middle, at: 0).clearPoints < cone.clearPoints)
    }

    @Test func aFlipOverSomethingDoublesItsPoints() {
        let cone = Feature.cone(.middle, at: 20)
        var run = Run(level: street([cone]))
        let events = run.handle(.swipe(.left)) + play(&run) { $0.state != .airborne }
        #expect(events.contains(.cleared(.cone, style: 2, points: Int(cone.clearPoints * 2))))
    }

    @Test func bailingLosesTheClearPoints() {
        // Clear a cone, then come down on a planter.
        var run = Run(level: street([.cone(.middle, at: 14), .planter(.middle, at: 44, length: 40)]))
        _ = tap(&run)
        let events = play(&run) { if case .bailed = $0.state { true } else { false } }
        #expect(events.contains { if case .cleared = $0 { true } else { false } })
        #expect(run.score == 0)
    }

    // MARK: Combo meter

    @Test func anotherTrickSoonAfterLandingKeepsTheComboGoing() {
        var run = Run(level: street())
        _ = run.handle(.swipe(.left))
        play(&run) { $0.state == .rolling }
        #expect(run.comboLinkLeft != nil)
        _ = run.step(0.3)
        // An ollie on its own doesn't add to the combo; the kickflip does.
        _ = run.handle(.swipe(.left))
        let events = rollUntilBanked(&run)
        #expect(banked(events) == [(50 + 150 + 150) * 3])
    }

    @Test func theComboBanksWhenTheMeterRunsOut() {
        var run = Run(level: street())
        _ = run.handle(.swipe(.left))
        play(&run) { $0.state == .rolling }
        let waiting = play(&run, for: Tuning.comboLinkTime - 0.1) { _ in false }
        #expect(banked(waiting).isEmpty)
        let after = play(&run, for: 0.2) { _ in false }
        #expect(banked(after) == [400])
    }

    @Test func bailingWhileTheMeterRunsLosesTheCombo() {
        var run = Run(level: street([.cone(.middle, at: 120)]))
        _ = run.handle(.swipe(.left))
        play(&run) { $0.state == .rolling }
        let events = play(&run) { if case .bailed = $0.state { true } else { false } }
        #expect(events.contains(.bail(.crashed)))
        #expect(run.score == 0)
    }

    // MARK: Gaps and quarter pipes

    @Test func clearingBothConesInOneJumpIsTheGap() {
        let gap = Gap(name: "TEST GAP", points: 300, kind: .over(.middle, from: 15, to: 23))
        var level = street([.cone(.middle, at: 15), .cone(.middle, at: 23)])
        level.gaps = [gap]
        var run = Run(level: level)
        _ = tap(&run)
        let events = rollUntilBanked(&run)
        #expect(events.contains(.gap("TEST GAP", points: 300)))
        #expect(banked(events).first ?? 0 > 300)
    }

    @Test func grindingFromOneRailOntoTheNextIsTheGap() {
        let first = ollieTopX + Tuning.skaterHalfWidth
        let second = first + 60 + 10
        var level = street([.rail(.middle, at: first, length: 60), .rail(.middle, at: second, length: 60)])
        level.gaps = [Gap(name: "RAIL GAP", points: 500, kind: .transfer(.middle, from: first, to: second))]
        var run = Run(level: level)
        _ = tap(&run)
        let events = rollUntilBanked(&run)
        #expect(events.contains(.gap("RAIL GAP", points: 500)))
    }

    @Test func aQuarterPipeLaunchesYouHigh() {
        var run = Run(level: street([.quarterPipe(.middle, at: 20)]))
        var highest: CGFloat = 0
        let events = play(&run) { highest = max(highest, $0.height); return $0.isAirborne == false && $0.x > 100 }
        #expect(events.contains(.launched))
        #expect(abs(highest - Tuning.quarterPipeAir) < 2)
        #expect(!events.contains { isBail($0) })
    }

    // MARK: Spots

    @Test func pickingUpALetter() {
        let high = LetterPickup(index: 0, letter: "P", lane: .middle, x: ollieTopX, height: 26)
        let low = LetterPickup(index: 1, letter: "O", lane: .middle, x: 300, height: 4)
        var run = Run(level: street(letters: [high, low]))
        // Rolling under a high letter misses it...
        var events = play(&run) { $0.x > ollieTopX + 20 }
        #expect(!events.contains(.letter(index: 0, letter: "P")))
        // ...rolling through a low one gets it, and its points.
        events = play(&run) { $0.x > 320 }
        #expect(events.contains(.letter(index: 1, letter: "O")))
        #expect(run.score == Tuning.letterPoints)

        // An ollie reaches the high one.
        var jumper = Run(level: street(letters: [high]))
        _ = tap(&jumper)
        events = play(&jumper) { $0.state == .rolling }
        #expect(events.contains(.letter(index: 0, letter: "P")))
        #expect(jumper.lettersFound == [0])
    }

    @Test func rollingIntoAHoleIsAFallButOllieingClearsIt() {
        var run = Run(level: street([.hole(.middle, at: 60)]))
        var events = play(&run) { if case .bailed = $0.state { true } else { false } }
        #expect(events.contains(.bail(.fell)))
        // Doesn't get up until past the hole.
        play(&run) { $0.state == .rolling }
        #expect(run.x > 60 + 28 - 3)

        var jumper = Run(level: street([.hole(.middle, at: 20, length: 28)]))
        _ = tap(&jumper)
        events = play(&jumper, for: 3) { $0.x > 200 }
        #expect(!events.contains { if case .bail = $0 { true } else { false } })
    }

    @Test func movingThingsWaitUntilTheyAreOnScreen() {
        var run = Run(level: street([.pedestrian(.back, at: 1000)]))
        play(&run, for: 20) { $0.x > 1000 - Tuning.movingStartDistance - 20 }
        #expect(run.x > 1000 - Tuning.movingStartDistance - 20)
        #expect(run.position(ofFeature: 0) == 1000)
        play(&run, for: 1) { _ in false }
        #expect(run.position(ofFeature: 0) < 1000)
    }

    @Test func aPedestrianWalkingIntoYourLaneIsABail() {
        var run = Run(level: street([.pedestrian(.middle, at: 400)]))
        let events = play(&run, for: 8) { if case .bailed = $0.state { true } else { false } }
        #expect(events.contains(.bail(.crashed)))
        // They walked toward you, so you met them before x = 400.
        #expect(run.x < 400)
    }

    @Test func afterABailASwipeTakesYouToAnotherLaneAndUp() {
        // A runner going your way: crash into it and you'd be stuck under it.
        var run = Run(level: street([.runner(.middle, at: 150)]))
        play(&run, for: 10) { if case .bailed = $0.state { true } else { false } }
        #expect(run.handle(.swipe(.up)) == [.laneSwitch(.back)])
        #expect(run.state == .rolling)
        #expect(run.lane == .back)
        #expect(run.speed == Tuning.speedAfterBail)
    }

    @Test func aSwipeWhileStillTumblingThroughTheAirDoesNothing() {
        var run = Run(level: street([.planter(.middle, at: ollieTopX, length: 60)]))
        _ = tap(&run)
        play(&run) { if case .bailed = $0.state { $0.height > 0 } else { false } }
        #expect(run.handle(.swipe(.up)) == [])
        #expect(run.lane == .middle)
    }

    @Test func curbsAndTracksDontStopYouButCanBeGround() {
        var run = Run(level: street([.curb(.middle, at: 30, length: 100), .tracks(.front, at: 200, length: 100)]))
        let events = play(&run, for: 3) { $0.x > 150 }
        #expect(!events.contains { if case .bail = $0 { true } else { false } })

        var grinder = Run(level: street([.curb(.middle, at: ollieTopX, length: 200)]))
        _ = tap(&grinder)
        let grind = play(&grinder) { $0.isGrinding }
        #expect(grind.contains(.grindStarted(.fiftyFifty)))
    }

    @Test func downhillKeepsSpeedingUpToItsLimit() {
        var run = Run(level: street(acceleration: 10, maxSpeed: 150))
        play(&run, for: 3) { _ in false }
        #expect(run.speed > Tuning.startSpeed + 25)
        play(&run, for: 10) { _ in false }
        #expect(run.speed == 150)
    }

    @Test func portlandHasEveryLetterOnceAndTidyLevels() {
        let city = City.portland
        let indices = city.levels.flatMap { $0.letters.map(\.index) }.sorted()
        #expect(indices == Array(0..<city.letters.count))
        for level in city.levels {
            #expect(level.features.allSatisfy { $0.end < level.length }, "\(level.name)")
            #expect(zip(level.features, level.features.dropFirst()).allSatisfy { $0.x <= $1.x }, "\(level.name)")
            for pickup in level.letters {
                #expect(city.letters[pickup.index] == pickup.letter, "\(level.name)")
                #expect(pickup.x < level.length)
            }
        }
        #expect(Set(city.levels.map(\.id)).count == city.levels.count)
    }

    @Test func onlyPortlandIsOpen() {
        #expect(City.all.count == 9)
        #expect(City.all.filter(\.isOpen) == [City.portland])
        #expect(City.portland.letters == Array("PORTLAND"))
        #expect(City.all[1].letters == Array("SANFRANCISCO"))
    }
}

@MainActor
struct CharacterTests {
    @Test func outfitsSavedBeforeTheRenameStillLoad() throws {
        let saved = #"{"kind":"sam","shirt":"red","pants":"khaki","board":"brown"}"#
        let outfit = try JSONDecoder().decode(Outfit.self, from: Data(saved.utf8))
        #expect(outfit.kind == .sammy)
        #expect(SkaterKind.pat.name == "PAT" && SkaterKind.sammy.name == "SAMMY")
    }

    @Test func angieStartsInARedBandanaWithNoHatOnAWhiteBoard() {
        var outfit = Outfit.standard
        outfit.switchSkater(to: .angie)
        #expect(outfit.kind == .angie && outfit.shirt == .red && outfit.hat == nil && outfit.board == .white)
        outfit.switchSkater(to: .sammy)
        #expect(outfit.kind == .sammy)
    }

    @Test func outfitsCycleAndWrap() {
        #expect(Outfit.cycle(SkaterKind.angie, in: SkaterKind.allCases, step: 1) == .pat)
        #expect(Outfit.cycle(SkaterKind.pat, in: SkaterKind.allCases, step: -1) == .angie)
        #expect(Outfit.cycle(ColorChoice?.some(.brown), in: Outfit.hatChoices, step: 1) == nil)
        #expect(Outfit.cycle(ColorChoice?.none, in: Outfit.hatChoices, step: 1) == .black)
    }

    @Test func progressSavesOutfitLettersAndBests() throws {
        let defaults = try #require(UserDefaults(suiteName: "skateTests.\(UUID().uuidString)"))
        let progress = Progress(defaults: defaults)
        #expect(progress.outfit == .standard)
        var outfit = Outfit.standard
        outfit.kind = .angie
        outfit.hat = nil
        progress.outfit = outfit
        #expect(Progress(defaults: defaults).outfit == outfit)

        #expect(progress.collect(letter: 3, in: .portland))
        #expect(!progress.collect(letter: 3, in: .portland))
        #expect(progress.letters(in: .portland) == [3])

        #expect(progress.record(score: 500, at: .downtown))
        #expect(!progress.record(score: 400, at: .downtown))
        #expect(progress.bestScore(at: .downtown) == 500)
    }

    @Test func longCityNamesShrinkOnlyAsMuchAsTheyNeedTo() {
        // Short names get double size.
        #expect(PixelFont.fittingScale(width: 50, into: 160, maxScale: 2, screenPixelsPerPixel: 12) == 2)
        // A long one gets the biggest size that fits, in whole screen pixels.
        let scale = PixelFont.fittingScale(width: 100, into: 160, maxScale: 2, screenPixelsPerPixel: 12)
        #expect(scale == 19.0 / 12)
        #expect(CGFloat(100) * scale <= 160)
        #expect(CGFloat(100) * (scale + 1.0 / 12) > 160)
    }

    @Test func artIsRectangular() {
        for template in CharacterArt.allTemplates + PeopleArt.allTemplates {
            #expect(Set(template.map(\.count)) == [18])
        }
        for kind in SkaterKind.allCases {
            for hat in [ColorChoice.yellow, nil] {
                let poses = CharacterArt.poses(for: Outfit(kind: kind, hat: hat))
                for sprite in [poses.roll, poses.crouch, poses.air, poses.grab, poses.bail] {
                    #expect(sprite.width == 18)
                }
            }
        }
        let board = CharacterArt.board(for: .standard)
        for sprite in [board.side, board.wheelsUp, board.underside, board.grip] {
            #expect(sprite.rows.allSatisfy { $0.count == 20 })
        }
        for glyph in PixelFont.allGlyphs {
            #expect(glyph.count == PixelFont.glyphHeight)
            #expect(Set(glyph.map(\.count)).count == 1)
        }
    }
}

@MainActor
struct GoalTests {
    @Test func goalsAreMetAsTheyHappen() {
        let goals = [
            Goal(id: "flip", text: "FLIP A CONE", kind: .clear(.cone, style: 2)),
            Goal(id: "ollie", text: "OLLIE A CONE", kind: .clear(.cone)),
            Goal(id: "land", text: "LAND KICKFLIP", kind: .land(.kickflip)),
            Goal(id: "score", text: "SCORE 100", kind: .score(100)),
            Goal(id: "clean", text: "NO BAILS", kind: .noBails),
        ]
        var tracker = GoalTracker(goals: goals)
        var run = Run(level: street([.cone(.middle, at: 20)], length: 600))
        var met: [String] = []
        let step = 1.0 / 120
        func advance(_ events: [RunEvent]) { met += tracker.update(run: run, events: events, dt: step).map(\.id) }
        advance(run.handle(.swipe(.left)))
        while !run.isFinished { advance(run.step(step)) }
        #expect(Set(met) == ["flip", "ollie", "land", "score", "clean"])
    }

    @Test func lettersFoundOnEarlierRunsCountForTheLettersGoal() {
        let goals = [Goal(id: "letters", text: "FIND 2 LETTERS", kind: .letters)]
        let run = Run(level: .downtown)
        // Downtown has P and O. Only P found before: not yet.
        var some = GoalTracker(goals: goals, lettersFoundBefore: [0])
        #expect(some.update(run: run, events: [], dt: 0).isEmpty)
        // Both found, on different runs: done, without finding them again.
        var both = GoalTracker(goals: goals, lettersFoundBefore: [0, 1])
        #expect(both.update(run: run, events: [], dt: 0).map(\.id) == ["letters"])
    }

    @Test func oldSavesGetTheLettersGoalForLettersFoundSeparately() throws {
        let defaults = try #require(UserDefaults(suiteName: "skate.tests.\(UUID())"))
        let progress = Progress(defaults: defaults)
        progress.collect(letter: 0, in: .portland)
        progress.collect(letter: 1, in: .portland)
        progress.completeEarnedLetterGoals(in: .portland)
        #expect(progress.goalsDone(at: .downtown).contains("downtown.letters"))
        #expect(!progress.goalsDone(at: .skidmoreFountain).contains("skidmore.letters"))
    }

    @Test func goalsDoneBeforeArentAnnouncedAgain() {
        let goals = [Goal(id: "score", text: "SCORE 1", kind: .score(1))]
        var tracker = GoalTracker(goals: goals, alreadyMet: ["score"])
        var run = Run(level: street())
        _ = run.handle(.press)
        let events = rollUntilBanked(&run)
        #expect(tracker.update(run: run, events: events, dt: 0).isEmpty)
    }

    @Test func aLongEnoughGrindMeetsTheGrindGoal() {
        let goals = [Goal(id: "grind", text: "GRIND 1S", kind: .grind(.rail, seconds: 1))]
        var tracker = GoalTracker(goals: goals)
        var run = Run(level: street([.rail(.middle, at: ollieTopX + Tuning.skaterHalfWidth, length: 200)]))
        var met: [String] = []
        let step = 1.0 / 120
        _ = run.handle(.press)
        _ = run.handle(.release(held: 0))
        for _ in 0..<(4 * 120) { met += tracker.update(run: run, events: run.step(step), dt: step).map(\.id) }
        #expect(met == ["grind"])
    }

    @Test func everyPortlandSpotHasFiveGoalsThatFitAndAGap() {
        for level in City.portland.levels {
            #expect(level.goals.count == 5, "\(level.name)")
            #expect(!level.gaps.isEmpty, "\(level.name)")
            #expect(Set(level.goals.map(\.id)).count == level.goals.count)
            for goal in level.goals {
                // Half the narrowest screen, so the results can show goals beside the score.
                #expect(PixelFont.width(of: goal.text) <= 86, "\(goal.text)")
                if case .gap(let name) = goal.kind {
                    #expect(level.gaps.contains { $0.name == name }, "\(name)")
                }
            }
            for goal in level.goals {
                // A grind goal needs a feature long enough to grind that long at top speed,
                // landing right at its start, with a fifth of a second to spare.
                if case .grind(let style, let seconds) = goal.kind {
                    let longest = level.features.filter { $0.style == style }.map(\.length).max() ?? 0
                    let time = (longest + 2 * Tuning.skaterHalfWidth) / level.maxSpeed
                    #expect(Double(time) >= seconds + 0.2, "\(goal.text): at most \(time) s")
                }
            }
            for gap in level.gaps {
                let parts = gap.features(in: level)
                #expect(!parts.isEmpty, "\(gap.name)")
                // The hint goes beside the gap's name on the goals screen, on the narrowest screen.
                #expect(!gap.hint.isEmpty, "\(gap.name)")
                #expect(PixelFont.width(of: gap.name) + 6 + PixelFont.width(of: gap.hint) <= 160, "\(gap.name): \(gap.hint)")
                if case .transfer = gap.kind {
                    #expect(parts.count == 2 && parts.allSatisfy { level.features[$0].isGrindable }, "\(gap.name)")
                }
            }
        }
    }
}

@MainActor
struct RewardTests {
    @Test func spellingPortlandUnlocksThePDXBoard() throws {
        #expect(!ColorChoice.clothes.contains(.pdx))
        #expect(!ColorChoice.boards(pdxUnlocked: false).contains(.pdx))
        #expect(ColorChoice.boards(pdxUnlocked: true).contains(.pdx))

        let defaults = try #require(UserDefaults(suiteName: "skateTests.\(UUID().uuidString)"))
        let progress = Progress(defaults: defaults)
        for index in 0..<7 { progress.collect(letter: index, in: .portland) }
        #expect(!progress.hasPDXBoard)
        progress.collect(letter: 7, in: .portland)
        #expect(progress.hasPDXBoard)
    }

    @Test func goalsAreSaved() throws {
        let defaults = try #require(UserDefaults(suiteName: "skateTests.\(UUID().uuidString)"))
        let progress = Progress(defaults: defaults)
        let goal = Level.downtown.goals[0]
        #expect(progress.complete(goal: goal, at: .downtown))
        #expect(!progress.complete(goal: goal, at: .downtown))
        #expect(progress.goalsDone(at: .downtown) == [goal.id])
    }

    @Test func the360FlipIsTheHardestButNotTooHard() {
        #expect(Trick.threeSixtyFlip.airTime > Trick.shoveIt.airTime)
        #expect(Trick.threeSixtyFlip.airTime < 0.5)
    }
}

@MainActor
struct FoodCartTests {
    @Test func everyFoodCartSignFitsAndHasItsLetters() {
        for sign in ThemeArt.foodCartSigns {
            #expect(SignFont.width(of: sign) <= 24, "\(sign)")
            #expect(sign.allSatisfy { SignFont.allGlyphs[$0] != nil }, "\(sign)")
        }
    }
}

@MainActor
struct TutorialTests {
    @Test func stepsGoOneAtATime() {
        var tutorial = Tutorial()
        var run = Run(level: Level.tutorial)
        var done: [String] = []
        func feed(_ events: [RunEvent]) { if let step = tutorial.update(run: run, events: events) { done.append(step.text) } }
        // An ollie, landed.
        feed(run.handle(.press))
        feed(run.handle(.release(held: 0)))
        while run.isAirborne { feed(run.step(1.0 / 120)) }
        #expect(done == ["TAP TO OLLIE"])
        // A lane change doesn't count yet: the next step is the high ollie.
        feed(run.handle(.swipe(.down)))
        #expect(done.count == 1)
        // Hold for a high one.
        feed(run.handle(.press))
        for _ in 0..<120 { feed(run.step(1.0 / 120)) }
        #expect(done.last == "HOLD TO OLLIE HIGHER")
        #expect(tutorial.index == 2)
    }

    @Test func thePracticeStreetIsTidy() {
        let level = Level.tutorial
        #expect(zip(level.features, level.features.dropFirst()).allSatisfy { $0.x <= $1.x })
        #expect(level.features.allSatisfy { $0.end < level.length && $0.lane != .middle })
        #expect(Tutorial.steps.allSatisfy { PixelFont.width(of: "\(Tutorial.steps.count)/\(Tutorial.steps.count) " + $0.text) <= 200 })
    }
}

@MainActor
struct StoreTests {
    @Test func onlyTipsAreForSaleUntilTheOtherCitiesAreReady() {
        #expect(!Store.fullGameOnSale)
        #expect(Store.productIDs == Store.tipIDs)
        #expect(Store.tipIDs == ["skate.tip.small", "skate.tip.medium", "skate.tip.large"])
        #expect(City.all.filter { !$0.isOpen }.count == 8)
    }

    @Test func pricesAndLocksDrawInThePixelFont() {
        for text in ["$0.99", "$2.99", "$4.99", "COMING SOON FOR $4.99", "DON'T UNLOCK ANYTHING.", "YOU'RE READY!"] {
            #expect(text.allSatisfy { $0 == "?" || PixelFont.glyph($0) != PixelFont.glyph("?") }, "\(text)")
        }
    }
}

@MainActor
struct GapFairnessTests {
    /// How many spots along the street a held ollie can pop from and still get the gap,
    /// rolling at `speed`. Each spot is a game pixel, so 10 is about a tenth of a second.
    private func window(for gap: Gap, in level: Level, speed: CGFloat) -> Int {
        let parts = gap.features(in: level).map { level.features[$0] }
        let first = parts.map(\.x).min()!
        // The gap's features moved along to x = 1300, on an otherwise empty street.
        let shift = 1300 - first
        var wins = 0
        for pressX in stride(from: 1100, through: 1300, by: 1) {
            var test = street(parts.map { var f = $0; f.x += shift; return f }, acceleration: 400, maxSpeed: speed)
            guard case .over(let lane, let from, let to) = gap.kind else { return 0 }
            test.gaps = [Gap(name: gap.name, points: gap.points, kind: .over(lane, from: from + shift, to: to + shift))]
            test.startLane = lane
            var run = Run(level: test)
            play(&run, for: 30) { $0.x >= CGFloat(pressX) }
            var events = run.handle(.press)
            events += play(&run) { $0.verticalSpeed <= 0 }
            events += run.handle(.release(held: 0.5))
            events += play(&run) { $0.state == .rolling || $0.x > 1600 }
            events += play(&run, for: 2) { _ in false }
            if events.contains(.gap(gap.name, points: gap.points)) { wins += 1 }
        }
        return wins
    }

    /// Nothing moving is in the way of a gap when you get to it, at any speed you could
    /// be going. Moving things start when you're `movingStartDistance` away; this rolls
    /// at a steady speed from there and checks the whole gap, with the skater's width.
    @Test func nothingMovingBlocksAGap() {
        for level in City.portland.levels {
            for gap in level.gaps {
                let parts = gap.features(in: level).map { level.features[$0] }
                guard let lane = parts.first?.lane else { continue }
                let from = parts.map(\.x).min()! - 40, to = parts.map(\.end).max()! + 10
                for mover in level.features where mover.isMoving && mover.lane == lane {
                    for speed in stride(from: Tuning.speedAfterBail, through: level.maxSpeed, by: 5) {
                        for x in stride(from: from, through: to, by: 1) where x >= mover.x - Tuning.movingStartDistance {
                            let moved = mover.velocity * (x - (mover.x - Tuning.movingStartDistance)) / speed
                            let start = mover.x + moved
                            let inTheWay = x + Tuning.skaterHalfWidth > start && x - Tuning.skaterHalfWidth < start + mover.length
                            #expect(!inTheWay, "\(gap.name): \(mover.style) at speed \(speed), x \(x)")
                            if inTheWay { break }
                        }
                    }
                }
            }
        }
    }

    /// Every jump-over gap in Portland can be done with a held ollie, without needing
    /// to have built up much speed first, and with a fair bit of room for timing.
    @Test func everyJumpGapCanBeClearedWithAHeldOllie() {
        for level in City.portland.levels {
            for gap in level.gaps {
                guard case .over = gap.kind else { continue }
                #expect(window(for: gap, in: level, speed: Tuning.startSpeed) >= 8, "\(gap.name) at start speed")
                #expect(window(for: gap, in: level, speed: 100) >= 15, "\(gap.name) at 100")
            }
        }
    }
}
