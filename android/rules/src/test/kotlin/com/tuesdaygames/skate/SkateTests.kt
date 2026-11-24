//
//  SkateTests.kt
//
//  The rules' tests, ported from skateTests/skateTests.swift: the same suites,
//  the same tests, the same numbers. Tests of the drawing and sound are in the
//  app module (app/src/test).
//

package com.tuesdaygames.skate

import com.tuesdaygames.skate.rules.*
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.sqrt
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

private const val step = 1.0 / 120

/** An empty street, or one with just the features (and letters) given. */
fun street(
    features: List<Feature> = emptyList(),
    letters: List<LetterPickup> = emptyList(),
    length: Double = 5000.0,
    acceleration: Double = 0.0,
    maxSpeed: Double = Tuning.maxSpeed,
) = Level(
    id = "test", name = "TEST", theme = Theme.Downtown, length = length, features = features, letters = letters,
    startX = 0.0, startLane = Lane.Middle, acceleration = acceleration, maxSpeed = maxSpeed,
)

/** Steps the run until `done` is true, collecting what happened. Gives up after `limit` seconds. */
fun play(
    run: Run,
    limit: Double = 5.0,
    onStep: (Run, Double) -> Unit = { _, _ -> },
    done: (Run) -> Boolean,
): List<RunEvent> {
    val events = mutableListOf<RunEvent>()
    var time = 0.0
    while (!done(run) && time < limit) {
        events += run.step(step)
        time += step
        onStep(run, time)
    }
    return events
}

/** Where a tapped ollie from x = 0 reaches its peak, so tests can put things just past it. */
val ollieTopX: Double
    get() {
        val liftOff = sqrt(2 * Tuning.gravity * Tuning.ollieHeight)
        return (Tuning.startSpeed * liftOff / Tuning.gravity).rounded()
    }

fun tap(run: Run): List<RunEvent> = run.handle(GestureEvent.Press) + run.handle(GestureEvent.Release(0.05))

/** Plays on until the skater is rolling and the combo has banked. */
fun rollUntilBanked(run: Run) = play(run) { it.state == SkaterState.Rolling && it.comboLinkLeft == null }

fun banked(events: List<RunEvent>): List<Int> = events.filterIsInstance<RunEvent.Banked>().map { it.points }

fun isBail(event: RunEvent) = event is RunEvent.Bail

val Run.isBailedNow: Boolean get() = state is SkaterState.Bailed

fun swipe(direction: SwipeDirection) = GestureEvent.Swipe(direction)

class GestureTests {
    @Test fun quickTapIsPressThenRelease() {
        val reader = GestureReader()
        assertEquals(listOf(GestureEvent.Press), reader.began(Point(0.0, 0.0), 0.0))
        assertEquals(emptyList(), reader.tick(0.05))
        assertEquals(listOf(GestureEvent.Release(0.08)), reader.ended(Point(3.0, 2.0), 0.08))
    }

    @Test fun holdingStillSendsHoldOnce() {
        val reader = GestureReader()
        reader.began(Point(0.0, 0.0), 0.0)
        assertEquals(listOf(GestureEvent.Hold), reader.tick(0.2))
        assertEquals(emptyList(), reader.tick(0.3))
        assertEquals(listOf(GestureEvent.Release(0.4)), reader.ended(Point(0.0, 0.0), 0.4))
    }

    @Test fun swipesFireOnceAndUseScreenDirections() {
        val reader = GestureReader()
        reader.began(Point(100.0, 100.0), 0.0)
        assertEquals(emptyList(), reader.moved(Point(100.0, 90.0), 0.02))
        // The screen's y grows downward, so moving the finger up the screen is a swipe up.
        assertEquals(listOf(swipe(SwipeDirection.Up)), reader.moved(Point(102.0, 60.0), 0.04))
        assertEquals(emptyList(), reader.moved(Point(102.0, 20.0), 0.06))
        assertEquals(emptyList(), reader.ended(Point(102.0, 20.0), 0.08))

        reader.began(Point(100.0, 100.0), 1.0)
        assertEquals(listOf(swipe(SwipeDirection.Left)), reader.moved(Point(60.0, 110.0), 1.03))
    }

    @Test fun pixelLayoutUsesWholePixels() {
        // An iPhone on its side: 874 x 402 points at 3x.
        val phone = PixelLayout(Size(874.0, 402.0), 3.0)
        assertEquals(12, phone.scale)
        assertEquals(Size(218.0, 100.0), phone.gameSize)
        assertEquals(phone.gameSize.width * 12, phone.frame.width * 3)

        // An iPad is squarer, so it shows more sky rather than less street.
        val pad = PixelLayout(Size(1376.0, 1032.0), 2.0)
        assertTrue(pad.gameSize.width >= PixelLayout.minimumSize.width)
        assertTrue(pad.gameSize.height > PixelLayout.minimumSize.height)

        // An Android phone on its side, measured in screen pixels.
        val android = PixelLayout(Size(2400.0, 1080.0), 1.0)
        assertEquals(11, android.scale)
        assertEquals(Size(218.0, 98.0), android.gameSize)
    }
}

class ComboTests {
    @Test fun multiplierCountsTricks() {
        val combo = Combo()
        combo.add(Trick.Ollie)
        combo.add(Trick.Kickflip)
        assertEquals(2, combo.multiplier)
        assertEquals((50 + 150) * 2, combo.total)
        assertEquals("OLLIE + KICKFLIP", combo.text())
    }

