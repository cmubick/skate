//
//  Haptics.kt
//
//  A tap on every pop, a snap on every landing, a buzz along every grind and a
//  thud on every bail. Ported from skate/UI/Haptics.swift, using the phone's
//  vibration motor (the VIBRATE permission in AndroidManifest.xml, which Android
//  grants without asking).
//
//  iOS has several kinds of tap; Android 11 and later have "primitives" that come
//  close (a click, a tick, a thud), played at a strength. Older phones get short
//  one-shot buzzes instead. From Android 13 the taps follow the phone's own Touch
//  feedback setting.
//

package com.tuesdaygames.skate.haptics

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

object Haptics {
    private var vibrator: Vibrator? = null
    private val main by lazy { Handler(Looper.getMainLooper()) }
    private var grinding = false

    fun setUp(context: Context) {
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Vibrator::class.java)
        }
    }

    /** Call when a run starts. (Nothing to warm up on Android.) */
    fun prepare() {}

    /** The board popping off the ground. */
    fun pop(charged: Boolean) = tap(Kind.Light, if (charged) 1f else 0.7f)

    /** Switching lanes or grind type. */
    fun tick() = tap(Kind.Tick, 0.6f)

    /** Wheels back on the ground. A perfect landing hits harder. */
    fun land(perfect: Boolean) {
        tap(Kind.Rigid, if (perfect) 1f else 0.75f)
        if (perfect) main.postDelayed({ tap(Kind.Rigid, 0.6f) }, 70)
    }

    fun bail() {
        tap(Kind.Heavy, 1f)
        main.postDelayed({ tap(Kind.Heavy, 0.7f) }, 110)
    }

    fun finish() {
        tap(Kind.Rigid, 0.7f)
        main.postDelayed({ tap(Kind.Rigid, 1f) }, 110)
    }

    /** A steady buzz for as long as you're on a rail. */
    fun startGrind() {
        if (grinding) return
        grinding = true
        val vibrator = vibrator ?: return
        try {
            if (!vibrator.hasVibrator()) return
            // One motor, so the lock-on knock and the buzz are one pattern: a short knock,
            // then the last part repeats until cancelled. Gentle, where the motor can be.
            val (knock, buzz) = if (vibrator.hasAmplitudeControl()) 150 to 70 else 255 to 255
            vibrate(vibrator, VibrationEffect.createWaveform(longArrayOf(0, 25, 1000), intArrayOf(0, knock, buzz), 2))
        } catch (error: Exception) {
        }
    }

    /** Safe to call any time, even when nothing is buzzing. */
    fun stopGrind() {
        if (!grinding) return
        grinding = false
        try {
            vibrator?.cancel()
        } catch (error: Exception) {
        }
    }

    private enum class Kind { Light, Tick, Rigid, Heavy }

    private fun tap(kind: Kind, intensity: Float) {
        // While the grind buzz is on, a tap would cancel it: the buzz says enough.
        if (grinding) return
        val vibrator = vibrator ?: return
        try {
            if (!vibrator.hasVibrator()) return
            vibrate(vibrator, effect(vibrator, kind, intensity))
        } catch (error: Exception) {
            // A phone that refuses to vibrate plays without it.
        }
    }

    private fun effect(vibrator: Vibrator, kind: Kind, intensity: Float): VibrationEffect {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val primitive = when (kind) {
                Kind.Light -> VibrationEffect.Composition.PRIMITIVE_CLICK
                Kind.Tick -> VibrationEffect.Composition.PRIMITIVE_TICK
                Kind.Rigid -> VibrationEffect.Composition.PRIMITIVE_CLICK
                Kind.Heavy -> VibrationEffect.Composition.PRIMITIVE_THUD
            }
            if (vibrator.areAllPrimitivesSupported(primitive)) {
                val scale = if (kind == Kind.Light) intensity * 0.6f else intensity
                return VibrationEffect.startComposition().addPrimitive(primitive, scale).compose()
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return VibrationEffect.createPredefined(
                when (kind) {
                    Kind.Light -> VibrationEffect.EFFECT_TICK
                    Kind.Tick -> VibrationEffect.EFFECT_TICK
                    Kind.Rigid -> VibrationEffect.EFFECT_CLICK
                    Kind.Heavy -> VibrationEffect.EFFECT_HEAVY_CLICK
                },
            )
        }
        val length = when (kind) {
            Kind.Tick -> 8L
            Kind.Light -> 12L
            Kind.Rigid -> 15L
            Kind.Heavy -> 30L
        }
        return VibrationEffect.createOneShot(length, (intensity * 255).toInt().coerceIn(1, 255))
    }

    private fun vibrate(vibrator: Vibrator, effect: VibrationEffect) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            vibrator.vibrate(effect, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_TOUCH))
        } else {
            vibrator.vibrate(effect)
        }
    }
}
