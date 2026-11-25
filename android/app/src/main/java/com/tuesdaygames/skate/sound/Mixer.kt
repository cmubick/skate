//
//  Mixer.kt
//
//  Android's stand-in for the iOS game's AVAudioEngine: a few voices mixed in
//  code into one AudioTrack, Android's player for raw samples. Each voice plays
//  a buffer once, or plays one and then loops another (a song's intro, then the
//  rest). A thread keeps the AudioTrack fed, and pauses it when nothing plays.
//
//  The audio is marked as game audio: it follows the media volume, and music
//  from another app keeps playing underneath because the game never asks to
//  take over the sound. (It's also how Music tells the game's sound from another
//  app's music, which is marked as media.)
//

package com.tuesdaygames.skate.sound

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Process

class Mixer(private val sampleRate: Int, voiceCount: Int, private val name: String) {

    private class Voice {
        var samples: FloatArray? = null
        var next: FloatArray? = null
        var loopNext = false
        var position = 0
        var volume = 1f
    }

    private val voices = List(voiceCount) { Voice() }
    private val lock = Object()
    private var track: AudioTrack? = null
    private var thread: Thread? = null
    private var running = false

    /** False while the app is in the background: everything is held where it is. */
    private var resumed = true

    /** True while anything is playing. */
    @Volatile var isPlaying = false
        private set

    /** Plays `samples` on a voice, from the start, replacing what it was playing.
     *  With `loop`, `samples` plays once and then `loop` repeats until stopped. */
    fun play(voice: Int, samples: FloatArray, volume: Float, loop: FloatArray? = null, loopFirst: Boolean = false) {
        synchronized(lock) {
            val v = voices[voice]
            if (loopFirst) {
                v.samples = samples
                v.next = samples
            } else {
                v.samples = samples
                v.next = loop
            }
            v.loopNext = loopFirst || loop != null
            v.position = 0
            v.volume = volume
            ensureRunning()
            lock.notifyAll()
        }
    }

    /** Sets what `voice` loops once `current` finishes, if `current` is still what it's
     *  playing (a song's intro, started before the rest was ready). False if it isn't. */
    fun setLoop(voice: Int, current: FloatArray, loop: FloatArray): Boolean = synchronized(lock) {
        val v = voices[voice]
        if (v.samples !== current || v.next != null) return false
        v.next = loop
        v.loopNext = true
        true
    }

    fun setVolume(voice: Int, volume: Float) = synchronized(lock) { voices[voice].volume = volume }

    fun isVoicePlaying(voice: Int): Boolean = synchronized(lock) { voices[voice].samples != null }

    fun stop(voice: Int) = synchronized(lock) {
        voices[voice].samples = null
        voices[voice].next = null
    }

    fun stopAll() = synchronized(lock) { voices.forEach { it.samples = null; it.next = null } }

    /** The app went to the background: go quiet, and keep each voice's place. */
    fun pause() = synchronized(lock) {
        resumed = false
        try {
            track?.pause()
        } catch (error: IllegalStateException) {
        }
    }

    fun resume() = synchronized(lock) {
        resumed = true
        lock.notifyAll()
    }

    private fun ensureRunning() {
        if (running) return
        val minimum = AudioTrack.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_FLOAT)
        val track = try {
            AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_GAME)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setSampleRate(sampleRate)
                        .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build(),
                )
                .setTransferMode(AudioTrack.MODE_STREAM)
                .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
                .setBufferSizeInBytes(maxOf(minimum, 4 * chunk))
                .build()
        } catch (error: Exception) {
            // A phone that can't set up the sound plays without it.
            return
        }
        this.track = track
        running = true
        thread = Thread({ feed(track) }, name).also { it.start() }
    }

    private fun feed(track: AudioTrack) {
        Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)
        val buffer = FloatArray(chunk)
        var started = false
        while (true) {
            synchronized(lock) {
                // Nothing to play, or in the background: stop the track and wait.
                while (!resumed || voices.none { it.samples != null }) {
                    isPlaying = false
                    if (started) {
                        try {
                            track.pause()
                            track.flush()
                        } catch (error: IllegalStateException) {
                        }
                        started = false
                    }
                    lock.wait()
                }
                isPlaying = true
                buffer.fill(0f)
                for (voice in voices) mixInto(voice, buffer)
            }
            for (i in buffer.indices) buffer[i] = buffer[i].coerceIn(-1f, 1f)
            if (!started) {
                try {
                    track.play()
                } catch (error: IllegalStateException) {
                    return
                }
                started = true
            }
            track.write(buffer, 0, buffer.size, AudioTrack.WRITE_BLOCKING)
        }
    }

    private fun mixInto(voice: Voice, buffer: FloatArray) {
        var filled = 0
        while (filled < buffer.size) {
            val samples = voice.samples ?: return
            if (samples.isEmpty()) {
                advanceToNext(voice)
                continue
            }
            val count = minOf(buffer.size - filled, samples.size - voice.position)
            val volume = voice.volume
            for (i in 0 until count) buffer[filled + i] += samples[voice.position + i] * volume
            filled += count
            voice.position += count
            if (voice.position >= samples.size) advanceToNext(voice)
        }
    }

    private fun advanceToNext(voice: Voice) {
        voice.position = 0
        if (voice.loopNext && voice.next != null) {
            voice.samples = voice.next
        } else {
            voice.samples = null
        }
    }

    private companion object {
        /** Samples mixed at a time: a few milliseconds, so taps sound straight away. */
        const val chunk = 256
    }
}