    @Test fun longCombosShowTheLatestTricks() {
        val combo = Combo()
        listOf(Trick.Ollie, Trick.Kickflip, Trick.FiftyFifty, Trick.Heelflip).forEach(combo::add)
        assertEquals("... + KICKFLIP + 50-50 + HEELFLIP", combo.text())
    }
}

class RunTests {
    @Test fun tapOllieLandsCleanAndBanks() {
        val run = Run(street())
        assertEquals(listOf<RunEvent>(RunEvent.Ollie(charged = false)), tap(run))
        assertTrue(run.isAirborne)
        val events = rollUntilBanked(run)
        assertTrue(RunEvent.Landed(perfect = false) in events)
        assertEquals(listOf(50), banked(events))
        assertEquals(50, run.score)
        assertTrue(run.speed > Tuning.startSpeed)
    }

    @Test fun theOlliePopsTheMomentTheFingerGoesDown() {
        val run = Run(street())
        assertEquals(listOf<RunEvent>(RunEvent.Ollie(charged = false)), run.handle(GestureEvent.Press))
        assertTrue(run.isAirborne)
    }

    @Test fun keepingTheFingerDownGoesHigher() {
        fun peak(held: Double): Double {
            val run = Run(street())
            run.handle(GestureEvent.Press)
            var highest = 0.0
            var released = false
            play(run, onStep = { r, time ->
                if (!released && time >= held) {
                    released = true
                    r.handle(GestureEvent.Release(held))
                }
            }) { r ->
                highest = max(highest, r.height)
                r.state == SkaterState.Rolling
            }
            return highest
        }
        val tapped = peak(0.0)
        val half = peak(0.2)
        val full = peak(1.0)
        assertTrue(abs(tapped - Tuning.ollieHeight) < 2)
        assertTrue(half > tapped + 5 && half < full - 5)
        assertTrue(abs(full - Tuning.chargedOllieHeight) < 2)
    }

    @Test fun aQuickUpSwipeChangesLanesInsteadOfOllieing() {
        val run = Run(street())
        run.handle(GestureEvent.Press)
        run.step(0.05)
        assertEquals(listOf<RunEvent>(RunEvent.LaneSwitch(Lane.Back)), run.handle(swipe(SwipeDirection.Up)))
        assertTrue(run.combo.isEmpty)
        val events = play(run) { it.state == SkaterState.Rolling }
        assertEquals(Lane.Back, run.lane)
        assertEquals(0, run.score)
        assertEquals(Tuning.startSpeed, run.speed)
        assertTrue(banked(events).isEmpty())
    }

    @Test fun aLateUpSwipeIsAFlipNotALaneChange() {
        val run = Run(street())
        run.handle(GestureEvent.Press)
        run.step(0.3)
        assertEquals(listOf<RunEvent>(RunEvent.TrickStarted(Trick.flip(SwipeDirection.Up))), run.handle(swipe(SwipeDirection.Up)))
        assertEquals(Lane.Middle, run.lane)
    }

    @Test fun pressingJustBeforeTouchdownPopsAgainOnLanding() {
        val run = Run(street())
        tap(run)
        play(run) { it.verticalSpeed < 0 && it.height < 3 }
        run.handle(GestureEvent.Press)
        val events = play(run) { it.verticalSpeed > 0 && it.height > 1 }
        val landed = events.indexOf(RunEvent.Landed(perfect = false))
        val popped = events.indexOf(RunEvent.Ollie(charged = false))
        assertTrue(landed >= 0 && popped >= 0 && landed < popped)
        assertTrue(run.isAirborne)
    }

    @Test fun theRunRemembersItsBestCombo() {
        val run = Run(street())
        run.handle(swipe(SwipeDirection.Left))
        rollUntilBanked(run)
        val kickflipCombo = run.bestCombo
        assertEquals((50 + 150) * 2, kickflipCombo)
        assertEquals("OLLIE + KICKFLIP", run.bestComboTricks)
        // A smaller one after doesn't replace it.
        tap(run)
        rollUntilBanked(run)
        assertEquals(kickflipCombo + 50, run.score)
        assertEquals(kickflipCombo, run.bestCombo)
        assertEquals("OLLIE + KICKFLIP", run.bestComboTricks)
    }

    @Test fun kickflipLandedCleanScoresTheCombo() {
        val run = Run(street())
        tap(run)
        run.step(0.02)
        assertEquals(
            listOf<RunEvent>(RunEvent.TrickStarted(Trick.Kickflip)),
            run.handle(GestureEvent.Press) + run.handle(swipe(SwipeDirection.Left)),
        )
        val events = play(run) { it.state == SkaterState.Rolling }
        assertTrue((banked(events + rollUntilBanked(run)).firstOrNull() ?: 0) >= 400)
    }

    @Test fun flippingTooLateIsABail() {
        val run = Run(street())
        tap(run)
        // Wait until just before touchdown, then flip.
        play(run) { it.verticalSpeed < 0 && it.height < 3 }
        run.handle(GestureEvent.Press)
        run.handle(swipe(SwipeDirection.Up))
        val events = play(run) { it.state != SkaterState.Airborne }
        assertTrue(RunEvent.Bail(BailReason.MidTrick) in events)
        assertEquals(0, run.score)
        assertTrue(run.combo.isEmpty)
    }

