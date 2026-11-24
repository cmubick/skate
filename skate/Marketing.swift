//
//  Marketing.swift
//  skate
//
//  Debug builds only: renders the App Store screenshots and artwork straight from
//  the game. Each shot is a real spot frozen on a staged moment (see
//  `Run.stage` and `GameScene.stageForMarketing`), captured at one pixel per game
//  pixel and blown up by a whole number, so every pixel stays crisp.
//
//  Run it by launching a debug build in the simulator with `-marketing YES`. The
//  PNGs land in the app's Documents/AppStore folder; `AppStore/make_assets.sh`
//  does all of it and copies them into the repo.
//

#if DEBUG
import ImageIO
import SpriteKit
import UIKit
import UniformTypeIdentifiers

@MainActor
enum Marketing {
    /// One size Apple asks for.
    struct Format {
        var folder: String
        var width: Int, height: Int
        /// Screen pixels per game pixel.
        var scale: Int
        /// Game pixels along the top kept for the caption. Zero for none: the game fills it.
        var captionRows: Int

        var posterWidth: Int { (width + scale - 1) / scale }
        var posterHeight: Int { (height + scale - 1) / scale }
        var gameSize: CGSize { CGSize(width: posterWidth, height: posterHeight - captionRows) }
    }

    /// iPhone with Dynamic Island, 6.1" (required).
    static let iPhone61 = Format(folder: "iphone-6.1in-2556x1179", width: 2556, height: 1179, scale: 9, captionRows: 31)
    /// iPhone with Dynamic Island, 6.9" (optional).
    static let iPhone69 = Format(folder: "iphone-6.9in-2868x1320", width: 2868, height: 1320, scale: 10, captionRows: 32)
    /// iPad 13" (required: the game runs on iPad).
    static let iPad13 = Format(folder: "ipad-13in-2752x2064", width: 2752, height: 2064, scale: 15, captionRows: 30)
    /// The product page header (iOS 27), 21:9.
    static let header = Format(folder: "header-3840x1646", width: 3840, height: 1646, scale: 16, captionRows: 0)
    /// The universal asset (header and search results), 16:9.
    static let universal = Format(folder: "universal-5244x2950", width: 5244, height: 2950, scale: 28, captionRows: 0)
    /// The search results asset, 3:2.
    static let search = Format(folder: "search-3840x2560", width: 3840, height: 2560, scale: 24, captionRows: 0)
    /// The in-app purchase review screenshot: the tip jar, as it looks on an iPhone.
    static let review = Format(folder: "iap-review-2556x1179", width: 2556, height: 1179, scale: 12, captionRows: 0)

    enum Source {
        /// A spot. With no staging, its goals screen as you arrive.
        case run(Level, RunStaging?)
        case menu(MenuScene.Page)
    }

    struct Shot {
        var name: String
        var caption: String?
        var source: Source
        var outfit = Outfit.standard
        var lettersFound: [Int] = []
        var goalsDone: [String: [String]] = [:]
        var anchor: CGFloat = 0.3
        var hud = true
        var popups: [(text: String, color: PixelColor)] = []
        var banners: [(title: String, text: String, color: PixelColor)] = []
        var sparks = false
    }

    // MARK: The shots

    private static func feature(_ level: Level, _ style: FeatureStyle, at x: CGFloat) -> Int {
        level.features.firstIndex { $0.style == style && $0.x == x }!
    }

    private static var angie: Outfit {
        var outfit = Outfit()
        outfit.switchSkater(to: .angie)
        return outfit
    }

    private static var sammy: Outfit {
        var outfit = Outfit()
        outfit.switchSkater(to: .sammy)
        outfit.shirt = .red
        outfit.hat = .blue
        outfit.board = .pdx
        return outfit
    }

