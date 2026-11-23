//
//  Progress.swift
//  skate
//
//  What's saved between launches: the skater's outfit, the city letters found,
//  and the best score at each spot.
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
