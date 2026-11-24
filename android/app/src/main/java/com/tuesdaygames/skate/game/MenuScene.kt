//
//  MenuScene.kt
//
//  The title screen, city picker, spot list, skater builder, full game screen
//  and tip jar, all in one scene that swaps pages. Ported from skate/UI/Menus.swift.
//

package com.tuesdaygames.skate.game

import com.tuesdaygames.skate.art.Palette
import com.tuesdaygames.skate.art.PixelCanvas
import com.tuesdaygames.skate.art.PixelColor
import com.tuesdaygames.skate.art.FeatureArt
import com.tuesdaygames.skate.art.StreetArt
import com.tuesdaygames.skate.art.ThemeArt
import com.tuesdaygames.skate.art.UIArt
import com.tuesdaygames.skate.haptics.Haptics
import com.tuesdaygames.skate.rules.City
import com.tuesdaygames.skate.rules.ColorChoice
import com.tuesdaygames.skate.rules.Lane
import com.tuesdaygames.skate.rules.Level
import com.tuesdaygames.skate.rules.Outfit
import com.tuesdaygames.skate.rules.PixelFont
import com.tuesdaygames.skate.rules.Progress
import com.tuesdaygames.skate.rules.Rect
import com.tuesdaygames.skate.rules.Size
import com.tuesdaygames.skate.rules.SkaterKind
import com.tuesdaygames.skate.rules.Theme
import com.tuesdaygames.skate.rules.rounded
import com.tuesdaygames.skate.rules.tutorial
import com.tuesdaygames.skate.sound.Music
import com.tuesdaygames.skate.sound.Sound
import com.tuesdaygames.skate.sound.Sounds
import com.tuesdaygames.skate.store.PurchaseOutcome
import com.tuesdaygames.skate.store.Store
import com.tuesdaygames.skate.store.StoreProduct
import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