    @Test fun holdingAGrabThroughLandingIsABail() {
        val run = Run(street())
        tap(run)
        run.handle(GestureEvent.Press)
        run.handle(GestureEvent.Hold)
        assertTrue(run.isHoldingGrab)
        val events = play(run) { it.state != SkaterState.Airborne }
        assertTrue(RunEvent.Bail(BailReason.HoldingGrab) in events)
    }

    @Test fun rollingIntoAConeIsABail() {
        val run = Run(street(listOf(Feature.cone(Lane.Middle, 60.0))))
        val events = play(run) { it.isBailedNow }
        assertTrue(RunEvent.Bail(BailReason.Crashed) in events)
        // Gets back up past the cone.
        play(run) { it.state == SkaterState.Rolling }
        assertEquals(SkaterState.Rolling, run.state)
        assertTrue(run.x > 60 + 7)
    }

    @Test fun conesInOtherLanesDontMatter() {
        val run = Run(street(listOf(Feature.cone(Lane.Front, 60.0), Feature.cone(Lane.Back, 80.0))))
        val events = play(run, limit = 2.0) { it.x > 200 }
        assertFalse(events.any(::isBail))
    }

    @Test fun switchingLanesStopsAtTheEdges() {
        val run = Run(street())
        assertEquals(listOf<RunEvent>(RunEvent.LaneSwitch(Lane.Front)), run.handle(swipe(SwipeDirection.Down)))
        assertEquals(emptyList(), run.handle(swipe(SwipeDirection.Down)))
        assertEquals(Lane.Front, run.lane)
        run.handle(swipe(SwipeDirection.Up))
        run.handle(swipe(SwipeDirection.Up))
        assertEquals(Lane.Back, run.lane)
        play(run, limit = 1.0) { it.drawnLane == 0.0 }
        assertEquals(0.0, run.drawnLane)
    }

    @Test fun landingOnARailGrindsAndRunningOffTheEndBanks() {
        // A rail that starts just past the top of the ollie, so the board comes down on it.
        val run = Run(street(listOf(Feature.rail(Lane.Middle, ollieTopX + Tuning.skaterHalfWidth, length = 100.0))))
        tap(run)
        val toRail = play(run) { it.isGrinding }
        assertTrue(RunEvent.GrindStarted(Trick.FiftyFifty) in toRail)
        val rest = rollUntilBanked(run)
        assertTrue(RunEvent.GrindEnded in rest)
        // Ollie plus the grind's base and per-second points, times two.
        assertTrue((banked(rest).firstOrNull() ?: 0) > (50 + 100) * 2)
    }

    @Test fun swipingDownOnARailSwitchesToABoardslideAndBack() {
        val run = Run(street(listOf(Feature.rail(Lane.Middle, ollieTopX + Tuning.skaterHalfWidth, length = 300.0))))
        tap(run)
        play(run) { it.isGrinding }
        assertEquals(listOf<RunEvent>(RunEvent.GrindSwitched(Trick.Boardslide)), run.handle(swipe(SwipeDirection.Down)))
        assertEquals(SkaterState.Grinding(0, Trick.Boardslide), run.state)
        assertEquals(listOf<RunEvent>(RunEvent.GrindSwitched(Trick.FiftyFifty)), run.handle(swipe(SwipeDirection.Down)))
    }

    @Test fun tappingOnARailPopsOffAndKeepsTheCombo() {
        val run = Run(street(listOf(Feature.rail(Lane.Middle, ollieTopX + Tuning.skaterHalfWidth, length = 300.0))))
        tap(run)
        play(run) { it.isGrinding }
        // Hopping off ends the grind, so the rumble and grind sound stop.
        assertEquals(listOf(RunEvent.GrindEnded, RunEvent.PopOff), tap(run))
        assertTrue(run.isAirborne)
        assertEquals(2, run.combo.multiplier)
    }

    @Test fun comingDownOnAPlanterIsABail() {
        // Low enough to clear on the way up, right where the ollie comes down.
        val run = Run(street(listOf(Feature.planter(Lane.Middle, ollieTopX, length = 60.0, height = Tuning.ollieHeight - 6))))
        tap(run)
        val events = play(run) { it.state != SkaterState.Airborne }
        assertTrue(RunEvent.Bail(BailReason.LandedOnBlock) in events)
    }

    @Test fun crossingTheFinishEndsTheRun() {
        val run = Run(street(length = 100.0))
        val events = play(run) { it.isFinished }
        assertTrue(RunEvent.Finished(score = 0) in events)
        assertEquals(emptyList(), run.step(step))
        assertEquals(emptyList(), tap(run))
    }

    @Test fun swipingSidewaysOnTheGroundKickflips() {
        val run = Run(street())
        assertEquals(
            listOf(RunEvent.Ollie(charged = false), RunEvent.TrickStarted(Trick.Kickflip)),
            run.handle(GestureEvent.Press) + run.handle(swipe(SwipeDirection.Left)),
        )
        val events = rollUntilBanked(run)
        assertEquals(listOf((50 + 150) * 2), banked(events))

        val other = Run(street())
        assertEquals(
            listOf(RunEvent.Ollie(charged = false), RunEvent.TrickStarted(Trick.Heelflip)),
            other.handle(swipe(SwipeDirection.Right)),
        )
    }

