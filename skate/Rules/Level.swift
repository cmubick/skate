//
//  Level.swift
//  skate
//
//  A run is one hand-built street: things to ollie over and things to grind,
//  each in one of three lanes, and a finish line.
//

import CoreGraphics

/// The three lanes, back to front. The back lane is highest on screen.
nonisolated enum Lane: Int, CaseIterable, Comparable, Sendable {
    case back = 0, middle = 1, front = 2

    /// The lane one step toward the back (up on screen), if there is one.
    var up: Lane? { Lane(rawValue: rawValue - 1) }
    /// The lane one step toward the front (down on screen), if there is one.
    var down: Lane? { Lane(rawValue: rawValue + 1) }

    static func < (a: Lane, b: Lane) -> Bool { a.rawValue < b.rawValue }
}

nonisolated struct Feature: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// A thin rail on posts. Grindable.
        case rail
        /// A solid ledge or bench. Grindable.
        case ledge
        /// A cone, planter or anything else to ollie over. Landing on it is a bail.
        case block
    }

    var kind: Kind
    var lane: Lane
    /// Where it starts along the street.
    var x: CGFloat
    var length: CGFloat
    var height: CGFloat

    var end: CGFloat { x + length }
    var isGrindable: Bool { kind != .block }

    static func rail(_ lane: Lane, at x: CGFloat, length: CGFloat, height: CGFloat = 14) -> Feature {
        Feature(kind: .rail, lane: lane, x: x, length: length, height: height)
    }

    static func ledge(_ lane: Lane, at x: CGFloat, length: CGFloat, height: CGFloat = 10) -> Feature {
        Feature(kind: .ledge, lane: lane, x: x, length: length, height: height)
    }

    static func cone(_ lane: Lane, at x: CGFloat) -> Feature {
        Feature(kind: .block, lane: lane, x: x, length: 9, height: 12)
    }

    static func planter(_ lane: Lane, at x: CGFloat, length: CGFloat = 24, height: CGFloat = 16) -> Feature {
        Feature(kind: .block, lane: lane, x: x, length: length, height: height)
    }
}

nonisolated struct Level: Equatable, Sendable {
    var name: String
    /// Where the finish line is.
    var length: CGFloat
    var features: [Feature]
    var startX: CGFloat = 40
    var startLane: Lane = .middle

    /// The grey-box street for the feel prototype (milestone 1): a bit of everything,
    /// about 30 seconds long.
    static let feelStreet = Level(name: "GREY BOX STREET", length: 2960, features: [
        // Warm up: single cones to ollie over.
        .cone(.middle, at: 240),
        .cone(.front, at: 352),
        // First rail, in the back lane where rails live.
        .rail(.back, at: 448, length: 80),
        .ledge(.middle, at: 608, length: 56),
        .cone(.front, at: 720), .cone(.front, at: 768),
        .rail(.middle, at: 864, length: 104),
        .cone(.back, at: 896),
        .ledge(.back, at: 1056, length: 80),
        .cone(.front, at: 1072),
        // A pair of cones close together: needs a charged ollie, or a lane switch.
        .cone(.middle, at: 1216), .cone(.middle, at: 1245),
        .rail(.front, at: 1344, length: 128),
        // Two short rails with a gap: transfer from one to the other.
        .rail(.back, at: 1536, length: 56), .rail(.back, at: 1624, length: 56),
        .planter(.middle, at: 1760),
        .ledge(.middle, at: 1888, length: 104),
        .cone(.back, at: 1904), .cone(.front, at: 1928),
        .rail(.back, at: 2096, length: 160),
        .cone(.front, at: 2272), .cone(.front, at: 2320), .cone(.front, at: 2368),
        .rail(.middle, at: 2448, length: 80),
        .ledge(.middle, at: 2576, length: 80),
        // Cones across every lane: no way round, ollie it.
        .cone(.back, at: 2752), .cone(.middle, at: 2768), .cone(.front, at: 2784),
    ])
}
