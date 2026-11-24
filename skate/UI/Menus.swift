//
//  Menus.swift
//  skate
//
//  The title screen, city picker, spot list and skater builder, all in one
//  scene that swaps pages. Plus the pieces every scene shares: a base scene
//  that knows the safe area, and pixel buttons.
//

import SpriteKit
import StoreKit
import UIKit

/// Moves between the menus and the game. The view controller does this.
protocol SceneRouter: AnyObject {
    func showMenu(_ page: MenuScene.Page)
    func play(_ level: Level, in city: City)
}

/// A scene sized in game pixels that keeps its controls inside the safe area.
class PixelScene: SKScene {
    weak var router: SceneRouter?
    /// The view's safe area, in points.
    var safeInsets: UIEdgeInsets = .zero { didSet { if oldValue != safeInsets { layoutScene() } } }
    /// How many points one game pixel takes up on screen.
    var pointsPerPixel: CGFloat = 1 { didSet { if oldValue != pointsPerPixel { layoutScene() } } }
    /// How many screen pixels one game pixel takes up (12 on an iPhone 18 Pro).
    var screenPixelsPerPixel = 1 { didSet { if oldValue != screenPixelsPerPixel { layoutScene() } } }

    /// The safe area in game pixels, with the origin at the bottom left of the screen.
    var safeFrame: CGRect {
        let ppp = max(pointsPerPixel, 0.01)
        let left = max(4, (safeInsets.left / ppp).rounded() + 2)
        let right = max(4, (safeInsets.right / ppp).rounded() + 2)
        let top = max(3, (safeInsets.top / ppp).rounded() + 2)
        let bottom = max(2, (safeInsets.bottom / ppp).rounded())
        return CGRect(x: left, y: bottom, width: size.width - left - right, height: size.height - top - bottom)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutScene()
    }

    /// Put things in place for the current size and safe area.
    func layoutScene() {}
}

/// A tappable box with a pixel-font label.
final class PixelButton: SKNode {
    var action: () -> Void
    var isEnabled = true {
        didSet { alpha = isEnabled ? 1 : 0.4 }
    }
    private let box = SKSpriteNode()
    private let label = PixelLabel(anchor: .zero)
    private let minWidth: Int
    private let color: PixelColor

    var text: String {
        get { label.text }
        set { label.text = newValue; redraw() }
    }

    init(_ text: String, minWidth: CGFloat = 0, color: PixelColor = PixelColor(0x24308C), action: @escaping () -> Void) {
        self.action = action
        self.minWidth = Int(minWidth)
        self.color = color
        super.init()
        box.anchorPoint = .zero
        addChild(box)
        label.zPosition = 1
        addChild(label)
        label.text = text
        redraw()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var boxRect: CGRect {
        CGRect(origin: box.position, size: box.size)
    }

    private func redraw() {
        // Everything on whole pixels, so the text stays sharp.
        let textWidth = PixelFont.width(of: label.text)
        let width = max(minWidth, textWidth + 8)
        let height = PixelFont.glyphHeight + 6
        box.texture = UIArt.box(width: width, height: height, fill: color)
        box.size = CGSize(width: width, height: height)
        box.position = CGPoint(x: -(width / 2), y: -(height / 2))
        label.position = CGPoint(x: -(width / 2) + (width - textWidth) / 2, y: -(height / 2) + 2)
    }

    /// True if the point is on the button, with a little extra room for fingers.
    /// The point is in the button's parent's coordinates, or in `space`'s if given
    /// (for buttons inside a scaled-down group).
    func hit(_ point: CGPoint, in space: SKNode? = nil) -> Bool {
        guard isEnabled, !isHidden, let parent else { return false }
        let local = space.map { parent.convert(point, from: $0) } ?? point
        return boxRect.offsetBy(dx: position.x, dy: position.y).insetBy(dx: -3, dy: -3).contains(local)
    }
}

enum UIArt {
    /// A glass tip jar with coins in it.
    static func tipJar() -> SKTexture {
        PixelSprite([
            ".lllllll.",
            "..lllll..",
            ".g.....g.",
            "g.......g",
            "g...o...g",
            "g..ooo..g",
            "g.ooooo.g",
            "gooooooog",
            ".ggggggg.",
        ], colors: ["l": Palette.lightGrey, "g": PixelColor(0x9CD0F8), "o": Palette.yellow]).texture()
    }