    /// The screenshots, best first: the first three show in search results. The
    /// skater sits a fifth of the way in, clear of the score and combo along the top.
    static var screenshots: [Shot] {
        let downtown = Level.downtown, skidmore = Level.skidmoreFountain
        let waterfront = Level.southeastWaterfront, zoo = Level.zooBomb, north = Level.northPortland
        return [
            Shot(name: "flip", caption: "FLIP IT WITH ONE THUMB",
                 source: .run(downtown, RunStaging(x: 1236, lane: .middle, height: 13, state: .airborne,
                                                   airTrick: AirTrick(trick: .kickflip, elapsed: 0.1, duration: 0.32),
                                                   combo: [.fiftyFifty, .kickflip], comboBonus: 130, score: 3450)),
                 lettersFound: [0, 1, 2], anchor: 0.2,
                 popups: [("CONE +130", Palette.yellow)]),
            Shot(name: "grind", caption: "GRIND REAL CITY SPOTS",
                 source: .run(skidmore, RunStaging(x: 1716, lane: .back, height: 12,
                                                   state: .grinding(feature: feature(skidmore, .fountain, at: 1600), trick: .fiftyFifty),
                                                   combo: [.kickflip, .fiftyFifty], score: 1850)),
                 lettersFound: [0, 1, 2], anchor: 0.2, sparks: true),
            Shot(name: "combo", caption: "STACK UP HUGE COMBOS",
                 source: .run(zoo, RunStaging(x: 1210, lane: .middle, height: 14, state: .airborne,
                                              airTrick: AirTrick(trick: .threeSixtyFlip, elapsed: 0.04, duration: 0.46),
                                              combo: [.kickflip, .fiftyFifty, .boardslide, .threeSixtyFlip],
                                              comboBonus: 290, score: 8920)),
                 lettersFound: [0, 1, 2, 3, 4, 5, 6], anchor: 0.2,
                 popups: [("BARRIER +290", Palette.yellow)]),
            Shot(name: "angie", caption: "SKATE AS ANGIE THE DOG",
                 source: .run(waterfront, RunStaging(x: 1770, lane: .back, height: 14,
                                                     state: .grinding(feature: feature(waterfront, .handrail, at: 1700), trick: .boardslide),
                                                     combo: [.heelflip, .fiftyFifty, .boardslide], score: 4210)),
                 outfit: angie, lettersFound: [0, 1, 2, 3, 4, 5], anchor: 0.2, sparks: true),
            Shot(name: "letters", caption: "SPELL OUT THE CITY",
                 source: .run(north, RunStaging(x: 1494, lane: .back, height: 9,
                                                state: .grinding(feature: feature(north, .bench, at: 1480), trick: .fiftyFifty),
                                                combo: [.kickflip, .fiftyFifty], score: 2760)),
                 outfit: sammy, lettersFound: [0, 1, 2, 3, 4], anchor: 0.2, sparks: true),
            Shot(name: "gaps", caption: "NAIL THE BIG GAPS",
                 source: .run(downtown, RunStaging(x: 1606, lane: .back, height: 14, state: .airborne,
                                                   airTrick: AirTrick(trick: .heelflip, elapsed: 0.14, duration: 0.32),
                                                   combo: [.fiftyFifty, .heelflip], comboBonus: 500, score: 5120)),
                 lettersFound: [0, 1, 2, 3], anchor: 0.2,
                 banners: [("PIONEER GAP", "+500", Palette.orange)]),
            Shot(name: "goals", caption: "5 GOALS AT EVERY SPOT",
                 source: .run(waterfront, nil),
                 lettersFound: [0, 1, 2, 3, 4], goalsDone: ["waterfront": ["waterfront.letters"]]),
            Shot(name: "skater", caption: "PICK YOUR SKATER",
                 source: .menu(.builder), outfit: sammy),
        ]
    }

    /// The key art: an ollie high over a bench on the waterfront, board flat under the
    /// feet, with the bridges, Mt Hood and Big Pink behind, in the middle of the frame,
    /// no HUD or text. `height` puts the skater clear of the bench and inside each
    /// format's safe area. (Not Downtown: Portlandia and the PORTLAND OREGON sign
    /// belong to others, so they're kept out of the key art.)
    static func keyArt(height: CGFloat, level: Level = .southeastWaterfront, x: CGFloat = 1398) -> Shot {
        Shot(name: "key-art", caption: nil,
             source: .run(level, RunStaging(x: x, lane: .middle, height: height, state: .airborne)),
             outfit: keyArtOutfit, anchor: 0.5, hud: false)
    }