    // Clearing things

    @Test fun ollieingOverAConeEarnsItsPoints() {
        val cone = Feature.cone(Lane.Middle, 20.0)
        val run = Run(street(listOf(cone)))
        tap(run)
        val events = rollUntilBanked(run)
        assertTrue(RunEvent.Cleared(FeatureStyle.Cone, 1.0, cone.clearPoints.toInt()) in events)
        assertEquals(50 + cone.clearPoints.toInt(), run.score)
    }

    @Test fun biggerAndMovingThingsAndHarderTricksAreWorthMore() {
        val cone = Feature.cone(Lane.Middle, 0.0)
        val planter = Feature.planter(Lane.Middle, 0.0)
        val walker = Feature.pedestrian(Lane.Middle, 0.0)
        val car = Feature.car(Lane.Middle, 0.0)
        val parkedCar = Feature.brokenCar(Lane.Middle, 0.0)
        assertTrue(planter.clearPoints > cone.clearPoints)
        assertTrue(walker.clearPoints > planter.clearPoints)
        assertTrue(car.clearPoints > parkedCar.clearPoints * 1.5)
        assertTrue(Trick.Grab.clearStyle > Trick.Ollie.clearStyle)
        assertTrue(Trick.Kickflip.clearStyle > Trick.Grab.clearStyle)
        assertTrue(Trick.ThreeSixtyFlip.clearStyle > Trick.Kickflip.clearStyle)
        // Low curbs and tracks aren't worth anything; manholes are, a little.
        assertEquals(0.0, Feature.curb(Lane.Middle, 0.0, length = 50.0).clearPoints)
        assertTrue(Feature.hole(Lane.Middle, 0.0).clearPoints > 0)
        assertTrue(Feature.hole(Lane.Middle, 0.0).clearPoints < cone.clearPoints)
    }

    @Test fun aFlipOverSomethingDoublesItsPoints() {
        val cone = Feature.cone(Lane.Middle, 20.0)
        val run = Run(street(listOf(cone)))
        val events = run.handle(swipe(SwipeDirection.Left)) + play(run) { it.state != SkaterState.Airborne }
        assertTrue(RunEvent.Cleared(FeatureStyle.Cone, 2.0, (cone.clearPoints * 2).toInt()) in events)
    }

    @Test fun bailingLosesTheClearPoints() {
        // Clear a cone, then come down on a planter.
        val run = Run(street(listOf(Feature.cone(Lane.Middle, 14.0), Feature.planter(Lane.Middle, 44.0, length = 40.0))))
        tap(run)
        val events = play(run) { it.isBailedNow }
        assertTrue(events.any { it is RunEvent.Cleared })
        assertEquals(0, run.score)
    }

    // Combo meter

    @Test fun anotherTrickSoonAfterLandingKeepsTheComboGoing() {
        val run = Run(street())
        run.handle(swipe(SwipeDirection.Left))
        play(run) { it.state == SkaterState.Rolling }
        assertNotNull(run.comboLinkLeft)
        run.step(0.3)
        // An ollie on its own doesn't add to the combo; the kickflip does.
        run.handle(swipe(SwipeDirection.Left))
        val events = rollUntilBanked(run)
        assertEquals(listOf((50 + 150 + 150) * 3), banked(events))
    }

    @Test fun theComboBanksWhenTheMeterRunsOut() {
        val run = Run(street())
        run.handle(swipe(SwipeDirection.Left))
        play(run) { it.state == SkaterState.Rolling }
        val waiting = play(run, limit = Tuning.comboLinkTime - 0.1) { false }
        assertTrue(banked(waiting).isEmpty())
        val after = play(run, limit = 0.2) { false }
        assertEquals(listOf(400), banked(after))
    }

    @Test fun bailingWhileTheMeterRunsLosesTheCombo() {
        val run = Run(street(listOf(Feature.cone(Lane.Middle, 120.0))))
        run.handle(swipe(SwipeDirection.Left))
        play(run) { it.state == SkaterState.Rolling }
        val events = play(run) { it.isBailedNow }
        assertTrue(RunEvent.Bail(BailReason.Crashed) in events)
        assertEquals(0, run.score)
    }

    // Gaps and quarter pipes

    @Test fun clearingBothConesInOneJumpIsTheGap() {
        val gap = Gap("TEST GAP", 300, Gap.Kind.Over(Lane.Middle, 15.0, 23.0))
        val level = street(listOf(Feature.cone(Lane.Middle, 15.0), Feature.cone(Lane.Middle, 23.0))).copy(gaps = listOf(gap))
        val run = Run(level)
        tap(run)
        val events = rollUntilBanked(run)
        assertTrue(RunEvent.GapDone("TEST GAP", 300) in events)
        assertTrue((banked(events).firstOrNull() ?: 0) > 300)
    }

    @Test fun grindingFromOneRailOntoTheNextIsTheGap() {
        val first = ollieTopX + Tuning.skaterHalfWidth
        val second = first + 60 + 10
        val level = street(listOf(Feature.rail(Lane.Middle, first, length = 60.0), Feature.rail(Lane.Middle, second, length = 60.0)))
            .copy(gaps = listOf(Gap("RAIL GAP", 500, Gap.Kind.Transfer(Lane.Middle, first, second))))
        val run = Run(level)
        tap(run)
        val events = rollUntilBanked(run)
        assertTrue(RunEvent.GapDone("RAIL GAP", 500) in events)
    }

