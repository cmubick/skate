//
//  Prefs.kt
//
//  Where the game saves things between launches: Android's SharedPreferences,
//  the counterpart of iOS's UserDefaults, under the same keys (see Progress.kt,
//  Sounds.kt, Music.kt and PlayStore.kt). Android deletes them when the app is
//  uninstalled.
//

package com.tuesdaygames.skate

import android.content.Context
import android.content.SharedPreferences
import com.tuesdaygames.skate.rules.KeyValueStore

class Prefs(context: Context) : KeyValueStore {
    private val prefs: SharedPreferences = context.getSharedPreferences(fileName, Context.MODE_PRIVATE)

    override fun getString(key: String): String? = prefs.getString(key, null)
    override fun putString(key: String, value: String) = prefs.edit().putString(key, value).apply()
    override fun getInt(key: String): Int = prefs.getInt(key, 0)
    override fun putInt(key: String, value: Int) = prefs.edit().putInt(key, value).apply()
    override fun getBoolean(key: String): Boolean = prefs.getBoolean(key, false)
    override fun putBoolean(key: String, value: Boolean) = prefs.edit().putBoolean(key, value).apply()

    companion object {
        /** The file in the app's private folder: shared_prefs/skate.xml. */
        const val fileName = "skate"
    }
}
