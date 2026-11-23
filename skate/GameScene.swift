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
    private let pauseButton = PixelButton("II") {}

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
        overlay.zPosition = 200
        cam.addChild(overlay)

        Haptics.prepare()
        _ = Sounds.shared
        updateLettersLabel()
        layoutScene()
        render()

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
        bestLabel.position = CGPoint(x: safe.minX, y: safe.maxY - line)
        comboLabel.position = CGPoint(x: 0, y: safe.maxY - line)
        multiplierLabel.position = CGPoint(x: 0, y: safe.maxY - line * 2)
        lettersLabel.position = CGPoint(x: safe.minX, y: (safe.minY + 1).rounded())
        pauseButton.position = CGPoint(x: (safe.maxX - 8).rounded(), y: (safe.maxY - 6).rounded())
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

        // Fixed steps, so the run plays the same at any frame rate.
        stepTime += dt
        while stepTime >= Self.step {
            stepTime -= Self.step
            react(run.step(Self.step))
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

    private func showOverlay(title: String, lines: [(String, PixelColor)], buttons: [(String, PixelColor, () -> Void)]) {
        overlay.removeAllChildren()
        overlayButtons.removeAll()
        let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.6), size: CGSize(width: size.width + 4, height: size.height + 4))
        dim.zPosition = -1
        overlay.addChild(dim)

        var y = CGFloat(10 * (lines.count + 1) / 2) + 10
        for (text, color) in [(title, Palette.yellow)] + lines {
            let label = PixelLabel(anchor: CGPoint(x: 0.5, y: 0.5))
            label.ink = color
            label.text = text
            label.position = CGPoint(x: 0, y: y.rounded())
            overlay.addChild(label)
            y -= 10
        }
        let spacing: CGFloat = 52
        let firstX = -spacing * CGFloat(buttons.count - 1) / 2
        for (index, (text, color, action)) in buttons.enumerated() {
            let button = PixelButton(text, minWidth: 46, color: color, action: action)
            button.position = CGPoint(x: (firstX + CGFloat(index) * spacing).rounded(), y: (y - 6).rounded())
            overlay.addChild(button)
            overlayButtons.append(button)
        }
    }

    private func openPauseMenu() {
        isOnBreak = true
        activeTouch = nil
        gestures = GestureReader()
        stopGrindFeedback()
        showOverlay(title: "PAUSED", lines: [(level.name, Palette.white)], buttons: [
            ("RESUME", PixelColor(0x00A844), { [weak self] in self?.closePauseMenu() }),
            ("QUIT", PixelColor(0x24308C), { [weak self] in self?.leave() }),
        ])
    }

    private func closePauseMenu() {
        isOnBreak = false
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
        let foundHere = run.lettersFound.sorted().map { String(city.letters[$0]) }.joined(separator: " ")
        var lines: [(String, PixelColor)] = [
            ("SCORE \(score)", Palette.white),
            (isBest ? "NEW BEST!" : "BEST \(progress.bestScore(at: level))", isBest ? Palette.yellow : Palette.lightGrey),
        ]
        if !foundHere.isEmpty { lines.append(("LETTERS: \(foundHere)", Palette.yellow)) }

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
        showOverlay(title: "FINISH!", lines: lines, buttons: buttons)
    }

    // MARK: Reacting

    private func react(_ events: [RunEvent]) {
        for event in events {
            switch event {
            case .ollie(let charged):
                Sounds.shared.play(.pop)
                Haptics.pop(charged: charged)
            case .popOff:
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
            case .landed(let points, let perfect):
                Sounds.shared.play(perfect ? .perfect : .land)
                Haptics.land(perfect: perfect)
                if perfect { popup("PERFECT!", color: Palette.yellow, rise: 8) }
                if points > Int(Trick.ollie.basePoints) { popup("+\(points)", color: Palette.white, rise: 0) }
            case .bail(let reason):
                Sounds.shared.play(.bail)
                Haptics.bail()
                popup(reason == .fell ? "SPLASH!" : "BAIL", color: Palette.orange, rise: 0)
            case .laneSwitch:
                Sounds.shared.play(.lane)
                Haptics.tick()
            case .letter(let index, let letter):
                Sounds.shared.play(.letter)
                Haptics.land(perfect: true)
                let isNew = progress.collect(letter: index, in: city)
                popup(isNew ? "\(letter)!" : "\(letter)", color: Palette.yellow, rise: 8)
                letterNodes[index]?.removeFromParent()
                letterNodes[index] = nil
                updateLettersLabel()
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
        board.texture = look.boardSide
        body.position = CGPoint(x: 0, y: 3)

        switch run.state {
        case .rolling:
            body.texture = run.isCharging ? look.crouch : look.roll
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
            board.xScale = steppedScale(cos(progress * .pi))
        case .threeSixtyFlip:
            board.texture = kickflip[frame]
            board.xScale = steppedScale(cos(progress * 2 * .pi))
        default:
            return
        }
        // The board floats up off the feet while it turns.
        board.position = CGPoint(x: 0, y: (4 * sin(progress * .pi)).rounded())
    }

    /// Quarter steps, so a spinning board looks like animation frames, not a smooth squash.
    private func steppedScale(_ value: Double) -> CGFloat {
        let stepped = (value * 4).rounded() / 4
        return CGFloat(abs(stepped) < 0.1 ? 0.125 : stepped)
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
        // The combo, or on the tutorial spot a hint when there's no combo going.
        comboLabel.text = run.combo.isEmpty ? hint() : run.combo.text(maxTricks: 2)
        multiplierLabel.text = run.combo.multiplier > 1 ? "X\(run.combo.multiplier)  \(run.combo.total)" : ""
    }

    /// First-run help, shown along the start of the tutorial spot.
    private func hint() -> String {
        guard level.showsHints else { return "" }
        switch run.x {
        case ..<330: return "TAP TO OLLIE. HOLD: HIGHER"
        case ..<640: return "SWIPE UP/DOWN: LANES"
        case ..<1000: return "SWIPE SIDEWAYS: KICKFLIP"
        case ..<1400: return "GRAB THE LETTERS"
        case ..<1800: return "SWIPE IN THE AIR FOR MORE"
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