    @Test fun aQuarterPipeLaunchesYouHigh() {
        val run = Run(street(listOf(Feature.quarterPipe(Lane.Middle, 20.0))))
        var highest = 0.0
        val events = play(run) {
            highest = max(highest, it.height)
            !it.isAirborne && it.x > 100
        }
        assertTrue(RunEvent.Launched in events)
        assertTrue(abs(highest - Tuning.quarterPipeAir) < 2)
        assertFalse(events.any(::isBail))
    }

    // Spots

    @Test fun pickingUpALetter() {
        val high = LetterPickup(0, 'P', Lane.Middle, ollieTopX, 26.0)
        val low = LetterPickup(1, 'O', Lane.Middle, 300.0, 4.0)
        val run = Run(street(letters = listOf(high, low)))
        // Rolling under a high letter misses it...
        var events = play(run) { it.x > ollieTopX + 20 }
        assertFalse(RunEvent.Letter(0, 'P') in events)
        // ...rolling through a low one gets it, and its points.
        events = play(run) { it.x > 320 }
        assertTrue(RunEvent.Letter(1, 'O') in events)
        assertEquals(Tuning.letterPoints, run.score)

        // An ollie reaches the high one.
        val jumper = Run(street(letters = listOf(high)))
        tap(jumper)
        events = play(jumper) { it.state == SkaterState.Rolling }
        assertTrue(RunEvent.Letter(0, 'P') in events)
        assertEquals(setOf(0), jumper.lettersFound)
    }

    @Test fun rollingIntoAHoleIsAFallButOllieingClearsIt() {
        val run = Run(street(listOf(Feature.hole(Lane.Middle, 60.0))))
        var events = play(run) { it.isBailedNow }
        assertTrue(RunEvent.Bail(BailReason.Fell) in events)
        // Doesn't get up until past the hole.
        play(run) { it.state == SkaterState.Rolling }
        assertTrue(run.x > 60 + 28 - 3)

        val jumper = Run(street(listOf(Feature.hole(Lane.Middle, 20.0, length = 28.0))))
        tap(jumper)
        events = play(jumper, limit = 3.0) { it.x > 200 }
        assertFalse(events.any(::isBail))
    }

    @Test fun movingThingsWaitUntilTheyAreOnScreen() {
        val run = Run(street(listOf(Feature.pedestrian(Lane.Back, 1000.0))))
        play(run, limit = 20.0) { it.x > 1000 - Tuning.movingStartDistance - 20 }
        assertTrue(run.x > 1000 - Tuning.movingStartDistance - 20)
        assertEquals(1000.0, run.position(0))
        play(run, limit = 1.0) { false }
        assertTrue(run.position(0) < 1000)
    }

    @Test fun aPedestrianWalkingIntoYourLaneIsABail() {
        val run = Run(street(listOf(Feature.pedestrian(Lane.Middle, 400.0))))
        val events = play(run, limit = 8.0) { it.isBailedNow }
        assertTrue(RunEvent.Bail(BailReason.Crashed) in events)
        // They walked toward you, so you met them before x = 400.
        assertTrue(run.x < 400)
    }

    @Test fun afterABailASwipeTakesYouToAnotherLaneAndUp() {
        // A runner going your way: crash into it and you'd be stuck under it.
        val run = Run(street(listOf(Feature.runner(Lane.Middle, 150.0))))
        play(run, limit = 10.0) { it.isBailedNow }
        assertEquals(listOf<RunEvent>(RunEvent.LaneSwitch(Lane.Back)), run.handle(swipe(SwipeDirection.Up)))
        assertEquals(SkaterState.Rolling, run.state)
        assertEquals(Lane.Back, run.lane)
        assertEquals(Tuning.speedAfterBail, run.speed)
    }

    @Test fun aSwipeWhileStillTumblingThroughTheAirDoesNothing() {
        val run = Run(street(listOf(Feature.planter(Lane.Middle, ollieTopX, length = 60.0))))
        tap(run)
        play(run) { it.isBailedNow && it.height > 0 }
        assertEquals(emptyList(), run.handle(swipe(SwipeDirection.Up)))
        assertEquals(Lane.Middle, run.lane)
    }

    @Test fun curbsAndTracksDontStopYouButCanBeGround() {
        val run = Run(street(listOf(Feature.curb(Lane.Middle, 30.0, length = 100.0), Feature.tracks(Lane.Front, 200.0, length = 100.0))))
        val events = play(run, limit = 3.0) { it.x > 150 }
        assertFalse(events.any(::isBail))

        val grinder = Run(street(listOf(Feature.curb(Lane.Middle, ollieTopX, length = 200.0))))
        tap(grinder)
        val grind = play(grinder) { it.isGrinding }
        assertTrue(RunEvent.GrindStarted(Trick.FiftyFifty) in grind)
    }

    @Test fun downhillKeepsSpeedingUpToItsLimit() {
        val run = Run(street(acceleration = 10.0, maxSpeed = 150.0))
        play(run, limit = 3.0) { false }
        assertTrue(run.speed > Tuning.startSpeed + 25)
        play(run, limit = 10.0) { false }
        assertEquals(150.0, run.speed)
    }

