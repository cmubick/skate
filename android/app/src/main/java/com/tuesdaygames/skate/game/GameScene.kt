//
//  GameScene.kt
//
//  Draws a run and feeds it touches. All the rules live in `Run`; this file
//  only turns what the run is doing into pixels, sounds and haptics.
//  Ported from skate/GameScene.swift: keep the two the same.
//
//  The scene is sized in game pixels (at least 180 x 96), with the origin at the
//  bottom left and the street along the bottom.
//

package com.tuesdaygames.skate.game

import com.tuesdaygames.skate.art.FeatureArt
import com.tuesdaygames.skate.art.FeatureLook
import com.tuesdaygames.skate.art.LetterArt
import com.tuesdaygames.skate.art.Palette
import com.tuesdaygames.skate.art.PixelColor
import com.tuesdaygames.skate.art.StreetArt
import com.tuesdaygames.skate.art.ThemeArt
import com.tuesdaygames.skate.art.UIArt
import com.tuesdaygames.skate.haptics.Haptics
import com.tuesdaygames.skate.rules.AirTrick
import com.tuesdaygames.skate.rules.BailReason
import com.tuesdaygames.skate.rules.City
import com.tuesdaygames.skate.rules.Feature
import com.tuesdaygames.skate.rules.GestureEvent
import com.tuesdaygames.skate.rules.GestureReader
import com.tuesdaygames.skate.rules.Goal
import com.tuesdaygames.skate.rules.GoalTracker
import com.tuesdaygames.skate.rules.Level
import com.tuesdaygames.skate.rules.Outfit
import com.tuesdaygames.skate.rules.PixelFont
import com.tuesdaygames.skate.rules.Point
import com.tuesdaygames.skate.rules.Progress
import com.tuesdaygames.skate.rules.Run
import com.tuesdaygames.skate.rules.RunEvent
import com.tuesdaygames.skate.rules.Size
import com.tuesdaygames.skate.rules.SkaterState
import com.tuesdaygames.skate.rules.Trick
import com.tuesdaygames.skate.rules.Tuning
import com.tuesdaygames.skate.rules.Tutorial
import com.tuesdaygames.skate.rules.downtown
import com.tuesdaygames.skate.rules.rounded
import com.tuesdaygames.skate.rules.tutorial
import com.tuesdaygames.skate.sound.Music
import com.tuesdaygames.skate.sound.Sound
import com.tuesdaygames.skate.sound.Sounds
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

