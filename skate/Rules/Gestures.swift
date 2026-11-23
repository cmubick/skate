//
//  Gestures.swift
//  skate
//
//  Turns one finger's touches into the game's four inputs: press, hold,
//  release and swipe. Knows nothing about skating.
//

import CoreGraphics
import Foundation

nonisolated enum SwipeDirection: Equatable, Sendable {
    case up, down, left, right
}

nonisolated enum GestureEvent: Equatable, Sendable {
    /// A finger went down. It may turn into a tap, a hold or a swipe.
    case press
    /// The finger has stayed down past the hold threshold without swiping.
    case hold
    /// The finger came up without swiping. `held` is how long it was down.
    case release(held: TimeInterval)
    /// The finger moved far enough to be a swipe. It fires as soon as the finger
    /// has moved far enough, not when it comes up, and nothing else follows for that touch.
    case swipe(SwipeDirection)
}

/// Follows one touch at a time. Points are in UIKit view coordinates (y grows downward)
/// and times in seconds.
nonisolated struct GestureReader {
    private var start: CGPoint?
    private var startTime: TimeInterval = 0
    private var swiped = false
    private var holdSent = false

    var isTouching: Bool { start != nil }

    mutating func began(at point: CGPoint, time: TimeInterval) -> [GestureEvent] {
        start = point
        startTime = time
        swiped = false
        holdSent = false
        return [.press]
    }

    mutating func moved(to point: CGPoint, time: TimeInterval) -> [GestureEvent] {
        guard let start, !swiped else { return [] }
        let dx = point.x - start.x
        let dy = point.y - start.y
        guard (dx * dx + dy * dy).squareRoot() >= Tuning.swipeDistance else { return [] }
        swiped = true
        if abs(dx) > abs(dy) {
            return [.swipe(dx > 0 ? .right : .left)]
        }
        return [.swipe(dy < 0 ? .up : .down)]
    }

    /// Call every frame so a hold is noticed while the finger stays still.
    mutating func tick(time: TimeInterval) -> [GestureEvent] {
        guard start != nil, !swiped, !holdSent, time - startTime >= Tuning.holdThreshold else { return [] }
        holdSent = true
        return [.hold]
    }

    mutating func ended(at point: CGPoint, time: TimeInterval) -> [GestureEvent] {
        guard start != nil else { return [] }
        var events = moved(to: point, time: time)
        if !swiped {
            events += tick(time: time)
            events.append(.release(held: max(0, time - startTime)))
        }
        start = nil
        return events
    }

    /// The system took the touch away (a call came in, say). Treat it as a release.
    mutating func cancelled(time: TimeInterval) -> [GestureEvent] {
        guard start != nil else { return [] }
        let events: [GestureEvent] = swiped ? [] : [.release(held: max(0, time - startTime))]
        start = nil
        return events
    }
}
