//
//  Tricks.swift
//  skate
//
//  The tricks, what they're worth, and the combo that chains them.
//

import Foundation

nonisolated enum Trick: Equatable, Sendable {
    case ollie
    case grab
    case kickflip
    case heelflip
    case shoveIt
    case threeSixtyFlip
    case fiftyFifty
    case boardslide

    var name: String {
        switch self {
        case .ollie: "OLLIE"
        case .grab: "GRAB"
        case .kickflip: "KICKFLIP"
        case .heelflip: "HEELFLIP"
        case .shoveIt: "SHOVE-IT"
        case .threeSixtyFlip: "360 FLIP"
        case .fiftyFifty: "50-50"
        case .boardslide: "BOARDSLIDE"
        }
    }

    var basePoints: Double {
        switch self {
        case .ollie: 50
        case .grab: 100
        case .kickflip, .heelflip, .shoveIt: 150
        case .threeSixtyFlip: 300
        case .fiftyFifty: 100
        case .boardslide: 150
        }
    }

    /// Extra points for each second a grind lasts, or a grab is held past the hold threshold.
    var pointsPerSecond: Double {
        switch self {
        case .grab: 250
        case .fiftyFifty: 100
        case .boardslide: 150
        default: 0
        }
    }

    /// How long the trick takes in the air. The board has to be back under your
    /// feet before you land, or you bail. Grabs last as long as you hold them.
    var airTime: TimeInterval {
        switch self {
        case .grab: 0.22
        case .kickflip, .heelflip: 0.32
        case .shoveIt: 0.34
        case .threeSixtyFlip: 0.46
        default: 0
        }
    }

    var isGrind: Bool { self == .fiftyFifty || self == .boardslide }

    /// How much the trick multiplies the points for clearing something while you do it.
    var clearStyle: Double {
        switch self {
        case .grab: 1.5
        case .kickflip, .heelflip, .shoveIt: 2
        case .threeSixtyFlip: 3
        default: 1
        }
    }

    /// The flip trick for a swipe in the air.
    static func flip(for direction: SwipeDirection) -> Trick {
        switch direction {
        case .left: .kickflip
        case .right: .heelflip
        case .down: .shoveIt
        case .up: .threeSixtyFlip
        }
    }
}

/// The tricks done since you last touched flat ground. Each one adds 1 to the
/// multiplier. Landing clean banks it; bailing loses it.
nonisolated struct Combo: Equatable, Sendable {
    struct Entry: Equatable, Sendable {
        var trick: Trick
        var points: Double
    }

    private(set) var entries: [Entry] = []
    /// Points for things cleared along the way. They ride on the combo's multiplier too.
    private(set) var bonus: Double = 0

    var isEmpty: Bool { entries.isEmpty }
    var multiplier: Int { entries.count }
    var points: Int { Int(entries.reduce(bonus) { $0 + $1.points }) }
    var total: Int { points * multiplier }

    mutating func add(_ trick: Trick) {
        entries.append(Entry(trick: trick, points: trick.basePoints))
    }

    /// Adds points to the latest trick, for a grind or grab that is still going.
    mutating func extendLast(by points: Double) {
        guard !entries.isEmpty else { return }
        entries[entries.count - 1].points += points
    }

    mutating func addBonus(_ points: Double) {
        bonus += points
    }

    mutating func clear() {
        entries.removeAll()
        bonus = 0
    }

    /// The combo as the player sees it, newest tricks last.
    func text(maxTricks: Int = 3) -> String {
        guard !entries.isEmpty else { return "" }
        let names = entries.suffix(maxTricks).map(\.trick.name)
        let lead = entries.count > maxTricks ? "... + " : ""
        return lead + names.joined(separator: " + ")
    }
}
