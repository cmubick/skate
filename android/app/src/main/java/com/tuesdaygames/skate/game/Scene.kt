//
//  Scene.kt
//
//  A small stand-in for the parts of SpriteKit the iOS game uses, so the
//  scenes can be ported line for line: nodes in a tree with a position, a
//  depth (z), a scale and an alpha; sprites with a picture or a plain color;
//  a camera; and the handful of actions the game runs (move, fade, wait,
//  run some code, remove, in sequence, together or repeated).
//
//  Coordinates are in game pixels with the origin at the bottom left and y
//  going up, as in SpriteKit. GameView.kt draws the tree onto the screen.
//

package com.tuesdaygames.skate.game

import android.graphics.Bitmap
import com.tuesdaygames.skate.art.PixelCanvas
import com.tuesdaygames.skate.art.PixelColor
import kotlin.random.Random

/** A picture the screen can draw: a canvas turned into an Android bitmap, once. */
class Texture(canvas: PixelCanvas) {
    val width = canvas.width
    val height = canvas.height
    val bitmap: Bitmap = Bitmap.createBitmap(canvas.pixels, width, height, Bitmap.Config.ARGB_8888)
}

fun PixelCanvas.texture() = Texture(this)

open class Node {
    var x = 0.0
    var y = 0.0
    var z = 0.0
    var alpha = 1.0
    var xScale = 1.0
    var yScale = 1.0
    var isHidden = false
    var name: String? = null

    var parent: Node? = null
        private set
    private val _children = mutableListOf<Node>()
    val children: List<Node> get() = _children

    fun position(x: Double, y: Double) {
        this.x = x
        this.y = y
    }

    fun setScale(scale: Double) {
        xScale = scale
        yScale = scale
    }

    fun addChild(node: Node) {
        node.removeFromParent()
        node.parent = this
        _children += node
    }

    fun removeFromParent() {
        parent?._children?.remove(this)
        parent = null
    }

    fun removeAllChildren() {
        _children.forEach { it.parent = null }
        _children.clear()
    }

    /** Where a point in the scene is, in this node's own coordinates. */
    fun convertFromScene(sceneX: Double, sceneY: Double): Pair<Double, Double> {
        val chain = generateSequence(this) { it.parent }.toList().reversed()
        var px = sceneX
        var py = sceneY
        // The scene itself is the root: its position doesn't move what's in it.
        for (node in chain.drop(1)) {
            px = (px - node.x) / node.xScale
            py = (py - node.y) / node.yScale
        }
        return px to py
    }

    // Actions

    private val running = mutableListOf<Action.Runner>()

    fun run(action: Action) {
        running += action.runner(this)
    }

    fun removeAllActions() = running.clear()

    val hasActions: Boolean get() = running.isNotEmpty()

    internal fun advanceActions(dt: Double) {
        if (running.isEmpty()) return
        for (runner in running.toList()) {
            if (runner !in running) continue
            if (runner.advance(dt) >= 0) running.remove(runner)
        }
    }
}

/** A picture, or a rectangle of one color, with its anchor point at its position. */
open class SpriteNode(texture: Texture? = null) : Node() {
    var texture: Texture? = texture
    var width: Double = texture?.width?.toDouble() ?: 0.0
    var height: Double = texture?.height?.toDouble() ?: 0.0

    /** Drawn when there's no texture: a plain rectangle. */
    var color: PixelColor? = null
    var anchorX = 0.5
    var anchorY = 0.5

    fun anchor(x: Double, y: Double) {
        anchorX = x
        anchorY = y
    }

    fun size(width: Double, height: Double) {
        this.width = width
        this.height = height
    }

    /** Sets the picture and resizes to it, as the iOS code does after setting a texture. */
    fun show(texture: Texture?) {
        this.texture = texture
        if (texture != null) size(texture.width.toDouble(), texture.height.toDouble())
    }

    companion object {
        fun rect(color: PixelColor, width: Double, height: Double) = SpriteNode().also {
            it.color = color
            it.size(width, height)
        }
    }
}

/** SpriteKit's timing modes, for the two the game uses. */
enum class Timing { Linear, EaseOut }

/**
 * Something a node does over time. Each `runner` is one go at it, for one node.
 * A runner's `advance` returns the time left over once it's done, or -1 while
 * it's still going, so sequences carry the spare time on to the next step.
 */
abstract class Action {
    abstract fun runner(node: Node): Runner

    interface Runner {
        fun advance(dt: Double): Double
    }

    private class Timed(val duration: Double, val timing: Timing, val step: (from: Double, to: Double) -> Unit) : Runner {
        var elapsed = 0.0
        var started = false
        var onStart: (() -> Unit)? = null

        fun ease(t: Double) = when (timing) {
            Timing.Linear -> t
            Timing.EaseOut -> 1 - (1 - t) * (1 - t)
        }