    @Test fun portlandHasEveryLetterOnceAndTidyLevels() {
        val city = City.portland
        val indices = city.levels.flatMap { level -> level.letters.map { it.index } }.sorted()
        assertEquals((0 until city.letters.size).toList(), indices)
        for (level in city.levels) {
            assertTrue(level.features.all { it.end < level.length }, level.name)
            assertTrue(level.features.zipWithNext().all { (a, b) -> a.x <= b.x }, level.name)
            for (pickup in level.letters) {
                assertEquals(city.letters[pickup.index], pickup.letter, level.name)
                assertTrue(pickup.x < level.length)
            }
        }
        assertEquals(city.levels.size, city.levels.map { it.id }.toSet().size)
    }

    @Test fun onlyPortlandIsOpen() {
        assertEquals(9, City.all.size)
        assertEquals(listOf(City.portland), City.all.filter { it.isOpen })
        assertEquals("PORTLAND".toList(), City.portland.letters)
        assertEquals("SANFRANCISCO".toList(), City.all[1].letters)
    }
}

class CharacterTests {
    @Test fun outfitsSavedBeforeTheRenameStillLoad() {
        val saved = """{"kind":"sam","shirt":"red","pants":"khaki","board":"brown"}"""
        val outfit = Progress.decodeOutfit(saved)
        assertEquals(SkaterKind.Sammy, outfit?.kind)
        assertNull(outfit?.hat)
        assertTrue(SkaterKind.Pat.displayName == "PAT" && SkaterKind.Sammy.displayName == "SAMMY")
    }

    @Test fun angieStartsInARedBandanaWithNoHatOnAWhiteBoard() {
        var outfit = Outfit.standard.switchingSkater(SkaterKind.Angie)
        assertTrue(
            outfit.kind == SkaterKind.Angie && outfit.shirt == ColorChoice.Red && outfit.hat == null &&
                outfit.board == ColorChoice.White,
        )
        outfit = outfit.switchingSkater(SkaterKind.Sammy)
        assertEquals(SkaterKind.Sammy, outfit.kind)
    }

    @Test fun outfitsCycleAndWrap() {
        assertEquals(SkaterKind.Pat, Outfit.cycle(SkaterKind.Angie, SkaterKind.entries, 1))
        assertEquals(SkaterKind.Angie, Outfit.cycle(SkaterKind.Pat, SkaterKind.entries, -1))
        assertNull(Outfit.cycle(ColorChoice.Brown, Outfit.hatChoices, 1))
        assertEquals(ColorChoice.Black, Outfit.cycle(null, Outfit.hatChoices, 1))
    }

    @Test fun progressSavesOutfitLettersAndBests() {
        val store = MemoryStore()
        val progress = Progress(store)
        assertEquals(Outfit.standard, progress.outfit)
        val outfit = Outfit.standard.copy(kind = SkaterKind.Angie, hat = null)
        progress.outfit = outfit
        assertEquals(outfit, Progress(store).outfit)
        // A yellow hat (the default) is saved too, not mistaken for no hat.
        progress.outfit = Outfit.standard
        assertEquals(Outfit.standard, Progress(store).outfit)

        assertTrue(progress.collect(3, City.portland))
        assertFalse(progress.collect(3, City.portland))
        assertEquals(setOf(3), progress.letters(City.portland))

        assertTrue(progress.record(500, Level.downtown))
        assertFalse(progress.record(400, Level.downtown))
        assertEquals(500, progress.bestScore(Level.downtown))
    }

    @Test fun longCityNamesShrinkOnlyAsMuchAsTheyNeedTo() {
        // Short names get double size.
        assertEquals(2.0, PixelFont.fittingScale(50, 160.0, 2.0, 12))
        // A long one gets the biggest size that fits, in whole screen pixels.
        val scale = PixelFont.fittingScale(100, 160.0, 2.0, 12)
        assertEquals(19.0 / 12, scale)
        assertTrue(100 * scale <= 160)
        assertTrue(100 * (scale + 1.0 / 12) > 160)
    }

    @Test fun glyphsAreRectangular() {
        for (glyph in PixelFont.allGlyphs) {
            assertEquals(PixelFont.glyphHeight, glyph.size)
            assertEquals(1, glyph.map { it.length }.toSet().size)
        }
    }
}

class GoalTests {
    @Test fun goalsAreMetAsTheyHappen() {
        val goals = listOf(
            Goal("flip", "FLIP A CONE", Goal.Kind.Clear(FeatureStyle.Cone, trickStyle = 2.0)),
            Goal("ollie", "OLLIE A CONE", Goal.Kind.Clear(FeatureStyle.Cone)),
            Goal("land", "LAND KICKFLIP", Goal.Kind.Land(Trick.Kickflip)),
            Goal("score", "SCORE 100", Goal.Kind.Score(100)),
            Goal("clean", "NO BAILS", Goal.Kind.NoBails),
        )
        val tracker = GoalTracker(goals)
        val run = Run(street(listOf(Feature.cone(Lane.Middle, 20.0)), length = 600.0))
        val met = mutableListOf<String>()
        fun advance(events: List<RunEvent>) {
            met += tracker.update(run, events, step).map { it.id }
        }
        advance(run.handle(swipe(SwipeDirection.Left)))
        while (!run.isFinished) advance(run.step(step))
        assertEquals(setOf("flip", "ollie", "land", "score", "clean"), met.toSet())
    }

