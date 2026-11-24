//
//  Level.swift
//  skate
//
//  A run is one hand-built spot: things to ollie over, things to grind and
//  holes to clear, each in one of three lanes, the city's letters to find, and
//  a finish line.
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

/// How a feature looks. Each spot has its own.
nonisolated enum FeatureStyle: Hashable, Sendable {
    // Things to grind.
    case rail, handrail, ledge, bench, curb, fountain, tracks, funbox, barrier
    // Things in the way.
    case cone, planter, pedestrian, runner, biker, skater, dog, cart, brokenCar, car, train, penguin, goat
    // Open manholes.
    case hole
    // Quarter pipes: roll up one and fly off the lip.
    case quarterPipe

    /// What it's called when you clear it.
    var name: String {
        switch self {
        case .rail: "RAIL"
        case .handrail: "HANDRAIL"
        case .ledge: "LEDGE"
        case .bench: "BENCH"
        case .curb: "CURB"
        case .fountain: "FOUNTAIN"
        case .tracks: "TRACKS"
        case .funbox: "FUNBOX"
        case .barrier: "BARRIER"
        case .cone: "CONE"
        case .planter: "PLANTER"
        case .pedestrian: "WALKER"
        case .runner: "RUNNER"
        case .biker: "BIKE"
        case .skater: "SKATER"
        case .dog: "ANGIE"
        case .cart: "CART"
        case .brokenCar, .car: "CAR"
        case .train: "TRAIN"
        case .penguin: "PENGUIN"
        case .goat: "GOAT"
        case .hole: "MANHOLE"
        case .quarterPipe: "QUARTER PIPE"
        }
    }
}

