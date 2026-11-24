//
//  GameViewController.swift
//  skate
//
//  Holds the SpriteKit view and keeps the game's pixels whole: the view is
//  sized so each game pixel is a whole number of screen pixels.
//

import UIKit
import SpriteKit

class GameViewController: UIViewController, SceneRouter {

    private let skView = SKView()
    private var currentScene: PixelScene?
    private var layout: PixelLayout?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.isMultipleTouchEnabled = true
        skView.isMultipleTouchEnabled = true
        skView.ignoresSiblingOrder = true
        view.addSubview(skView)
        // Tips can be bought from the menus; the store loads in the background.
        Store.shared.onChange = { [weak self] in
            (self?.currentScene as? MenuScene)?.layoutScene()
        }
        Store.shared.start()
        // Letters goals done across several runs count (older saves needed one run).
        City.all.forEach { Progress.shared.completeEarnedLetterGoals(in: $0) }
        #if DEBUG
        // `-hideFPS YES` on the launch arguments keeps the counter off (for screenshots).
        skView.showsFPS = !UserDefaults.standard.bool(forKey: "hideFPS")
        #endif
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let screenScale = view.window?.screen.scale ?? view.traitCollection.displayScale
        let layout = PixelLayout(viewSize: view.bounds.size, screenScale: screenScale)
        self.layout = layout
        skView.frame = layout.frame
        if let scene = currentScene {
            if scene.size != layout.gameSize { scene.size = layout.gameSize }
            configure(scene)
        } else {
            showMenu(Self.startPage)
            #if DEBUG
            // `-marketing YES` renders the App Store screenshots and art (see Marketing.swift).
            if UserDefaults.standard.bool(forKey: "marketing") {
                Task { await Marketing.exportAll(in: view) }
            }
            // `-fireworks YES` shows the all-goals fireworks on a spot's results screen.
            if UserDefaults.standard.bool(forKey: "fireworks") {
                play(.downtown, in: .portland)
                Task {
                    try? await Task.sleep(for: .seconds(3))
                    (self.currentScene as? GameScene)?.showFireworksForTesting()
                }
            }
            // `-level waterfront` (a spot's id) opens straight on that spot's goals.
            if let id = UserDefaults.standard.string(forKey: "level"),
               let city = City.all.first(where: { $0.levels.contains { $0.id == id } }),
               let level = city.levels.first(where: { $0.id == id }) {
                play(level, in: city)
            }
            #endif
        }
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        currentScene?.safeInsets = view.safeAreaInsets
    }

    private func configure(_ scene: PixelScene) {
        guard let layout else { return }
        scene.router = self
        scene.pointsPerPixel = layout.pointsPerPixel
        scene.screenPixelsPerPixel = layout.scale
        scene.safeInsets = view.safeAreaInsets
    }

    private func present(_ scene: PixelScene) {
        scene.scaleMode = .fill
        configure(scene)
        if currentScene == nil {
            skView.presentScene(scene)
        } else {
            skView.presentScene(scene, transition: .fade(with: .black, duration: 0.2))
        }
        currentScene = scene
    }

    /// The menu page the app opens on: the title, or in debug builds whatever
    /// `-page cities|spots|builder|tips|fullgame` on the launch arguments asks for.
    /// (`-level <spot id>` goes on into a spot.)
    private static var startPage: MenuScene.Page {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "page") {
        case "cities": return .cities
        case "spots": return .spots(.portland)
        case "builder": return .builder
        case "tips": return .tips(back: .title)
        case "fullgame": return .fullGame
        default: return .title
        }
        #else
        return .title
        #endif
    }

    // MARK: SceneRouter

    func showMenu(_ page: MenuScene.Page) {
        guard let layout else { return }
        if let menu = currentScene as? MenuScene {
            menu.show(page)
        } else {
            present(MenuScene(size: layout.gameSize, page: page))
        }
    }

    func play(_ level: Level, in city: City) {
        guard let layout else { return }
        present(GameScene(size: layout.gameSize, level: level, city: city, outfit: Progress.shared.outfit))
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }
}

/// Works out how big the game is in its own pixels, and how big a frame to show it in.
///
/// The game is at least 180 x 96 pixels: big, chunky pixels so the skater and the street
/// fill the screen. Each game pixel is drawn as the largest whole number of screen pixels
/// that still fits that (12 on an iPhone 18 Pro, giving 218 x 100), and any room left
/// over shows more of the street to the right and more sky above.
nonisolated struct PixelLayout: Equatable {
    static let minimumSize = CGSize(width: 180, height: 96)

    /// Screen pixels per game pixel.
    let scale: Int
    /// The game's size in game pixels.
    let gameSize: CGSize
    /// Where the game view goes, in points, centered in the screen.
    let frame: CGRect

    var pointsPerPixel: CGFloat { frame.width / gameSize.width }

    init(viewSize: CGSize, screenScale: CGFloat) {
        let pixelWidth = Int((viewSize.width * screenScale).rounded())
        let pixelHeight = Int((viewSize.height * screenScale).rounded())
        let fitWidth = pixelWidth / Int(Self.minimumSize.width)
        let fitHeight = pixelHeight / Int(Self.minimumSize.height)
        scale = max(1, min(fitWidth, fitHeight))
        let width = max(1, pixelWidth / scale)
        let height = max(1, pixelHeight / scale)
        gameSize = CGSize(width: width, height: height)
        let size = CGSize(width: CGFloat(width * scale) / screenScale,
                          height: CGFloat(height * scale) / screenScale)
        frame = CGRect(x: ((viewSize.width - size.width) / 2 * screenScale).rounded() / screenScale,
                       y: ((viewSize.height - size.height) / 2 * screenScale).rounded() / screenScale,
                       width: size.width, height: size.height)
    }
}