    @Test fun lettersFoundOnEarlierRunsCountForTheLettersGoal() {
        val goals = listOf(Goal("letters", "FIND 2 LETTERS", Goal.Kind.Letters))
        val run = Run(Level.downtown)
        // Downtown has P and O. Only P found before: not yet.
        val some = GoalTracker(goals, lettersFoundBefore = setOf(0))
        assertTrue(some.update(run, emptyList(), 0.0).isEmpty())
        // Both found, on different runs: done, without finding them again.
        val both = GoalTracker(goals, lettersFoundBefore = setOf(0, 1))
        assertEquals(listOf("letters"), both.update(run, emptyList(), 0.0).map { it.id })
    }

    @Test fun oldSavesGetTheLettersGoalForLettersFoundSeparately() {
        val progress = Progress(MemoryStore())
        progress.collect(0, City.portland)
        progress.collect(1, City.portland)
        progress.completeEarnedLetterGoals(City.portland)
        assertTrue("downtown.letters" in progress.goalsDone(Level.downtown))
        assertFalse("skidmore.letters" in progress.goalsDone(Level.skidmoreFountain))
    }

    @Test fun goalsDoneBeforeArentAnnouncedAgain() {
        val goals = listOf(Goal("score", "SCORE 1", Goal.Kind.Score(1)))
        val tracker = GoalTracker(goals, alreadyMet = setOf("score"))
        val run = Run(street())
        run.handle(GestureEvent.Press)
        val events = rollUntilBanked(run)
        assertTrue(tracker.update(run, events, 0.0).isEmpty())
    }

    @Test fun aLongEnoughGrindMeetsTheGrindGoal() {
        val goals = listOf(Goal("grind", "GRIND 1S", Goal.Kind.Grind(FeatureStyle.Rail, seconds = 1.0)))
        val tracker = GoalTracker(goals)
        val run = Run(street(listOf(Feature.rail(Lane.Middle, ollieTopX + Tuning.skaterHalfWidth, length = 200.0))))
        val met = mutableListOf<String>()
        run.handle(GestureEvent.Press)
        run.handle(GestureEvent.Release(0.0))
        repeat(4 * 120) { met += tracker.update(run, run.step(step), step).map { it.id } }
        assertEquals(listOf("grind"), met)
    }

    @Test fun everyPortlandSpotHasFiveGoalsThatFitAndAGap() {
        for (level in City.portland.levels) {
            assertEquals(5, level.goals.size, level.name)
            assertTrue(level.gaps.isNotEmpty(), level.name)
            assertEquals(level.goals.size, level.goals.map { it.id }.toSet().size)
            for (goal in level.goals) {
                // Half the narrowest screen, so the results can show goals beside the score.
                assertTrue(PixelFont.width(goal.text) <= 86, goal.text)
                val kind = goal.kind
                if (kind is Goal.Kind.GapNamed) assertTrue(level.gaps.any { it.name == kind.name }, kind.name)
            }
            for (goal in level.goals) {
                // A grind goal needs a feature long enough to grind that long at top speed,
                // landing right at its start, with a fifth of a second to spare.
                val kind = goal.kind
                if (kind is Goal.Kind.Grind) {
                    val longest = level.features.filter { it.style == kind.style }.maxOfOrNull { it.length } ?: 0.0
                    val time = (longest + 2 * Tuning.skaterHalfWidth) / level.maxSpeed
                    assertTrue(time >= kind.seconds + 0.2, "${goal.text}: at most $time s")
                }
            }
            for (gap in level.gaps) {
                val parts = gap.features(level)
                assertTrue(parts.isNotEmpty(), gap.name)
                // The hint goes beside the gap's name on the goals screen, on the narrowest screen.
                assertTrue(gap.hint.isNotEmpty(), gap.name)
                assertTrue(PixelFont.width(gap.name) + 6 + PixelFont.width(gap.hint) <= 160, "${gap.name}: ${gap.hint}")
                if (gap.kind is Gap.Kind.Transfer) {
                    assertTrue(parts.size == 2 && parts.all { level.features[it].isGrindable }, gap.name)
                }
            }
        }
    }
}

class RewardTests {
    @Test fun spellingPortlandUnlocksThePDXBoard() {
        assertFalse(ColorChoice.Pdx in ColorChoice.clothes)
        assertFalse(ColorChoice.Pdx in ColorChoice.boards(pdxUnlocked = false))
        assertTrue(ColorChoice.Pdx in ColorChoice.boards(pdxUnlocked = true))

        val progress = Progress(MemoryStore())
        for (index in 0 until 7) progress.collect(index, City.portland)
        assertFalse(progress.hasPDXBoard)
        progress.collect(7, City.portland)
        assertTrue(progress.hasPDXBoard)
    }

    @Test fun goalsAreSaved() {
        val progress = Progress(MemoryStore())
        val goal = Level.downtown.goals[0]
        assertTrue(progress.complete(goal, Level.downtown))
        assertFalse(progress.complete(goal, Level.downtown))
        assertEquals(setOf(goal.id), progress.goalsDone(Level.downtown))
    }