    /// A little padlock, for things in the full game.
    static func padlock() -> SKTexture {
        PixelSprite([
            "..###..",
            ".#...#.",
            ".#...#.",
            "#######",
            "###.###",
            "###.###",
            "#######",
        ], colors: ["#": Palette.yellow]).texture()
    }

    /// A rounded box with a light rim.
    static func box(width: Int, height: Int, fill: PixelColor) -> SKTexture {
        var canvas = PixelCanvas(width: width, height: height)
        canvas.fill(x: 1, y: 0, width: width - 2, height: height, Palette.black)
        canvas.fill(x: 0, y: 1, width: width, height: height - 2, Palette.black)
        canvas.fill(x: 1, y: 1, width: width - 2, height: height - 2, fill)
        canvas.fill(x: 1, y: height - 2, width: width - 2, height: 1, PixelColor(0xFCFCFC, alpha: 90))
        return canvas.texture()
    }

    /// A see-through dark panel to sit text on.
    static func panel(width: Int, height: Int) -> SKTexture {
        var canvas = PixelCanvas(width: width, height: height)
        canvas.fill(x: 1, y: 0, width: width - 2, height: height, PixelColor(0x000000, alpha: 150))
        canvas.fill(x: 0, y: 1, width: width, height: height - 2, PixelColor(0x000000, alpha: 150))
        return canvas.texture()
    }
}

// MARK: - Menus

final class MenuScene: PixelScene {
    enum Page: Equatable {
        case title
        case cities
        case spots(City)
        case builder
        /// The full game: coming soon, with a link to the tip jar.
        case fullGame
        /// The tip jar, and the page its BACK button returns to.
        indirect case tips(back: Page)
    }

    /// The tip jar's color: loud on purpose.
    static let tipColor = PixelColor(0xE8508C)

    /// What the tip jar says after a purchase.
    private var tipMessage = ""

    private(set) var page: Page
    private let progress = Progress.shared
    private let backdrop = SKNode()
    private var strips: [ParallaxStrip] = []
    private let content = SKNode()
    private var buttons: [PixelButton] = []
    private var scroll: CGFloat = 0
    private var lastUpdate: TimeInterval?
    private var touchStart: CGPoint?

    /// Which city the city picker is showing.
    private var cityIndex = 0

    init(size: CGSize, page: Page) {
        self.page = page
        super.init(size: size)
        if case .spots(let city) = page, let index = City.all.firstIndex(of: city) { cityIndex = index }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        anchorPoint = .zero
        let look = ThemeArt.look(for: .skidmore)
        backgroundColor = look.sky.skColor
        addChild(backdrop)
        let groundTop = CGFloat(StreetArt.groundTop)
        strips = look.layers.enumerated().map { index, layer in
            ParallaxStrip(texture: layer.texture, factor: layer.factor, y: groundTop + layer.lift, z: CGFloat(-30 + index * 10))
        } + [ParallaxStrip(texture: look.ground, factor: 1, y: 0, z: -5)] + skidmorePlaza()
        strips.forEach { backdrop.addChild($0.node) }
        content.zPosition = 50
        addChild(content)
        layoutScene()
    }

    /// Skidmore Fountain going by on the back of the plaza, and the MAX tracks along the front.
    private func skidmorePlaza() -> [ParallaxStrip] {
        let fountain = FeatureArt.fountain(width: 64)
        var spaced = PixelCanvas(width: 300, height: fountain.height)
        spaced.draw(fountain, x: 0, y: 0)
        let tracks = FeatureArt.tracks(width: 60)
        return [
            ParallaxStrip(texture: tracks.texture(), factor: 1, y: StreetArt.baseline(forLane: CGFloat(Lane.front.rawValue)), z: -4),
            ParallaxStrip(texture: spaced.texture(), factor: 1, y: StreetArt.baseline(forLane: CGFloat(Lane.back.rawValue)), z: -3),
        ]
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = min(0.1, currentTime - (lastUpdate ?? currentTime))
        lastUpdate = currentTime
        // The street drifts by behind the menus.
        scroll += CGFloat(dt) * 24
        backdrop.position.x = -scroll.rounded()
        strips.forEach { $0.update(cameraLeft: scroll.rounded()) }
    }