nonisolated struct Feature: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// A thin rail on posts. Grindable.
        case rail
        /// A solid ledge, bench or curb. Grindable.
        case ledge
        /// Anything to ollie over or go around. Landing on it is a bail.
        case block
        /// A gap in the ground. Rolling into it is a bail; ollie over it.
        case hole
        /// A ramp you roll up and launch off.
        case ramp
    }

    var kind: Kind
    var style: FeatureStyle
    var lane: Lane
    /// Where it starts along the street. Moving things start here once they come on screen.
    var x: CGFloat
    var length: CGFloat
    var height: CGFloat
    /// Pixels per second, once it's on screen. Negative comes toward you; positive goes
    /// the same way you do, only slower.
    var velocity: CGFloat = 0

    var end: CGFloat { x + length }
    var isGrindable: Bool { kind == .rail || kind == .ledge }
    var isMoving: Bool { velocity != 0 }
    /// Low things, like curbs and train tracks, don't stop you rolling; you can only grind them.
    var isLow: Bool { height <= Tuning.lowFeatureHeight }

    /// Points for getting all the way over it in the air: more for bigger things, and
    /// more again for things on the move. Low curbs and tracks aren't worth anything.
    /// The trick you're doing on the way over multiplies this (see `Trick.clearStyle`).
    var clearPoints: Double {
        guard kind != .ramp, kind == .hole || !isLow else { return 0 }
        let size = Tuning.clearBase + Double(height) * Tuning.clearPerHeight + Double(length) * Tuning.clearPerLength
        let moving = isMoving ? Tuning.clearMovingBase + Double(abs(velocity)) / Tuning.clearMovingSpeedPerStep : 1
        return ((size * moving) / 5).rounded() * 5
    }

    // MARK: Things to grind

    static func rail(_ lane: Lane, at x: CGFloat, length: CGFloat, height: CGFloat = 14) -> Feature {
        Feature(kind: .rail, style: .rail, lane: lane, x: x, length: length, height: height)
    }

    static func handrail(_ lane: Lane, at x: CGFloat, length: CGFloat) -> Feature {
        Feature(kind: .rail, style: .handrail, lane: lane, x: x, length: length, height: 14)
    }

    static func ledge(_ lane: Lane, at x: CGFloat, length: CGFloat, height: CGFloat = 10) -> Feature {
        Feature(kind: .ledge, style: .ledge, lane: lane, x: x, length: length, height: height)
    }

    static func bench(_ lane: Lane, at x: CGFloat, length: CGFloat = 36) -> Feature {
        Feature(kind: .ledge, style: .bench, lane: lane, x: x, length: length, height: 9)
    }

    static func curb(_ lane: Lane, at x: CGFloat, length: CGFloat) -> Feature {
        Feature(kind: .ledge, style: .curb, lane: lane, x: x, length: length, height: 5)
    }

    static func fountain(_ lane: Lane, at x: CGFloat, length: CGFloat = 72) -> Feature {
        Feature(kind: .ledge, style: .fountain, lane: lane, x: x, length: length, height: 12)
    }

    static func tracks(_ lane: Lane, at x: CGFloat, length: CGFloat) -> Feature {
        Feature(kind: .rail, style: .tracks, lane: lane, x: x, length: length, height: 3)
    }

    static func funbox(_ lane: Lane, at x: CGFloat, length: CGFloat = 64) -> Feature {
        Feature(kind: .ledge, style: .funbox, lane: lane, x: x, length: length, height: 11)
    }

    static func barrier(_ lane: Lane, at x: CGFloat, length: CGFloat = 40) -> Feature {
        Feature(kind: .ledge, style: .barrier, lane: lane, x: x, length: length, height: 11)
    }

    // MARK: Things in the way

    static func cone(_ lane: Lane, at x: CGFloat) -> Feature {
        Feature(kind: .block, style: .cone, lane: lane, x: x, length: 9, height: 12)
    }

    static func planter(_ lane: Lane, at x: CGFloat, length: CGFloat = 24, height: CGFloat = 16) -> Feature {
        Feature(kind: .block, style: .planter, lane: lane, x: x, length: length, height: height)
    }

    /// Someone walking toward you. Too tall to ollie: go around.
    static func pedestrian(_ lane: Lane, at x: CGFloat, speed: CGFloat = 14) -> Feature {
        Feature(kind: .block, style: .pedestrian, lane: lane, x: x, length: 10, height: 21, velocity: -speed)
    }

    /// A jogger going your way, slower than you.
    static func runner(_ lane: Lane, at x: CGFloat) -> Feature {
        Feature(kind: .block, style: .runner, lane: lane, x: x, length: 12, height: 21, velocity: 30)
    }

    /// A cyclist going your way, rider and all as tall as you: go around.
    static func biker(_ lane: Lane, at x: CGFloat, speed: CGFloat = 50) -> Feature {
        Feature(kind: .block, style: .biker, lane: lane, x: x, length: 22, height: 22, velocity: speed)
    }

    /// Another skater, cruising slower than you.
    static func skater(_ lane: Lane, at x: CGFloat) -> Feature {
        Feature(kind: .block, style: .skater, lane: lane, x: x, length: 12, height: 22, velocity: 40)
    }

    /// Angie, out for a walk.
    static func dog(_ lane: Lane, at x: CGFloat) -> Feature {
        Feature(kind: .block, style: .dog, lane: lane, x: x, length: 15, height: 11, velocity: -10)
    }

    static func cart(_ lane: Lane, at x: CGFloat) -> Feature {
        Feature(kind: .block, style: .cart, lane: lane, x: x, length: 15, height: 13)
    }

    static func brokenCar(_ lane: Lane, at x: CGFloat) -> Feature {
        Feature(kind: .block, style: .brokenCar, lane: lane, x: x, length: 40, height: 17)
    }

    /// A car coming up the street toward you.
    static func car(_ lane: Lane, at x: CGFloat, speed: CGFloat = 60) -> Feature {
        Feature(kind: .block, style: .car, lane: lane, x: x, length: 40, height: 17, velocity: -speed)
    }

    /// A light rail train. Far too big to ollie: get out of its lane.
    static func train(_ lane: Lane, at x: CGFloat) -> Feature {
        Feature(kind: .block, style: .train, lane: lane, x: x, length: 150, height: 40, velocity: -80)
    }

    static func penguin(_ lane: Lane, at x: CGFloat) -> Feature {
        Feature(kind: .block, style: .penguin, lane: lane, x: x, length: 8, height: 11, velocity: -8)
    }

    static func goat(_ lane: Lane, at x: CGFloat) -> Feature {
        Feature(kind: .block, style: .goat, lane: lane, x: x, length: 16, height: 13, velocity: -12)
    }

    // MARK: Ramps

    /// A quarter pipe facing you: ride up it and you're launched high off the lip.
    static func quarterPipe(_ lane: Lane, at x: CGFloat, length: CGFloat = 36) -> Feature {
        Feature(kind: .ramp, style: .quarterPipe, lane: lane, x: x, length: length, height: Tuning.quarterPipeLip)
    }

    /// How high the ramp is this far along it.
    func rampHeight(at position: CGFloat, start: CGFloat) -> CGFloat {
        let along = max(0, min(1, (position - start) / length))
        return (height * along * along).rounded()
    }

    // MARK: Holes

    /// An open manhole, about two feet across next to the skater.
    static func hole(_ lane: Lane, at x: CGFloat, length: CGFloat = 14) -> Feature {
        Feature(kind: .hole, style: .hole, lane: lane, x: x, length: length, height: 0)
    }
}