    /// Pat as usual, but on a white board: the default brown one vanishes against the
    /// boardwalk and the bench.
    private static var keyArtOutfit: Outfit {
        var outfit = Outfit()
        outfit.board = .white
        return outfit
    }

    /// Places to try for the key art, rendered as headers by `-keyArtDrafts YES`.
    static let keyArtDrafts: [(Level, CGFloat)] = [
        (.downtown, 1238), (.downtown, 2000), (.skidmoreFountain, 1500), (.skidmoreFountain, 2300),
        (.southeastWaterfront, 1104), (.southeastWaterfront, 1400), (.southeastWaterfront, 2150),
        (.northPortland, 1150), (.zooBomb, 2240),
    ]

    // MARK: Exporting

    /// Renders everything into Documents/AppStore. Puts saved progress back afterwards.
    static func exportAll(in host: UIView) async {
        let defaults = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier!
        let saved = defaults.persistentDomain(forName: domain) ?? [:]
        let out = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("AppStore")
        try? FileManager.default.removeItem(at: out)

        if UserDefaults.standard.bool(forKey: "keyArtDrafts") {
            for (level, x) in keyArtDrafts {
                await export(keyArt(height: 8, level: level, x: x), format: header, host: host, to: out,
                             file: "\(level.id)-\(Int(x)).png")
            }
            defaults.setPersistentDomain(saved, forName: domain)
            print("MARKETING DONE \(out.path)")
            return
        }

        for format in [iPhone61, iPhone69, iPad13] {
            for (index, shot) in screenshots.enumerated() {
                await export(shot, format: format, host: host, to: out, file: "\(index + 1)-\(shot.name).png")
            }
        }
        await export(keyArt(height: 15), format: header, host: host, to: out, file: "header.png")
        await export(keyArt(height: 21), format: universal, host: host, to: out, file: "universal.png")
        await export(keyArt(height: 17), format: search, host: host, to: out, file: "search.png")
        await export(Shot(name: "tips", caption: nil, source: .menu(.tips(back: .title))), format: review,
                     host: host, to: out, file: "iap-review-tip-jar.png")

        defaults.setPersistentDomain(saved, forName: domain)
        print("MARKETING DONE \(out.path)")
    }

    private static func export(_ shot: Shot, format: Format, host: UIView, to folder: URL, file: String) async {
        guard let game = await capture(shot, size: format.gameSize, host: host) else {
            print("MARKETING FAILED \(format.folder)/\(file)")
            return
        }
        let image = compose(game: game, caption: shot.caption, format: format)
        let directory = folder.appendingPathComponent(format.folder)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(file)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }

