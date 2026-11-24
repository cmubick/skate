//
//  GameScene.swift
//  skate
//
//  Draws a run and feeds it touches. All the rules live in `Run`; this file
//  only turns what the run is doing into pixels, sounds and haptics.
//
//  The scene is sized in game pixels (at least 180 x 96), with the origin at the
//  bottom left and the street along the bottom.
//

import SpriteKit
import UIKit

final class GameScene: PixelScene {

    private let level: Level
    private let city: City
    private let look: SkaterLook
    private let progress = Progress.shared
    private var run: Run
    private var gestures = GestureReader()
    private weak var activeTouch: UITouch?

    private var lastUpdate: TimeInterval?
    private var stepTime: TimeInterval = 0
    private static let step: TimeInterval = 1.0 / 120

    // The street.
    private let world = SKNode()
    private let cam = SKCameraNode()
    private var strips: [ParallaxStrip] = []
    private var featureNodes: [(node: SKSpriteNode, look: FeatureLook)] = []
    private var letterNodes: [Int: SKSpriteNode] = [:]

    // The skater.
    private let skater = SKNode()
    private let body = SKSpriteNode()
    private let board = SKSpriteNode()
    /// The last picture of a spinning board, so each new one leaves a ghost behind.
    private var lastSpinStep: Int?
    private let shadow = SKSpriteNode(texture: StreetArt.shadow())
    private var sparkTimer: TimeInterval = 0
    /// How far the camera has risen to keep a high jump on screen.
    private var cameraLift: CGFloat = 0
    /// True while the grind rumble and sound are on, so they can't be left running.
    private var grindFeedbackOn = false

    // The HUD, drawn over everything and fixed to the screen.
    private let scoreLabel = PixelLabel(anchor: CGPoint(x: 0, y: 1))
    private let bestLabel = PixelLabel(anchor: CGPoint(x: 0, y: 1))
    private let comboLabel = PixelLabel(anchor: CGPoint(x: 0.5, y: 1))
    private let multiplierLabel = PixelLabel(anchor: CGPoint(x: 0.5, y: 1))
    private let lettersLabel = SKSpriteNode()
    private let pauseButton = PixelButton(PixelFont.pauseSymbol) {}

    /// The combo meter: drains while you roll after a landing. Trick again before it's gone.
    private let comboMeter = SKSpriteNode(color: Palette.yellow.skColor, size: CGSize(width: 1, height: 2))
    private var comboMeterOrigin: CGPoint = .zero
    private static let comboMeterWidth: CGFloat = 40
    /// Goal and gap banners, callouts and the city celebration, over the street.
    private let banners = SKNode()

    // Goals.
    private var goalTracker: GoalTracker
    /// Done on earlier runs, and done on this one.
    private let goalsBefore: Set<String>
    private var goalsThisRun: Set<String> = []
    private let cityWasComplete: Bool
    private var cityCompletedThisRun = false

    // Feel.
    private var timeScale = 1.0
    private var slowMoLeft: TimeInterval = 0
    private var shakeLeft: TimeInterval = 0
    /// The biggest callout given for the combo going now.
    private var announcedTier = 0
    private static let callouts: [(points: Int, text: String)] = [
        (1000, "SICK!"), (2500, "GNARLY!"), (5000, "RADICAL!"), (10000, "LEGENDARY!"),
    ]

    /// The pause menu or the end-of-run results, over everything.
    private let overlay = SKNode()
    private var overlayButtons: [PixelButton] = []
    private var overlayTouchStart: CGPoint?
    private var isOnBreak = false