class MenuScene(
    size: Size,
    page: Page,
    private val progress: Progress,
    private val store: Store,
    /** What the store shows its payment sheet over (the Activity). */
    private val storeHost: () -> Any?,
) : PixelScene(size) {

    sealed interface Page {
        data object Title : Page
        data object Cities : Page
        data class Spots(val city: City) : Page
        data object Builder : Page

        /** The full game: coming soon, with a link to the tip jar. */
        data object FullGame : Page

        /** The tip jar, and the page its BACK button returns to. */
        data class Tips(val back: Page) : Page
    }

    /** What the tip jar says after a purchase. */
    private var tipMessage = ""

    var page: Page = page
        private set
    private val backdrop = Node()
    private var strips: List<ParallaxStrip> = emptyList()
    private val content = Node()
    private val buttons = mutableListOf<PixelButton>()
    private var scroll = 0.0
    private var lastUpdate: Double? = null
    private var touchStart: Pair<Double, Double>? = null

    /** Which city the city picker is showing. */
    private var cityIndex = 0

    init {
        (page as? Page.Spots)?.let { spots -> City.all.indexOf(spots.city).takeIf { it >= 0 }?.let { cityIndex = it } }
    }

    override fun didMove() {
        val look = ThemeArt.look(Theme.Skidmore)
        backgroundColor = look.sky
        addChild(backdrop)
        val groundTop = StreetArt.groundTop.toDouble()
        strips = look.layers.mapIndexed { index, layer ->
            ParallaxStrip(layer.canvas.texture(), layer.factor, groundTop + layer.lift, (-30 + index * 10).toDouble())
        } + ParallaxStrip(look.ground.texture(), 1.0, 0.0, -5.0) + skidmorePlaza()
        strips.forEach { backdrop.addChild(it.node) }
        content.z = 50.0
        addChild(content)
        layoutScene()
    }

    /** Skidmore Fountain going by on the back of the plaza, and the MAX tracks along the front. */
    private fun skidmorePlaza(): List<ParallaxStrip> {
        val fountain = FeatureArt.fountain(64)
        val spaced = PixelCanvas(300, fountain.height)
        spaced.draw(fountain, 0, 0)
        val tracks = FeatureArt.tracks(60)
        return listOf(
            ParallaxStrip(tracks.texture(), 1.0, StreetArt.baseline(Lane.Front.raw.toDouble()), -4.0),
            ParallaxStrip(spaced.texture(), 1.0, StreetArt.baseline(Lane.Back.raw.toDouble()), -3.0),
        )
    }

    override fun update(currentTime: Double) {
        val dt = min(0.1, currentTime - (lastUpdate ?: currentTime))
        lastUpdate = currentTime
        // The street drifts by behind the menus.
        scroll += dt * 24
        backdrop.x = -scroll.rounded()
        strips.forEach { it.update(scroll.rounded()) }
    }

    fun show(page: Page) {
        this.page = page
        layoutScene()
        if (page is Page.Tips && store.state.tips.isEmpty()) store.refresh()
    }

    override fun layoutScene() {
        if (!isShowing) return
        strips.forEach { it.layout(size.width + 64) }
        content.removeAllChildren()
        buttons.clear()
        when (val page = page) {
            Page.Title -> buildTitle()
            Page.Cities -> buildCities()
            is Page.Spots -> buildSpots(page.city)
            Page.Builder -> buildBuilder()
            Page.FullGame -> buildFullGame()
            is Page.Tips -> buildTips(page.back)
        }
    }

    /** Android's back button goes back a page, as each page's BACK button does. */
    override fun back(): Boolean {
        when (val page = page) {
            Page.Title -> return false
            Page.Cities, Page.Builder -> show(Page.Title)
            is Page.Spots, Page.FullGame -> show(Page.Cities)
            is Page.Tips -> show(page.back)
        }
        return true
    }

    // Building blocks

    private fun label(
        text: String, x: Double, y: Double, anchorX: Double = 0.5, anchorY: Double = 0.5,
        color: PixelColor = Palette.white, scale: Double = 1.0,
    ): PixelLabel {
        val label = PixelLabel(anchorX, anchorY)
        label.ink = color
        label.text = text
        label.setScale(scale)
        label.position(x.rounded(), y.rounded())
        content.addChild(label)
        return label
    }

    private fun button(
        text: String, x: Double, y: Double, minWidth: Double = 0.0,
        color: PixelColor = PixelColor(0x24308C), action: () -> Unit,
    ): PixelButton {
        val button = PixelButton(text, minWidth, color, action)
        button.position(x.rounded(), y.rounded())
        content.addChild(button)
        buttons += button
        return button
    }

    private fun panel(rect: Rect) {
        val panel = SpriteNode(UIArt.panel(rect.width.toInt(), rect.height.toInt()).texture())
        panel.anchor(0.0, 0.0)
        panel.position(rect.minX.rounded(), rect.minY.rounded())
        panel.z = -1.0
        content.addChild(panel)
    }

    private fun skaterPreview(x: Double, y: Double, scale: Double) {
        val preview = SpriteNode(SkaterLook(progress.outfit).standing)
        preview.anchor(0.5, 0.0)
        preview.setScale(scale)
        preview.position(x.rounded(), y.rounded())
        content.addChild(preview)
        val shadow = SpriteNode(StreetArt.shadow(20).texture())
        shadow.setScale(scale)
        shadow.position(x.rounded(), y.rounded())
        shadow.z = -0.5
        content.addChild(shadow)
    }

    /** The city's letters, found ones in gold and the rest in grey. */
    private fun letterRuns(city: City): List<Pair<String, PixelColor>> {
        val found = progress.letters(city)
        return city.letters.mapIndexed { index, letter ->
            letter.toString() to if (index in found) Palette.yellow else PixelColor(0x9C9C9C)
        }
    }

    private fun runsLabel(runs: List<Pair<String, PixelColor>>, x: Double, y: Double, anchorX: Double, anchorY: Double) {
        val node = SpriteNode(TextTextures.texture(runs))
        node.anchor(anchorX, anchorY)
        node.position(x.rounded(), y.rounded())
        content.addChild(node)
    }

    // Pages

    private fun buildTitle() {
        val safe = safeFrame
        // The skater on the left; the name and buttons in a column on the right.
        skaterPreview(safe.minX + safe.width * 0.25, StreetArt.baseline(1.0), scale = 2.0)
        val buttonX = safe.minX + safe.width * 0.68
        label("SKATE", buttonX, safe.maxY - 10, color = Palette.yellow, scale = 2.0)
        label("TUESDAY GAMES", buttonX, safe.maxY - 25, color = Palette.white)
        button("PLAY", buttonX, 58.0, minWidth = 64.0, color = PixelColor(0x00A844)) { show(Page.Cities) }
        // The tip jar, right under PLAY, with a jar of coins beside it.
        button("TIP JAR", buttonX, 42.0, minWidth = 64.0, color = tipColor) { openTips(Page.Title) }
        val jar = SpriteNode(UIArt.tipJar().texture())
        jar.anchor(1.0, 0.5)
        jar.position((buttonX - 36).rounded(), 42.0)
        content.addChild(jar)
        button("TUTORIAL", buttonX, 26.0, minWidth = 64.0) { router?.play(Level.tutorial, City.portland) }
        button("SKATER", buttonX, 10.0, minWidth = 64.0) { show(Page.Builder) }
        addAudioToggles(safe.minX + 9, safe.maxY - 8)
    }

    /** Music and sound on/off, side by side, starting at (x, y) (the first one's center). */
    private fun addAudioToggles(x: Double, y: Double) {
        for ((index, isMusic) in listOf(true, false).withIndex()) {
            val on = if (isMusic) Music.isOn else !Sounds.isMuted
            val icon = if (isMusic) UIArt.musicIcon(on) else UIArt.soundIcon(on)
            val toggle = PixelButton.icon(icon.texture()) {
                if (isMusic) Music.isOn = !Music.isOn else Sounds.isMuted = !Sounds.isMuted
                layoutScene()
            }
            toggle.position((x + index * 16).rounded(), y.rounded())
            content.addChild(toggle)
            buttons += toggle
        }
    }

    private fun buildCities() {
        val safe = safeFrame
        val city = City.all[cityIndex]
        panel(Rect(safe.minX, safe.minY + 2, safe.width, safe.height - 2))
        label("CHOOSE A CITY", safe.midX, safe.maxY - 8)
        label("${cityIndex + 1}/${City.all.size}", safe.maxX - 4, safe.maxY - 8, anchorX = 1.0, color = PixelColor(0x9C9C9C))

        // As big as fits between the arrows, up to double size.
        val nameWidth = PixelFont.width(city.name)
        val nameScale = PixelFont.fittingScale(nameWidth, safe.width - 44, 2.0, screenPixelsPerPixel)
        // Line the left edge up with a screen pixel, so every letter stays sharp.
        val nameLeft = snapToScreen(safe.midX - nameWidth * nameScale / 2)
        val name = label(
            city.name, 0.0, 0.0, anchorX = 0.0,
            color = if (city.isOpen) Palette.white else PixelColor(0x9C9C9C), scale = nameScale,
        )
        name.position(nameLeft, safe.midY + 10)
        button("<", safe.minX + 12, safe.midY + 10) { changeCity(-1) }
        button(">", safe.maxX - 12, safe.midY + 10) { changeCity(1) }

        if (city.isOpen) {
            runsLabel(letterRuns(city), safe.midX, safe.midY - 6, 0.5, 0.5)
            label("FREE", safe.midX, safe.midY - 17, color = Palette.green)
            button("GO", safe.maxX - 26, safe.minY + 12, minWidth = 40.0, color = PixelColor(0x00A844)) { show(Page.Spots(city)) }
        } else {
            // Locked: part of the full game, which isn't out yet.
            val lock = SpriteNode(UIArt.padlock().texture())
            lock.anchor(1.0, 0.5)
            val comingWidth = PixelFont.width("COMING SOON").toDouble()
            lock.position((safe.midX - comingWidth / 2 - 4).rounded(), safe.midY - 8)
            content.addChild(lock)
            label("COMING SOON", safe.midX, safe.midY - 8, color = Palette.yellow)
            label("IN THE FULL GAME", safe.midX, safe.midY - 19, color = PixelColor(0x9C9C9C))
            button("FULL GAME", safe.maxX - 34, safe.minY + 12, minWidth = 56.0, color = PixelColor(0x8C38C8)) { show(Page.FullGame) }
        }
        button("BACK", safe.minX + 20, safe.minY + 12) { show(Page.Title) }
        button("TIP JAR", (safe.midX - 6).rounded(), safe.minY + 12, minWidth = 44.0, color = tipColor) { openTips(Page.Cities) }
    }

    // Full game and tips

    private fun buildFullGame() {
        val safe = safeFrame
        panel(Rect(safe.minX, safe.minY + 2, safe.width, safe.height - 2))
        label("FULL GAME", safe.midX, safe.maxY - 8, color = Palette.yellow)
        val lines = listOf(
            "8 MORE CITIES TO SKATE:" to Palette.white,
            "SAN FRANCISCO, LOS ANGELES," to PixelColor(0xBCBCBC),
            "NEW YORK, FRESNO, SACRAMENTO," to PixelColor(0xBCBCBC),
            "AUSTIN, SEATTLE AND ASTORIA" to PixelColor(0xBCBCBC),
        )
        for ((index, line) in lines.withIndex()) label(line.first, safe.midX, safe.maxY - 22 - index * 10, color = line.second)
        val state = store.state
        val fullGame = state.fullGame
        if (Store.fullGameOnSale && fullGame != null && !state.isUnlocked) {
            button("BUY ${fullGame.price}", safe.midX, safe.minY + 30, minWidth = 64.0, color = PixelColor(0x00A844)) { buy(fullGame) }
        } else if (state.isUnlocked) {
            label("YOU HAVE IT. THANK YOU!", safe.midX, safe.minY + 30, color = Palette.green)
        } else {
            label("COMING SOON FOR ${Store.fullGamePrice}", safe.midX, safe.minY + 30, color = Palette.yellow)
        }
        button("BACK", safe.minX + 20, safe.minY + 12) { show(Page.Cities) }
        button("TIP JAR", safe.maxX - 30, safe.minY + 12, minWidth = 48.0, color = tipColor) { openTips(Page.FullGame) }
    }

    private fun openTips(page: Page) {
        tipMessage = ""
        show(Page.Tips(back = page))
    }

    private fun buildTips(back: Page) {
        val safe = safeFrame
        panel(Rect(safe.minX, safe.minY + 2, safe.width, safe.height - 2))
        label("TIP JAR", safe.midX, safe.maxY - 8, color = Palette.yellow)
        label("TIPS ARE OPTIONAL AND", safe.midX, safe.maxY - 22, color = PixelColor(0xBCBCBC))
        label("DON'T UNLOCK ANYTHING.", safe.midX, safe.maxY - 32, color = PixelColor(0xBCBCBC))
        val state = store.state
        val products = state.tips
        val rowY = safe.midY - 4
        val spacing = min(64.0, (safe.width - 20) / 3)
        for ((index, tip) in tipLabels.withIndex()) {
            val x = safe.midX + (index - 1) * spacing
            val product = products.getOrNull(index)
            button(product?.price ?: tip.second, x, rowY, minWidth = 48.0, color = tipColor) {
                if (product != null) {
                    buy(product)
                } else {
                    tipMessage = if (store.state.hasLoaded) "TIPS AREN'T SET UP YET" else "ONE MOMENT..."
                    layoutScene()
                }
            }
            label(tip.first, x, rowY - 13, color = PixelColor(0x9C9C9C))
        }
        if (tipMessage.isNotEmpty()) label(tipMessage, safe.midX, safe.minY + 28, color = Palette.yellow)
        val jar = SpriteNode(UIArt.tipJar().texture())
        jar.position((safe.midX - 34).rounded(), (safe.maxY - 8).rounded())
        content.addChild(jar)
        button("BACK", safe.minX + 20, safe.minY + 12) { show(back) }
    }

    private fun buy(product: StoreProduct) {
        store.buy(product, storeHost()) { outcome ->
            tipMessage = when (outcome) {
                PurchaseOutcome.Success -> if (product.id == Store.fullGameID) "" else "THANK YOU!"
                PurchaseOutcome.Pending -> "WAITING FOR APPROVAL"
                PurchaseOutcome.Cancelled -> ""
                PurchaseOutcome.Failed -> "THAT DIDN'T WORK. TRY AGAIN?"
            }
            if (outcome == PurchaseOutcome.Success) Sounds.play(Sound.Finish)
            layoutScene()
        }
    }

    private fun changeCity(step: Int) {
        cityIndex = (cityIndex + step + City.all.size) % City.all.size
        Sounds.play(Sound.Lane)
        Haptics.tick()
        layoutScene()
    }

    private fun buildSpots(city: City) {
        val safe = safeFrame
        panel(Rect(safe.minX, safe.minY + 2, safe.width, safe.height - 2))
        val headerY = safe.maxY - 8
        val back = button("BACK", safe.minX + 20, headerY) { show(Page.Cities) }
        val tip = button("TIP JAR", safe.maxX - 26, headerY, minWidth = 44.0, color = tipColor) { openTips(Page.Spots(city)) }
        // The city's name between the two buttons, smaller if it has to be.
        val roomForName = 2 * min(safe.midX - back.frame.maxX, tip.frame.minX - safe.midX) - 6
        val nameWidth = PixelFont.width(city.name)
        val nameScale = PixelFont.fittingScale(nameWidth, roomForName, 1.0, screenPixelsPerPixel)
        val name = label(city.name, 0.0, 0.0, anchorX = 0.0, color = Palette.yellow, scale = nameScale)
        name.position(snapToScreen(safe.midX - nameWidth * nameScale / 2), headerY)

        // The list fills the rest of the panel: shrunk to fit if it has to be, with
        // the letters, goal dots and best scores lined up on the right.
        val list = SpotsList(city, progress) { level -> router?.play(level, city) }
        val area = Rect(safe.minX + 2, safe.minY + 5, safe.width - 5, safe.maxY - 17 - (safe.minY + 5))
        val scale = min(
            PixelFont.fittingScale(list.naturalWidth, area.width, 1.0, screenPixelsPerPixel),
            PixelFont.fittingScale(list.naturalHeight, area.height, 1.0, screenPixelsPerPixel),
        )
        list.build(floor(area.width / scale).toInt())
        list.setScale(scale)
        list.position(snapToScreen(area.minX), snapToScreen(area.maxY))
        content.addChild(list)
        buttons += list.buttons
    }

    /** The nearest screen pixel, so anything scaled down still lands sharp. */
    private fun snapToScreen(value: Double): Double {
        val step = 1.0 / max(1, screenPixelsPerPixel)
        return (value / step).rounded() * step
    }

    private class Row(val title: String, val value: String, val enabled: Boolean, val change: (Outfit, Int) -> Outfit)

    private fun buildBuilder() {
        val safe = safeFrame
        val outfit = progress.outfit
        panel(Rect(safe.minX + safe.width * 0.34, safe.minY + 2, safe.width * 0.66, safe.height - 2))
        label("YOUR SKATER", safe.minX + safe.width * 0.67, safe.maxY - 8, color = Palette.yellow)
        skaterPreview(safe.minX + safe.width * 0.17, StreetArt.baseline(1.0), scale = 2.0)

        val labelX = safe.minX + safe.width * 0.37
        val leftArrowX = safe.minX + safe.width * 0.66
        val rightArrowX = safe.maxX - 8
        val valueX = (leftArrowX + rightArrowX) / 2
        val rowHeight = 12.0

        val rows = listOf(
            Row("SKATER", outfit.kind.displayName, true) { o, step ->
                o.switchingSkater(Outfit.cycle(o.kind, SkaterKind.entries, step))
            },
            Row(if (outfit.kind.isDog) "BANDANA" else "SHIRT", outfit.shirt.displayName, true) { o, step ->
                o.copy(shirt = Outfit.cycle(o.shirt, ColorChoice.clothes, step))
            },
            Row("PANTS", if (outfit.kind.wearsPants) outfit.pants.displayName else "-", outfit.kind.wearsPants) { o, step ->
                o.copy(pants = Outfit.cycle(o.pants, ColorChoice.clothes, step))
            },
            Row("HAT", outfit.hat?.displayName ?: "NONE", true) { o, step ->
                o.copy(hat = Outfit.cycle(o.hat, Outfit.hatChoices, step))
            },
            Row("BOARD", outfit.board.displayName, true) { o, step ->
                o.copy(board = Outfit.cycle(o.board, ColorChoice.boards(pdxUnlocked = progress.hasPDXBoard), step))
            },
        )
        for ((index, row) in rows.withIndex()) {
            val y = safe.maxY - 24 - index * rowHeight
            label(row.title, labelX, y, anchorX = 0.0, color = if (row.enabled) Palette.white else PixelColor(0x7C7C7C))
            label(row.value, valueX, y, color = if (row.enabled) Palette.yellow else PixelColor(0x7C7C7C))
            for ((step, x) in listOf(-1 to leftArrowX, 1 to rightArrowX)) {
                val arrow = button(if (step < 0) "<" else ">", x, y) {
                    progress.outfit = row.change(progress.outfit, step)
                    Sounds.play(Sound.Lane)
                    Haptics.tick()
                    layoutScene()
                }
                arrow.isEnabled = row.enabled
            }
        }
        button("DONE", safe.minX + safe.width * 0.17, safe.minY + 10, minWidth = 44.0, color = PixelColor(0x00A844)) {
            show(Page.Title)
        }
    }

    // Touches

    override fun touchBegan(touch: Touch) {
        touchStart = touch.sceneX to touch.sceneY
    }

    override fun touchEnded(touch: Touch) {
        val start = touchStart ?: return
        touchStart = null
        val px = touch.sceneX
        val py = touch.sceneY
        // Swipe sideways through the cities.
        if (page == Page.Cities && abs(px - start.first) > 12 && abs(px - start.first) > abs(py - start.second)) {
            changeCity(if (px < start.first) 1 else -1)
            return
        }
        buttons.firstOrNull { it.hitInScene(start.first, start.second) && it.hitInScene(px, py) }?.let { button ->
            Sounds.play(Sound.Pop)
            Haptics.pop(charged = false)
            button.action()
        }
    }

    override fun touchCancelled(touch: Touch) {
        touchStart = null
    }

    companion object {
        /** The tip jar's color: loud on purpose. */
        val tipColor = PixelColor(0xE8508C)

        /** The three tips, always shown. Prices come from Google Play once it answers;
         *  until then they show the usual US prices. */
        val tipLabels = listOf("SMALL" to "$0.99", "GENEROUS" to "$2.99", "BIG" to "$4.99")
    }
}