    func show(_ page: Page) {
        self.page = page
        layoutScene()
        if case .tips = page, Store.shared.tips.isEmpty { Task { await Store.shared.refresh() } }
    }

    override func layoutScene() {
        guard view != nil else { return }
        strips.forEach { $0.layout(viewWidth: size.width + 64) }
        content.removeAllChildren()
        buttons.removeAll()
        switch page {
        case .title: buildTitle()
        case .cities: buildCities()
        case .spots(let city): buildSpots(city)
        case .builder: buildBuilder()
        case .fullGame: buildFullGame()
        case .tips(let back): buildTips(back: back)
        }
    }

    // MARK: Building blocks

    @discardableResult
    private func label(_ text: String, at point: CGPoint, anchor: CGPoint = CGPoint(x: 0.5, y: 0.5),
                       color: PixelColor = Palette.white, scale: CGFloat = 1) -> PixelLabel {
        let label = PixelLabel(anchor: anchor)
        label.ink = color
        label.text = text
        label.setScale(scale)
        label.position = CGPoint(x: point.x.rounded(), y: point.y.rounded())
        content.addChild(label)
        return label
    }

    @discardableResult
    private func button(_ text: String, at point: CGPoint, minWidth: CGFloat = 0,
                        color: PixelColor = PixelColor(0x24308C), action: @escaping () -> Void) -> PixelButton {
        let button = PixelButton(text, minWidth: minWidth, color: color, action: action)
        button.position = CGPoint(x: point.x.rounded(), y: point.y.rounded())
        content.addChild(button)
        buttons.append(button)
        return button
    }

    private func panel(_ rect: CGRect) {
        let panel = SKSpriteNode(texture: UIArt.panel(width: Int(rect.width), height: Int(rect.height)))
        panel.anchorPoint = .zero
        panel.position = CGPoint(x: rect.minX.rounded(), y: rect.minY.rounded())
        panel.zPosition = -1
        content.addChild(panel)
    }

    private func skaterPreview(at point: CGPoint, scale: CGFloat) {
        let preview = SKSpriteNode(texture: SkaterLook(outfit: progress.outfit).standing)
        preview.anchorPoint = CGPoint(x: 0.5, y: 0)
        preview.setScale(scale)
        preview.position = CGPoint(x: point.x.rounded(), y: point.y.rounded())
        content.addChild(preview)
        let shadow = SKSpriteNode(texture: StreetArt.shadow(width: 20))
        shadow.setScale(scale)
        shadow.position = CGPoint(x: point.x.rounded(), y: point.y.rounded())
        shadow.zPosition = -0.5
        content.addChild(shadow)
    }

    /// The city's letters, found ones in gold and the rest in grey.
    private func letterRuns(for city: City, only indices: [Int]? = nil) -> [(String, PixelColor)] {
        let found = progress.letters(in: city)
        return city.letters.enumerated().compactMap { index, letter in
            if let indices, !indices.contains(index) { return nil }
            return (String(letter), found.contains(index) ? Palette.yellow : PixelColor(0x9C9C9C))
        }
    }

    private func runsLabel(_ runs: [(String, PixelColor)], at point: CGPoint, anchor: CGPoint) {
        let node = SKSpriteNode(texture: PixelFont.texture(runs: runs))
        node.anchorPoint = anchor
        node.position = CGPoint(x: point.x.rounded(), y: point.y.rounded())
        content.addChild(node)
    }

    // MARK: Pages

