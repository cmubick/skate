//
//  PixelScene.kt
//
//  The pieces every scene shares: a base scene that knows the safe area, pixel
//  buttons and labels, and the scrolling backdrop strips. Ported from the top
//  of skate/UI/Menus.swift and the bottom of skate/GameScene.swift.
//

package com.tuesdaygames.skate.game

import com.tuesdaygames.skate.art.Palette
import com.tuesdaygames.skate.art.PixelColor
import com.tuesdaygames.skate.art.PixelText
import com.tuesdaygames.skate.art.UIArt
import com.tuesdaygames.skate.rules.City
import com.tuesdaygames.skate.rules.Level
import com.tuesdaygames.skate.rules.PixelFont
import com.tuesdaygames.skate.rules.Rect
import com.tuesdaygames.skate.rules.Size
import com.tuesdaygames.skate.rules.rounded
import kotlin.math.ceil
import kotlin.math.max

/** Moves between the menus and the game. The game view does this. */
interface SceneRouter {
    fun showMenu(page: MenuScene.Page)
    fun play(level: Level, city: City)
}

/** A scene sized in game pixels that keeps its controls inside the safe area. */
abstract class PixelScene(size: Size) : Node() {
    var size: Size = size
        set(value) {
            if (field != value) {
                field = value
                layoutScene()
            }
        }

    var router: SceneRouter? = null

    /** The color behind everything. */
    var backgroundColor: PixelColor = Palette.black

    /** What the screen is looking at, if not the scene's bottom-left corner. */
    var camera: Node? = null

    /** True once the scene is on screen (SpriteKit's `view != nil`). */
    var isShowing = false
        private set

    /** The screen's safe area, in screen pixels. */
    var safeInsets: Insets = Insets.zero
        set(value) {
            if (field != value) {
                field = value
                layoutScene()
            }
        }

    /** How many screen pixels one game pixel takes up (iOS: points per pixel). */
    var pointsPerPixel: Double = 1.0
        set(value) {
            if (field != value) {
                field = value
                layoutScene()
            }
        }

    /** How many screen pixels one game pixel takes up (11 on a 2400 x 1080 phone). */
    var screenPixelsPerPixel = 1
        set(value) {
            if (field != value) {
                field = value
                layoutScene()
            }
        }

    /** The safe area in game pixels, with the origin at the bottom left of the screen. */
    val safeFrame: Rect
        get() {
            val ppp = max(pointsPerPixel, 0.01)
            val left = max(4.0, (safeInsets.left / ppp).rounded() + 2)
            val right = max(4.0, (safeInsets.right / ppp).rounded() + 2)
            val top = max(3.0, (safeInsets.top / ppp).rounded() + 2)
            val bottom = max(2.0, (safeInsets.bottom / ppp).rounded())
            return Rect(left, bottom, size.width - left - right, size.height - top - bottom)
        }

    /** Called once, when the scene first goes on screen. */
    fun moveToView() {
        if (isShowing) return
        isShowing = true
        didMove()
    }

    protected open fun didMove() {}

    /** Put things in place for the current size and safe area. */
    open fun layoutScene() {}

    /** Called every frame, before actions run. `currentTime` is in seconds. */
    open fun update(currentTime: Double) {}

    open fun touchBegan(touch: Touch) {}
    open fun touchMoved(touch: Touch) {}
    open fun touchEnded(touch: Touch) {}
    open fun touchCancelled(touch: Touch) {}

    /** Android's back button or gesture. False lets the app go to the background. */
    open fun back(): Boolean = false

    /** The app is going into the background. */
    open fun willResignActive() {}
}

/** A line of pixel-font text. Hidden while it has no text. */
class PixelLabel(anchorX: Double, anchorY: Double) : SpriteNode() {
    init {
        anchor(anchorX, anchorY)
        isHidden = true
    }

    var text: String = ""
        set(value) {
            if (value != field) {
                field = value
                redraw()
            }
        }

    var ink: PixelColor = Palette.white
        set(value) {
            if (value != field) {
                field = value
                redraw()
            }
        }

    private fun redraw() {
        if (text.isEmpty()) {
            isHidden = true
            return
        }
        show(TextTextures.texture(text, ink))
        isHidden = false
    }
}

/** Text pictures, kept so the same text isn't drawn again every frame. */
object TextTextures {
    private val cache = HashMap<String, Texture>()

