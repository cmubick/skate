//
//  Progress.swift
//  skate
//
//  What's saved between launches: the skater's outfit, the city letters found,
//  the best score and the goals done at each spot.
//

import Foundation

final class Progress {
    static let shared = Progress(defaults: .standard)

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var outfit: Outfit {
        get {
            guard let data = defaults.data(forKey: "outfit"),
                  let outfit = try? JSONDecoder().decode(Outfit.self, from: data) else { return .standard }
            return outfit
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { defaults.set(data, forKey: "outfit") }
        }
    }

    /// Which of a city's letters have been found, by their place in the city's name.
    func letters(in city: City) -> Set<Int> {
        Set(defaults.array(forKey: "letters.\(city.id)") as? [Int] ?? [])
    }

    /// Saves a letter. Returns true if it's new.
    @discardableResult
    func collect(letter index: Int, in city: City) -> Bool {
        var found = letters(in: city)
        guard found.insert(index).inserted else { return false }
        defaults.set(found.sorted(), forKey: "letters.\(city.id)")
        return true
    }

    /// True once every letter of the city's name has been found.
    func isComplete(_ city: City) -> Bool {
        !city.letters.isEmpty && letters(in: city).count >= city.letters.count
    }

    /// Spelling PORTLAND wins the PDX carpet board.
    var hasPDXBoard: Bool { isComplete(.portland) }

    /// The goals done at a spot, by id.
    func goalsDone(at level: Level) -> Set<String> {
        Set(defaults.array(forKey: "goals.\(level.id)") as? [String] ?? [])
    }

    /// Saves a goal as done. Returns true if it's new.
    @discardableResult
    func complete(goal: Goal, at level: Level) -> Bool {
        var done = goalsDone(at: level)
        guard done.insert(goal.id).inserted else { return false }
        defaults.set(done.sorted(), forKey: "goals.\(level.id)")
        return true
    }

    /// Marks done any letters goal whose letters were all found, even across different
    /// runs. Saves from before that counted made you find them all in one run.
    func completeEarnedLetterGoals(in city: City) {
        let found = letters(in: city)
        for level in city.levels where GoalTracker.allLettersFound(at: level, found: found) {
            for goal in level.goals where goal.kind == .letters { complete(goal: goal, at: level) }
        }
    }

    /// True once every goal at every spot in the city is done.
    func allGoalsDone(in city: City) -> Bool {
        city.levels.allSatisfy { level in level.goals.allSatisfy { goalsDone(at: level).contains($0.id) } }
            && city.levels.contains { !$0.goals.isEmpty }
    }

    func bestScore(at level: Level) -> Int {
        defaults.integer(forKey: "bestScore.\(level.id)")
    }

    /// Saves the score if it's a new best. Returns true if it was.
    @discardableResult
    func record(score: Int, at level: Level) -> Bool {
        guard score > bestScore(at: level) else { return false }
        defaults.set(score, forKey: "bestScore.\(level.id)")
        return true
    }
}
