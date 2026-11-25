//
//  Music.kt
//
//  Plays each spot's song (see Songs.kt): the intro once, then the rest on a
//  loop. A song is rendered the first time it's needed, off the main thread,
//  and kept for next time. The intro starts as soon as it's rendered, while the
//  rest is still being made: on a slow phone, or a debug build (which Android
//  runs far slower), a whole song can take a while. Quieter while a menu is up.
//  Silent when the player turns music off (remembered between launches as
//  "musicOff", as on iOS), or has their own music going. Ported from
//  skate/UI/Music.swift.
//

package com.tuesdaygames.skate.sound

import android.media.AudioAttributes
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import com.tuesdaygames.skate.rules.KeyValueStore
import com.tuesdaygames.skate.rules.Level
import java.util.concurrent.Executors

object Music {
    /** Under the sound effects, which play at 0.7. */
    const val volume = 0.45f
    const val duckedVolume = 0.18f

    private const val offKey = "musicOff"

    private var store: KeyValueStore? = null
    private var audio: AudioManager? = null
    private var mixer: Mixer? = null
    private val rendered = HashMap<String, Pair<FloatArray, FloatArray>>()
    /** Intros ready before the rest of their song. */
    private val intros = HashMap<String, FloatArray>()
    /** The song whose intro is playing without the rest, which follows when it's ready. */
    private var introOnly: String? = null
    private val rendering = HashSet<String>()
    private val renderer by lazy { Executors.newSingleThreadExecutor() }
    private val main by lazy { Handler(Looper.getMainLooper()) }

    /** The song that should be playing, if any. */
    private var wanted: Chiptune.Song? = null
    private var isDucked = false

    /** Called once at launch. */
    fun setUp(store: KeyValueStore, audio: AudioManager?) {
        this.store = store
        this.audio = audio
        isOn = !store.getBoolean(offKey)
    }

    /** The player's music setting. Separate from the sound effects. */
    var isOn = true
        set(value) {
            val changed = field != value
            field = value
            store?.putBoolean(offKey, !value)
            if (!changed) return
            if (!value) {
                mixer?.stop(0)
            } else {
                // Pick the song up again, at the volume it should be.
                wanted?.let(::startOrRender)
            }
        }

    /** Each spot's song. The tutorial street is Downtown's. */
    fun song(level: Level): Chiptune.Song? = when (level.id) {
        "downtown", "tutorial" -> Songs.downtown
        "skidmore" -> Songs.skidmore
        "burnside" -> Songs.burnside
        "northportland" -> Songs.northPortland
        "waterfront" -> Songs.waterfront
        "zoobomb" -> Songs.zooBomb
        else -> null
    }

    /** Starts a song from its intro. It begins as soon as it's rendered. */
    fun play(song: Chiptune.Song) {
        wanted = song
        isDucked = false
        introOnly = null
        mixer?.stop(0)
        if (!canPlay) return
        startOrRender(song)
    }

    fun stop() {
        wanted = null
        introOnly = null
        mixer?.stop(0)
    }

    /** Quieter under a menu; back up after. Picks the song up again if something stopped it. */
    fun setDucked(ducked: Boolean) {
        isDucked = ducked
        mixer?.setVolume(0, if (ducked) duckedVolume else volume)
        val song = wanted ?: return
        if (!ducked && mixer?.isVoicePlaying(0) != true && canPlay) startOrRender(song)
    }

    /**
     * Another app playing music, a podcast or a video: anything playing that's
     * marked as media. The game's own sound is marked as game audio (see Mixer.kt),
     * so it never counts. (Asking Android only whether any music was playing used to
     * take the click of the button that started a run for someone's music, and the
     * song didn't start until music was switched off and on again.)
     */
    private val othersPlaying: Boolean
        get() = try {
            audio?.activePlaybackConfigurations.orEmpty().any {
                it.audioAttributes.usage == AudioAttributes.USAGE_MEDIA
            }
        } catch (error: RuntimeException) {
            false
        }

    /** Music on, and no other app playing music. */
    private val canPlay: Boolean
        get() = isOn && !othersPlaying

    /** Starts what's ready of the song: all of it, or the intro with the rest to follow. */
    private fun startOrRender(song: Chiptune.Song) {
        val whole = rendered[song.name]
        val intro = intros[song.name]
        when {
            whole != null -> start(whole.first, whole.second)
            intro != null -> startIntro(song.name, intro)
            else -> render(song)
        }
    }

    private fun render(song: Chiptune.Song) {
        if (!rendering.add(song.name)) return
        renderer.execute {
            val intro = Chiptune.renderIntro(song)
            main.post {
                intros[song.name] = intro
                if (wanted?.name == song.name && mixer?.isVoicePlaying(0) != true && canPlay) startIntro(song.name, intro)
            }
            val loop = Chiptune.renderLoop(song)
            main.post {
                rendering.remove(song.name)
                intros.remove(song.name)
                rendered[song.name] = intro to loop
                if (wanted?.name != song.name) return@post
                if (introOnly == song.name) {
                    introOnly = null
                    // Usually the intro is still going: the rest follows it.
                    if (mixer?.setLoop(0, intro, loop) == true) return@post
                    // The intro already finished: go straight on to the rest.
                    if (mixer?.isVoicePlaying(0) != true && canPlay) start(loop, loop)
                } else if (mixer?.isVoicePlaying(0) != true && canPlay) {
                    start(intro, loop)
                }
            }
        }
    }

    private fun startIntro(name: String, intro: FloatArray) {
        introOnly = name
        mixer().play(0, intro, currentVolume)
    }

    private fun start(first: FloatArray, loop: FloatArray) {
        introOnly = null
        mixer().play(0, first, currentVolume, loop = loop)
    }

    private fun mixer(): Mixer = mixer ?: Mixer(Chiptune.sampleRate.toInt(), 1, "Skate music").also { mixer = it }

    private val currentVolume get() = if (isDucked) duckedVolume else volume

    fun pause() = mixer?.pause()

    /** Back from the background. If the player started their own music while away,
     *  the game's song stays off (until the next run, or the next unpause). */
    fun resume() {
        if (othersPlaying) {
            introOnly = null
            mixer?.stop(0)
        }
        mixer?.resume()
    }
}
