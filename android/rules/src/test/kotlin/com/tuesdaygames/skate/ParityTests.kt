//
//  ParityTests.kt
//
//  Checks the port's rules against the iOS game: the same scripted player on
//  every spot must see exactly the same things happen, step for step, as it
//  does on iOS. The iOS numbers are in src/test/resources/parity/runs.txt,
//  written by android/tools/parity/make_fixtures.sh from the Swift code itself.
//

package com.tuesdaygames.skate

import com.tuesdaygames.skate.rules.*
import java.security.MessageDigest
import java.util.Locale
import kotlin.test.Test
import kotlin.test.assertEquals

class ParityTests {
    private fun describe(event: RunEvent): String = when (event) {
        is RunEvent.Ollie -> "ollie ${event.charged}"
        RunEvent.PopOff -> "popOff"
        RunEvent.Launched -> "launched"
        is RunEvent.TrickStarted -> "trickStarted ${event.trick.displayName}"
        is RunEvent.GrindStarted -> "grindStarted ${event.trick.displayName}"
        is RunEvent.GrindSwitched -> "grindSwitched ${event.trick.displayName}"
        RunEvent.GrindEnded -> "grindEnded"
        is RunEvent.Landed -> "landed ${event.perfect}"
        is RunEvent.LandedTrick -> "landedTrick ${event.trick.displayName}"
        is RunEvent.Banked -> "banked ${event.points}"
        is RunEvent.Bail -> "bail ${event.reason.name.replaceFirstChar { it.lowercase() }}"
        is RunEvent.LaneSwitch -> "lane ${event.lane.raw}"
        is RunEvent.Letter -> "letter ${event.index} ${event.letter}"
        is RunEvent.Cleared -> "cleared ${event.style.displayName} ${(event.trickStyle * 10).toInt()} ${event.points}"
        is RunEvent.GapDone -> "gap ${event.name} ${event.points}"
        is RunEvent.Finished -> "finished ${event.score}"
    }

    /** The same scripted player as tools/parity/main.swift. */
    private fun scriptedRun(level: Level): String {
        val run = Run(level)
        val directions = listOf(SwipeDirection.Left, SwipeDirection.Right, SwipeDirection.Up, SwipeDirection.Down)
        val trace = mutableListOf<String>()
        var t = 0
        var presses = 0
        var pressedAt = -1
        var holdFor = 0
        var swipeAt = -1
        var direction = SwipeDirection.Left
        fun note(events: List<RunEvent>) {
            trace += events.map { "$t:" + describe(it) }
        }
        while (!run.isFinished && t < 120 * 90) {
            if (t % 54 == 0) {
                note(run.handle(GestureEvent.Press))
                pressedAt = t
                presses += 1
                holdFor = if (presses % 3 == 0) 30 else 9
                if (presses % 4 == 0) {
                    swipeAt = t + 5
                    direction = directions[(presses / 4) % 4]
                } else {
                    swipeAt = -1
                }
            }
            if (t == swipeAt) {
                note(run.handle(GestureEvent.Swipe(direction)))
                pressedAt = -1
            }
            if (pressedAt >= 0 && holdFor > 15 && t == pressedAt + 15) note(run.handle(GestureEvent.Hold))
            if (pressedAt >= 0 && t == pressedAt + holdFor) {
                note(run.handle(GestureEvent.Release(holdFor.toDouble() / 120)))
                pressedAt = -1
            }
            note(run.step(1.0 / 120))
            t += 1
        }
        val x = String.format(Locale.ROOT, "%.6f", run.x)
        val digest = MessageDigest.getInstance("SHA-256").digest(trace.joinToString("\n").toByteArray())
        val hash = digest.joinToString("") { "%02x".format(it) }
        return "${run.score}\t${run.bestCombo}\t$x\t${trace.size}\t$hash"
    }

    @Test fun everySpotPlaysOutExactlyAsOnIOS() {
        val expected = javaClass.getResource("/parity/runs.txt")!!.readText().lines().filter { it.isNotBlank() }
        val levels = City.portland.levels + Level.tutorial
        assertEquals(levels.size, expected.size)
        for ((level, line) in levels.zip(expected)) {
            assertEquals(line, "run.${level.id}\t" + scriptedRun(level), level.name)
        }
    }
}
