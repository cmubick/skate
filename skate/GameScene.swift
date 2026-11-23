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

final class GameScene: SKScene {

    /// The view's safe area, in points. The HUD stays inside it.
    var safeInsets: UIEdgeInsets = .zero { didSet { layoutHud() } }
    /// How many points one game pixel takes up on screen.
    var pointsPerPixel: CGFloat = 1 { didSet { layoutHud() } }

    private let level = Level.feelStreet
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

    // The skater.
    private let skater = SKNode()
    private let body = SKSpriteNode(texture: SkaterArt.roll.texture())
    private let board = SKSpriteNode(texture: BoardArt.side.texture())
    private let shadow = SKSpriteNode(texture: StreetArt.shadow())
    private var sparkTimer: TimeInterval = 0
    /// How far the camera has risen to keep a high jump on screen.
    private var cameraLift: CGFloat = 0
    /// True while the grind rumble and sound are on, so they can't be left running.
    private var grindFeedbackOn = false

    private enum Textures {
        static let roll = SkaterArt.roll.texture()
        static let crouch = SkaterArt.crouch.texture()
        static let air = SkaterArt.air.texture()
        static let grab = SkaterArt.grab.texture()
        static let bail = SkaterArt.bail.texture()
        static let side = BoardArt.side.texture()
        static let wheelsUp = BoardArt.wheelsUp.texture()
        static let underside = BoardArt.underside.texture()
        static let grip = BoardArt.grip.texture()
    }

    // The HUD, drawn over everything and fixed to the screen.
    private let scoreLabel = PixelLabel(anchor: CGPoint(x: 0, y: 1))
    private let bestLabel = PixelLabel(anchor: CGPoint(x: 0, y: 1))
    private let comboLabel = PixelLabel(anchor: CGPoint(x: 0.5, y: 1))
    private let multiplierLabel = PixelLabel(anchor: CGPoint(x: 0.5, y: 1))
    private let hintLabel = PixelLabel(anchor: CGPoint(x: 0.5, y: 0))
    private let debugLabel = PixelLabel(anchor: CGPoint(x: 1, y: 1))
    private let results = SKNode()
    private var finishedAt: TimeInterval?

    private var bestScore: Int {
        get { UserDefaults.standard.integer(forKey: "bestScore.feelStreet") }
        set { UserDefaults.standard.set(newValue, forKey: "bestScore.feelStreet") }
    }