/// One of the city's letters, floating somewhere along a run.
nonisolated struct LetterPickup: Equatable, Sendable {
    /// Its place in the city's name (P is 0 in Portland).
    var index: Int
    var letter: Character
    var lane: Lane
    var x: CGFloat
    /// How high its bottom is above the lane. Up to 16 can be reached rolling; higher needs an ollie.
    var height: CGFloat
}

/// The look of a spot: its sky, backdrops and ground.
nonisolated enum Theme: Equatable, Sendable {
    case downtown, skidmore, burnside, northPortland, waterfront, zooBomb
}

nonisolated struct Level: Equatable, Sendable {
    var id: String
    var name: String
    var theme: Theme
    /// Where the finish line is.
    var length: CGFloat
    var features: [Feature]
    var letters: [LetterPickup] = []
    var startX: CGFloat = 40
    var startLane: Lane = .middle
    /// Speed gained every second, for downhill runs.
    var acceleration: CGFloat = 0
    var maxSpeed: CGFloat = Tuning.maxSpeed
    /// Show the how-to-play hints along the way.
    var showsHints = false
    /// Named jumps worth a bonus.
    var gaps: [Gap] = []
    /// Things to do here, kept once done.
    var goals: [Goal] = []
}

/// A named jump. Pull it off for a fat bonus on the combo.
nonisolated struct Gap: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// Get over everything that starts in `lane` from `from` to `to`, in one jump.
        case over(Lane, from: CGFloat, to: CGFloat)
        /// Grind the thing starting at `from`, then land a grind on the one starting at `to`,
        /// without touching the ground in between.
        case transfer(Lane, from: CGFloat, to: CGFloat)
    }

    var name: String
    var points: Int
    var kind: Kind

    /// The features this gap is made of, by their place in the level.
    func features(in level: Level) -> [Int] {
        switch kind {
        case .over(let lane, let from, let to):
            return level.features.indices.filter {
                let feature = level.features[$0]
                return feature.lane == lane && feature.x >= from && feature.x <= to
            }
        case .transfer(let lane, let from, let to):
            let start = level.features.indices.first { level.features[$0].lane == lane && level.features[$0].x == from }
            let end = level.features.indices.first { level.features[$0].lane == lane && level.features[$0].x == to }
            guard let start, let end else { return [] }
            return [start, end]
        }
    }
}