    private func buildTitle() {
        let safe = safeFrame
        // The skater on the left; the name and buttons in a column on the right.
        skaterPreview(at: CGPoint(x: safe.minX + safe.width * 0.25, y: StreetArt.baseline(forLane: 1)), scale: 2)
        let buttonX = safe.minX + safe.width * 0.68
        label("SKATE", at: CGPoint(x: buttonX, y: safe.maxY - 10), color: Palette.yellow, scale: 2)
        label("TUESDAY GAMES", at: CGPoint(x: buttonX, y: safe.maxY - 25), color: Palette.white)
        button("PLAY", at: CGPoint(x: buttonX, y: 58), minWidth: 64, color: PixelColor(0x00A844)) { [weak self] in
            self?.show(.cities)
        }
        // The tip jar, right under PLAY, with a jar of coins beside it.
        button("TIP JAR", at: CGPoint(x: buttonX, y: 42), minWidth: 64, color: Self.tipColor) { [weak self] in
            self?.openTips(from: .title)
        }
        let jar = SKSpriteNode(texture: UIArt.tipJar())
        jar.anchorPoint = CGPoint(x: 1, y: 0.5)
        jar.position = CGPoint(x: (buttonX - 36).rounded(), y: 42)
        content.addChild(jar)
        button("TUTORIAL", at: CGPoint(x: buttonX, y: 26), minWidth: 64) { [weak self] in
            self?.router?.play(.tutorial, in: .portland)
        }
        button("SKATER", at: CGPoint(x: buttonX, y: 10), minWidth: 64) { [weak self] in
            self?.show(.builder)
        }
    }

    private func buildCities() {
        let safe = safeFrame
        let city = City.all[cityIndex]
        panel(CGRect(x: safe.minX, y: safe.minY + 2, width: safe.width, height: safe.height - 2))
        label("CHOOSE A CITY", at: CGPoint(x: safe.midX, y: safe.maxY - 8))
        label("\(cityIndex + 1)/\(City.all.count)", at: CGPoint(x: safe.maxX - 4, y: safe.maxY - 8),
              anchor: CGPoint(x: 1, y: 0.5), color: PixelColor(0x9C9C9C))

        // As big as fits between the arrows, up to double size.
        let nameWidth = PixelFont.width(of: city.name)
        let nameScale = PixelFont.fittingScale(width: nameWidth, into: safe.width - 44, maxScale: 2,
                                               screenPixelsPerPixel: screenPixelsPerPixel)
        // Line the left edge up with a screen pixel, so every letter stays sharp.
        let screenPixel = 1 / CGFloat(max(1, screenPixelsPerPixel))
        let nameLeft = ((safe.midX - CGFloat(nameWidth) * nameScale / 2) / screenPixel).rounded() * screenPixel
        let name = label(city.name, at: .zero, anchor: CGPoint(x: 0, y: 0.5),
                         color: city.isOpen ? Palette.white : PixelColor(0x9C9C9C), scale: nameScale)
        name.position = CGPoint(x: nameLeft, y: safe.midY + 10)
        button("<", at: CGPoint(x: safe.minX + 12, y: safe.midY + 10)) { [weak self] in self?.changeCity(by: -1) }
        button(">", at: CGPoint(x: safe.maxX - 12, y: safe.midY + 10)) { [weak self] in self?.changeCity(by: 1) }

        if city.isOpen {
            runsLabel(letterRuns(for: city), at: CGPoint(x: safe.midX, y: safe.midY - 6), anchor: CGPoint(x: 0.5, y: 0.5))
            label("FREE", at: CGPoint(x: safe.midX, y: safe.midY - 17), color: Palette.green)
            button("GO", at: CGPoint(x: safe.maxX - 26, y: safe.minY + 12), minWidth: 40, color: PixelColor(0x00A844)) { [weak self] in
                self?.show(.spots(city))
            }
        } else {
            // Locked: part of the full game, which isn't out yet.
            let lock = SKSpriteNode(texture: UIArt.padlock())
            lock.anchorPoint = CGPoint(x: 1, y: 0.5)
            let comingWidth = CGFloat(PixelFont.width(of: "COMING SOON"))
            lock.position = CGPoint(x: (safe.midX - comingWidth / 2 - 4).rounded(), y: safe.midY - 8)
            content.addChild(lock)
            label("COMING SOON", at: CGPoint(x: safe.midX, y: safe.midY - 8), color: Palette.yellow)
            label("IN THE FULL GAME", at: CGPoint(x: safe.midX, y: safe.midY - 19), color: PixelColor(0x9C9C9C))
            button("FULL GAME", at: CGPoint(x: safe.maxX - 34, y: safe.minY + 12), minWidth: 56, color: PixelColor(0x8C38C8)) { [weak self] in
                self?.show(.fullGame)
            }
        }
        button("BACK", at: CGPoint(x: safe.minX + 20, y: safe.minY + 12)) { [weak self] in self?.show(.title) }
        button("TIP JAR", at: CGPoint(x: (safe.midX - 6).rounded(), y: safe.minY + 12), minWidth: 44, color: Self.tipColor) { [weak self] in
            self?.openTips(from: .cities)
        }
    }

