//
//  Progress.kt
//
//  What's saved between launches: the skater's outfit, the city letters found,
//  the best score and the goals done at each spot. Ported from skate/Rules/Progress.swift.
//
//  The keys are the same as on iOS ("outfit", "letters.<city>", "bestScore.<spot>",
//  "goals.<spot>"). Don't rename them: they're on players' phones.
//

package com.tuesdaygames.skate.rules

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Where saved values live. The app passes Android's SharedPreferences (the
 * counterpart of iOS's UserDefaults); the tests pass a plain map.
 */
interface KeyValueStore {
    fun getString(key: String): String?
    fun putString(key: String, value: String)
    fun getInt(key: String): Int
    fun putInt(key: String, value: Int)
    fun getBoolean(key: String): Boolean
    fun putBoolean(key: String, value: Boolean)
}

/** A store kept in memory only. Used by the tests. */
class MemoryStore : KeyValueStore {
    private val values = mutableMapOf<String, Any>()
    override fun getString(key: String) = values[key] as? String
    override fun putString(key: String, value: String) { values[key] = value }
    override fun getInt(key: String) = values[key] as? Int ?: 0
    override fun putInt(key: String, value: Int) { values[key] = value }
    override fun getBoolean(key: String) = values[key] as? Boolean ?: false
    override fun putBoolean(key: String, value: Boolean) { values[key] = value }
}

class Progress(private val store: KeyValueStore) {

    var outfit: Outfit
        get() = store.getString("outfit")?.let(::decodeOutfit) ?: Outfit.standard
        set(value) = store.putString("outfit", json.encodeToString(Outfit.serializer(), value))

    /** Which of a city's letters have been found, by their place in the city's name. */
    fun letters(city: City): Set<Int> = readList("letters.${city.id}").mapNotNull { it.toIntOrNull() }.toSet()

    /** Saves a letter. Returns true if it's new. */
    fun collect(letter: Int, city: City): Boolean {
        val found = letters(city).toMutableSet()
        if (!found.add(letter)) return false
        writeList("letters.${city.id}", found.sorted().map { it.toString() })
        return true
    }

    /** True once every letter of the city's name has been found. */
    fun isComplete(city: City): Boolean = city.letters.isNotEmpty() && letters(city).size >= city.letters.size

    /** Spelling PORTLAND wins the PDX carpet board. */
    val hasPDXBoard: Boolean get() = isComplete(City.portland)

    /** The goals done at a spot, by id. */
    fun goalsDone(level: Level): Set<String> = readList("goals.${level.id}").toSet()

    /** Saves a goal as done. Returns true if it's new. */
    fun complete(goal: Goal, level: Level): Boolean {
        val done = goalsDone(level).toMutableSet()
        if (!done.add(goal.id)) return false
        writeList("goals.${level.id}", done.sorted())
        return true
    }

    /** Marks done any letters goal whose letters were all found, even across different
     *  runs. Saves from before that counted made you find them all in one run. */
    fun completeEarnedLetterGoals(city: City) {
        val found = letters(city)
        for (level in city.levels) {
            if (!GoalTracker.allLettersFound(level, found)) continue
            for (goal in level.goals) if (goal.kind == Goal.Kind.Letters) complete(goal, level)
        }
    }

    /** True once every goal at every spot in the city is done. */
    fun allGoalsDone(city: City): Boolean =
        city.levels.all { level -> level.goals.all { it.id in goalsDone(level) } } &&
            city.levels.any { it.goals.isNotEmpty() }

    fun bestScore(level: Level): Int = store.getInt("bestScore.${level.id}")

    /** Saves the score if it's a new best. Returns true if it was. */
    fun record(score: Int, level: Level): Boolean {
        if (score <= bestScore(level)) return false
        store.putInt("bestScore.${level.id}", score)
        return true
    }

    // Lists are kept as one string, the items joined by commas (iOS keeps an array).
    private fun readList(key: String): List<String> =
        store.getString(key)?.split(",")?.filter { it.isNotEmpty() } ?: emptyList()

    private fun writeList(key: String, items: List<String>) = store.putString(key, items.joinToString(","))

    companion object {
        // Every field written, so a saved yellow hat isn't mistaken for no hat.
        private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

        /** As on iOS, a saved outfit without a hat has no hat. */
        @Serializable
        private class SavedOutfit(
            val kind: SkaterKind,
            val shirt: ColorChoice,
            val pants: ColorChoice,
            val hat: ColorChoice? = null,
            val board: ColorChoice,
        )

        /** Reads an outfit saved as JSON: {"kind":"sam","shirt":"red","pants":"khaki","board":"brown"}. */
        fun decodeOutfit(text: String): Outfit? = try {
            val saved = json.decodeFromString(SavedOutfit.serializer(), text)
            Outfit(saved.kind, saved.shirt, saved.pants, saved.hat, saved.board)
        } catch (error: Exception) {
            null
        }
    }
}