    override init(size: CGSize) {
        run = Run(level: level)
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Building the scene

    override func didMove(to view: SKView) {
        backgroundColor = Palette.sky.skColor
        anchorPoint = .zero
        addChild(world)
        addChild(cam)
        camera = cam

        let groundTop = CGFloat(StreetArt.groundTop)
        strips = [
            ParallaxStrip(texture: StreetArt.skyline(), factor: 0.2, y: groundTop, z: -30),
            ParallaxStrip(texture: StreetArt.buildings(), factor: 0.5, y: groundTop, z: -20),
            ParallaxStrip(texture: StreetArt.ground(), factor: 1, y: 0, z: -10),
        ]
        strips.forEach { world.addChild($0.node) }

        for feature in level.features {
            let sprite = SKSpriteNode(texture: FeatureArt.texture(for: feature))
            sprite.anchorPoint = .zero
            sprite.position = CGPoint(x: feature.x, y: StreetArt.baseline(forLane: CGFloat(feature.lane.rawValue)))
            sprite.zPosition = laneZ(CGFloat(feature.lane.rawValue))
            world.addChild(sprite)

            let footprint = SKSpriteNode(color: Palette.shadow.skColor, size: CGSize(width: feature.length, height: 1))
            footprint.anchorPoint = .zero
            footprint.position = CGPoint(x: feature.x + 1, y: sprite.position.y - 1)
            footprint.zPosition = sprite.zPosition - 1
            world.addChild(footprint)
        }

        let finish = SKSpriteNode(texture: FeatureArt.finishLine(height: 46))
        finish.anchorPoint = .zero
        finish.position = CGPoint(x: level.length, y: 12)
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

        for label in [scoreLabel, bestLabel, comboLabel, multiplierLabel, hintLabel, debugLabel] {
            label.zPosition = 100
            cam.addChild(label)
        }
        multiplierLabel.ink = Palette.yellow
        results.zPosition = 200
        cam.addChild(results)

        Haptics.prepare()
        _ = Sounds.shared
        layoutHud()
        render()

        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive),
                                               name: UIApplication.willResignActiveNotification, object: nil)
    }

    @objc private func appWillResignActive() {
        stopGrindFeedback()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutHud()
        render()
    }

    private func layoutHud() {
        guard scene != nil else { return }
        let ppp = max(pointsPerPixel, 0.01)
        let left = -size.width / 2 + max(4, (safeInsets.left / ppp).rounded() + 2)
        let right = size.width / 2 - max(4, (safeInsets.right / ppp).rounded() + 2)
        let top = size.height / 2 - max(3, (safeInsets.top / ppp).rounded() + 2)
        let line = CGFloat(PixelFont.glyphHeight + 3)
        // Score and best on the left, the combo on its own rows below the middle of the top.
        scoreLabel.position = CGPoint(x: left, y: top)
        bestLabel.position = CGPoint(x: left, y: top - line)
        comboLabel.position = CGPoint(x: 0, y: top - line)
        multiplierLabel.position = CGPoint(x: 0, y: top - line * 2)
        debugLabel.position = CGPoint(x: right, y: top)
        hintLabel.position = CGPoint(x: 0, y: -size.height / 2 + 1)
        strips.forEach { $0.layout(viewWidth: size.width) }
    }

    // MARK: Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let view, let touch = touches.first else { return }
        if run.isFinished {
            if let finishedAt, (lastUpdate ?? 0) - finishedAt > 0.8 { restart() }
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
        guard let view, let touch = activeTouch, touches.contains(touch) else { return }
        activeTouch = nil
        apply(gestures.ended(at: touch.location(in: view), time: touch.timestamp))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
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

    private func restart() {
        stopGrindFeedback()
        run = Run(level: level)
        cameraLift = 0
        finishedAt = nil
        results.removeAllChildren()
        world.children.filter { $0.name == "popup" || $0.name == "spark" }.forEach { $0.removeFromParent() }
        Haptics.prepare()
        render()
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
            case .bail:
                Sounds.shared.play(.bail)
                Haptics.bail()
                popup("BAIL", color: Palette.orange, rise: 0)
            case .laneSwitch:
                Sounds.shared.play(.lane)
                Haptics.tick()
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
        label.name = "popup"
        label.zPosition = 60
        label.position = CGPoint(x: skater.position.x, y: (skater.position.y + 30 + rise).rounded())
        world.addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 10, duration: 0.7), .sequence([.wait(forDuration: 0.4), .fadeOut(withDuration: 0.3)])]),
            .removeFromParent(),
        ]))
    }

    private func showResults(score: Int) {
        finishedAt = lastUpdate
        let isBest = score > bestScore
        if isBest { bestScore = score }

        let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.55), size: size)
        results.addChild(dim)
        let lines: [(String, PixelColor)] = [
            ("FINISH!", Palette.yellow),
            ("SCORE \(score)", Palette.white),
            ("BEST COMBO \(run.bestCombo)", Palette.white),
            (isBest ? "NEW BEST!" : "BEST \(bestScore)", isBest ? Palette.yellow : Palette.lightGrey),
            ("", Palette.white),
            ("TAP TO SKATE AGAIN", Palette.white),
        ]
        for (index, line) in lines.enumerated() where !line.0.isEmpty {
            let label = PixelLabel(anchor: CGPoint(x: 0.5, y: 0.5))
            label.ink = line.1
            label.text = line.0
            label.position = CGPoint(x: 0, y: CGFloat(28 - index * 11))
            results.addChild(label)
        }
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
        let skaterTop = baseline + run.height + 30
        let wantedLift = max(0, skaterTop - size.height)
        cameraLift += (wantedLift - cameraLift) * CGFloat(min(1, dt * 12))
        cam.position = CGPoint(x: cameraLeft + size.width / 2, y: size.height / 2 + cameraLift.rounded())
        strips.forEach { $0.update(cameraLeft: cameraLeft) }

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
        board.texture = Textures.side
        body.position = CGPoint(x: 0, y: 3)

        switch run.state {
        case .rolling:
            body.texture = run.isCharging ? Textures.crouch : Textures.roll
        case .airborne:
            if let trick = run.airTrick {
                body.texture = trick.trick == .grab ? Textures.grab : Textures.air
                animateBoard(trick)
            } else {
                body.texture = Textures.air
            }
        case .grinding(_, let trick):
            body.texture = Textures.crouch
            if trick == .boardslide { board.xScale = 0.375 }
        case .bailed:
            body.texture = Textures.bail
            body.position = CGPoint(x: -4, y: 0)
            board.texture = Textures.wheelsUp
            board.position = CGPoint(x: 16, y: 0)
        }
        if let texture = body.texture { body.size = texture.size() }
        if let texture = board.texture { board.size = texture.size() }
    }

    private func animateBoard(_ trick: AirTrick) {
        let progress = trick.progress
        let kickflip = [Textures.side, Textures.underside, Textures.wheelsUp, Textures.grip]
        let heelflip = [Textures.side, Textures.grip, Textures.wheelsUp, Textures.underside]
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
        dot.name = "spark"
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
        bestLabel.text = bestScore > 0 ? "BEST \(bestScore)" : ""
        comboLabel.text = run.combo.text(maxTricks: 2)
        multiplierLabel.text = run.combo.multiplier > 1 ? "X\(run.combo.multiplier)  \(run.combo.total)" : ""
        hintLabel.text = hint()
        #if DEBUG
        debugLabel.text = "SPD \(Int(run.speed))"
        #endif
    }

    /// First-run help, shown along the start of the street.
    private func hint() -> String {
        switch run.x {
        case ..<330: "TAP TO OLLIE. HOLD: HIGHER"
        case ..<640: "SWIPE UP/DOWN: SWITCH LANES"
        case ..<1000: "SWIPE SIDEWAYS: KICKFLIP"
        case ..<1400: "LAND ON RAILS TO GRIND"
        case ..<1800: "SWIPE IN THE AIR FOR MORE"
        default: ""
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
