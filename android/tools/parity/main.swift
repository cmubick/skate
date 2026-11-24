//
//  main.swift
//
//  Run by make_fixtures.sh, built together with the iOS game's own rules, art
//  and sound code. Writes a fingerprint of every picture (art.txt), every sound
//  and song (sounds.txt) and a scripted run on each spot (runs.txt).
//  ParityTests.kt in the Android port makes the same things and compares.
//
//  Keep the lists here and in ParityTests.kt the same, in the same order.
//

import CryptoKit
import Foundation

enum Recorder {
    nonisolated(unsafe) static var canvases: [PixelCanvas] = []
}

func sha(_ bytes: [UInt8]) -> String {
    SHA256.hash(data: Data(bytes)).map { String(format: "%02x", $0) }.joined()
}

var art = ""
func record(_ name: String, _ canvas: PixelCanvas) {
    art += "\(name)\t\(canvas.width)\t\(canvas.height)\t\(sha(canvas.pixels))\n"
}

func canvas(_ sprite: PixelSprite) -> PixelCanvas {
    var canvas = PixelCanvas(width: sprite.width, height: sprite.height)
    canvas.draw(sprite, x: 0, y: 0)
    return canvas
}

/// Calls `make`, then records every canvas it turned into a texture.
func recordTextures(_ name: String, _ make: () -> Void) {
    Recorder.canvases = []
    make()
    for (index, canvas) in Recorder.canvases.enumerated() { record("\(name).\(index)", canvas) }
}

// MARK: Art

var angie = Outfit.standard
angie.switchSkater(to: .angie)
let outfits: [Outfit] = [
    .standard,
    Outfit(kind: .sammy, shirt: .white, pants: .navy, hat: nil, board: .pink),
    angie,
    Outfit(kind: .pat, shirt: .yellow, pants: .black, hat: .red, board: .pdx),
    Outfit(kind: .angie, shirt: .teal, pants: .khaki, hat: .green, board: .pdx),
]
for (o, outfit) in outfits.enumerated() {
    let poses = CharacterArt.poses(for: outfit)
    for (name, sprite) in [("roll", poses.roll), ("crouch", poses.crouch), ("air", poses.air), ("grab", poses.grab),
                           ("bail", poses.bail), ("slide0", poses.slide[0]), ("slide1", poses.slide[1])] {
        record("outfit\(o).\(name)", canvas(sprite))
    }
    let board = CharacterArt.board(for: outfit)
    for (name, sprite) in [("side", board.side), ("wheelsUp", board.wheelsUp), ("underside", board.underside),
                           ("grip", board.grip), ("endOn", board.endOn)] {
        record("outfit\(o).board.\(name)", canvas(sprite))
    }
    for step in 0..<CharacterArt.spinSteps {
        record("outfit\(o).spin\(step)", CharacterArt.spin(for: outfit, step: step, graphicUp: false))
        record("outfit\(o).spinUp\(step)", CharacterArt.spin(for: outfit, step: step, graphicUp: true))
    }
    record("outfit\(o).standing", CharacterArt.canvasStanding(outfit: outfit))
}

let themes: [Theme] = [.downtown, .skidmore, .burnside, .northPortland, .waterfront, .zooBomb]
for (index, theme) in themes.enumerated() {
    var look: ThemeLook?
    recordTextures("theme\(index)") { look = ThemeArt.look(for: theme) }
    let sky = look!.sky
    art += "theme\(index).sky\t\(sky.r)\t\(sky.g)\t\(sky.b)\n"
}

for level in City.portland.levels + [.tutorial] {
    for (index, feature) in level.features.enumerated() {
        var look: FeatureLook?
        recordTextures("feature.\(level.id).\(index)") { look = FeatureArt.look(for: feature, seed: index) }
        art += "feature.\(level.id).\(index).offset\t\(Int(look!.offset.x))\t\(Int(look!.offset.y))\n"
    }
}

for (index, letter) in "PORTLAND".enumerated() {
    recordTextures("token\(index)") {
        _ = LetterArt.token(letter, found: false)
        _ = LetterArt.token(letter, found: true)
    }
}

recordTextures("text") {
    _ = PixelFont.texture("SCORE 1234", color: Palette.white)
    _ = PixelFont.texture("New best!", color: Palette.yellow)
    _ = PixelFont.texture(runs: [("P", Palette.yellow), ("ORTLAND", PixelColor(0xA8A8A8))])
}