    // MARK: Full game and tips

    private func buildFullGame() {
        let safe = safeFrame
        panel(CGRect(x: safe.minX, y: safe.minY + 2, width: safe.width, height: safe.height - 2))
        label("FULL GAME", at: CGPoint(x: safe.midX, y: safe.maxY - 8), color: Palette.yellow)
        let lines = [
            ("8 MORE CITIES TO SKATE:", Palette.white),
            ("SAN FRANCISCO, LOS ANGELES,", PixelColor(0xBCBCBC)),
            ("NEW YORK, FRESNO, SACRAMENTO,", PixelColor(0xBCBCBC)),
            ("AUSTIN, SEATTLE AND ASTORIA", PixelColor(0xBCBCBC)),
        ]
        for (index, (text, color)) in lines.enumerated() {
            label(text, at: CGPoint(x: safe.midX, y: safe.maxY - 22 - CGFloat(index) * 10), color: color)
        }
        if Store.fullGameOnSale, let product = Store.shared.fullGame, !Store.shared.isUnlocked {
            button("BUY \(product.displayPrice)", at: CGPoint(x: safe.midX, y: safe.minY + 30), minWidth: 64,
                   color: PixelColor(0x00A844)) { [weak self] in self?.buy(product) }
        } else if Store.shared.isUnlocked {
            label("YOU HAVE IT. THANK YOU!", at: CGPoint(x: safe.midX, y: safe.minY + 30), color: Palette.green)
        } else {
            label("COMING SOON FOR \(Store.fullGamePrice)", at: CGPoint(x: safe.midX, y: safe.minY + 30), color: Palette.yellow)
        }
        button("BACK", at: CGPoint(x: safe.minX + 20, y: safe.minY + 12)) { [weak self] in self?.show(.cities) }
        button("TIP JAR", at: CGPoint(x: safe.maxX - 30, y: safe.minY + 12), minWidth: 48, color: Self.tipColor) { [weak self] in
            self?.openTips(from: .fullGame)
        }
    }

    private func openTips(from page: Page) {
        tipMessage = ""
        show(.tips(back: page))
    }

    /// The three tips, always shown. Prices come from the App Store once it answers;
    /// until then they show the usual US prices.
    static let tipLabels: [(name: String, price: String)] = [("SMALL", "$0.99"), ("MEDIUM", "$2.99"), ("LARGE", "$4.99")]

    private func buildTips(back: Page) {
        let safe = safeFrame
        panel(CGRect(x: safe.minX, y: safe.minY + 2, width: safe.width, height: safe.height - 2))
        label("TIP JAR", at: CGPoint(x: safe.midX, y: safe.maxY - 8), color: Palette.yellow)
        label("TIPS ARE OPTIONAL AND", at: CGPoint(x: safe.midX, y: safe.maxY - 22), color: PixelColor(0xBCBCBC))
        label("DON'T UNLOCK ANYTHING.", at: CGPoint(x: safe.midX, y: safe.maxY - 32), color: PixelColor(0xBCBCBC))
        let products = Store.shared.tips
        let rowY = safe.midY - 4
        let spacing = min(64, (safe.width - 20) / 3)
        for (index, tip) in Self.tipLabels.enumerated() {
            let x = safe.midX + CGFloat(index - 1) * spacing
            let product = index < products.count ? products[index] : nil
            button(product?.displayPrice ?? tip.price, at: CGPoint(x: x, y: rowY), minWidth: 48,
                   color: Self.tipColor) { [weak self] in
                guard let self else { return }
                if let product {
                    self.buy(product)
                } else {
                    self.tipMessage = Store.shared.hasLoaded ? "TIPS AREN'T SET UP YET" : "ONE MOMENT..."
                    self.layoutScene()
                }
            }
            label(tip.name, at: CGPoint(x: x, y: rowY - 13), color: PixelColor(0x9C9C9C))
        }
        if !tipMessage.isEmpty {
            label(tipMessage, at: CGPoint(x: safe.midX, y: safe.minY + 28), color: Palette.yellow)
        }
        let jar = SKSpriteNode(texture: UIArt.tipJar())
        jar.position = CGPoint(x: (safe.midX - 34).rounded(), y: (safe.maxY - 8).rounded())
        content.addChild(jar)
        button("BACK", at: CGPoint(x: safe.minX + 20, y: safe.minY + 12)) { [weak self] in self?.show(back) }
    }