class GameScene(
    size: Size,
    private val level: Level,
    private val city: City,
    outfit: Outfit,
    private val progress: Progress,
) : PixelScene(size) {

    private val look = SkaterLook(outfit)
    private var run = Run(level)
    private var gestures = GestureReader()
    private var activeTouch: Int? = null

    private var lastUpdate: Double? = null
    private var stepTime = 0.0

    // The street.
    private val world = Node()
    private val cam = Node()
    private var strips: List<ParallaxStrip> = emptyList()
    private val featureNodes = mutableListOf<Pair<SpriteNode, Pair<FeatureLook, List<Texture>>>>()
    private val letterNodes = mutableMapOf<Int, SpriteNode>()

    // The skater.
    private val skater = Node()
    private val body = SpriteNode()
    private val board = SpriteNode()

    /** The last picture of a spinning board, so each new one leaves a ghost behind. */
    private var lastSpinStep: Int? = null
    private val shadow = SpriteNode(StreetArt.shadow().texture())
    private var sparkTimer = 0.0

    /** How far the camera has risen to keep a high jump on screen. */
    private var cameraLift = 0.0

    /** How far in from the left the skater sits, as a share of the screen. */
    private var cameraAnchor = 0.3

    /** True while the grind rumble and sound are on, so they can't be left running. */
    private var grindFeedbackOn = false

    /** The grind sound looping now: metal, concrete or a boardslide. */
    private var grindLoop: Sound? = null
    private var rollingSoundOn = false

    // The HUD, drawn over everything and fixed to the screen.
    private val scoreLabel = PixelLabel(0.0, 1.0)
    private val bestLabel = PixelLabel(0.0, 1.0)
    private val comboLabel = PixelLabel(0.5, 1.0)
    private val multiplierLabel = PixelLabel(0.5, 1.0)
    private val lettersLabel = SpriteNode().also { it.anchor(0.0, 0.0) }
    private val pauseButton = PixelButton(PixelFont.pauseSymbol) {}

    /** The combo meter: drains while you roll after a landing. Trick again before it's gone. */
    private val comboMeter = SpriteNode.rect(Palette.yellow, 1.0, 2.0)
    private var comboMeterX = 0.0
    private var comboMeterY = 0.0

    /** Goal and gap banners, callouts and the city celebration, over the street. */
    private val banners = Node()

    // The tutorial, when this run is one: the step to do, in a box over the street.
    private val tutorial: Tutorial? = if (level.id == Level.tutorial.id) Tutorial() else null
    private val tutorialBox = Node()

    // Goals.
    private val goalTracker: GoalTracker

    /** Done on earlier runs, and done on this one. */
    private val goalsBefore: Set<String>
    private val goalsThisRun = mutableSetOf<String>()
    private val cityWasComplete: Boolean

    /** Whether every goal in the city was done before this run (for the fireworks). */
    private val cityGoalsWereDone: Boolean
    private var cityCompletedThisRun = false

    // Feel.
    private var timeScale = 1.0
    private var slowMoLeft = 0.0
    private var shakeLeft = 0.0

    /** The biggest callout given for the combo going now. */
    private var announcedTier = 0

    /** The pause menu or the end-of-run results, over everything. */
    private val overlay = Node()
    private val overlayButtons = mutableListOf<PixelButton>()
    private var overlayTouchStart: Pair<Double, Double>? = null

    /** The music and sound switches on the goals and pause screens. */
    private var musicToggle: PixelButton? = null
    private var soundToggle: PixelButton? = null
    private var isOnBreak = false

    init {
        progress.completeEarnedLetterGoals(city)
        goalsBefore = progress.goalsDone(level)
        goalTracker = GoalTracker(level.goals, alreadyMet = goalsBefore, lettersFoundBefore = progress.letters(city))
        cityWasComplete = progress.isComplete(city)
        cityGoalsWereDone = progress.allGoalsDone(city)
    }

    // Building the scene

    override fun didMove() {
        val theme = ThemeArt.look(level.theme)
        backgroundColor = theme.sky
        addChild(world)
        addChild(cam)
        camera = cam

        val groundTop = StreetArt.groundTop.toDouble()
        strips = theme.layers.mapIndexed { index, layer ->
            ParallaxStrip(layer.canvas.texture(), layer.factor, groundTop + layer.lift, (-30 + index * 10).toDouble())
        } + ParallaxStrip(theme.ground.texture(), 1.0, 0.0, -10.0)
        strips.forEach { world.addChild(it.node) }

        for ((index, feature) in level.features.withIndex()) {
            val featureLook = FeatureArt.look(feature, seed = index)
            val frames = featureLook.frames.map { it.texture() }
            val lane = feature.lane.raw.toDouble()
            val node = SpriteNode(frames[0])
            node.anchor(0.0, 0.0)
            node.position(feature.x + featureLook.offsetX, StreetArt.baseline(lane) + featureLook.offsetY)
            // Holes and tracks lie on the ground, under anything in their lane.
            val onGround = feature.kind == Feature.Kind.Hole || feature.kind == Feature.Kind.Decor || feature.isLow
            node.z = laneZ(lane) - if (onGround) 3 else 0
            world.addChild(node)
            featureNodes += node to (featureLook to frames)

            if (!onGround) {
                val footprint = SpriteNode.rect(Palette.shadow, feature.length, 1.0)
                footprint.anchor(0.0, 0.0)
                footprint.position(1.0, -1 - featureLook.offsetY)
                footprint.z = -1.0
                node.addChild(footprint)
            }
        }

        val found = progress.letters(city)
        for (pickup in level.letters) {
            val token = SpriteNode(LetterArt.token(pickup.letter, found = pickup.index in found).texture())
            token.anchor(0.0, 0.0)
            val lane = pickup.lane.raw.toDouble()
            token.position(pickup.x - 5, StreetArt.baseline(lane) + pickup.height)
            token.z = laneZ(lane) + 4
            token.run(Action.repeatForever(Action.sequence(Action.moveBy(0.0, 1.0, 0.3), Action.moveBy(0.0, -1.0, 0.3))))
            world.addChild(token)
            letterNodes[pickup.index] = token
        }

        val finish = SpriteNode(FeatureArt.finishLine(46).texture())
        finish.anchor(0.0, 0.0)
        finish.position(level.length, 8.0)
        finish.z = -5.0
        world.addChild(finish)

        body.anchor(0.5, 0.0)
        body.position(0.0, 3.0)
        board.anchor(0.5, 0.0)
        skater.addChild(board)
        skater.addChild(body)
        world.addChild(skater)
        shadow.anchor(0.5, 0.5)
        world.addChild(shadow)

        for (label in listOf(scoreLabel, bestLabel, comboLabel, multiplierLabel)) {
            label.z = 100.0
            cam.addChild(label)
        }
        multiplierLabel.ink = Palette.yellow
        lettersLabel.z = 100.0
        cam.addChild(lettersLabel)
        pauseButton.z = 100.0
        cam.addChild(pauseButton)
        comboMeter.anchor(0.0, 0.5)
        comboMeter.z = 100.0
        comboMeter.isHidden = true
        cam.addChild(comboMeter)
        banners.z = 150.0
        cam.addChild(banners)
        tutorialBox.z = 120.0
        cam.addChild(tutorialBox)
        overlay.z = 200.0
        cam.addChild(overlay)

        Haptics.prepare()
        Sounds.prepare()
        updateLettersLabel()
        layoutScene()
        render()
        playMusic()
        if (level.goals.isNotEmpty()) showIntro()
        showTutorialStep()
    }

    /** The spot's song, from the top. */
    private fun playMusic() {
        Music.song(level)?.let(Music::play)
    }

    override fun willResignActive() {
        stopGrindFeedback()
        if (!run.isFinished && !isOnBreak) openPauseMenu()
    }

    /** Android's back button: pauses a run, and on the pause or goals screen, leaves. */
    override fun back(): Boolean {
        if (!run.isFinished && !isOnBreak) openPauseMenu() else leave()
        return true
    }

    override fun layoutScene() {
        if (!isShowing) return
        // HUD positions are relative to the camera, at the middle of the screen.
        val safe = safeFrame.offsetBy(-size.width / 2, -size.height / 2)
        val line = (PixelFont.glyphHeight + 3).toDouble()
        scoreLabel.position(safe.minX, safe.maxY)
        placeBestLabel()
        lettersLabel.position(safe.minX, (safe.minY + 1).rounded())
        pauseButton.position((safe.maxX - 8).rounded(), (safe.maxY - 6).rounded())
        // The combo (or a tip) gets the whole second line, centered in the room left of the pause button.
        val pauseLeft = pauseButton.frame.minX
        val middle = floor((safe.minX + pauseLeft - 2) / 2)
        comboLabel.position(middle, safe.maxY - line)
        multiplierLabel.position(middle, safe.maxY - line * 2)
        comboMeterX = middle - comboMeterWidth / 2
        comboMeterY = safe.maxY - line * 3 + 1
        tutorialBox.position(middle, (safe.maxY - line * 3 - 5).rounded())
        strips.forEach { it.layout(size.width) }
    }

    private fun updateLettersLabel() {
        val found = progress.letters(city)
        val runs = city.letters.mapIndexed { index, letter ->
            letter.toString() to if (index in found) Palette.yellow else PixelColor(0xA8A8A8)
        }
        lettersLabel.show(TextTextures.texture(runs))
    }

    // Touches

    override fun touchBegan(touch: Touch) {
        val point = touch.sceneX - cam.x to touch.sceneY - cam.y
        if (isOnBreak || run.isFinished) {
            overlayTouchStart = point
            return
        }
        if (activeTouch == null && pauseButton.hit(point.first, point.second)) {
            openPauseMenu()
            return
        }
        if (activeTouch != null) return
        activeTouch = touch.id
        apply(gestures.began(Point(touch.viewX, touch.viewY), touch.time))
    }

    override fun touchMoved(touch: Touch) {
        if (touch.id != activeTouch) return
        apply(gestures.moved(Point(touch.viewX, touch.viewY), touch.time))
    }

    override fun touchEnded(touch: Touch) {
        val start = overlayTouchStart
        if (start != null) {
            overlayTouchStart = null
            val px = touch.sceneX - cam.x
            val py = touch.sceneY - cam.y
            overlayButtons.firstOrNull { it.hit(start.first, start.second) && it.hit(px, py) }?.let { button ->
                Sounds.play(Sound.Pop)
                Haptics.pop(charged = false)
                button.action()
            }
            return
        }
        if (touch.id != activeTouch) return
        activeTouch = null
        apply(gestures.ended(Point(touch.viewX, touch.viewY), touch.time))
    }

    override fun touchCancelled(touch: Touch) {
        overlayTouchStart = null
        if (touch.id != activeTouch) return
        activeTouch = null
        apply(gestures.cancelled(touch.time))
    }

    private fun apply(gestureEvents: List<GestureEvent>) {
        for (gesture in gestureEvents) process(run.handle(gesture), dt = 0.0)
    }

    /** Everything the run reports goes through here: goals, the tutorial, then sounds and pictures. */
    private fun process(events: List<RunEvent>, dt: Double) {
        trackGoals(events, dt)
        trackTutorial(events)
        react(events)
    }

    // The loop

    override fun update(currentTime: Double) {
        val dt = min(0.1, currentTime - (lastUpdate ?: currentTime))
        lastUpdate = currentTime
        if (isOnBreak) return
        apply(gestures.tick(currentTime))

        // Slow motion for a moment after something big.
        if (slowMoLeft > 0) {
            slowMoLeft -= dt
            if (slowMoLeft <= 0) timeScale = 1.0
        }
        shakeLeft = max(0.0, shakeLeft - dt)

        // Fixed steps, so the run plays the same at any frame rate.
        stepTime += dt * timeScale
        while (stepTime >= stepLength) {
            stepTime -= stepLength
            process(run.step(stepLength), dt = stepLength)
        }
        sparkTimer += dt
        // A safety net: whatever happened, no rumble or grind sound unless on a rail.
        if (grindFeedbackOn && !run.isGrinding) stopGrindFeedback()
        setRollingSound(run.state == SkaterState.Rolling && !run.isFinished)
        render(dt)
    }

    private fun startGrindFeedback() {
        grindFeedbackOn = true
        Haptics.startGrind()
        Sounds.play(Sound.Lock)
        playGrindLoop()
    }

    /** Metal on rails, a rasp on concrete and wood, a scrape for a boardslide. */
    private fun playGrindLoop() {
        val state = run.state as? SkaterState.Grinding ?: return
        val sound = when {
            state.trick == Trick.Boardslide -> Sound.Slide
            level.features[state.feature].kind == Feature.Kind.Rail -> Sound.Grind
            else -> Sound.Scrape
        }
        if (sound == grindLoop) return
        grindLoop?.let(Sounds::stopLoop)
        grindLoop = sound
        Sounds.startLoop(sound)
    }

    /** Wheels on the pavement, while rolling. */
    private fun setRollingSound(on: Boolean) {
        if (on == rollingSoundOn) return
        rollingSoundOn = on
        if (on) Sounds.startLoop(Sound.Roll) else Sounds.stopLoop(Sound.Roll)
    }

    private fun stopGrindFeedback() {
        grindFeedbackOn = false
        Haptics.stopGrind()
        grindLoop?.let(Sounds::stopLoop)
        grindLoop = null
    }

    // Pause and results

    /** One line on the pause menu or results: crossed out when it's a goal that's done,
     *  or a row of hopping letters for a city just spelled. */
    private data class OverlayLine(
        val text: String,
        val color: PixelColor,
        val struck: Boolean = false,
        val hopping: Boolean = false,
        /** A few grey words after the text: what a gap is. */
        val hint: String? = null,
    )

    private class OverlayButton(val text: String, val color: PixelColor, val action: () -> Unit)

    /** A title across the top, one or two columns of lines, and buttons along the bottom. */
    private fun showOverlay(title: String, columns: List<List<OverlayLine>>, buttons: List<OverlayButton>) {
        Music.setDucked(true)
        setRollingSound(false)
        overlay.removeAllChildren()
        overlayButtons.clear()
        setHudHidden(true)
        val dim = SpriteNode.rect(PixelColor(0, alpha = 191), size.width + 4, size.height + 4)
        dim.z = -1.0
        overlay.addChild(dim)

        val rows = columns.maxOfOrNull { it.size } ?: 0
        val top = (10 * (rows + 1) / 2 + 10).toDouble()
        addOverlayLabel(OverlayLine(title, Palette.yellow), 0.0, top)
        val half = (safeFrame.width / 4).rounded()
        for ((index, column) in columns.withIndex()) {
            val x = if (columns.size == 1) 0.0 else if (index == 0) -half else half
            for ((row, line) in column.withIndex()) addOverlayLabel(line, x, top - 10 * (row + 1))
        }
        val buttonY = top - 10 * (rows + 1) - 6
        // Four buttons squeeze up a little to fit narrow screens.
        val spacing = if (buttons.size > 3) 49.0 else 52.0
        val firstX = -spacing * (buttons.size - 1) / 2
        for ((index, spec) in buttons.withIndex()) {
            val button = PixelButton(spec.text, if (buttons.size > 3) 44.0 else 46.0, spec.color, spec.action)
            button.position((firstX + index * spacing).rounded(), buttonY.rounded())
            overlay.addChild(button)
            overlayButtons += button
        }
    }

    private fun addOverlayLabel(line: OverlayLine, atX: Double, atY: Double) {
        val px = atX.rounded()
        val py = atY.rounded()
        if (line.hopping) {
            // Each letter hops in turn, over and over.
            val width = PixelFont.width(line.text).toDouble()
            var x = px - (width / 2).rounded()
            for ((index, letter) in line.text.withIndex()) {
                val label = PixelLabel(0.0, 0.5)
                label.ink = if (index % 2 == 0) Palette.yellow else Palette.orange
                label.text = letter.toString()
                label.position(x, py)
                overlay.addChild(label)
                label.run(
                    Action.sequence(
                        Action.wait(index * 0.08),
                        Action.repeatForever(
                            Action.sequence(Action.moveBy(0.0, 3.0, 0.1), Action.moveBy(0.0, -3.0, 0.1), Action.wait(0.9)),
                        ),
                    ),
                )
                x += PixelFont.width(letter.toString()) + PixelFont.gap
            }
            return
        }
        val hint = line.hint
        if (hint != null) {
            // The text and its hint side by side, centered together.
            val textWidth = PixelFont.width(line.text).toDouble()
            val total = textWidth + 6 + PixelFont.width(hint)
            val left = (px - total / 2).rounded()
            for ((text, ink, x) in listOf(Triple(line.text, line.color, left), Triple(hint, PixelColor(0x9C9C9C), left + textWidth + 6))) {
                val label = PixelLabel(0.0, 0.5)
                label.ink = ink
                label.text = text
                label.position(x, py)
                overlay.addChild(label)
            }
            return
        }
        val label = PixelLabel(0.5, 0.5)
        label.ink = line.color
        label.text = line.text
        label.position(px, py)
        overlay.addChild(label)
        if (line.struck) {
            val width = (PixelFont.width(line.text) + 2).toDouble()
            val strike = SpriteNode.rect(line.color, width, 1.0)
            strike.position(px, py + 0.5)
            strike.z = 1.0
            overlay.addChild(strike)
        }
    }

    /** The spot's goals, crossed out once done. With `hints`, a gap still to do says what it is. */
    private fun goalLines(hints: Boolean = true): List<OverlayLine> {
        val doneCount = level.goals.count { it.id in goalsBefore || it.id in goalsThisRun }
        return listOf(OverlayLine("GOALS $doneCount/${level.goals.size}", Palette.yellow)) + level.goals.map { goal ->
            when {
                goal.id in goalsThisRun -> OverlayLine(goal.text, Palette.yellow, struck = true)
                goal.id in goalsBefore -> OverlayLine(goal.text, PixelColor(0x8C8C8C), struck = true)
                else -> {
                    val kind = goal.kind
                    val gap = if (hints && kind is Goal.Kind.GapNamed) level.gaps.firstOrNull { it.name == kind.name } else null
                    OverlayLine(goal.text, Palette.white, hint = gap?.hint?.takeIf { it.isNotEmpty() })
                }
            }
        }
    }

    /** Before the run: the spot's goals, so you know what to go for. */
    private fun showIntro() {
        isOnBreak = true
        showOverlay(
            level.name, listOf(goalLines()),
            listOf(
                OverlayButton("GO", PixelColor(0x00A844)) { closePauseMenu() },
                OverlayButton("SPOTS", PixelColor(0x24308C)) { leave() },
            ),
        )
        addAudioToggles()
    }

    /** Music and sound on/off, in the top-left corner of the overlay. */
    private fun addAudioToggles() {
        val safe = safeFrame.offsetBy(-size.width / 2, -size.height / 2)
        val music = PixelButton.icon(UIArt.musicIcon(Music.isOn).texture()) {
            Music.isOn = !Music.isOn
            refreshAudioToggles()
        }
        val sound = PixelButton.icon(UIArt.soundIcon(!Sounds.isMuted).texture()) {
            Sounds.isMuted = !Sounds.isMuted
            refreshAudioToggles()
        }
        for ((index, toggle) in listOf(music, sound).withIndex()) {
            toggle.position((safe.minX + 9 + index * 16).rounded(), (safe.maxY - 8).rounded())
            overlay.addChild(toggle)
            overlayButtons += toggle
        }
        musicToggle = music
        soundToggle = sound
    }

    private fun refreshAudioToggles() {
        musicToggle?.setIcon(UIArt.musicIcon(Music.isOn).texture())
        soundToggle?.setIcon(UIArt.soundIcon(!Sounds.isMuted).texture())
    }

    private fun openPauseMenu() {
        isOnBreak = true
        activeTouch = null
        gestures = GestureReader()
        stopGrindFeedback()
        val lines = tutorial?.let { listOf(OverlayLine(it.current?.text ?: "", Palette.white)) } ?: goalLines()
        showOverlay(
            "PAUSED", listOf(lines),
            listOf(
                OverlayButton("RESUME", PixelColor(0x00A844)) { closePauseMenu() },
                OverlayButton("QUIT", PixelColor(0x24308C)) { leave() },
            ),
        )
        addAudioToggles()
    }

    /** The HUD steps aside while a menu or the results are up. */
    private fun setHudHidden(hidden: Boolean) {
        for (node in listOf(scoreLabel, bestLabel, comboLabel, multiplierLabel, lettersLabel, pauseButton, banners)) {
            node.alpha = if (hidden) 0.0 else 1.0
        }
    }

    private fun closePauseMenu() {
        Music.setDucked(false)
        isOnBreak = false
        setHudHidden(false)
        overlay.removeAllChildren()
        overlayButtons.clear()
        lastUpdate = null
    }

    private fun leave() {
        stopGrindFeedback()
        router?.showMenu(if (tutorial == null) MenuScene.Page.Spots(city) else MenuScene.Page.Title)
    }

    private fun showResults(score: Int) {
        val isBest = tutorial == null && progress.record(score, level)
        val columnWidth = (safeFrame.width / 2).toInt() - 6
        val stats = mutableListOf(
            OverlayLine("SCORE $score", Palette.white),
            OverlayLine(
                if (isBest) "NEW BEST!" else "BEST ${progress.bestScore(level)}",
                if (isBest) Palette.yellow else Palette.lightGrey,
            ),
        )
        if (run.bestCombo > 0) {
            stats += OverlayLine("COMBO ${run.bestCombo}", Palette.white)
            // As many of its last tricks as fit.
            val tricks = run.bestComboTricks.split(" + ").filter { it != "..." }
            var shown = tricks.takeLast(2).joinToString(" + ")
            if (PixelFont.width(shown) > columnWidth) shown = tricks.lastOrNull() ?: ""
            stats += OverlayLine(shown, Palette.lightGrey)
        }
        if (cityCompletedThisRun) {
            stats += OverlayLine(city.name.filter { it != ' ' }, Palette.yellow, hopping = true)
            stats += OverlayLine("PDX BOARD!", Palette.orange)
        } else {
            val foundHere = run.lettersFound.sorted().joinToString(" ") { city.letters[it].toString() }
            if (foundHere.isNotEmpty()) stats += OverlayLine("FOUND $foundHere", Palette.yellow)
        }

        val buttons = mutableListOf(OverlayButton("AGAIN", PixelColor(0x00A844)) { router?.play(level, city) })
        val index = city.levels.indexOf(level)
        if (index >= 0 && index + 1 < city.levels.size) {
            val next = city.levels[index + 1]
            buttons += OverlayButton("NEXT", PixelColor(0x24308C)) { router?.play(next, city) }
        }
        buttons += OverlayButton("SPOTS", PixelColor(0x24308C)) { leave() }
        buttons += OverlayButton("TIP JAR", MenuScene.tipColor) {
            stopGrindFeedback()
            router?.showMenu(MenuScene.Page.Tips(back = if (tutorial == null) MenuScene.Page.Spots(city) else MenuScene.Page.Title))
        }
        val columns = if (level.goals.isEmpty()) listOf(stats) else listOf(stats, goalLines(hints = false))
        // The run that ticks off the city's last goal gets fireworks: first the city's
        // name spelled out in them, then the results with more going off behind.
        val finishedCity = tutorial == null && !cityGoalsWereDone && progress.allGoalsDone(city)
        if (!finishedCity) {
            showOverlay("FINISH!", columns, buttons)
            return
        }
        celebrateAllGoals {
            showOverlay("ALL ${city.name} GOALS!", columns, buttons)
            fireworks()
        }
    }

    /** The screen dims, a rocket goes up, and it bursts into the city's name. `then`
     *  runs as the letters start to fall. */
    private fun celebrateAllGoals(then: () -> Unit) {
        showOverlay("", emptyList(), emptyList())
        val show = Node()
        show.z = -0.5
        overlay.addChild(show)
        // Side bursts while the name is up.
        for ((delay, side) in listOf(0.3 to -1.0, 1.2 to 1.0, 1.9 to -1.0)) {
            show.run(
                Action.sequence(
                    Action.wait(delay),
                    Action.run {
                        val x = side * (size.width / 2 - 24).rounded()
                        val y = Random.nextDouble(10.0, 24.0).rounded()
                        launchFirework(show, x, y, listOf(Palette.orange, PixelColor(0x68C0F0), Palette.green).random())
                    },
                ),
            )
        }
        val rise = 0.6
        val rocket = SpriteNode.rect(Palette.white, 1.0, 2.0)
        rocket.position(0.0, -size.height / 2)
        show.addChild(rocket)
        rocket.run(Action.sequence(Action.moveTo(0.0, 8.0, rise), Action.removeFromParent()))
        Sounds.play(Sound.Pop)
        show.run(
            Action.sequence(
                Action.wait(rise),
                Action.run {
                    Sounds.play(Sound.Burst)
                    Haptics.finish()
                    spellInFireworks(city.name, show, 0.0, 8.0)
                },
            ),
        )
        run(Action.sequence(Action.wait(rise + 2.6), Action.run(then)))
    }

    /** Sparks that fly out from the center into the letters of `text`, twinkle, then fall. */
    private fun spellInFireworks(text: String, show: Node, centerX: Double, centerY: Double) {
        // Each letter pixel is a spark, spaced out so the letters read as fireworks.
        val spacing = listOf(3, 2).firstOrNull { PixelFont.width(text) * it <= safeFrame.width - 8 } ?: 1
        val width = PixelFont.width(text) * spacing
        val height = PixelFont.glyphHeight * spacing
        val left = -width / 2
        val bottom = centerY.toInt() - height / 2
        val colors = listOf(Palette.yellow, Palette.orange, PixelColor(0xF878B8), PixelColor(0x68C0F0))
        var cursor = 0
        for ((letterIndex, character) in text.withIndex()) {
            val rows = PixelFont.glyph(character)
            val color = colors[letterIndex % colors.size]
            for ((row, line) in rows.withIndex()) {
                for ((column, pixel) in line.withIndex()) {
                    if (pixel != '#') continue
                    val targetX = (left + (cursor + column) * spacing).toDouble()
                    val targetY = (bottom + (PixelFont.glyphHeight - 1 - row) * spacing).toDouble()
                    val dot = max(1, spacing - 1).toDouble()
                    val spark = SpriteNode.rect(color, dot, dot)
                    spark.anchor(0.0, 0.0)
                    spark.position(centerX, centerY)
                    show.addChild(spark)
                    var flicker = 0
                    spark.run(
                        Action.sequence(
                            Action.wait(Random.nextDouble(0.0, 0.15)),
                            Action.moveTo(targetX, targetY, 0.7, Timing.EaseOut),
                            Action.repeat(
                                Action.sequence(
                                    Action.wait(0.12, range = 0.08),
                                    Action.run {
                                        flicker += 1
                                        spark.color = if (flicker % 3 == 0) Palette.white else color
                                    },
                                ),
                                count = 12,
                            ),
                            Action.group(Action.moveBy(0.0, -12.0, 0.7), Action.fadeOut(0.7)),
                            Action.removeFromParent(),
                        ),
                    )
                }
            }
            cursor += rows[0].length + PixelFont.gap
        }
    }

    /** Fireworks going off behind the results, over and over until you leave. */
    private fun fireworks() {
        Sounds.play(Sound.Perfect)
        Haptics.finish()
        val colors = listOf(Palette.yellow, Palette.orange, PixelColor(0xF878B8), PixelColor(0x68C0F0), Palette.green, Palette.white)
        val show = Node()
        show.z = -0.5
        overlay.addChild(show)
        var burst = 0
        show.run(
            Action.repeatForever(
                Action.sequence(
                    Action.run {
                        val color = colors[burst % colors.size]
                        burst += 1
                        // Somewhere across the top two thirds, left and right in turn.
                        val side = if (burst % 2 == 0) -1.0 else 1.0
                        val x = (side * Random.nextDouble(20.0, max(20.0001, size.width / 2 - 12))).rounded()
                        val y = Random.nextDouble(0.0, max(0.0001, size.height / 2 - 14)).rounded()
                        launchFirework(show, x, y, color)
                        if (burst % 2 == 0) Sounds.play(Sound.Burst)
                    },
                    Action.wait(0.45, range = 0.3),
                ),
            ),
        )
    }

    /** One rocket: a spark rising from the bottom, then a ring of sparks falling away. */
    private fun launchFirework(show: Node, x: Double, y: Double, color: PixelColor) {
        val rocket = SpriteNode.rect(Palette.white, 1.0, 2.0)
        rocket.position(x, -size.height / 2)
        show.addChild(rocket)
        val rise = 0.5
        rocket.run(Action.sequence(Action.moveTo(x, y, rise), Action.removeFromParent()))
        show.run(
            Action.sequence(
                Action.wait(rise),
                Action.run {
                    val count = 18
                    for (index in 0 until count) {
                        val angle = index.toDouble() / count * 2 * PI
                        val reach = Random.nextDouble(14.0, 20.0)
                        val spark = SpriteNode.rect(if (index % 4 == 0) Palette.white else color, 1.0, 1.0)
                        spark.position(x, y)
                        show.addChild(spark)
                        spark.run(
                            Action.sequence(
                                Action.moveBy(reach * cos(angle), reach * sin(angle), 0.5, Timing.EaseOut),
                                Action.group(Action.moveBy(0.0, -6.0, 0.5), Action.fadeOut(0.5)),
                                Action.removeFromParent(),
                            ),
                        )
                    }
                },
            ),
        )
    }

    // Tutorial

    private fun trackTutorial(events: List<RunEvent>) {
        val tutorial = tutorial ?: return
        tutorial.update(run, events) ?: return
        Sounds.play(Sound.Letter)
        Haptics.land(perfect = true)
        // NICE! in the box for a moment, then the next step.
        tutorialBox.removeAllChildren()
        val nice = PixelLabel(0.5, 0.5)
        nice.ink = Palette.green
        nice.text = "NICE!"
        val back = SpriteNode.rect(PixelColor(0, alpha = 153), nice.width + 8, nice.height + 3)
        back.z = -1.0
        tutorialBox.addChild(back)
        tutorialBox.addChild(nice)
        tutorialBox.run(Action.sequence(Action.wait(0.8), Action.run { showTutorialStep() }))
    }

    /** The step to do now, in a box under the score; or, once they're all done, the way out. */
    private fun showTutorialStep() {
        tutorialBox.removeAllChildren()
        val tutorial = tutorial ?: return
        val step = tutorial.current
        if (step == null) {
            isOnBreak = true
            stopGrindFeedback()
            showOverlay(
                "YOU'RE READY!",
                listOf(
                    listOf(
                        OverlayLine("NOW GO SKATE PORTLAND", Palette.white),
                        OverlayLine("FIND THE LETTERS", Palette.lightGrey),
                        OverlayLine("AND DO THE GOALS", Palette.lightGrey),
                    ),
                ),
                listOf(
                    OverlayButton("PLAY", PixelColor(0x00A844)) { router?.play(Level.downtown, City.portland) },
                    OverlayButton("MENU", PixelColor(0x24308C)) { leave() },
                    OverlayButton("TIP JAR", MenuScene.tipColor) { router?.showMenu(MenuScene.Page.Tips(back = MenuScene.Page.Title)) },
                ),
            )
            return
        }
        // One line, clear of the skater: the step number in grey, then what to do.
        val texture = TextTextures.texture(
            listOf("${tutorial.index + 1}/${Tutorial.steps.size} " to Palette.lightGrey, step.text to Palette.yellow),
        )
        val text = SpriteNode(texture)
        val back = SpriteNode.rect(PixelColor(0, alpha = 153), text.width + 8, text.height + 3)
        back.z = -1.0
        tutorialBox.addChild(back)
        tutorialBox.addChild(text)
    }

    // Goals

    private fun trackGoals(events: List<RunEvent>, dt: Double) {
        for (goal in goalTracker.update(run, events, dt)) {
            progress.complete(goal, level)
            goalsThisRun += goal.id
            Sounds.play(Sound.Goal)
            Haptics.land(perfect = true)
            showBanner(goal.text, "GOAL!", Palette.yellow)
        }
    }

    /** A banner across the top of the street for a moment: a goal done, or a gap. */
    private fun showBanner(text: String, title: String, color: PixelColor) {
        val stack = banners.children.count { it.name == "banner" }
        val banner = Node()
        banner.name = "banner"
        val safe = safeFrame.offsetBy(-size.width / 2, -size.height / 2)
        val y = (safe.maxY - 34 - stack * 11).rounded()
        val label = PixelLabel(0.5, 0.5)
        label.ink = color
        label.text = "$title $text"
        val back = SpriteNode.rect(PixelColor(0, alpha = 140), label.width + 8, label.height + 3)
        back.z = -1.0
        banner.addChild(back)
        banner.addChild(label)
        banner.position(0.0, y + 6)
        banner.alpha = 0.0
        banners.addChild(banner)
        banner.run(
            Action.sequence(
                Action.group(Action.fadeIn(0.12), Action.moveBy(0.0, -6.0, 0.12)),
                Action.wait(1.4),
                Action.fadeOut(0.3),
                Action.removeFromParent(),
            ),
        )
    }

    // Big moments

    private fun slowMotion(seconds: Double, scale: Double = 0.35) {
        if (!slowMotionOn) return
        timeScale = scale
        slowMoLeft = max(slowMoLeft, seconds)
    }

    /** SICK!, GNARLY! and so on, once each as a combo grows. */
    private fun checkCallout(total: Int) {
        val tier = callouts.indexOfLast { total >= it.first }
        if (tier < 0 || tier + 1 <= announcedTier) return
        announcedTier = tier + 1
        val label = PixelLabel(0.5, 0.5)
        label.ink = listOf(Palette.yellow, Palette.orange, PixelColor(0xF878B8), Palette.white)[min(tier, 3)]
        label.text = callouts[tier].second
        label.setScale(2.0)
        label.position(0.0, 6.0)
        banners.addChild(label)
        label.run(
            Action.sequence(
                Action.moveBy(0.0, 4.0, 0.15),
                Action.wait(0.6),
                Action.fadeOut(0.3),
                Action.removeFromParent(),
            ),
        )
        Haptics.land(perfect = true)
        slowMotion(0.45)
    }

    /** The last letter of the city: the name hops in, letter by letter, and the reward shows. */
    private fun celebrateCity() {
        val name = city.name.filter { it != ' ' }
        val width = (PixelFont.width(name) * 2).toDouble()
        var x = -(width / 2).rounded()
        val colors = listOf(Palette.yellow, Palette.orange, PixelColor(0xF878B8), Palette.white)
        for ((index, letter) in name.withIndex()) {
            val label = PixelLabel(0.0, 0.5)
            label.ink = colors[index % colors.size]
            label.text = letter.toString()
            label.setScale(2.0)
            label.position(x, 4.0)
            label.alpha = 0.0
            banners.addChild(label)
            var flash = 0
            label.run(
                Action.sequence(
                    Action.wait(0.1 * index),
                    Action.group(
                        Action.fadeIn(0.05),
                        Action.sequence(Action.moveBy(0.0, 8.0, 0.1), Action.moveBy(0.0, -8.0, 0.12)),
                    ),
                    Action.repeat(
                        Action.sequence(
                            Action.wait(0.1),
                            Action.run {
                                flash += 1
                                label.ink = colors[(index + flash) % colors.size]
                            },
                        ),
                        count = 16,
                    ),
                    Action.fadeOut(0.3),
                    Action.removeFromParent(),
                ),
            )
            x += (PixelFont.width(letter.toString()) + PixelFont.gap) * 2
        }
        val reward = PixelLabel(0.5, 0.5)
        reward.ink = Palette.white
        reward.text = "${city.name} SPELLED! PDX BOARD"
        reward.position(0.0, -14.0)
        reward.alpha = 0.0
        banners.addChild(reward)
        reward.run(
            Action.sequence(
                Action.wait(0.9), Action.fadeIn(0.1), Action.wait(1.6), Action.fadeOut(0.3), Action.removeFromParent(),
            ),
        )
        repeat(24) { spark(skater.z + 6) }
        Sounds.play(Sound.Finish)
        Haptics.finish()
        slowMotion(0.8, scale = 0.4)
    }

    // Reacting

    private fun react(events: List<RunEvent>) {
        for (event in events) {
            when (event) {
                is RunEvent.Ollie -> {
                    Sounds.play(Sound.Pop)
                    Haptics.pop(event.charged)
                }
                RunEvent.PopOff -> {
                    Sounds.play(Sound.Pop)
                    Haptics.pop(charged = false)
                }
                RunEvent.Launched -> {
                    Sounds.play(Sound.Launch)
                    Haptics.pop(charged = true)
                }
                is RunEvent.TrickStarted -> Sounds.play(
                    when (event.trick) {
                        Trick.Kickflip, Trick.Heelflip -> Sound.Flip
                        Trick.ShoveIt, Trick.ThreeSixtyFlip -> Sound.Spin
                        Trick.Grab -> Sound.Grab
                        else -> Sound.Trick
                    },
                )
                is RunEvent.GrindStarted -> startGrindFeedback()
                is RunEvent.GrindSwitched -> {
                    Haptics.tick()
                    Sounds.play(Sound.Lock)
                    playGrindLoop()
                }
                RunEvent.GrindEnded -> stopGrindFeedback()
                is RunEvent.Landed -> {
                    Sounds.play(if (event.perfect) Sound.Perfect else Sound.Land)
                    Haptics.land(event.perfect)
                    if (event.perfect) popup("PERFECT!", Palette.yellow, rise = 8.0)
                    checkCallout(run.combo.total)
                }
                is RunEvent.LandedTrick -> {}
                is RunEvent.Banked -> {
                    checkCallout(event.points)
                    announcedTier = 0
                    if (event.points > Trick.Ollie.basePoints.toInt()) {
                        Sounds.play(Sound.Bank)
                        popup("+${event.points}", Palette.white, rise = 0.0)
                    }
                }
                is RunEvent.GapDone -> {
                    Sounds.play(Sound.Gap)
                    Haptics.land(perfect = true)
                    showBanner("+${event.points}", event.name, Palette.orange)
                }
                is RunEvent.Bail -> {
                    Sounds.play(if (event.reason == BailReason.Fell) Sound.Fall else Sound.Bail)
                    Haptics.bail()
                    shakeLeft = 0.3
                    announcedTier = 0
                    popup(if (event.reason == BailReason.Fell) "MANHOLE!" else "BAIL", Palette.orange, rise = 0.0)
                }
                is RunEvent.LaneSwitch -> {
                    Sounds.play(Sound.Lane)
                    Haptics.tick()
                }
                is RunEvent.Cleared -> {
                    Sounds.play(Sound.Clear)
                    popup("${event.style.displayName} +${event.points}", Palette.yellow, rise = 16.0)
                }
                is RunEvent.Letter -> {
                    Sounds.play(Sound.Letter)
                    Haptics.land(perfect = true)
                    val isNew = progress.collect(event.index, city)
                    popup(if (isNew) "${event.letter}!" else "${event.letter}", Palette.yellow, rise = 8.0)
                    letterNodes.remove(event.index)?.removeFromParent()
                    updateLettersLabel()
                    if (isNew && !cityWasComplete && !cityCompletedThisRun && progress.isComplete(city)) {
                        cityCompletedThisRun = true
                        celebrateCity()
                    }
                }
                is RunEvent.Finished -> {
                    stopGrindFeedback()
                    Sounds.play(Sound.Finish)
                    Haptics.finish()
                    showResults(event.score)
                }
            }
        }
    }

    private fun popup(text: String, color: PixelColor, rise: Double) {
        val label = PixelLabel(0.5, 0.0)
        label.ink = color
        label.text = text
        label.z = 60.0
        label.position(skater.x, (skater.y + 26 + rise).rounded())
        world.addChild(label)
        label.run(
            Action.sequence(
                Action.group(Action.moveBy(0.0, 10.0, 0.7), Action.sequence(Action.wait(0.4), Action.fadeOut(0.3))),
                Action.removeFromParent(),
            ),
        )
    }

    // Drawing

    private fun laneZ(lane: Double): Double = (10 * (lane.rounded().toInt() + 1)).toDouble()

    private fun render(dt: Double = 0.0) {
        val baseline = StreetArt.baseline(run.drawnLane)
        val z = laneZ(run.drawnLane)

        // Camera: the skater sits 30% in from the left, so you can see what's coming,
        // and the camera rises when a big jump would take their head off the top.
        val cameraLeft = (run.x - size.width * cameraAnchor).rounded()
        val skaterTop = baseline + run.height + 26
        val wantedLift = max(0.0, skaterTop - size.height)
        cameraLift += (wantedLift - cameraLift) * min(1.0, dt * 12)
        cam.position(cameraLeft + size.width / 2, size.height / 2 + cameraLift.rounded())
        if (shakeLeft > 0) {
            // A bail rattles the screen for a moment, settling as it goes.
            val amount = if (shakeLeft > 0.15) 2 else 1
            cam.x += Random.nextInt(-amount, amount + 1)
            cam.y += Random.nextInt(-amount, amount + 1)
        }
        strips.forEach { it.update(cameraLeft) }

        // Moving things, and their walk cycles.
        val frame = (run.time * 6).toInt() % 2
        for ((index, feature) in level.features.withIndex()) {
            if (!feature.isMoving) continue
            val (node, art) = featureNodes[index]
            val (featureLook, frames) = art
            val x = run.position(index) + featureLook.offsetX
            node.x = x.rounded()
            if (frames.size > 1 && x != feature.x + featureLook.offsetX) node.texture = frames[frame]
        }

        skater.position(run.x.rounded(), (baseline + run.height).rounded())
        skater.z = z + 5
        shadow.position(run.x.rounded(), baseline.rounded())
        shadow.z = z - 0.5

        renderSkater()
        if (run.state is SkaterState.Grinding && sparkTimer > 0.04) {
            sparkTimer = 0.0
            spark(z + 6)
        }
        renderHud()
    }

    private fun renderSkater() {
        board.xScale = 1.0
        board.position(0.0, 0.0)
        board.anchor(0.5, 0.0)
        board.z = 0.0
        val spinning = run.airTrick?.trick.let { it == Trick.ShoveIt || it == Trick.ThreeSixtyFlip }
        if (!spinning) lastSpinStep = null
        board.show(look.boardSide)
        body.position(0.0, 3.0)

        when (val state = run.state) {
            SkaterState.Rolling -> body.show(look.roll)
            SkaterState.Airborne -> {
                val trick = run.airTrick
                if (trick != null) {
                    body.show(if (trick.trick == Trick.Grab) look.grab else look.air)
                    animateBoard(trick)
                } else {
                    body.show(look.air)
                }
            }
            is SkaterState.Grinding -> if (state.trick == Trick.Boardslide) {
                // The board turned across the rail, its deck sitting on it and the near
                // wheels hanging down in front; arms out, wobbling to keep balance.
                body.show(look.slide[(run.time * 4).toInt() % look.slide.size])
                board.show(look.boardEndOn)
                board.position(0.0, -2.0)
                body.position(0.0, 2.0)
            } else {
                body.show(look.crouch)
            }
            is SkaterState.Bailed -> {
                body.show(look.bail)
                body.position(-4.0, 0.0)
                board.show(look.boardWheelsUp)
                board.position(16.0, 0.0)
            }
        }
    }

    private fun animateBoard(trick: AirTrick) {
        val progress = trick.progress
        val kickflip = listOf(look.boardSide, look.boardUnderside, look.boardWheelsUp, look.boardGrip)
        val heelflip = listOf(look.boardSide, look.boardGrip, look.boardWheelsUp, look.boardUnderside)
        val frame = min(3, (progress * 4).toInt())
        when (trick.trick) {
            Trick.Kickflip -> board.show(kickflip[frame])
            Trick.Heelflip -> board.show(heelflip[frame])
            Trick.ShoveIt -> {
                // Half a turn, flat, grip tape up.
                spinBoard((progress * (spinSteps / 2)).rounded().toInt(), graphicUp = false, progress = progress)
                return
            }
            Trick.ThreeSixtyFlip -> {
                // A full turn, flipping over on the way: graphic and wheels up in the middle.
                spinBoard((progress * spinSteps).rounded().toInt(), graphicUp = frame == 1 || frame == 2, progress = progress)
                return
            }
            else -> return
        }
        // The board floats up off the feet while it turns.
        board.position(0.0, (4 * sin(progress * PI)).rounded())
    }

    /** The board spinning flat, out in front of the feet, leaving a fading trail behind. */
    private fun spinBoard(step: Int, graphicUp: Boolean, progress: Double) {
        val index = step % spinSteps
        // Side-on at the start and end, so it leaves and comes back to the feet cleanly.
        // Centered just under the shoes, with the knees tucked up a little to make room.
        body.position(0.0, 3 + (3 * sin(progress * PI)).rounded())
        board.z = 1.0
        if (index == 0 || (!graphicUp && index == spinSteps / 2)) {
            board.show(look.boardSide)
        } else {
            board.show(if (graphicUp) look.spinGraphicUp[index] else look.spinGripUp[index])
            board.anchor(0.5, 0.5)
            board.position(0.0, 1.0)
        }
        val texture = board.texture
        if (index != lastSpinStep && texture != null) {
            lastSpinStep = index
            val ghost = SpriteNode(texture)
            ghost.anchor(board.anchorX, board.anchorY)
            ghost.alpha = 0.45
            ghost.position(skater.x + board.x, skater.y + board.y)
            ghost.z = skater.z - 0.5
            world.addChild(ghost)
            ghost.run(Action.sequence(Action.fadeOut(0.12), Action.removeFromParent()))
        }
    }

    private fun spark(z: Double) {
        val colors = listOf(Palette.yellow, Palette.white, Palette.orange)
        val dot = SpriteNode.rect(colors.random(), 1.0, 1.0)
        dot.anchor(0.0, 0.0)
        dot.z = z
        dot.position(skater.x - Random.nextInt(2, 7), skater.y)
        world.addChild(dot)
        dot.run(
            Action.sequence(
                Action.group(
                    Action.moveBy(-Random.nextDouble(6.0, 14.0), Random.nextDouble(1.0, 6.0), 0.2),
                    Action.fadeOut(0.2),
                ),
                Action.removeFromParent(),
            ),
        )
    }

    private fun renderHud() {
        scoreLabel.text = "SCORE ${run.score}"
        val best = progress.bestScore(level)
        bestLabel.text = if (best > 0) "BEST $best" else ""
        placeBestLabel()
        // The combo, or on the tutorial spot a hint when there's no combo going.
        comboLabel.text = if (run.combo.isEmpty) hint() else run.combo.text(maxTricks = 2)
        multiplierLabel.text = if (run.combo.multiplier > 1) "X${run.combo.multiplier}  ${run.combo.total}" else ""
        val left = run.comboLinkLeft
        if (left != null) {
            comboMeter.isHidden = false
            comboMeter.position(comboMeterX, comboMeterY)
            comboMeter.size(max(1.0, (comboMeterWidth * (left / Tuning.comboLinkTime)).rounded()), 2.0)
            comboMeter.color = if (left < 0.4) Palette.orange else Palette.yellow
        } else {
            comboMeter.isHidden = true
        }
    }

    /** BEST sits on the score's line, just after the score. */
    private fun placeBestLabel() {
        bestLabel.position(scoreLabel.x + scoreLabel.width + 8, scoreLabel.y)
    }

    /** First-run help, shown along the start of the tutorial spot. */
    private fun hint(): String {
        if (!level.showsHints) return ""
        return when {
            run.x < 330 -> "TAP TO OLLIE. HOLD: HIGHER"
            run.x < 640 -> "SWIPE UP/DOWN: LANES"
            run.x < 950 -> "SWIPE SIDEWAYS: KICKFLIP"
            run.x < 1250 -> "TAP IN THE AIR: GRAB"
            run.x < 1550 -> "AIR SWIPE UP/DOWN: SPINS"
            run.x < 1800 -> "TRICK AGAIN SOON: COMBO"
            else -> ""
        }
    }

    // Debug

    /** The fireworks, on an empty results screen, for checking how they look
     *  (`--ez fireworks true` on a debug build). Saves nothing. */
    fun showFireworksForTesting() {
        celebrateAllGoals {
            showOverlay("ALL ${city.name} GOALS!", listOf(goalLines(hints = false)), emptyList())
            fireworks()
        }
    }

    private companion object {
        const val stepLength = 1.0 / 120
        const val comboMeterWidth = 40.0
        val spinSteps = com.tuesdaygames.skate.art.CharacterArt.spinSteps

        /** Off for now: the slow motion felt jarring. See the backlog. */
        const val slowMotionOn = false

        val callouts = listOf(1000 to "SICK!", 2500 to "GNARLY!", 5000 to "RADICAL!", 10000 to "LEGENDARY!")
    }
}
