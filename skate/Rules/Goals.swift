//
//  Goals.swift
//  skate
//
//  Each spot has a handful of goals. They're listed before a run, announced the
//  moment you get one, and crossed off at the end. Once done they stay done.
//

import Foundation

nonisolated struct Goal: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        /// Reach this score in one run.
        case score(Int)
        /// Bank a single combo worth this much.
        case combo(Int)
        /// Find every letter hidden at this spot. Letters found on earlier runs count:
        /// you never have to find one again.
        case letters
        /// Get all the way over one of these, doing at least this hard a trick
        /// (see `Trick.clearStyle`: 1 is any jump, 2 a flip, 3 a 360 flip).
        case clear(FeatureStyle, style: Double = 1)
        /// Get over this many of these in one run.
        case clears(FeatureStyle, count: Int)
        /// Keep one grind on one of these going this long.
        case grind(FeatureStyle, seconds: Double)
        /// Pull off the gap with this name.
        case gap(String)
        /// Land this trick clean.
        case land(Trick)
        /// Get to the finish without bailing.
        case noBails
    }

    /// Saved once done, so it must stay the same.
    var id: String
    /// Short enough to fit half the screen (checked in the tests).
    var text: String
    var kind: Kind
}

/// Watches a run and says when each of the spot's goals is met.
nonisolated struct GoalTracker: Sendable {
    let goals: [Goal]
    private(set) var met: Set<String> = []
    private var clearCounts: [FeatureStyle: Int] = [:]
    private var grinding: (feature: Int, seconds: Double)?
    private var bailed = false
    /// The city's letters found on earlier runs, by their place in its name.
    private let lettersFoundBefore: Set<Int>

    /// `alreadyMet`: goals done on earlier runs, which don't need announcing again.
    /// `lettersFoundBefore`: the city's letters found on earlier runs.
    init(goals: [Goal], alreadyMet: Set<String> = [], lettersFoundBefore: Set<Int> = []) {
        self.goals = goals
        met = alreadyMet
        self.lettersFoundBefore = lettersFoundBefore
    }

    /// True if every letter at this spot has been found, on this run or any before.
    static func allLettersFound(at level: Level, found: Set<Int>) -> Bool {
        let here = Set(level.letters.map(\.index))
        return !here.isEmpty && here.isSubset(of: found)
    }

    /// Call after every step of the run, with what happened in it. Returns goals just met.
    mutating func update(run: Run, events: [RunEvent], dt: TimeInterval) -> [Goal] {
        var bankedCombo = 0
        var landed: Set<String> = []
        var gaps: Set<String> = []
        var clears: [(FeatureStyle, Double)] = []
        var finished = false
        for event in events {
            switch event {
            case .banked(let points): bankedCombo = max(bankedCombo, points)
            case .landedTrick(let trick): landed.insert(trick.name)
            case .gap(let name, _): gaps.insert(name)
            case .cleared(let style, let trickStyle, _):
                clears.append((style, trickStyle))
                clearCounts[style, default: 0] += 1
            case .bail: bailed = true
            case .finished: finished = true
            default: break
            }
        }
        if case .grinding(let feature, _) = run.state {
            let seconds = (grinding?.feature == feature ? grinding?.seconds ?? 0 : 0) + dt
            grinding = (feature, seconds)
        } else {
            grinding = nil
        }

        var newlyMet: [Goal] = []
        for goal in goals where !met.contains(goal.id) {
            let done: Bool
            switch goal.kind {
            case .score(let target): done = run.score >= target
            case .combo(let target): done = bankedCombo >= target
            case .letters:
                done = Self.allLettersFound(at: run.level, found: lettersFoundBefore.union(run.lettersFound))
            case .clear(let style, let trickStyle):
                done = clears.contains { $0.0 == style && $0.1 >= trickStyle }
            case .clears(let style, let count): done = clearCounts[style, default: 0] >= count
            case .grind(let style, let seconds):
                if let grinding, run.level.features[grinding.feature].style == style {
                    done = grinding.seconds >= seconds
                } else {
                    done = false
                }
            case .gap(let name): done = gaps.contains(name)
            case .land(let trick): done = landed.contains(trick.name)
            case .noBails: done = finished && !bailed
            }
            if done {
                met.insert(goal.id)
                newlyMet.append(goal)
            }
        }
        return newlyMet
    }
}