    private func buy(_ product: Product) {
        let scene = view?.window?.windowScene
        Task { [weak self] in
            let outcome = await Store.shared.buy(product, in: scene)
            guard let self else { return }
            switch outcome {
            case .success: self.tipMessage = product.id == Store.fullGameID ? "" : "THANK YOU!"
            case .pending: self.tipMessage = "WAITING FOR APPROVAL"
            case .cancelled: self.tipMessage = ""
            case .failed: self.tipMessage = "THAT DIDN'T WORK. TRY AGAIN?"
            }
            if outcome == .success { Sounds.shared.play(.finish) }
            self.layoutScene()
        }
    }

    private func changeCity(by step: Int) {
        cityIndex = (cityIndex + step + City.all.count) % City.all.count
        Sounds.shared.play(.lane)
        Haptics.tick()
        layoutScene()
    }

    private func buildSpots(_ city: City) {
        let safe = safeFrame
        panel(CGRect(x: safe.minX, y: safe.minY + 2, width: safe.width, height: safe.height - 2))
        let headerY = safe.maxY - 8
        let back = button("BACK", at: CGPoint(x: safe.minX + 20, y: headerY)) { [weak self] in self?.show(.cities) }
        let tip = button("TIP JAR", at: CGPoint(x: safe.maxX - 26, y: headerY), minWidth: 44, color: Self.tipColor) { [weak self] in
            self?.openTips(from: .spots(city))
        }
        // The city's name between the two buttons, smaller if it has to be.
        let roomForName = 2 * min(safe.midX - back.calculateAccumulatedFrame().maxX,
                                  tip.calculateAccumulatedFrame().minX - safe.midX) - 6
        let nameWidth = PixelFont.width(of: city.name)
        let nameScale = PixelFont.fittingScale(width: nameWidth, into: roomForName, maxScale: 1,
                                               screenPixelsPerPixel: screenPixelsPerPixel)
        let name = label(city.name, at: .zero, anchor: CGPoint(x: 0, y: 0.5), color: Palette.yellow, scale: nameScale)
        name.position = CGPoint(x: snapToScreen(safe.midX - CGFloat(nameWidth) * nameScale / 2), y: headerY)

        // The list fills the rest of the panel: shrunk to fit if it has to be, with
        // the letters, goal dots and best scores lined up on the right.
        let list = SpotsList(city: city, progress: progress) { [weak self] level in
            self?.router?.play(level, in: city)
        }
        let area = CGRect(x: safe.minX + 2, y: safe.minY + 5, width: safe.width - 5, height: safe.maxY - 17 - (safe.minY + 5))
        let scale = min(
            PixelFont.fittingScale(width: list.naturalWidth, into: area.width, maxScale: 1, screenPixelsPerPixel: screenPixelsPerPixel),
            PixelFont.fittingScale(width: list.naturalHeight, into: area.height, maxScale: 1, screenPixelsPerPixel: screenPixelsPerPixel))
        list.build(width: Int((area.width / scale).rounded(.down)))
        list.setScale(scale)
        list.position = CGPoint(x: snapToScreen(area.minX), y: snapToScreen(area.maxY))
        content.addChild(list)
        buttons += list.buttons
    }

    /// The nearest screen pixel, so anything scaled down still lands sharp.
    private func snapToScreen(_ value: CGFloat) -> CGFloat {
        let step = 1 / CGFloat(max(1, screenPixelsPerPixel))
        return (value / step).rounded() * step
    }

