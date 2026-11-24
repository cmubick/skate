//
//  Music.kt
//
//  Plays each spot's song (see Songs.kt): the intro once, then the rest on a
//  loop. A song is rendered the first time it's needed, off the main thread,
//  and kept for next time. Quieter while a menu is up. Silent when the player
//  turns music off (remembered between launches as "musicOff", as on iOS), or
//  has their own music going. Ported from skate/UI/Music.swift.
//

package com.tuesdaygames.skate.sound

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
                wanted?.let { song -> rendered[song.name]?.let(::start) ?: render(song) }
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
        mixer?.stop(0)
        if (!canPlay) return
        rendered[song.name]?.let(::start) ?: render(song)
    }

    fun stop() {
        wanted = null
        mixer?.stop(0)
    }

    /** Quieter under a menu; back up after. Picks the song up again if something stopped it. */
    fun setDucked(ducked: Boolean) {
        isDucked = ducked
        mixer?.setVolume(0, if (ducked) duckedVolume else volume)
        val song = wanted ?: return
        if (!ducked && mixer?.isVoicePlaying(0) != true && canPlay) rendered[song.name]?.let(::start)
    }

    /**
     * Music on, and no other app playing music. Android can only say whether any
     * music is playing, so while the game's own sound is going it assumes that's
     * all there is.
     */
    private val canPlay: Boolean
        get() {
            if (!isOn) return false
            val othersPlaying = audio?.isMusicActive == true && !Sounds.isPlaying && mixer?.isPlaying != true
            return !othersPlaying
        }

    private fun render(song: Chiptune.Song) {
        if (!rendering.add(song.name)) return
        renderer.execute {
            val intro = Chiptune.renderIntro(song)
            val loop = Chiptune.renderLoop(song)
            main.post {
                rendering.remove(song.name)
                rendered[song.name] = intro to loop
                if (wanted?.name == song.name && canPlay) start(intro to loop)
            }
        }
    }

    private fun start(buffers: Pair<FloatArray, FloatArray>) {
        val mixer = mixer ?: Mixer(Chiptune.sampleRate.toInt(), 1, "Skate music").also { mixer = it }
        mixer.play(0, buffers.first, if (isDucked) duckedVolume else volume, loop = buffers.second)
    }

    fun pause() = mixer?.pause()
    fun resume() = mixer?.resume()
}
