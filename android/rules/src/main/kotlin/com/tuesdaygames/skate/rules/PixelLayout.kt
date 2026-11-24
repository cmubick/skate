//
//  PixelLayout.kt
//
//  Works out how big the game is in its own pixels, and how big a frame to show
//  it in. Ported from the bottom of skate/GameViewController.swift.
//
//  The game is at least 180 x 96 pixels: big, chunky pixels so the skater and the
//  street fill the screen. Each game pixel is drawn as the largest whole number of
//  screen pixels that still fits that (11 on a 2400 x 1080 phone, giving 218 x 98),
//  and any room left over shows more of the street to the right and more sky above.
//

package com.tuesdaygames.skate.rules

import kotlin.math.max
import kotlin.math.min

data class Size(val width: Double, val height: Double)

data class Rect(val x: Double, val y: Double, val width: Double, val height: Double) {
    val minX: Double get() = x
    val minY: Double get() = y
    val maxX: Double get() = x + width
    val maxY: Double get() = y + height
    val midX: Double get() = x + width / 2
    val midY: Double get() = y + height / 2

    fun offsetBy(dx: Double, dy: Double) = Rect(x + dx, y + dy, width, height)
    fun insetBy(dx: Double, dy: Double) = Rect(x + dx, y + dy, width - 2 * dx, height - 2 * dy)
    fun contains(px: Double, py: Double) = px >= minX && px < maxX && py >= minY && py < maxY
}

/**
 * `viewSize` is in points and `screenScale` is screen pixels per point. On Android
 * the view's size is already in screen pixels, so the app passes a scale of 1.
 */
data class PixelLayout(val viewSize: Size, val screenScale: Double) {
    /** Screen pixels per game pixel. */
    val scale: Int

    /** The game's size in game pixels. */
    val gameSize: Size

    /** Where the game view goes, in points, centered in the screen. */
    val frame: Rect

    val pointsPerPixel: Double get() = frame.width / gameSize.width

    init {
        val pixelWidth = (viewSize.width * screenScale).rounded().toInt()
        val pixelHeight = (viewSize.height * screenScale).rounded().toInt()
        val fitWidth = pixelWidth / minimumSize.width.toInt()
        val fitHeight = pixelHeight / minimumSize.height.toInt()
        scale = max(1, min(fitWidth, fitHeight))
        val width = max(1, pixelWidth / scale)
        val height = max(1, pixelHeight / scale)
        gameSize = Size(width.toDouble(), height.toDouble())
        val size = Size((width * scale) / screenScale, (height * scale) / screenScale)
        frame = Rect(
            ((viewSize.width - size.width) / 2 * screenScale).rounded() / screenScale,
            ((viewSize.height - size.height) / 2 * screenScale).rounded() / screenScale,
            size.width, size.height,
        )
    }

    companion object {
        val minimumSize = Size(180.0, 96.0)
    }
}