    /// The shot at one pixel per game pixel.
    private static func capture(_ shot: Shot, size: CGSize, host: UIView) async -> CGImage? {
        // Saved progress as the shot needs it: these letters and goals, this skater.
        let defaults = UserDefaults.standard
        defaults.setPersistentDomain([:], forName: Bundle.main.bundleIdentifier!)
        Progress.shared.outfit = shot.outfit
        defaults.set(shot.lettersFound, forKey: "letters.portland")
        for (level, goals) in shot.goalsDone { defaults.set(goals, forKey: "goals.\(level)") }

        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.ignoresSiblingOrder = true
        host.insertSubview(view, at: 0)
        defer { view.removeFromSuperview() }

        let scene: PixelScene
        switch shot.source {
        case .run(let level, _): scene = GameScene(size: size, level: level, city: .portland, outfit: shot.outfit)
        case .menu(let page): scene = MenuScene(size: size, page: page)
        }
        scene.scaleMode = .fill
        scene.pointsPerPixel = 1
        scene.screenPixelsPerPixel = 1
        scene.safeInsets = .zero
        view.presentScene(scene)
        try? await Task.sleep(for: .milliseconds(300))
        if case .run(_, let staging?) = shot.source, let game = scene as? GameScene {
            // Popups crowd the combo on narrow screens (iPad), so they're left out there.
            game.stageForMarketing(staging, cameraAnchor: shot.anchor, hud: shot.hud,
                                   popups: size.width >= 200 ? shot.popups : [],
                                   sparks: shot.sparks, banners: shot.banners)
        }
        try? await Task.sleep(for: .milliseconds(200))
        view.isPaused = true

        let crop = (scene as? GameScene)?.marketingVisibleRect ?? CGRect(origin: .zero, size: size)
        guard let raw = view.texture(from: scene, crop: crop)?.cgImage() else { return nil }
        let width = Int(size.width), height = Int(size.height)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.setFillColor(scene.backgroundColor.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .none
        context.draw(raw, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    /// The caption band and its color.
    static let bandColor = PixelColor(0x141A3C)

    /// The game blown up to the format's size, with the caption across the top.
    private static func compose(game: CGImage, caption: String?, format: Format) -> CGImage {
        let width = format.width, height = format.height, scale = format.scale
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.interpolationQuality = .none
        context.setFillColor(cgColor(bandColor))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // Centered sideways; a pixel or two can fall off the edges. With a caption the
        // game sits at the bottom, otherwise it's centered.
        let gameWidth = game.width * scale, gameHeight = game.height * scale
        let x = (width - gameWidth) / 2
        let y = format.captionRows > 0 ? 0 : (height - gameHeight) / 2
        context.draw(game, in: CGRect(x: x, y: y, width: gameWidth, height: gameHeight))

        if let caption, format.captionRows > 0 {
            // A dark line between the band and the game, one game pixel thick.
            context.setFillColor(cgColor(Palette.black))
            context.fill(CGRect(x: 0, y: gameHeight, width: width, height: scale))
            let band = CGRect(x: 0, y: gameHeight + scale, width: width, height: height - gameHeight - scale)
            drawCaption(caption, in: band, width: width, context: context)
        }
        return context.makeImage()!
    }

    /// The caption in the pixel font, as big as fits: one line, or two if that's bigger.
    private static func drawCaption(_ caption: String, in band: CGRect, width: Int, context: CGContext) {
        let lineHeight = PixelFont.glyphHeight + 1
        func size(for lines: [String]) -> Int {
            let widest = lines.map { PixelFont.width(of: $0) }.max() ?? 1
            let tall = lines.count * lineHeight + (lines.count - 1) * 3
            let fill = lines.count == 1 ? 0.5 : 0.8
            return min(Int(band.height * fill) / tall, Int(Double(width) * 0.9) / widest)
        }
        var lines = [caption]
        let words = caption.split(separator: " ").map(String.init)
        if words.count > 1 {
            let splits = (1..<words.count).map { [words[..<$0].joined(separator: " "), words[$0...].joined(separator: " ")] }
            if let best = splits.max(by: { size(for: $0) < size(for: $1) }), size(for: best) > size(for: lines) { lines = best }
        }
        let pixel = size(for: lines)
        let blockHeight = (lines.count * lineHeight + (lines.count - 1) * 3) * pixel
        var top = Int(band.midY) + blockHeight / 2
        for line in lines {
            var canvas = PixelCanvas(width: PixelFont.width(of: line), height: lineHeight)
            PixelFont.draw(line, into: &canvas, x: 0, y: 0, color: Palette.black)
            PixelFont.draw(line, into: &canvas, x: 0, y: 1, color: Palette.yellow)
            guard let image = canvas.cgImage() else { continue }
            let lineWidth = canvas.width * pixel
            top -= lineHeight * pixel
            context.draw(image, in: CGRect(x: (width - lineWidth) / 2, y: top, width: lineWidth, height: lineHeight * pixel))
            top -= 3 * pixel
        }
    }

    private static func cgColor(_ color: PixelColor) -> CGColor {
        CGColor(srgbRed: CGFloat(color.r) / 255, green: CGFloat(color.g) / 255, blue: CGFloat(color.b) / 255, alpha: 1)
    }
}
#endif
