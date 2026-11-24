//
//  GameView.kt
//
//  Holds the scene on screen and keeps the game's pixels whole: the game is
//  drawn so each game pixel is a whole number of screen pixels (PixelLayout).
//  Switches between the menus and a run. The Android counterpart of
//  skate/GameViewController.swift and SpriteKit's SKView.
//

package com.tuesdaygames.skate.game

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.os.SystemClock
import android.view.MotionEvent
import android.view.View
import com.tuesdaygames.skate.rules.City
import com.tuesdaygames.skate.rules.Level
import com.tuesdaygames.skate.rules.PixelLayout
import com.tuesdaygames.skate.rules.Progress
import com.tuesdaygames.skate.rules.Size
import com.tuesdaygames.skate.sound.Music
import com.tuesdaygames.skate.sound.Sounds
import com.tuesdaygames.skate.store.Store

@SuppressLint("ViewConstructor")
class GameView(
    context: Context,
    private val progress: Progress,
    private val store: Store,
    /** The menu page to open on (debug builds can ask for another). */
    private val startPage: MenuScene.Page,
    /** What the store shows its payment sheet over (the Activity). */
    private val storeHost: () -> Any?,
    /** Debug builds show frames per second in the corner, as SpriteKit does. */
    private val showsFPS: Boolean,
) : View(context), SceneRouter {

    private var layout: PixelLayout? = null
    private var current: PixelScene? = null

    /** The scene fading out, while one fades in. */
    private var leaving: PixelScene? = null
    private var transitionStart = 0.0

    /** Things to do once the game has a size: say, a debug switch opening a spot. */
    private val onceLaidOut = mutableListOf<(GameView) -> Unit>()

    var safeInsets: Insets = Insets.zero
        set(value) {
            field = value
            current?.safeInsets = value
        }

    private val paint = Paint().apply {
        isFilterBitmap = false
        isAntiAlias = false
        isDither = false
    }
    private val fillPaint = Paint().apply { isAntiAlias = false }
    private val rect = RectF()
    private var lastFrame: Double? = null

    // Frames per second, for debug builds.
    private var fpsFrames = 0
    private var fpsSince = 0.0
    private var fpsText = ""
    private val fpsPaint = Paint().apply {
        color = Color.WHITE
        isAntiAlias = true
    }

    init {
        setBackgroundColor(Color.BLACK)
        // Tips can be bought from the menus; the store loads in the background.
        store.onChange = { (current as? MenuScene)?.layoutScene() }
    }

    /** Runs `action` as soon as the game has a size (straight away if it has). */
    fun whenLaidOut(action: (GameView) -> Unit) {
        if (layout != null) action(this) else onceLaidOut += action
    }

    val scene: PixelScene? get() = current

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        if (w <= 0 || h <= 0) return
        val layout = PixelLayout(Size(w.toDouble(), h.toDouble()), 1.0)
        this.layout = layout
        val scene = current
        if (scene != null) {
            scene.size = layout.gameSize
            configure(scene)
        } else {
            showMenu(startPage)
            val waiting = onceLaidOut.toList()
            onceLaidOut.clear()
            waiting.forEach { it(this) }
        }
    }

    private fun configure(scene: PixelScene) {
        val layout = layout ?: return
        scene.router = this
        scene.pointsPerPixel = layout.pointsPerPixel
        scene.screenPixelsPerPixel = layout.scale
        scene.safeInsets = safeInsets
    }

    private fun present(scene: PixelScene) {
        configure(scene)
        scene.moveToView()
        if (current != null) {
            // A quick fade through black, as SpriteKit's fade transition does.
            leaving = current
            transitionStart = now()
        }
        current = scene
        invalidate()
    }

    // SceneRouter

    override fun showMenu(page: MenuScene.Page) {
        val layout = layout ?: return
        Music.stop()
        Sounds.stopAllLoops()
        val menu = current as? MenuScene
        if (menu != null) {
            menu.show(page)
        } else {
            present(MenuScene(layout.gameSize, page, progress, store, storeHost))
        }
    }

    override fun play(level: Level, city: City) {
        val layout = layout ?: return
        present(GameScene(layout.gameSize, level, city, progress.outfit, progress))
    }

    /** Android's back button. False when there's nowhere further back to go. */
    fun back(): Boolean = current?.back() ?: false

    fun willResignActive() {
        current?.willResignActive()
    }

    // The loop

    private fun now() = System.nanoTime() / 1e9

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val scene = current ?: return
        val layout = layout ?: return
        val time = now()
        val dt = (time - (lastFrame ?: time)).coerceIn(0.0, 0.1)
        lastFrame = time

        // As SpriteKit does: the scene's update, then its actions, then drawing.
        scene.update(time)
        advanceActions(scene, dt)

        // The fade: the old scene goes to black over 0.1 s, then the new one comes up from black.
        val fadeSeconds = 0.1
        val elapsed = time - transitionStart
        val leaving = leaving
        val shown = if (leaving != null && elapsed < fadeSeconds) leaving else scene
        if (leaving != null && elapsed >= 2 * fadeSeconds) this.leaving = null
        draw(shown, canvas, layout)
        if (this.leaving != null) {
            val black = if (elapsed < fadeSeconds) elapsed / fadeSeconds else 2 - elapsed / fadeSeconds
            fillPaint.color = Color.argb((black.coerceIn(0.0, 1.0) * 255).toInt(), 0, 0, 0)
            canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), fillPaint)
        }

        if (showsFPS) drawFPS(canvas, time)
        // Keep going, every frame.
        postInvalidateOnAnimation()
    }

    private fun advanceActions(root: Node, dt: Double) {
        // A snapshot first: actions can add and remove nodes as they go.
        val all = mutableListOf<Node>()
        fun collect(node: Node) {
            all += node
            node.children.forEach(::collect)
        }
        collect(root)
        for (node in all) node.advanceActions(dt)
    }

    private class Item(val sprite: SpriteNode, val x: Double, val y: Double, val sx: Double, val sy: Double, val alpha: Double, val z: Double, val order: Int)

    private val items = ArrayList<Item>()

    private fun draw(scene: PixelScene, canvas: Canvas, layout: PixelLayout) {
        val scale = layout.scale.toDouble()
        val frame = layout.frame
        val sceneWidth = scene.size.width
        val sceneHeight = scene.size.height
        val camera = scene.camera
        val viewLeft = if (camera != null) camera.x - sceneWidth / 2 else 0.0
        val viewBottom = if (camera != null) camera.y - sceneHeight / 2 else 0.0

        canvas.save()
        canvas.clipRect(frame.minX.toFloat(), frame.minY.toFloat(), frame.maxX.toFloat(), frame.maxY.toFloat())
        canvas.drawColor(scene.backgroundColor.argb)

        // Everything visible, then drawn deepest first, as SpriteKit does with `ignoresSiblingOrder`.
        items.clear()
        var order = 0
        fun collect(node: Node, px: Double, py: Double, sx: Double, sy: Double, alpha: Double, z: Double) {
            if (node.isHidden) return
            val wx = px + node.x * sx
            val wy = py + node.y * sy
            val nsx = sx * node.xScale
            val nsy = sy * node.yScale
            val a = alpha * node.alpha
            val nz = z + node.z
            if (node is SpriteNode && a > 0.004 && node.width > 0 && node.height > 0) {
                items += Item(node, wx, wy, nsx, nsy, a, nz, order++)
            }
            for (child in node.children) collect(child, wx, wy, nsx, nsy, a, nz)
        }
        for (child in scene.children) collect(child, 0.0, 0.0, 1.0, 1.0, 1.0, 0.0)
        items.sortWith(compareBy<Item> { it.z }.thenBy { it.order })

        for (item in items) {
            val sprite = item.sprite
            val w = sprite.width * item.sx
            val h = sprite.height * item.sy
            val left = item.x - sprite.anchorX * w - viewLeft
            val bottom = item.y - sprite.anchorY * h - viewBottom
            // Off screen: skip it.
            if (left > sceneWidth || left + w < 0 || bottom > sceneHeight || bottom + h < 0) continue
            rect.set(
                (frame.minX + left * scale).toFloat(),
                (frame.minY + (sceneHeight - bottom - h) * scale).toFloat(),
                (frame.minX + (left + w) * scale).toFloat(),
                (frame.minY + (sceneHeight - bottom) * scale).toFloat(),
            )
            val alpha = (item.alpha.coerceIn(0.0, 1.0) * 255).toInt()
            val texture = sprite.texture
            if (texture != null) {
                paint.alpha = alpha
                canvas.drawBitmap(texture.bitmap, null, rect, paint)
            } else {
                val color = sprite.color ?: continue
                fillPaint.color = color.argb
                fillPaint.alpha = color.a * alpha / 255
                canvas.drawRect(rect, fillPaint)
            }
        }
        canvas.restore()
    }

    private fun drawFPS(canvas: Canvas, time: Double) {
        fpsFrames += 1
        if (time - fpsSince >= 0.5) {
            fpsText = "%.1f fps".format(fpsFrames / (time - fpsSince))
            fpsSince = time
            fpsFrames = 0
        }
        fpsPaint.textSize = 12 * resources.displayMetrics.density
        val textWidth = fpsPaint.measureText(fpsText)
        fillPaint.color = Color.argb(140, 0, 0, 0)
        canvas.drawRect(width - textWidth - 12, height - fpsPaint.textSize - 10, width.toFloat(), height.toFloat(), fillPaint)
        canvas.drawText(fpsText, width - textWidth - 6, height - 6f, fpsPaint)
    }

    // Touches

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        val scene = current ?: return true
        val layout = layout ?: return true
        fun touch(index: Int): Touch {
            val px = event.getX(index).toDouble()
            val py = event.getY(index).toDouble()
            val scale = layout.scale.toDouble()
            val camera = scene.camera
            val viewLeft = if (camera != null) camera.x - scene.size.width / 2 else 0.0
            val viewBottom = if (camera != null) camera.y - scene.size.height / 2 else 0.0
            val density = resources.displayMetrics.density.toDouble()
            return Touch(
                id = event.getPointerId(index),
                sceneX = viewLeft + (px - layout.frame.minX) / scale,
                sceneY = viewBottom + scene.size.height - (py - layout.frame.minY) / scale,
                viewX = px / density,
                viewY = py / density,
                // Android stamps touches on its uptime clock; this puts them on the frame clock.
                time = event.eventTime / 1000.0 + (now() - SystemClock.uptimeMillis() / 1000.0),
            )
        }
        // Touches go to the scene being shown, not one still fading out.
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> scene.touchBegan(touch(event.actionIndex))
            MotionEvent.ACTION_MOVE -> for (index in 0 until event.pointerCount) scene.touchMoved(touch(index))
            MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP -> scene.touchEnded(touch(event.actionIndex))
            MotionEvent.ACTION_CANCEL -> for (index in 0 until event.pointerCount) scene.touchCancelled(touch(index))
        }
        return true
    }
}