    init(size: CGSize, level: Level, city: City, outfit: Outfit) {
        self.level = level
        self.city = city
        look = SkaterLook(outfit: outfit)
        run = Run(level: level)
        goalsBefore = Progress.shared.goalsDone(at: level)
        goalTracker = GoalTracker(goals: level.goals, alreadyMet: goalsBefore)
        cityWasComplete = Progress.shared.isComplete(city)
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Building the scene

    override func didMove(to view: SKView) {
        let theme = ThemeArt.look(for: level.theme)
        backgroundColor = theme.sky.skColor
        anchorPoint = .zero
        addChild(world)
        addChild(cam)
        camera = cam

        let groundTop = CGFloat(StreetArt.groundTop)
        strips = theme.layers.enumerated().map { index, layer in
            ParallaxStrip(texture: layer.texture, factor: layer.factor, y: groundTop + layer.lift, z: CGFloat(-30 + index * 10))
        } + [ParallaxStrip(texture: theme.ground, factor: 1, y: 0, z: -10)]
        strips.forEach { world.addChild($0.node) }

        for (index, feature) in level.features.enumerated() {
            let featureLook = FeatureArt.look(for: feature, seed: index)
            let lane = CGFloat(feature.lane.rawValue)
            let node = SKSpriteNode(texture: featureLook.frames[0])
            node.anchorPoint = .zero
            node.position = CGPoint(x: feature.x + featureLook.offset.x,
                                    y: StreetArt.baseline(forLane: lane) + featureLook.offset.y)
            // Holes and tracks lie on the ground, under anything in their lane.
            let onGround = feature.kind == .hole || feature.isLow
            node.zPosition = laneZ(lane) - (onGround ? 3 : 0)
            world.addChild(node)
            featureNodes.append((node, featureLook))

            if !onGround {
                let footprint = SKSpriteNode(color: Palette.shadow.skColor, size: CGSize(width: feature.length, height: 1))
                footprint.anchorPoint = .zero
                footprint.position = CGPoint(x: 1, y: -1 - featureLook.offset.y)
                footprint.zPosition = -1
                node.addChild(footprint)
            }
        }

        let found = progress.letters(in: city)
        for pickup in level.letters {
            let token = SKSpriteNode(texture: LetterArt.token(pickup.letter, found: found.contains(pickup.index)))
            token.anchorPoint = .zero
            let lane = CGFloat(pickup.lane.rawValue)
            token.position = CGPoint(x: pickup.x - 5, y: StreetArt.baseline(forLane: lane) + pickup.height)
            token.zPosition = laneZ(lane) + 4
            token.run(.repeatForever(.sequence([.moveBy(x: 0, y: 1, duration: 0.3), .moveBy(x: 0, y: -1, duration: 0.3)])))
            world.addChild(token)
            letterNodes[pickup.index] = token
        }

        let finish = SKSpriteNode(texture: FeatureArt.finishLine(height: 46))
        finish.anchorPoint = .zero
        finish.position = CGPoint(x: level.length, y: 8)
        finish.zPosition = -5
        world.addChild(finish)

        body.anchorPoint = CGPoint(x: 0.5, y: 0)
        body.position = CGPoint(x: 0, y: 3)
        board.anchorPoint = CGPoint(x: 0.5, y: 0)
        skater.addChild(board)
        skater.addChild(body)
        world.addChild(skater)
        shadow.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        world.addChild(shadow)

        for label in [scoreLabel, bestLabel, comboLabel, multiplierLabel] {
            label.zPosition = 100
            cam.addChild(label)
        }
        multiplierLabel.ink = Palette.yellow
        lettersLabel.anchorPoint = .zero
        lettersLabel.zPosition = 100
        cam.addChild(lettersLabel)
        pauseButton.zPosition = 100
        cam.addChild(pauseButton)
        comboMeter.anchorPoint = CGPoint(x: 0, y: 0.5)
        comboMeter.zPosition = 100
        comboMeter.isHidden = true
        cam.addChild(comboMeter)
        banners.zPosition = 150
        cam.addChild(banners)
        overlay.zPosition = 200
        cam.addChild(overlay)

        Haptics.prepare()
        _ = Sounds.shared
        updateLettersLabel()
        layoutScene()
        render()
        if !level.goals.isEmpty { showIntro() }

        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive),
                                               name: UIApplication.willResignActiveNotification, object: nil)
    }

    @objc private func appWillResignActive() {
        stopGrindFeedback()
        if !run.isFinished, !isOnBreak { openPauseMenu() }
    }

    override func layoutScene() {
        guard view != nil else { return }
        // HUD positions are relative to the camera, at the middle of the screen.
        let safe = safeFrame.offsetBy(dx: -size.width / 2, dy: -size.height / 2)
        let line = CGFloat(PixelFont.glyphHeight + 3)
        scoreLabel.position = CGPoint(x: safe.minX, y: safe.maxY)
        placeBestLabel()
        lettersLabel.position = CGPoint(x: safe.minX, y: (safe.minY + 1).rounded())
        pauseButton.position = CGPoint(x: (safe.maxX - 8).rounded(), y: (safe.maxY - 6).rounded())
        // The combo (or a tip) gets the whole second line, centered in the room left of the pause button.
        let pauseLeft = pauseButton.calculateAccumulatedFrame().minX
        let middle = ((safe.minX + pauseLeft - 2) / 2).rounded(.down)
        comboLabel.position = CGPoint(x: middle, y: safe.maxY - line)
        multiplierLabel.position = CGPoint(x: middle, y: safe.maxY - line * 2)
        comboMeterOrigin = CGPoint(x: middle - Self.comboMeterWidth / 2, y: safe.maxY - line * 3 + 1)
        strips.forEach { $0.layout(viewWidth: size.width) }
    }

    private func updateLettersLabel() {
        let found = progress.letters(in: city)
        let runs = city.letters.enumerated().map { index, letter in
            (String(letter), found.contains(index) ? Palette.yellow : PixelColor(0xA8A8A8))
        }
        let texture = PixelFont.texture(runs: runs)
        lettersLabel.texture = texture
        lettersLabel.size = texture.size()
    }

    // MARK: Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view, let touch = touches.first else { return }
        let point = touch.location(in: cam)
        if isOnBreak || run.isFinished {
            overlayTouchStart = point
            return
        }
        if activeTouch == nil, pauseButton.hit(point) {
            openPauseMenu()
            return
        }
        guard activeTouch == nil else { return }
        activeTouch = touch
        apply(gestures.began(at: touch.location(in: view), time: touch.timestamp))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view, let touch = activeTouch, touches.contains(touch) else { return }
        apply(gestures.moved(to: touch.location(in: view), time: touch.timestamp))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let start = overlayTouchStart, let touch = touches.first {
            overlayTouchStart = nil
            let point = touch.location(in: cam)
            if let button = overlayButtons.first(where: { $0.hit(start) && $0.hit(point) }) {
                Sounds.shared.play(.pop)
                Haptics.pop(charged: false)
                button.action()
            }
            return
        }
        guard let view, let touch = activeTouch, touches.contains(touch) else { return }
        activeTouch = nil
        apply(gestures.ended(at: touch.location(in: view), time: touch.timestamp))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        overlayTouchStart = nil
        guard let touch = activeTouch, touches.contains(touch) else { return }
        activeTouch = nil
        apply(gestures.cancelled(time: touch.timestamp))
    }

    private func apply(_ gestureEvents: [GestureEvent]) {
        for gesture in gestureEvents {
            react(run.handle(gesture))
        }
    }

    // MARK: The loop

    override func update(_ currentTime: TimeInterval) {
        let dt = min(0.1, currentTime - (lastUpdate ?? currentTime))
        lastUpdate = currentTime
        guard !isOnBreak else { return }
        apply(gestures.tick(time: currentTime))

        // Slow motion for a moment after something big.
        if slowMoLeft > 0 {
            slowMoLeft -= dt
            if slowMoLeft <= 0 { timeScale = 1 }
        }
        shakeLeft = max(0, shakeLeft - dt)

        // Fixed steps, so the run plays the same at any frame rate.
        stepTime += dt * timeScale
        while stepTime >= Self.step {
            stepTime -= Self.step
            let events = run.step(Self.step)
            trackGoals(events)
            react(events)
        }
        sparkTimer += dt
        // A safety net: whatever happened, no rumble or grind sound unless on a rail.
        if grindFeedbackOn, !run.isGrinding { stopGrindFeedback() }
        render(dt: dt)
    }

    private func startGrindFeedback() {
        grindFeedbackOn = true
        Haptics.startGrind()
        Sounds.shared.startLoop(.grind)
    }

    private func stopGrindFeedback() {
        grindFeedbackOn = false
        Haptics.stopGrind()
        Sounds.shared.stopLoop(.grind)
    }

    // MARK: Pause and results

    /// One line on the pause menu or results: crossed out when it's a goal that's done,
    /// or a row of hopping letters for a city just spelled.
    private struct OverlayLine {
        var text: String
        var color: PixelColor
        var struck = false
        var hopping = false
    }

    /// A title across the top, one or two columns of lines, and buttons along the bottom.
    private func showOverlay(title: String, columns: [[OverlayLine]], buttons: [(String, PixelColor, () -> Void)]) {
        overlay.removeAllChildren()
        overlayButtons.removeAll()
        setHudHidden(true)
        let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.75), size: CGSize(width: size.width + 4, height: size.height + 4))
        dim.zPosition = -1
        overlay.addChild(dim)

        let rows = columns.map(\.count).max() ?? 0
        let top = CGFloat(10 * (rows + 1) / 2) + 10
        addOverlayLabel(OverlayLine(text: title, color: Palette.yellow), at: CGPoint(x: 0, y: top))
        let half = (safeFrame.width / 4).rounded()
        for (index, column) in columns.enumerated() {
            let x: CGFloat = columns.count == 1 ? 0 : (index == 0 ? -half : half)
            for (row, line) in column.enumerated() {
                addOverlayLabel(line, at: CGPoint(x: x, y: top - CGFloat(10 * (row + 1))))
            }
        }
        let buttonY = top - CGFloat(10 * (rows + 1)) - 6
        let spacing: CGFloat = 52
        let firstX = -spacing * CGFloat(buttons.count - 1) / 2
        for (index, (text, color, action)) in buttons.enumerated() {
            let button = PixelButton(text, minWidth: 46, color: color, action: action)
            button.position = CGPoint(x: (firstX + CGFloat(index) * spacing).rounded(), y: buttonY.rounded())
            overlay.addChild(button)
            overlayButtons.append(button)
        }
    }

    private func addOverlayLabel(_ line: OverlayLine, at point: CGPoint) {
        let point = CGPoint(x: point.x.rounded(), y: point.y.rounded())
        if line.hopping {
            // Each letter hops in turn, over and over.
            let letters = line.text.map(String.init)
            let width = CGFloat(PixelFont.width(of: line.text))
            var x = point.x - (width / 2).rounded()
            for (index, letter) in letters.enumerated() {
                let label = PixelLabel(anchor: CGPoint(x: 0, y: 0.5))
                label.ink = index.isMultiple(of: 2) ? Palette.yellow : Palette.orange
                label.text = letter
                label.position = CGPoint(x: x, y: point.y)
                overlay.addChild(label)
                label.run(.sequence([
                    .wait(forDuration: Double(index) * 0.08),
                    .repeatForever(.sequence([
                        .moveBy(x: 0, y: 3, duration: 0.1), .moveBy(x: 0, y: -3, duration: 0.1), .wait(forDuration: 0.9),
                    ])),
                ]))
                x += CGFloat(PixelFont.width(of: letter) + PixelFont.gap)
            }
            return
        }
        let label = PixelLabel(anchor: CGPoint(x: 0.5, y: 0.5))
        label.ink = line.color
        label.text = line.text
        label.position = point
        overlay.addChild(label)
        if line.struck {
            let width = CGFloat(PixelFont.width(of: line.text) + 2)
            let strike = SKSpriteNode(color: line.color.skColor, size: CGSize(width: width, height: 1))
            strike.position = CGPoint(x: point.x, y: point.y + 0.5)
            strike.zPosition = 1
            overlay.addChild(strike)
        }
    }

    /// The spot's goals, crossed out once done.
    private func goalLines() -> [OverlayLine] {
        let doneCount = level.goals.filter { goalsBefore.contains($0.id) || goalsThisRun.contains($0.id) }.count
        return [OverlayLine(text: "GOALS \(doneCount)/\(level.goals.count)", color: Palette.yellow)] + level.goals.map { goal in
            if goalsThisRun.contains(goal.id) { return OverlayLine(text: goal.text, color: Palette.yellow, struck: true) }
            if goalsBefore.contains(goal.id) { return OverlayLine(text: goal.text, color: PixelColor(0x8C8C8C), struck: true) }
            return OverlayLine(text: goal.text, color: Palette.white)
        }
    }

    /// Before the run: the spot's goals, so you know what to go for.
    private func showIntro() {
        isOnBreak = true
        showOverlay(title: level.name, columns: [goalLines()], buttons: [
            ("GO", PixelColor(0x00A844), { [weak self] in self?.closePauseMenu() }),
            ("SPOTS", PixelColor(0x24308C), { [weak self] in self?.leave() }),
        ])
    }

    private func openPauseMenu() {
        isOnBreak = true
        activeTouch = nil
        gestures = GestureReader()
        stopGrindFeedback()
        showOverlay(title: "PAUSED", columns: [goalLines()], buttons: [
            ("RESUME", PixelColor(0x00A844), { [weak self] in self?.closePauseMenu() }),
            ("QUIT", PixelColor(0x24308C), { [weak self] in self?.leave() }),
        ])
    }

    /// The HUD steps aside while a menu or the results are up.
    private func setHudHidden(_ hidden: Bool) {
        for node in [scoreLabel, bestLabel, comboLabel, multiplierLabel, lettersLabel, pauseButton, banners] as [SKNode] {
            node.alpha = hidden ? 0 : 1
        }
    }

    private func closePauseMenu() {
        isOnBreak = false
        setHudHidden(false)
        overlay.removeAllChildren()
        overlayButtons.removeAll()
        lastUpdate = nil
    }

    private func leave() {
        stopGrindFeedback()
        router?.showMenu(.spots(city))
    }

    private func showResults(score: Int) {
        let isBest = progress.record(score: score, at: level)
        let columnWidth = Int(safeFrame.width / 2) - 6
        var stats: [OverlayLine] = [
            OverlayLine(text: "SCORE \(score)", color: Palette.white),
            OverlayLine(text: isBest ? "NEW BEST!" : "BEST \(progress.bestScore(at: level))",
                        color: isBest ? Palette.yellow : Palette.lightGrey),
        ]
        if run.bestCombo > 0 {
            stats.append(OverlayLine(text: "COMBO \(run.bestCombo)", color: Palette.white))
            // As many of its last tricks as fit.
            let tricks = run.bestComboTricks.components(separatedBy: " + ").filter { $0 != "..." }
            var shown = tricks.suffix(2).joined(separator: " + ")
            if PixelFont.width(of: shown) > columnWidth { shown = tricks.last ?? "" }
            stats.append(OverlayLine(text: shown, color: Palette.lightGrey))
        }
        if cityCompletedThisRun {
            stats.append(OverlayLine(text: city.name.filter { $0 != " " }, color: Palette.yellow, hopping: true))
            stats.append(OverlayLine(text: "PDX BOARD!", color: Palette.orange))
        } else {
            let foundHere = run.lettersFound.sorted().map { String(city.letters[$0]) }.joined(separator: " ")
            if !foundHere.isEmpty { stats.append(OverlayLine(text: "FOUND \(foundHere)", color: Palette.yellow)) }
        }

        var buttons: [(String, PixelColor, () -> Void)] = [
            ("AGAIN", PixelColor(0x00A844), { [weak self] in
                guard let self else { return }
                self.router?.play(self.level, in: self.city)
            }),
        ]
        if let index = city.levels.firstIndex(of: level), index + 1 < city.levels.count {
            let next = city.levels[index + 1]
            buttons.append(("NEXT", PixelColor(0x24308C), { [weak self] in
                guard let self else { return }
                self.router?.play(next, in: self.city)
            }))
        }
        buttons.append(("SPOTS", PixelColor(0x24308C), { [weak self] in self?.leave() }))
        let columns = level.goals.isEmpty ? [stats] : [stats, goalLines()]
        showOverlay(title: "FINISH!", columns: columns, buttons: buttons)
    }

    // MARK: Goals

    private func trackGoals(_ events: [RunEvent]) {
        for goal in goalTracker.update(run: run, events: events, dt: Self.step) {
            progress.complete(goal: goal, at: level)
            goalsThisRun.insert(goal.id)
            Sounds.shared.play(.letter)
            Haptics.land(perfect: true)
            showBanner(goal.text, title: "GOAL!", color: Palette.yellow)
        }
    }

    /// A banner across the top of the street for a moment: a goal done, or a gap.
    private func showBanner(_ text: String, title: String, color: PixelColor) {
        let stack = banners.children.filter { $0.name == "banner" }.count
        let banner = SKNode()
        banner.name = "banner"
        let safe = safeFrame.offsetBy(dx: -size.width / 2, dy: -size.height / 2)
        let y = (safe.maxY - 34 - CGFloat(stack) * 11).rounded()
        let label = PixelLabel(anchor: CGPoint(x: 0.5, y: 0.5))
        label.ink = color
        label.text = "\(title) \(text)"
        let back = SKSpriteNode(color: SKColor(white: 0, alpha: 0.55),
                                size: CGSize(width: label.size.width + 8, height: label.size.height + 3))
        back.zPosition = -1
        banner.addChild(back)
        banner.addChild(label)
        banner.position = CGPoint(x: 0, y: y + 6)
        banner.alpha = 0
        banners.addChild(banner)
        banner.run(.sequence([
            .group([.fadeIn(withDuration: 0.12), .moveBy(x: 0, y: -6, duration: 0.12)]),
            .wait(forDuration: 1.4),
            .fadeOut(withDuration: 0.3),
            .removeFromParent(),
        ]))
    }

    // MARK: Big moments

    private func slowMotion(for seconds: TimeInterval, scale: Double = 0.35) {
        timeScale = scale
        slowMoLeft = max(slowMoLeft, seconds)
    }

    /// SICK!, GNARLY! and so on, once each as a combo grows.
    private func checkCallout(total: Int) {
        guard let tier = Self.callouts.lastIndex(where: { total >= $0.points }), tier + 1 > announcedTier else { return }
        announcedTier = tier + 1
        let label = PixelLabel(anchor: CGPoint(x: 0.5, y: 0.5))
        label.ink = [Palette.yellow, Palette.orange, PixelColor(0xF878B8), Palette.white][min(tier, 3)]
        label.text = Self.callouts[tier].text
        label.setScale(2)
        label.position = CGPoint(x: 0, y: 6)
        banners.addChild(label)
        label.run(.sequence([
            .moveBy(x: 0, y: 4, duration: 0.15),
            .wait(forDuration: 0.6),
            .fadeOut(withDuration: 0.3),
            .removeFromParent(),
        ]))
        Haptics.land(perfect: true)
        slowMotion(for: 0.45)
    }

    /// The last letter of the city: the name hops in, letter by letter, and the reward shows.
    private func celebrateCity() {
        let name = city.name.filter { $0 != " " }
        let letters = name.map(String.init)
        let width = CGFloat(PixelFont.width(of: name) * 2)
        var x = -(width / 2).rounded()
        let colors = [Palette.yellow, Palette.orange, PixelColor(0xF878B8), Palette.white]
        for (index, letter) in letters.enumerated() {
            let label = PixelLabel(anchor: CGPoint(x: 0, y: 0.5))
            label.ink = colors[index % colors.count]
            label.text = letter
            label.setScale(2)
            label.position = CGPoint(x: x, y: 4)
            label.alpha = 0
            banners.addChild(label)
            var flash = 0
            label.run(.sequence([
                .wait(forDuration: 0.1 * Double(index)),
                .group([.fadeIn(withDuration: 0.05), .sequence([.moveBy(x: 0, y: 8, duration: 0.1), .moveBy(x: 0, y: -8, duration: 0.12)])]),
                .repeat(.sequence([
                    .wait(forDuration: 0.1),
                    .run { flash += 1; label.ink = colors[(index + flash) % colors.count] },
                ]), count: 16),
                .fadeOut(withDuration: 0.3),
                .removeFromParent(),
            ]))
            x += CGFloat((PixelFont.width(of: letter) + PixelFont.gap) * 2)
        }
        let reward = PixelLabel(anchor: CGPoint(x: 0.5, y: 0.5))
        reward.ink = Palette.white
        reward.text = "\(city.name) SPELLED! PDX BOARD"
        reward.position = CGPoint(x: 0, y: -14)
        reward.alpha = 0
        banners.addChild(reward)
        reward.run(.sequence([.wait(forDuration: 0.9), .fadeIn(withDuration: 0.1), .wait(forDuration: 1.6),
                              .fadeOut(withDuration: 0.3), .removeFromParent()]))
        for _ in 0..<24 { spark(z: skater.zPosition + 6) }
        Sounds.shared.play(.finish)
        Haptics.finish()
        slowMotion(for: 0.8, scale: 0.4)
    }

    // MARK: Reacting

    private func react(_ events: [RunEvent]) {
        for event in events {
            switch event {
            case .ollie(let charged):
                Sounds.shared.play(.pop)
                Haptics.pop(charged: charged)
            case .popOff, .launched:
                Sounds.shared.play(.pop)
                Haptics.pop(charged: false)
            case .trickStarted:
                Sounds.shared.play(.trick)
            case .grindStarted:
                startGrindFeedback()
            case .grindSwitched:
                Haptics.tick()
                Sounds.shared.play(.trick)
            case .grindEnded:
                stopGrindFeedback()
            case .landed(let perfect):
                Sounds.shared.play(perfect ? .perfect : .land)
                Haptics.land(perfect: perfect)
                if perfect { popup("PERFECT!", color: Palette.yellow, rise: 8) }
                checkCallout(total: run.combo.total)
            case .landedTrick:
                break
            case .banked(let points):
                checkCallout(total: points)
                announcedTier = 0
                if points > Int(Trick.ollie.basePoints) { popup("+\(points)", color: Palette.white, rise: 0) }
            case .gap(let name, let points):
                Sounds.shared.play(.perfect)
                Haptics.land(perfect: true)
                showBanner("+\(points)", title: name, color: Palette.orange)
            case .bail(let reason):
                Sounds.shared.play(.bail)
                Haptics.bail()
                shakeLeft = 0.3
                announcedTier = 0
                popup(reason == .fell ? "MANHOLE!" : "BAIL", color: Palette.orange, rise: 0)
            case .laneSwitch:
                Sounds.shared.play(.lane)
                Haptics.tick()
            case .cleared(let style, _, let points):
                popup("\(style.name) +\(points)", color: Palette.yellow, rise: 16)
            case .letter(let index, let letter):
                Sounds.shared.play(.letter)
                Haptics.land(perfect: true)
                let isNew = progress.collect(letter: index, in: city)
                popup(isNew ? "\(letter)!" : "\(letter)", color: Palette.yellow, rise: 8)
                letterNodes[index]?.removeFromParent()
                letterNodes[index] = nil
                updateLettersLabel()
                if isNew, !cityWasComplete, !cityCompletedThisRun, progress.isComplete(city) {
                    cityCompletedThisRun = true
                    celebrateCity()
                }
            case .finished(let score):
                stopGrindFeedback()
                Sounds.shared.play(.finish)
                Haptics.finish()
                showResults(score: score)
            }
        }
    }

    private func popup(_ text: String, color: PixelColor, rise: CGFloat) {
        let label = PixelLabel(anchor: CGPoint(x: 0.5, y: 0))
        label.ink = color
        label.text = text
        label.zPosition = 60
        label.position = CGPoint(x: skater.position.x, y: (skater.position.y + 26 + rise).rounded())
        world.addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 10, duration: 0.7), .sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 0.3)])]),
            .removeFromParent(),
        ]))
    }

    // MARK: Drawing

    private func laneZ(_ lane: CGFloat) -> CGFloat {
        CGFloat(10 * (Int(lane.rounded()) + 1))
    }

    private func render(dt: TimeInterval = 0) {
        let baseline = StreetArt.baseline(forLane: run.drawnLane)
        let z = laneZ(run.drawnLane)

        // Camera: the skater sits 30% in from the left, so you can see what's coming,
        // and the camera rises when a big jump would take their head off the top.
        let cameraLeft = (run.x - size.width * 0.3).rounded()
        let skaterTop = baseline + run.height + 26
        let wantedLift = max(0, skaterTop - size.height)
        cameraLift += (wantedLift - cameraLift) * CGFloat(min(1, dt * 12))
        cam.position = CGPoint(x: cameraLeft + size.width / 2, y: size.height / 2 + cameraLift.rounded())
        if shakeLeft > 0 {
            // A bail rattles the screen for a moment, settling as it goes.
            let amount = shakeLeft > 0.15 ? 2 : 1
            cam.position.x += CGFloat(Int.random(in: -amount...amount))
            cam.position.y += CGFloat(Int.random(in: -amount...amount))
        }
        strips.forEach { $0.update(cameraLeft: cameraLeft) }

        // Moving things, and their walk cycles.
        let frame = Int(run.time * 6) % 2
        for (index, feature) in level.features.enumerated() where feature.isMoving {
            let (node, featureLook) = featureNodes[index]
            let x = run.position(ofFeature: index) + featureLook.offset.x
            node.position.x = x.rounded()
            if featureLook.frames.count > 1, x != feature.x + featureLook.offset.x {
                node.texture = featureLook.frames[frame]
            }
        }

        skater.position = CGPoint(x: run.x.rounded(), y: (baseline + run.height).rounded())
        skater.zPosition = z + 5
        shadow.position = CGPoint(x: run.x.rounded(), y: baseline.rounded())
        shadow.zPosition = z - 0.5

        renderSkater()
        if case .grinding = run.state, sparkTimer > 0.04 {
            sparkTimer = 0
            spark(z: z + 6)
        }
        renderHud()
    }

    private func renderSkater() {
        board.zRotation = 0
        board.xScale = 1
        board.position = .zero
        board.anchorPoint = CGPoint(x: 0.5, y: 0)
        board.zPosition = 0
        if let trick = run.airTrick?.trick, trick == .shoveIt || trick == .threeSixtyFlip {} else { lastSpinStep = nil }
        board.texture = look.boardSide
        body.position = CGPoint(x: 0, y: 3)

        switch run.state {
        case .rolling:
            body.texture = look.roll
        case .airborne:
            if let trick = run.airTrick {
                body.texture = trick.trick == .grab ? look.grab : look.air
                animateBoard(trick)
            } else {
                body.texture = look.air
            }
        case .grinding(_, let trick):
            body.texture = look.crouch
            if trick == .boardslide { board.xScale = 0.375 }
        case .bailed:
            body.texture = look.bail
            body.position = CGPoint(x: -4, y: 0)
            board.texture = look.boardWheelsUp
            board.position = CGPoint(x: 16, y: 0)
        }
        if let texture = body.texture { body.size = texture.size() }
        if let texture = board.texture { board.size = texture.size() }
    }

    private func animateBoard(_ trick: AirTrick) {
        let progress = trick.progress
        let kickflip = [look.boardSide, look.boardUnderside, look.boardWheelsUp, look.boardGrip]
        let heelflip = [look.boardSide, look.boardGrip, look.boardWheelsUp, look.boardUnderside]
        let frame = min(3, Int(progress * 4))
        switch trick.trick {
        case .kickflip:
            board.texture = kickflip[frame]
        case .heelflip:
            board.texture = heelflip[frame]
        case .shoveIt:
            // Half a turn, flat, grip tape up.
            spinBoard(step: Int((progress * Double(CharacterArt.spinSteps / 2)).rounded()), graphicUp: false,
                      progress: progress)
            return
        case .threeSixtyFlip:
            // A full turn, flipping over on the way: graphic and wheels up in the middle.
            spinBoard(step: Int((progress * Double(CharacterArt.spinSteps)).rounded()), graphicUp: frame == 1 || frame == 2,
                      progress: progress)
            return
        default:
            return
        }
        // The board floats up off the feet while it turns.
        board.position = CGPoint(x: 0, y: (4 * sin(progress * .pi)).rounded())
    }

    /// The board spinning flat, out in front of the feet, leaving a fading trail behind.
    private func spinBoard(step: Int, graphicUp: Bool, progress: Double) {
        let index = step % CharacterArt.spinSteps
        // Side-on at the start and end, so it leaves and comes back to the feet cleanly.
        // Centered just under the shoes, with the knees tucked up a little to make room.
        body.position = CGPoint(x: 0, y: 3 + (3 * sin(progress * .pi)).rounded())
        board.zPosition = 1
        if index == 0 || (!graphicUp && index == CharacterArt.spinSteps / 2) {
            board.texture = look.boardSide
        } else {
            board.texture = graphicUp ? look.spinGraphicUp[index] : look.spinGripUp[index]
            board.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            board.position = CGPoint(x: 0, y: 1)
        }
        if index != lastSpinStep, let texture = board.texture {
            lastSpinStep = index
            let ghost = SKSpriteNode(texture: texture)
            ghost.anchorPoint = board.anchorPoint
            ghost.size = texture.size()
            ghost.alpha = 0.45
            ghost.position = CGPoint(x: skater.position.x + board.position.x, y: skater.position.y + board.position.y)
            ghost.zPosition = skater.zPosition - 0.5
            world.addChild(ghost)
            ghost.run(.sequence([.fadeOut(withDuration: 0.12), .removeFromParent()]))
        }
    }

    private func spark(z: CGFloat) {
        let colors = [Palette.yellow, Palette.white, Palette.orange]
        let dot = SKSpriteNode(color: colors.randomElement()!.skColor, size: CGSize(width: 1, height: 1))
        dot.anchorPoint = .zero
        dot.zPosition = z
        dot.position = CGPoint(x: skater.position.x - CGFloat(Int.random(in: 2...6)), y: skater.position.y)
        world.addChild(dot)
        dot.run(.sequence([
            .group([.moveBy(x: -CGFloat.random(in: 6...14), y: CGFloat.random(in: 1...6), duration: 0.2),
                    .fadeOut(withDuration: 0.2)]),
            .removeFromParent(),
        ]))
    }

    private func renderHud() {
        scoreLabel.text = "SCORE \(run.score)"
        let best = progress.bestScore(at: level)
        bestLabel.text = best > 0 ? "BEST \(best)" : ""
        placeBestLabel()
        // The combo, or on the tutorial spot a hint when there's no combo going.
        comboLabel.text = run.combo.isEmpty ? hint() : run.combo.text(maxTricks: 2)
        multiplierLabel.text = run.combo.multiplier > 1 ? "X\(run.combo.multiplier)  \(run.combo.total)" : ""
        if let left = run.comboLinkLeft {
            comboMeter.isHidden = false
            comboMeter.position = comboMeterOrigin
            comboMeter.size = CGSize(width: max(1, (Self.comboMeterWidth * CGFloat(left / Tuning.comboLinkTime)).rounded()), height: 2)
            comboMeter.color = left < 0.4 ? Palette.orange.skColor : Palette.yellow.skColor
        } else {
            comboMeter.isHidden = true
        }
    }

    /// BEST sits on the score's line, just after the score.
    private func placeBestLabel() {
        bestLabel.position = CGPoint(x: scoreLabel.position.x + scoreLabel.size.width + 8, y: scoreLabel.position.y)
    }

    /// First-run help, shown along the start of the tutorial spot.
    private func hint() -> String {
        guard level.showsHints else { return "" }
        switch run.x {
        case ..<330: return "TAP TO OLLIE. HOLD: HIGHER"
        case ..<640: return "SWIPE UP/DOWN: LANES"
        case ..<950: return "SWIPE SIDEWAYS: KICKFLIP"
        case ..<1250: return "TAP IN THE AIR: GRAB"
        case ..<1550: return "AIR SWIPE UP/DOWN: SPINS"
        case ..<1800: return "TRICK AGAIN SOON: COMBO"
        default: return ""
        }
    }
}