recordTextures("ui") {
    _ = UIArt.tipJar()
    _ = UIArt.musicIcon(on: true)
    _ = UIArt.musicIcon(on: false)
    _ = UIArt.soundIcon(on: true)
    _ = UIArt.soundIcon(on: false)
    _ = UIArt.padlock()
    _ = UIArt.box(width: 46, height: 13, fill: PixelColor(0x00A844))
    _ = UIArt.panel(width: 100, height: 50)
    _ = StreetArt.shadow()
    _ = StreetArt.shadow(width: 20)
    _ = FeatureArt.finishLine(height: 46)
}
record("menu.fountain", FeatureArt.fountain(width: 64))
record("menu.tracks", FeatureArt.tracks(width: 60))

try! art.write(toFile: "art.txt", atomically: true, encoding: .utf8)

// MARK: Sounds and songs

func summary<T: BinaryFloatingPoint>(_ samples: [T], probes: Int) -> String {
    var sum = 0.0, squares = 0.0
    for sample in samples {
        sum += Double(sample)
        squares += Double(sample) * Double(sample)
    }
    let stride = max(1, samples.count / probes)
    let picked = Swift.stride(from: 0, to: samples.count, by: stride).map { String(format: "%.9f", Double(samples[$0])) }
    return "\(samples.count)\t\(String(format: "%.9f", sum))\t\(String(format: "%.9f", squares))\t" + picked.joined(separator: " ")
}

var sounds = ""
for sound in Sound.allCases {
    sounds += "sound.\(sound)\t" + summary(SoundSynth.samples(for: sound), probes: 16) + "\n"
}
for song in Songs.all {
    sounds += "song.\(song.name).intro\t" + summary(Chiptune.renderIntro(song), probes: 32) + "\n"
    sounds += "song.\(song.name).loop\t" + summary(Chiptune.renderLoop(song), probes: 32) + "\n"
}
try! sounds.write(toFile: "sounds.txt", atomically: true, encoding: .utf8)

// MARK: Runs

func describe(_ event: RunEvent) -> String {
    switch event {
    case .ollie(let charged): "ollie \(charged)"
    case .popOff: "popOff"
    case .launched: "launched"
    case .trickStarted(let trick): "trickStarted \(trick.name)"
    case .grindStarted(let trick): "grindStarted \(trick.name)"
    case .grindSwitched(let trick): "grindSwitched \(trick.name)"
    case .grindEnded: "grindEnded"
    case .landed(let perfect): "landed \(perfect)"
    case .landedTrick(let trick): "landedTrick \(trick.name)"
    case .banked(let points): "banked \(points)"
    case .bail(let reason): "bail \(reason)"
    case .laneSwitch(let lane): "lane \(lane.rawValue)"
    case .letter(let index, let letter): "letter \(index) \(letter)"
    case .cleared(let style, let trickStyle, let points): "cleared \(style.name) \(Int(trickStyle * 10)) \(points)"
    case .gap(let name, let points): "gap \(name) \(points)"
    case .finished(let score): "finished \(score)"
    }
}

/// A scripted player: a press every 54 steps (0.45 s); every third one held for a
/// quarter of a second (so it's a hold), the rest let go after 9 steps; every fourth
/// one followed 5 steps later by a swipe, in turn left, right, up and down.
func scriptedRun(_ level: Level) -> String {
    var run = Run(level: level)
    let directions: [SwipeDirection] = [.left, .right, .up, .down]
    var trace: [String] = []
    var t = 0, presses = 0, pressedAt = -1, holdFor = 0, swipeAt = -1
    var direction = SwipeDirection.left
    func note(_ events: [RunEvent]) { trace += events.map { "\(t):" + describe($0) } }
    while !run.isFinished, t < 120 * 90 {
        if t % 54 == 0 {
            note(run.handle(.press))
            pressedAt = t
            presses += 1
            holdFor = presses % 3 == 0 ? 30 : 9
            if presses % 4 == 0 {
                swipeAt = t + 5
                direction = directions[(presses / 4) % 4]
            } else {
                swipeAt = -1
            }
        }
        if t == swipeAt {
            note(run.handle(.swipe(direction)))
            pressedAt = -1
        }
        if pressedAt >= 0, holdFor > 15, t == pressedAt + 15 { note(run.handle(.hold)) }
        if pressedAt >= 0, t == pressedAt + holdFor {
            note(run.handle(.release(held: Double(holdFor) / 120)))
            pressedAt = -1
        }
        note(run.step(1.0 / 120))
        t += 1
    }
    let x = String(format: "%.6f", run.x)
    return "\(run.score)\t\(run.bestCombo)\t\(x)\t\(trace.count)\t\(sha(Array(trace.joined(separator: "\n").utf8)))"
}

var runs = ""
for level in City.portland.levels + [.tutorial] {
    runs += "run.\(level.id)\t" + scriptedRun(level) + "\n"
}
try! runs.write(toFile: "runs.txt", atomically: true, encoding: .utf8)
