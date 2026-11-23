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

    static func rail(_ lane: Lane, at x: CGFloat, length: CGFloat, height: CGFloat = 12) -> Feature {
        Feature(kind: .rail, lane: lane, x: x, length: length, height: height)
    }

    static func ledge(_ lane: Lane, at x: CGFloat, length: CGFloat, height: CGFloat = 9) -> Feature {
        Feature(kind: .ledge, lane: lane, x: x, length: length, height: height)
    }

    static func cone(_ lane: Lane, at x: CGFloat) -> Feature {
        Feature(kind: .block, lane: lane, x: x, length: 7, height: 10)
    }

    static func planter(_ lane: Lane, at x: CGFloat, length: CGFloat = 20, height: CGFloat = 15) -> Feature {
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
    static let feelStreet = Level(name: "GREY BOX STREET", length: 3700, features: [
        // Warm up: single cones to ollie over.
        .cone(.middle, at: 300),
        .cone(.front, at: 440),
        // First rail, in the back lane where rails live.
        .rail(.back, at: 560, length: 96),
        .ledge(.middle, at: 760, length: 64),
        .cone(.front, at: 900), .cone(.front, at: 960),
        .rail(.middle, at: 1080, length: 128),
        .cone(.back, at: 1120),
        .ledge(.back, at: 1320, length: 96),
        .cone(.front, at: 1340),
        // A pair of cones close together: needs a charged ollie, or a lane switch.
        .cone(.middle, at: 1520), .cone(.middle, at: 1556),
        .rail(.front, at: 1680, length: 160),
        // Two short rails with a gap: transfer from one to the other.
        .rail(.back, at: 1920, length: 64), .rail(.back, at: 2030, length: 64),
        .planter(.middle, at: 2200),
        .ledge(.middle, at: 2360, length: 128),
        .cone(.back, at: 2380), .cone(.front, at: 2410),
        .rail(.back, at: 2620, length: 192),
        .cone(.front, at: 2840), .cone(.front, at: 2900), .cone(.front, at: 2960),
        .rail(.middle, at: 3060, length: 96),
        .ledge(.middle, at: 3220, length: 96),
        // Cones across every lane: no way round, ollie it.
        .cone(.back, at: 3440), .cone(.middle, at: 3460), .cone(.front, at: 3480),
    ])
}