    private func buildBuilder() {
        let safe = safeFrame
        var outfit = progress.outfit
        panel(CGRect(x: safe.minX + safe.width * 0.34, y: safe.minY + 2, width: safe.width * 0.66, height: safe.height - 2))
        label("YOUR SKATER", at: CGPoint(x: safe.minX + safe.width * 0.67, y: safe.maxY - 8), color: Palette.yellow)
        skaterPreview(at: CGPoint(x: safe.minX + safe.width * 0.17, y: StreetArt.baseline(forLane: 1)), scale: 2)

        let labelX = safe.minX + safe.width * 0.37
        let leftArrowX = safe.minX + safe.width * 0.66
        let rightArrowX = safe.maxX - 8
        let valueX = (leftArrowX + rightArrowX) / 2
        let rowHeight: CGFloat = 12

        struct Row {
            var title: String
            var value: String
            var enabled: Bool
            var change: (inout Outfit, Int) -> Void
        }
        let rows: [Row] = [
            Row(title: "SKATER", value: outfit.kind.name, enabled: true) { outfit, step in
                outfit.switchSkater(to: Outfit.cycle(outfit.kind, in: SkaterKind.allCases, step: step))
            },
            Row(title: outfit.kind.isDog ? "BANDANA" : "SHIRT", value: outfit.shirt.name, enabled: true) { outfit, step in
                outfit.shirt = Outfit.cycle(outfit.shirt, in: ColorChoice.clothes, step: step)
            },
            Row(title: "PANTS", value: outfit.kind.wearsPants ? outfit.pants.name : "-", enabled: outfit.kind.wearsPants) { outfit, step in
                outfit.pants = Outfit.cycle(outfit.pants, in: ColorChoice.clothes, step: step)
            },
            Row(title: "HAT", value: outfit.hat?.name ?? "NONE", enabled: true) { outfit, step in
                outfit.hat = Outfit.cycle(outfit.hat, in: Outfit.hatChoices, step: step)
            },
            Row(title: "BOARD", value: outfit.board.name, enabled: true) { outfit, step in
                outfit.board = Outfit.cycle(outfit.board, in: ColorChoice.boards(pdxUnlocked: Progress.shared.hasPDXBoard), step: step)
            },
        ]
        for (index, row) in rows.enumerated() {
            let y = safe.maxY - 24 - CGFloat(index) * rowHeight
            label(row.title, at: CGPoint(x: labelX, y: y), anchor: CGPoint(x: 0, y: 0.5),
                  color: row.enabled ? Palette.white : PixelColor(0x7C7C7C))
            label(row.value, at: CGPoint(x: valueX, y: y), color: row.enabled ? Palette.yellow : PixelColor(0x7C7C7C))
            for (step, x) in [(-1, leftArrowX), (1, rightArrowX)] {
                let arrow = button(step < 0 ? "<" : ">", at: CGPoint(x: x, y: y)) { [weak self] in
                    row.change(&outfit, step)
                    self?.progress.outfit = outfit
                    Sounds.shared.play(.lane)
                    Haptics.tick()
                    self?.layoutScene()
                }
                arrow.isEnabled = row.enabled
            }
        }
        button("DONE", at: CGPoint(x: safe.minX + safe.width * 0.17, y: safe.minY + 10), minWidth: 44,
               color: PixelColor(0x00A844)) { [weak self] in
            self?.show(.title)
        }
    }

    // MARK: Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = touches.first.map { $0.location(in: self) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let start = touchStart else { return }
        touchStart = nil
        let point = touch.location(in: self)
        // Swipe sideways through the cities.
        if page == .cities, abs(point.x - start.x) > 12, abs(point.x - start.x) > abs(point.y - start.y) {
            changeCity(by: point.x < start.x ? 1 : -1)
            return
        }
        if let button = buttons.first(where: { $0.hit(start, in: self) && $0.hit(point, in: self) }) {
            Sounds.shared.play(.pop)
            Haptics.pop(charged: false)
            button.action()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = nil
    }
}

// MARK: - The spots list

/// A city's spots, one row each: the spot's button on the left, then its letters,
/// a dot per goal and the best score, lined up in columns on the right. It's laid
/// out in whole game pixels from its top-left corner; the menu scales it down to
/// fit if the screen is short or narrow, so nothing ever overlaps.
final class SpotsList: SKNode {
    static let rowPitch = 14
    static let buttonHeight = PixelFont.glyphHeight + 6
    static let nameGap = 6, columnGap = 4