// MARK: - Helpers

/// A line of pixel-font text.
final class PixelLabel: SKSpriteNode {
    var text: String = "" {
        didSet { if text != oldValue { redraw() } }
    }
    var ink: PixelColor = Palette.white {
        didSet { if ink != oldValue { redraw() } }
    }

    convenience init(anchor: CGPoint) {
        self.init(texture: nil, color: .clear, size: .zero)
        anchorPoint = anchor
        isHidden = true
    }

    private func redraw() {
        guard !text.isEmpty else {
            isHidden = true
            return
        }
        let texture = PixelFont.texture(text, color: ink)
        self.texture = texture
        size = texture.size()
        isHidden = false
    }
}

/// A row of one texture, repeated across the screen and scrolled at a fraction of
/// the camera's speed so far-off things move slower.
final class ParallaxStrip {
    let node = SKNode()
    private let texture: SKTexture
    private let factor: CGFloat
    private let y: CGFloat
    private var tiles: [SKSpriteNode] = []

    private var tileWidth: CGFloat { texture.size().width }

    init(texture: SKTexture, factor: CGFloat, y: CGFloat, z: CGFloat) {
        self.texture = texture
        self.factor = factor
        self.y = y
        node.zPosition = z
    }

    func layout(viewWidth: CGFloat) {
        let needed = Int((viewWidth / tileWidth).rounded(.up)) + 1
        while tiles.count < needed {
            let tile = SKSpriteNode(texture: texture)
            tile.anchorPoint = .zero
            node.addChild(tile)
            tiles.append(tile)
        }
    }

    func update(cameraLeft: CGFloat) {
        let width = tileWidth
        let scrolled = cameraLeft * factor
        let offset = (scrolled.truncatingRemainder(dividingBy: width) + width).truncatingRemainder(dividingBy: width)
        for (index, tile) in tiles.enumerated() {
            tile.position = CGPoint(x: (cameraLeft - offset + CGFloat(index) * width).rounded(), y: y)
        }
    }
}
