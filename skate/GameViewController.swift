//
//  GameViewController.swift
//  skate
//
//  Holds the SpriteKit view and keeps the game's pixels whole: the view is
//  sized so each game pixel is a whole number of screen pixels.
//

import UIKit
import SpriteKit

class GameViewController: UIViewController {

    private let skView = SKView()
    private var gameScene: GameScene?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.isMultipleTouchEnabled = true
        skView.isMultipleTouchEnabled = true
        skView.ignoresSiblingOrder = true
        view.addSubview(skView)
        #if DEBUG
        skView.showsFPS = true
        #endif
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let screenScale = view.window?.screen.scale ?? view.traitCollection.displayScale
        let layout = PixelLayout(viewSize: view.bounds.size, screenScale: screenScale)
        skView.frame = layout.frame

        if let scene = gameScene {
            if scene.size != layout.gameSize { scene.size = layout.gameSize }
        } else {
            let scene = GameScene(size: layout.gameSize)
            scene.scaleMode = .fill
            skView.presentScene(scene)
            gameScene = scene
        }
        gameScene?.pointsPerPixel = layout.pointsPerPixel
        gameScene?.safeInsets = view.safeAreaInsets
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        gameScene?.safeInsets = view.safeAreaInsets
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }
}

/// Works out how big the game is in its own pixels, and how big a frame to show it in.
///
/// The game is at least 256 x 144 pixels. Each game pixel is drawn as the largest whole
/// number of screen pixels that still fits that, and any room left over shows more of
/// the street to the right and more sky above.
nonisolated struct PixelLayout: Equatable {
    static let minimumSize = CGSize(width: 256, height: 144)

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