/** A city's spots, one row each: the spot's button on the left, then its letters,
 *  a dot per goal and the best score, lined up in columns on the right. It's laid
 *  out in whole game pixels from its top-left corner; the menu scales it down to
 *  fit if the screen is short or narrow, so nothing ever overlaps. */
class SpotsList(private val city: City, private val progress: Progress, private val play: (Level) -> Unit) : Node() {
    val buttons = mutableListOf<PixelButton>()

    private val titles: List<String> get() = city.levels.mapIndexed { index, level -> "${index + 1} ${level.name}" }
    private val nameColumn: Int get() = titles.maxOfOrNull { PixelFont.width(it) + 8 } ?: 0
    private val lettersColumn: Int
        get() = city.levels.maxOfOrNull { level ->
            PixelFont.width(level.letters.joinToString("") { city.letters[it.index].toString() })
        } ?: 0
    private val dotsColumn: Int get() = max(0, (city.levels.maxOfOrNull { it.goals.size } ?: 0) * 3 - 1)

    /** Room for a five-digit score at least, so the columns don't jump about as scores go up. */
    private val scoreColumn: Int
        get() = (listOf(PixelFont.width("00000")) + city.levels.map { PixelFont.width("${progress.bestScore(it)}") }).max()

    /** The narrowest the list can be with nothing touching. */
    val naturalWidth: Int get() = nameColumn + nameGap + lettersColumn + columnGap + dotsColumn + columnGap + scoreColumn
    val naturalHeight: Int get() = max(0, city.levels.size * rowPitch - 1)