    /** The text drawn in `color` with a dark drop shadow, so it reads over anything. */
    fun texture(text: String, color: PixelColor = Palette.white): Texture {
        val key = "${text.uppercase()}|${color.r},${color.g},${color.b}"
        cache[key]?.let { return it }
        val texture = PixelText.canvas(text, color).texture()
        if (cache.size > 200) cache.clear()
        cache[key] = texture
        return texture
    }

    /** Text in several colors side by side. */
    fun texture(runs: List<Pair<String, PixelColor>>): Texture = PixelText.canvas(runs).texture()
}

/** A tappable box with a pixel-font label. */
class PixelButton(
    text: String,
    minWidth: Double = 0.0,
    private val color: PixelColor = PixelColor(0x24308C),
    var action: () -> Unit,
) : Node() {
    var isEnabled = true
        set(value) {
            field = value
            alpha = if (value) 1.0 else 0.4
        }
    private val box = SpriteNode().also { it.anchor(0.0, 0.0) }
    private val label = PixelLabel(0.0, 0.0)

    /** A picture instead of text, for the music and sound buttons. */
    private val iconNode = SpriteNode().also { it.anchor(0.0, 0.0) }
    private val minWidth = minWidth.toInt()

    var text: String
        get() = label.text
        set(value) {
            label.text = value
            redraw()
        }

    init {
        addChild(box)
        label.z = 1.0
        addChild(label)
        iconNode.z = 1.0
        addChild(iconNode)
        label.text = text
        redraw()
    }

    fun setIcon(icon: Texture) {
        iconNode.show(icon)
        redraw()
    }

    private fun redraw() {
        // Everything on whole pixels, so the text stays sharp.
        val iconWidth = if (iconNode.texture == null) 0 else iconNode.width.toInt()
        val textWidth = if (iconWidth > 0) iconWidth else PixelFont.width(label.text)
        val width = max(minWidth, textWidth + if (iconWidth > 0) 6 else 8)
        val height = PixelFont.glyphHeight + 6
        box.show(boxes.getOrPut(Triple(width, height, color)) { UIArt.box(width, height, color).texture() })
        box.position((-(width / 2)).toDouble(), (-(height / 2)).toDouble())
        label.position((-(width / 2) + (width - textWidth) / 2).toDouble(), (-(height / 2) + 2).toDouble())
        label.isHidden = iconWidth > 0 || label.text.isEmpty()
        iconNode.position(
            (-(width / 2) + (width - iconWidth) / 2).toDouble(),
            (-(height / 2) + (height - iconNode.height.toInt()) / 2).toDouble(),
        )
    }

    /** The box, in the button's parent's coordinates. */
    val frame: Rect get() = Rect(x + box.x, y + box.y, box.width, box.height)

    /** True if the point is on the button, with a little extra room for fingers.
     *  The point is in the button's parent's coordinates. */
    fun hit(px: Double, py: Double): Boolean {
        if (!isEnabled || isHidden || parent == null) return false
        return frame.insetBy(-3.0, -3.0).contains(px, py)
    }

    /** The same, for a point in the scene (for buttons inside a scaled-down group). */
    fun hitInScene(sceneX: Double, sceneY: Double): Boolean {
        val parent = parent ?: return false
        val (px, py) = parent.convertFromScene(sceneX, sceneY)
        return hit(px, py)
    }

    companion object {
        /** Button boxes, kept: the menus rebuild their buttons whenever anything changes. */
        private val boxes = HashMap<Triple<Int, Int, PixelColor>, Texture>()

        /** A square button with a picture on it. */
        fun icon(icon: Texture, color: PixelColor = PixelColor(0x24308C), action: () -> Unit) =
            PixelButton("", color = color, action = action).also { it.setIcon(icon) }
    }
}

/** A row of one texture, repeated across the screen and scrolled at a fraction of
 *  the camera's speed so far-off things move slower. */
class ParallaxStrip(private val texture: Texture, private val factor: Double, private val y: Double, z: Double) {
    val node = Node().also { it.z = z }
    private val tiles = mutableListOf<SpriteNode>()
    private val tileWidth: Double get() = texture.width.toDouble()

    fun layout(viewWidth: Double) {
        val needed = ceil(viewWidth / tileWidth).toInt() + 1
        while (tiles.size < needed) {
            val tile = SpriteNode(texture).also { it.anchor(0.0, 0.0) }
            node.addChild(tile)
            tiles += tile
        }
    }

    fun update(cameraLeft: Double) {
        val width = tileWidth
        val scrolled = cameraLeft * factor
        val offset = ((scrolled % width) + width) % width
        for ((index, tile) in tiles.withIndex()) {
            tile.position((cameraLeft - offset + index * width).rounded(), y)
        }
    }
}
