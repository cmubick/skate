//
//  Sounds.kt
//
//  Plays the sound effects. Muting is remembered between launches (saved as
//  "soundMuted", as on iOS). Ported from the second half of skate/UI/Sounds.swift.
//
//  Every sound is a buffer in memory played through the mixer: six voices take
//  turns with the one-off sounds, and each looping sound has a voice of its own.
//

package com.tuesdaygames.skate.sound

import com.tuesdaygames.skate.rules.KeyValueStore

object Sounds {
    private const val mutedKey = "soundMuted"

    /** Voices for one-off sounds, so a few can overlap. */
    private const val voiceCount = 6

    private var store: KeyValueStore? = null
    private var mixer: Mixer? = null
    private var buffers: Map<Sound, FloatArray> = emptyMap()
    private var nextVoice = 0
    private val loopVoices: Map<Sound, Int> = Sound.loops.sorted().withIndex().associate { it.value to voiceCount + it.index }

    /** Called once at launch, with where settings are saved. */
    fun setUp(store: KeyValueStore) {
        this.store = store
        isMuted = store.getBoolean(mutedKey)
    }

    var isMuted = false
        set(value) {
            field = value
            store?.putBoolean(mutedKey, value)
            if (value) stopAllLoops()
        }

    /** True while any sound is coming out (so Music can tell ours from another app's). */
    val isPlaying: Boolean get() = mixer?.isPlaying == true

    /** Makes every sound, so the first one plays without a hitch. Done on the first
     *  sound anyway; spots call it as they start. */
    fun prepare() {
        if (mixer != null) return
        buffers = Sound.entries.associateWith { sound ->
            val samples = SoundSynth.samples(sound)
            FloatArray(samples.size) { samples[it].coerceIn(-1.0, 1.0).toFloat() }
        }
        mixer = Mixer(SoundSynth.sampleRate.toInt(), voiceCount + Sound.loops.size, "Skate sounds")
    }

    fun play(sound: Sound) {
        if (isMuted) return
        prepare()
        val buffer = buffers[sound] ?: return
        mixer?.play(nextVoice, buffer, 0.7f)
        nextVoice = (nextVoice + 1) % voiceCount
    }

    fun startLoop(sound: Sound) {
        if (isMuted) return
        prepare()
        val buffer = buffers[sound] ?: return
        val voice = loopVoices[sound] ?: return
        // Rolling is there all the time, so it sits well back.
        mixer?.play(voice, buffer, if (sound == Sound.Roll) 0.3f else 0.7f, loopFirst = true)
    }

    fun stopLoop(sound: Sound) {
        val voice = loopVoices[sound] ?: return
        mixer?.stop(voice)
    }

    fun stopAllLoops() = Sound.loops.forEach(::stopLoop)

    fun pause() = mixer?.pause()
    fun resume() = mixer?.resume()
}