    /** Lay the rows out across `width` game pixels (at least `naturalWidth`); any
     *  extra room goes between the names and the columns. */
    fun build(width: Int) {
        removeAllChildren()
        buttons.clear()
        val fullWidth = max(width, naturalWidth)
        val scoreRight = fullWidth
        val dotsLeft = scoreRight - scoreColumn - columnGap - dotsColumn
        val lettersRight = dotsLeft - columnGap
        val found = progress.letters(city)

        for ((row, level) in city.levels.withIndex()) {
            val boxTop = -row * rowPitch
            val boxBottom = boxTop - buttonHeight
            // The text inside a button sits two pixels up from its bottom; the columns match it.
            val textY = (boxBottom + 2).toDouble()

            val button = PixelButton(titles[row]) { play(level) }
            val buttonWidth = PixelFont.width(titles[row]) + 8
            // A button's box hangs half its size either side of its position.
            button.position((buttonWidth / 2).toDouble(), (boxBottom + buttonHeight / 2).toDouble())
            addChild(button)
            buttons += button

            val runs = level.letters.map { it.index }.map {
                city.letters[it].toString() to if (it in found) Palette.yellow else PixelColor(0x9C9C9C)
            }
            if (runs.isNotEmpty()) {
                val letters = SpriteNode(TextTextures.texture(runs))
                letters.anchor(1.0, 0.0)
                letters.position(lettersRight.toDouble(), textY)
                addChild(letters)
            }

            // A dot for each goal: yellow once it's done.
            val doneGoals = progress.goalsDone(level)
            for ((index, goal) in level.goals.withIndex()) {
                val dot = SpriteNode.rect(if (goal.id in doneGoals) Palette.yellow else PixelColor(0x5C5C5C), 2.0, 2.0)
                dot.anchor(0.0, 0.0)
                dot.position((dotsLeft + index * 3).toDouble(), (boxBottom + 5).toDouble())
                addChild(dot)
            }

            val best = progress.bestScore(level)
            if (best > 0) {
                val score = PixelLabel(1.0, 0.0)
                score.text = "$best"
                score.position(scoreRight.toDouble(), textY)
                addChild(score)
            }
        }
    }

    companion object {
        const val rowPitch = 14
        const val buttonHeight = PixelFont.glyphHeight + 6
        const val nameGap = 6
        const val columnGap = 4
    }
}
