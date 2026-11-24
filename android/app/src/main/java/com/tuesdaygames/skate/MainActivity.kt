//
//  MainActivity.kt
//
//  The app: full screen and on its side, with the game view filling it. Sets up
//  saving, sound, music, haptics and the store, and passes the back button and
//  going into the background on to the game. The Android counterpart of the
//  iOS AppDelegate, SceneDelegate and the setup in GameViewController.swift.
//

package com.tuesdaygames.skate

import android.content.pm.ApplicationInfo
import android.media.AudioManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.tuesdaygames.skate.game.GameScene
import com.tuesdaygames.skate.game.GameView
import com.tuesdaygames.skate.game.Insets
import com.tuesdaygames.skate.game.MenuScene
import com.tuesdaygames.skate.haptics.Haptics
import com.tuesdaygames.skate.rules.City
import com.tuesdaygames.skate.rules.Level
import com.tuesdaygames.skate.rules.Progress
import com.tuesdaygames.skate.rules.downtown
import com.tuesdaygames.skate.sound.Music
import com.tuesdaygames.skate.sound.Sounds
import com.tuesdaygames.skate.store.PlayStore
import com.tuesdaygames.skate.store.Store

class MainActivity : ComponentActivity() {
    private lateinit var game: GameView
    private lateinit var store: Store

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val prefs = Prefs(applicationContext)
        val progress = Progress(prefs)
        Sounds.setUp(prefs)
        Music.setUp(prefs, getSystemService(AudioManager::class.java))
        Haptics.setUp(applicationContext)
        // Debug builds can pretend the full game is or is not owned: `--ez unlocked true`.
        val pretend = if (isDebuggable && intent.hasExtra("unlocked")) intent.getBooleanExtra("unlocked", false) else null
        store = PlayStore(applicationContext, prefs, pretend)
        // Letters goals done across several runs count (older saves needed one run).
        City.all.forEach(progress::completeEarnedLetterGoals)

        game = GameView(
            this, progress, store, startPage,
            storeHost = { this },
            showsFPS = isDebuggable && !intent.getBooleanExtra("hideFPS", false),
        )
        setContentView(game)
        store.start()

        // Full screen: the game draws under where the bars would be and into the
        // camera cutout, and keeps its buttons inside the safe area.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, game).apply {
            hide(WindowInsetsCompat.Type.systemBars())
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
        ViewCompat.setOnApplyWindowInsetsListener(game) { _, insets ->
            val safe = insets.getInsets(WindowInsetsCompat.Type.displayCutout() or WindowInsetsCompat.Type.systemBars())
            game.safeInsets = Insets(safe.left.toDouble(), safe.top.toDouble(), safe.right.toDouble(), safe.bottom.toDouble())
            insets
        }

        // Back pauses a run, or goes back a menu page; from the title it leaves the app.
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (!game.back()) moveTaskToBack(true)
            }
        })

        if (isDebuggable) debugStart()
    }

    override fun onPause() {
        super.onPause()
        game.willResignActive()
        Haptics.stopGrind()
        Sounds.pause()
        Music.pause()
    }

    override fun onResume() {
        super.onResume()
        Sounds.resume()
        Music.resume()
        // A purchase can be made or refunded while the app is in the background.
        store.refresh()
    }

    private val isDebuggable: Boolean
        get() = applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0

    /** The menu page the app opens on: the title, or in debug builds whatever
     *  `--es page cities|spots|builder|tips|fullgame` asks for. */
    private val startPage: MenuScene.Page
        get() {
            if (!isDebuggable) return MenuScene.Page.Title
            return when (intent.getStringExtra("page")) {
                "cities" -> MenuScene.Page.Cities
                "spots" -> MenuScene.Page.Spots(City.portland)
                "builder" -> MenuScene.Page.Builder
                "tips" -> MenuScene.Page.Tips(back = MenuScene.Page.Title)
                "fullgame" -> MenuScene.Page.FullGame
                else -> MenuScene.Page.Title
            }
        }

    /**
     * Debug builds can skip ahead from the command line, as the iOS launch arguments do:
     * `--es level waterfront` opens straight on that spot, and `--ez fireworks true`
     * shows the all-goals fireworks on Downtown, without saving.
     */
    private fun debugStart() {
        val id = intent.getStringExtra("level")
        val city = City.all.firstOrNull { city -> city.levels.any { it.id == id } }
        val level = city?.levels?.firstOrNull { it.id == id }
        if (city != null && level != null) game.whenLaidOut { it.play(level, city) }
        if (intent.getBooleanExtra("fireworks", false)) {
            game.whenLaidOut { view ->
                view.play(Level.downtown, City.portland)
                view.postDelayed({ (view.scene as? GameScene)?.showFireworksForTesting() }, 3000)
            }
        }
    }
}