    private let city: City
    private let progress: Progress
    private let play: (Level) -> Void
    private(set) var buttons: [PixelButton] = []

    private var titles: [String] { city.levels.enumerated().map { "\($0.offset + 1) \($0.element.name)" } }
    private var nameColumn: Int { titles.map { PixelFont.width(of: $0) + 8 }.max() ?? 0 }
    private var lettersColumn: Int {
        city.levels.map { level in PixelFont.width(of: String(level.letters.map { city.letters[$0.index] })) }.max() ?? 0
    }
    private var dotsColumn: Int { max(0, (city.levels.map(\.goals.count).max() ?? 0) * 3 - 1) }
    /// Room for a five-digit score at least, so the columns don't jump about as scores go up.
    private var scoreColumn: Int {
        ([PixelFont.width(of: "00000")] + city.levels.map { PixelFont.width(of: "\(progress.bestScore(at: $0))") }).max()!
    }

    /// The narrowest the list can be with nothing touching.
    var naturalWidth: Int { nameColumn + Self.nameGap + lettersColumn + Self.columnGap + dotsColumn + Self.columnGap + scoreColumn }
    var naturalHeight: Int { max(0, city.levels.count * Self.rowPitch - 1) }

    init(city: City, progress: Progress, play: @escaping (Level) -> Void) {
        self.city = city
        self.progress = progress
        self.play = play
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Lay the rows out across `width` game pixels (at least `naturalWidth`); any
    /// extra room goes between the names and the columns.
    func build(width: Int) {
        removeAllChildren()
        buttons.removeAll()
        let width = max(width, naturalWidth)
        let scoreRight = width
        let dotsLeft = scoreRight - scoreColumn - Self.columnGap - dotsColumn
        let lettersRight = dotsLeft - Self.columnGap
        let found = progress.letters(in: city)
        let done = { (level: Level) in self.progress.goalsDone(at: level) }

        for (row, level) in city.levels.enumerated() {
            let boxTop = -row * Self.rowPitch
            let boxBottom = boxTop - Self.buttonHeight
            // The text inside a button sits two pixels up from its bottom; the columns match it.
            let textY = CGFloat(boxBottom + 2)

            let button = PixelButton(titles[row]) { [weak self] in self?.play(level) }
            let buttonWidth = PixelFont.width(of: titles[row]) + 8
            // A button's box hangs half its size either side of its position.
            button.position = CGPoint(x: buttonWidth / 2, y: boxBottom + Self.buttonHeight / 2)
            addChild(button)
            buttons.append(button)

            let runs: [(String, PixelColor)] = level.letters.map(\.index).map {
                (String(city.letters[$0]), found.contains($0) ? Palette.yellow : PixelColor(0x9C9C9C))
            }
            if !runs.isEmpty {
                let letters = SKSpriteNode(texture: PixelFont.texture(runs: runs))
                letters.anchorPoint = CGPoint(x: 1, y: 0)
                letters.position = CGPoint(x: CGFloat(lettersRight), y: textY)
                addChild(letters)
            }

            // A dot for each goal: yellow once it's done.
            let doneGoals = done(level)
            for (index, goal) in level.goals.enumerated() {
                let dot = SKSpriteNode(color: (doneGoals.contains(goal.id) ? Palette.yellow : PixelColor(0x5C5C5C)).skColor,
                                       size: CGSize(width: 2, height: 2))
                dot.anchorPoint = .zero
                dot.position = CGPoint(x: dotsLeft + index * 3, y: boxBottom + 5)
                addChild(dot)
            }

            let best = progress.bestScore(at: level)
            if best > 0 {
                let score = PixelLabel(anchor: CGPoint(x: 1, y: 0))
                score.text = "\(best)"
                score.position = CGPoint(x: CGFloat(scoreRight), y: textY)
                addChild(score)
            }
        }
    }
}