    @Test fun the360FlipIsTheHardestButNotTooHard() {
        assertTrue(Trick.ThreeSixtyFlip.airTime > Trick.ShoveIt.airTime)
        assertTrue(Trick.ThreeSixtyFlip.airTime < 0.5)
    }

    @Test fun pricesAndLocksDrawInThePixelFont() {
        for (text in listOf("$0.99", "$2.99", "$4.99", "COMING SOON FOR $4.99", "DON'T UNLOCK ANYTHING.", "YOU'RE READY!")) {
            assertTrue(text.all { it == '?' || PixelFont.glyph(it) != PixelFont.glyph('?') }, text)
        }
    }
}

class TutorialTests {
    @Test fun stepsGoOneAtATime() {
        val tutorial = Tutorial()
        val run = Run(Level.tutorial)
        val done = mutableListOf<String>()
        fun feed(events: List<RunEvent>) {
            tutorial.update(run, events)?.let { done += it.text }
        }
        // An ollie, landed.
        feed(run.handle(GestureEvent.Press))
        feed(run.handle(GestureEvent.Release(0.0)))
        while (run.isAirborne) feed(run.step(step))
        assertEquals(listOf("TAP TO OLLIE"), done)
        // A lane change doesn't count yet: the next step is the high ollie.
        feed(run.handle(swipe(SwipeDirection.Down)))
        assertEquals(1, done.size)
        // Hold for a high one.
        feed(run.handle(GestureEvent.Press))
        repeat(120) { feed(run.step(step)) }
        assertEquals("HOLD TO OLLIE HIGHER", done.last())
        assertEquals(2, tutorial.index)
    }

    @Test fun thePracticeStreetIsTidy() {
        val level = Level.tutorial
        assertTrue(level.features.zipWithNext().all { (a, b) -> a.x <= b.x })
        assertTrue(level.features.all { it.end < level.length && it.lane != Lane.Middle })
        val count = Tutorial.steps.size
        assertTrue(Tutorial.steps.all { PixelFont.width("$count/$count " + it.text) <= 200 })
    }
}

class GapFairnessTests {
    /** How many spots along the street a held ollie can pop from and still get the gap,
     *  rolling at `speed`. Each spot is a game pixel, so 10 is about a tenth of a second. */
    private fun window(gap: Gap, level: Level, speed: Double): Int {
        val parts = gap.features(level).map { level.features[it] }
        val first = parts.minOf { it.x }
        // The gap's features moved along to x = 1300, on an otherwise empty street.
        val shift = 1300 - first
        var wins = 0
        for (pressX in 1100..1300) {
            val kind = gap.kind as? Gap.Kind.Over ?: return 0
            val test = street(parts.map { it.copy(x = it.x + shift) }, acceleration = 400.0, maxSpeed = speed).copy(
                gaps = listOf(Gap(gap.name, gap.points, Gap.Kind.Over(kind.lane, kind.from + shift, kind.to + shift))),
                startLane = kind.lane,
            )
            val run = Run(test)
            play(run, limit = 30.0) { it.x >= pressX }
            val events = run.handle(GestureEvent.Press).toMutableList()
            events += play(run) { it.verticalSpeed <= 0 }
            events += run.handle(GestureEvent.Release(0.5))
            events += play(run) { it.state == SkaterState.Rolling || it.x > 1600 }
            events += play(run, limit = 2.0) { false }
            if (RunEvent.GapDone(gap.name, gap.points) in events) wins += 1
        }
        return wins
    }

    /** Nothing moving is in the way of a gap when you get to it, at any speed you could
     *  be going. Moving things start when you're `movingStartDistance` away; this rolls
     *  at a steady speed from there and checks the whole gap, with the skater's width. */
    @Test fun nothingMovingBlocksAGap() {
        for (level in City.portland.levels) {
            for (gap in level.gaps) {
                val parts = gap.features(level).map { level.features[it] }
                val lane = parts.firstOrNull()?.lane ?: continue
                val from = parts.minOf { it.x } - 40
                val to = parts.maxOf { it.end } + 10
                for (mover in level.features.filter { it.isMoving && it.lane == lane }) {
                    for (speed in strideDoubles(Tuning.speedAfterBail, level.maxSpeed, 5.0, through = true)) {
                        for (x in strideDoubles(from, to, 1.0, through = true)) {
                            if (x < mover.x - Tuning.movingStartDistance) continue
                            val moved = mover.velocity * (x - (mover.x - Tuning.movingStartDistance)) / speed
                            val start = mover.x + moved
                            val inTheWay = x + Tuning.skaterHalfWidth > start && x - Tuning.skaterHalfWidth < start + mover.length
                            assertFalse(inTheWay, "${gap.name}: ${mover.style} at speed $speed, x $x")
                        }
                    }
                }
            }
        }
    }

    /** Every jump-over gap in Portland can be done with a held ollie, without needing
     *  to have built up much speed first, and with a fair bit of room for timing. */
    @Test fun everyJumpGapCanBeClearedWithAHeldOllie() {
        for (level in City.portland.levels) {
            for (gap in level.gaps) {
                if (gap.kind !is Gap.Kind.Over) continue
                assertTrue(window(gap, level, Tuning.startSpeed) >= 8, "${gap.name} at start speed")
                assertTrue(window(gap, level, 100.0) >= 15, "${gap.name} at 100")
            }
        }
    }
}