        override fun advance(dt: Double): Double {
            if (!started) {
                started = true
                onStart?.invoke()
            }
            val before = if (duration <= 0) 0.0 else ease(minOf(1.0, elapsed / duration))
            elapsed += dt
            val after = if (duration <= 0) 1.0 else ease(minOf(1.0, elapsed / duration))
            step(before, after)
            return if (elapsed >= duration) elapsed - duration else -1.0
        }
    }

    companion object {
        fun wait(duration: Double, range: Double = 0.0) = object : Action() {
            override fun runner(node: Node): Runner {
                val length = if (range > 0) duration + Random.nextDouble(-range / 2, range / 2) else duration
                return Timed(maxOf(0.0, length), Timing.Linear) { _, _ -> }
            }
        }

        fun moveBy(dx: Double, dy: Double, duration: Double, timing: Timing = Timing.Linear) = object : Action() {
            override fun runner(node: Node): Runner = Timed(duration, timing) { from, to ->
                node.x += dx * (to - from)
                node.y += dy * (to - from)
            }
        }

        fun moveTo(x: Double, y: Double, duration: Double, timing: Timing = Timing.Linear) = object : Action() {
            override fun runner(node: Node): Runner {
                var startX = 0.0
                var startY = 0.0
                return Timed(duration, timing) { _, to ->
                    node.x = startX + (x - startX) * to
                    node.y = startY + (y - startY) * to
                }.also {
                    it.onStart = {
                        startX = node.x
                        startY = node.y
                    }
                }
            }
        }

        fun fadeAlpha(to: Double, duration: Double) = object : Action() {
            override fun runner(node: Node): Runner {
                var start = 0.0
                return Timed(duration, Timing.Linear) { _, t -> node.alpha = start + (to - start) * t }
                    .also { it.onStart = { start = node.alpha } }
            }
        }

        fun fadeIn(duration: Double) = fadeAlpha(1.0, duration)
        fun fadeOut(duration: Double) = fadeAlpha(0.0, duration)

        fun run(block: () -> Unit) = object : Action() {
            override fun runner(node: Node): Runner = object : Runner {
                override fun advance(dt: Double): Double {
                    block()
                    return dt
                }
            }
        }

        fun removeFromParent() = object : Action() {
            override fun runner(node: Node): Runner = object : Runner {
                override fun advance(dt: Double): Double {
                    node.removeFromParent()
                    return dt
                }
            }
        }

        fun sequence(actions: List<Action>) = repeatEach(actions, count = 1)
        fun sequence(vararg actions: Action) = sequence(actions.toList())

        fun repeat(action: Action, count: Int) = repeatEach(listOf(action), count)

        fun repeatForever(action: Action) = repeatEach(listOf(action), count = -1)

        /** The actions one after another, `count` times through (forever if negative). */
        private fun repeatEach(actions: List<Action>, count: Int) = object : Action() {
            override fun runner(node: Node): Runner = object : Runner {
                var index = 0
                var round = 0
                var current: Runner? = null

                override fun advance(dt: Double): Double {
                    var left = dt
                    // A guard against a loop of actions that take no time at all.
                    var steps = 0
                    while (true) {
                        if (count in 0..round || actions.isEmpty()) return left
                        val runner = current ?: actions[index].runner(node).also { current = it }
                        val spare = runner.advance(left)
                        if (spare < 0) return -1.0
                        left = spare
                        current = null
                        index += 1
                        if (index == actions.size) {
                            index = 0
                            round += 1
                        }
                        steps += 1
                        if (count < 0 && steps > 1000) return -1.0
                    }
                }
            }
        }

        fun group(actions: List<Action>) = object : Action() {
            override fun runner(node: Node): Runner = object : Runner {
                val runners = actions.map { it.runner(node) }.toMutableList()
                var spare = Double.MAX_VALUE

                override fun advance(dt: Double): Double {
                    for (runner in runners.toList()) {
                        val left = runner.advance(dt)
                        if (left >= 0) {
                            spare = minOf(spare, left)
                            runners.remove(runner)
                        }
                    }
                    return if (runners.isEmpty()) (if (spare == Double.MAX_VALUE) dt else spare) else -1.0
                }
            }
        }

        fun group(vararg actions: Action) = group(actions.toList())
    }
}

/** Where the safe area is, in screen pixels from each edge. */
data class Insets(val left: Double, val top: Double, val right: Double, val bottom: Double) {
    companion object {
        val zero = Insets(0.0, 0.0, 0.0, 0.0)
    }
}

/** A finger on the screen, as a scene sees it. */
class Touch(
    /** Android's pointer id: the same for one finger from down to up. */
    val id: Int,
    /** In the scene, in game pixels, y up. */
    val sceneX: Double,
    val sceneY: Double,
    /** In points on the screen (dp), y down: what the gesture reader measures swipes in. */
    val viewX: Double,
    val viewY: Double,
    /** Seconds, on the same clock as the scene's update time. */
    val time: Double,
)
