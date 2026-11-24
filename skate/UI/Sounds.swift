//
//  Sounds.swift
//  skate
//
//  Chip-style sound effects, generated in code so the app ships no audio files.
//  Square waves and noise, like a 4-voice NES sound chip.
//

import AVFoundation

nonisolated enum Sound: CaseIterable, Sendable {
    /// The board popping off the ground.
    case pop
    /// A flip or grab: a quick swish.
    case trick
    /// Wheels back down.
    case land
    /// A perfect landing: a bright two-note blip.
    case perfect
    /// Metal under the board. Loops for as long as the grind lasts.
    case grind
    /// Switching lanes.
    case lane
    /// A tumble.
    case bail
    /// Crossing the finish line.
    case finish
    /// Picking up one of the city's letters.
    case letter
    /// Wheels on pavement, with a clack over the cracks. Loops while rolling.
    case roll
    /// Concrete and wood under the trucks: ledges, benches, curbs. Loops.
    case scrape
    /// A boardslide: the deck scraping across. Loops.
    case slide
    /// Locking onto a rail or ledge.
    case lock
    /// A kickflip or heelflip: a flick and the board whirring round.
    case flip
    /// A shove-it or 360 flip: a whoosh.
    case spin
    /// A grab.
    case grab
    /// Flying off the lip of a quarter pipe.
    case launch
    /// Getting all the way over something.
    case clear
    /// A combo counted into the score.
    case bank
    /// A named gap.
    case gap
    /// A goal done.
    case goal
    /// Dropping into a manhole.
    case fall
    /// A firework going off.
    case burst

    /// The sounds that loop for as long as something lasts.
    static let loops: Set<Sound> = [.grind, .scrape, .slide, .roll]
}

/// Builds each sound's samples, from -1 to 1.
nonisolated enum SoundSynth {
    static let sampleRate = 22_050.0

    /// A square wave that glides from one pitch to another and fades out.
    static func square(from start: Double, to end: Double, seconds: Double, level: Double, duty: Double = 0.5) -> [Double] {
        let count = Int(seconds * sampleRate)
        var phase = 0.0
        return (0..<count).map { index in
            let progress = Double(index) / Double(max(count, 1))
            phase += (start + (end - start) * progress) / sampleRate
            let wave: Double = phase.truncatingRemainder(dividingBy: 1) < duty ? 1 : -1
            return wave * level * (1 - progress)
        }
    }

    /// A triangle wave, the NES's bass voice.
    static func triangle(_ frequency: Double, seconds: Double, level: Double) -> [Double] {
        let count = Int(seconds * sampleRate)
        return (0..<count).map { index in
            let t = Double(index) / sampleRate
            let phase = (t * frequency).truncatingRemainder(dividingBy: 1)
            let wave = phase < 0.5 ? 4 * phase - 1 : 3 - 4 * phase
            return wave * level * (1 - Double(index) / Double(max(count, 1)))
        }
    }

    /// Noise, held for `hold` samples at a time: long holds sound low and crunchy.
    static func noise(seconds: Double, hold: Int, level: Double, decay: Double, seed: UInt64) -> [Double] {
        var generator = SeededGenerator(seed: seed)
        let count = Int(seconds * sampleRate)
        var value = 0.0
        return (0..<count).map { index in
            if index % max(1, hold) == 0 { value = Bool.random(using: &generator) ? 1 : -1 }
            let t = Double(index) / sampleRate
            return value * level * exp(-t / decay)
        }
    }

    static func mix(_ a: [Double], _ b: [Double]) -> [Double] {
        let count = max(a.count, b.count)
        return (0..<count).map { (index: Int) -> Double in
            (index < a.count ? a[index] : 0) + (index < b.count ? b[index] : 0)
        }
    }

    static func silence(_ seconds: Double) -> [Double] {
        [Double](repeating: 0, count: Int(seconds * sampleRate))
    }

    static func samples(for sound: Sound) -> [Double] {
        switch sound {
        case .pop:
            return mix(square(from: 220, to: 660, seconds: 0.07, level: 0.25, duty: 0.25),
                       noise(seconds: 0.05, hold: 2, level: 0.25, decay: 0.012, seed: 1))
        case .trick:
            return noise(seconds: 0.12, hold: 1, level: 0.18, decay: 0.05, seed: 2)
        case .land:
            return mix(noise(seconds: 0.08, hold: 6, level: 0.4, decay: 0.02, seed: 3),
                       triangle(110, seconds: 0.08, level: 0.4))
        case .perfect:
            return mix(samples(for: .land),
                       square(from: 1320, to: 1320, seconds: 0.06, level: 0.16, duty: 0.25)
                       + square(from: 1760, to: 1760, seconds: 0.1, level: 0.16, duty: 0.25))
        case .grind:
            // Exactly one loop's worth: a gritty hum with a little wobble.
            let count = Int(0.4 * sampleRate)
            var generator = SeededGenerator(seed: 4)
            var value = 0.0
            return (0..<count).map { index in
                if index % 3 == 0 { value = Double.random(in: -1...1, using: &generator) }
                let hum: Double = (Double(index) * 180 / sampleRate).truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : -1
                return value * 0.12 + hum * 0.05
            }
        case .lane:
            return square(from: 880, to: 990, seconds: 0.03, level: 0.12, duty: 0.125)
        case .bail:
            return mix(noise(seconds: 0.35, hold: 12, level: 0.45, decay: 0.12, seed: 5),
                       square(from: 300, to: 60, seconds: 0.3, level: 0.2))
        case .letter:
            return [988.0, 1319, 1976].flatMap { square(from: $0, to: $0, seconds: 0.05, level: 0.16, duty: 0.25) }
        case .finish:
            let notes: [Double] = [523, 659, 784, 1047]
            return notes.flatMap { square(from: $0, to: $0, seconds: 0.1, level: 0.18, duty: 0.25) }
                + square(from: 1047, to: 1047, seconds: 0.3, level: 0.18, duty: 0.5)
        case .roll:
            // Half a second: a low rumble, and two clacks over the sidewalk joints.
            let count = Int(0.5 * sampleRate)
            var generator = SeededGenerator(seed: 10)
            var value = 0.0
            var out = (0..<count).map { (index: Int) -> Double in
                if index % 14 == 0 { value = Double.random(in: -1...1, using: &generator) }
                return value * 0.09
            }
            let clack = mix(noise(seconds: 0.03, hold: 2, level: 0.2, decay: 0.008, seed: 11), triangle(95, seconds: 0.03, level: 0.2))
            for start in [0, count / 2] {
                for (offset, sample) in clack.enumerated() where start + offset < count { out[start + offset] += sample }
            }
            return out
        case .scrape:
            let count = Int(0.4 * sampleRate)
            var generator = SeededGenerator(seed: 12)
            var value = 0.0
            return (0..<count).map { (index: Int) -> Double in
                if index % 2 == 0 { value = Double.random(in: -1...1, using: &generator) }
                // A gritty rasp that wobbles as the trucks chatter (whole cycles, so it loops cleanly).
                let wobble = 0.7 + 0.3 * sin(2 * .pi * 15 * Double(index) / Double(count) * 0.4)
                return value * 0.15 * wobble
            }
        case .slide:
            let count = Int(0.4 * sampleRate)
            var generator = SeededGenerator(seed: 13)
            var value = 0.0
            return (0..<count).map { (index: Int) -> Double in
                if index % 4 == 0 { value = Double.random(in: -1...1, using: &generator) }
                let buzz: Double = (Double(index) * 95 / sampleRate).truncatingRemainder(dividingBy: 1) < 0.25 ? 1 : -1
                let wobble = 0.75 + 0.25 * sin(2 * .pi * 10 * Double(index) / Double(count) * 0.4)
                return (value * 0.13 + buzz * 0.04) * wobble
            }
        case .lock:
            return mix(mix(square(from: 1180, to: 1180, seconds: 0.09, level: 0.12, duty: 0.25),
                           square(from: 1770, to: 1770, seconds: 0.07, level: 0.08, duty: 0.5)),
                       noise(seconds: 0.04, hold: 2, level: 0.2, decay: 0.01, seed: 14))
        case .flip:
            // A flick, then the board whirring: a rising tone that flutters.
            let whir = square(from: 500, to: 1400, seconds: 0.12, level: 0.11, duty: 0.125).enumerated().map { index, sample in
                sample * ((index / 220) % 2 == 0 ? 1 : 0.35)
            }
            return mix(whir, noise(seconds: 0.05, hold: 1, level: 0.16, decay: 0.015, seed: 15))
        case .spin:
            // A whoosh that swells and fades.
            let count = Int(0.2 * sampleRate)
            var generator = SeededGenerator(seed: 16)
            var value = 0.0
            return (0..<count).map { (index: Int) -> Double in
                if index % 2 == 0 { value = Double.random(in: -1...1, using: &generator) }
                let progress = Double(index) / Double(count)
                return value * 0.18 * sin(.pi * progress)
            }
        case .grab:
            return mix(noise(seconds: 0.08, hold: 3, level: 0.16, decay: 0.03, seed: 17),
                       square(from: 320, to: 260, seconds: 0.05, level: 0.08, duty: 0.25))
        case .launch:
            return mix(square(from: 180, to: 900, seconds: 0.22, level: 0.18, duty: 0.25),
                       noise(seconds: 0.15, hold: 2, level: 0.15, decay: 0.05, seed: 18))
        case .clear:
            return square(from: 880, to: 880, seconds: 0.04, level: 0.13, duty: 0.25)
                + square(from: 1175, to: 1175, seconds: 0.06, level: 0.13, duty: 0.25)
        case .bank:
            return square(from: 1319, to: 1319, seconds: 0.05, level: 0.14, duty: 0.5)
                + square(from: 1976, to: 1976, seconds: 0.16, level: 0.14, duty: 0.5)
        case .gap:
            let notes: [Double] = [659, 784, 988, 1319]
            return notes.flatMap { square(from: $0, to: $0, seconds: 0.05, level: 0.15, duty: 0.25) }
                + square(from: 1568, to: 1568, seconds: 0.16, level: 0.15, duty: 0.25)
        case .goal:
            let notes: [Double] = [784, 988, 1175]
            let fanfare = notes.flatMap { square(from: $0, to: $0, seconds: 0.08, level: 0.15, duty: 0.5) }
                + square(from: 1568, to: 1568, seconds: 0.28, level: 0.15, duty: 0.5)
            return mix(fanfare, silence(0.24) + triangle(196, seconds: 0.28, level: 0.3))
        case .fall:
            let whistle = square(from: 1200, to: 150, seconds: 0.45, level: 0.16, duty: 0.5)
            let thud = mix(triangle(60, seconds: 0.15, level: 0.45), noise(seconds: 0.12, hold: 8, level: 0.3, decay: 0.04, seed: 19))
            return whistle + thud
        case .burst:
            return mix(noise(seconds: 0.45, hold: 2, level: 0.22, decay: 0.12, seed: 20),
                       noise(seconds: 0.06, hold: 6, level: 0.3, decay: 0.02, seed: 21))
        }
    }
}

/// Plays the sound effects. Muting is remembered between launches.
///
/// Every sound is a buffer in memory played through an audio engine: a few voices
/// take turns with the one-off sounds, and each looping sound has a voice of its
/// own. (One `AVAudioPlayer` per sound was much slower to set up.)
final class Sounds {
    static let shared = Sounds()
    private static let mutedKey = "soundMuted"
    /// Voices for one-off sounds, so a few can overlap.
    private static let voiceCount = 6

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: SoundSynth.sampleRate, channels: 1)!
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private var voices: [AVAudioPlayerNode] = []
    private var nextVoice = 0
    private var loopVoices: [Sound: AVAudioPlayerNode] = [:]
    private var isSetUp = false

    var isMuted: Bool {
        didSet {
            UserDefaults.standard.set(isMuted, forKey: Sounds.mutedKey)
            if isMuted { stopAllLoops() }
        }
    }

    private init() {
        isMuted = UserDefaults.standard.bool(forKey: Sounds.mutedKey)
    }

    /// Makes every sound and sets up the audio session, so the first sound plays
    /// without a hitch. Done on the first sound anyway; spots call it as they start.
    func prepare() {
        guard !isSetUp else { return }
        isSetUp = true
        // Ambient: the silent switch mutes the game, and the player's own music keeps playing.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        for sound in Sound.allCases {
            let samples = SoundSynth.samples(for: sound)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
                  let channel = buffer.floatChannelData?[0] else { continue }
            buffer.frameLength = AVAudioFrameCount(samples.count)
            for (index, sample) in samples.enumerated() { channel[index] = Float(max(-1, min(1, sample))) }
            buffers[sound] = buffer
        }
        func addVoice() -> AVAudioPlayerNode {
            let voice = AVAudioPlayerNode()
            engine.attach(voice)
            engine.connect(voice, to: engine.mainMixerNode, format: format)
            return voice
        }
        voices = (0..<Self.voiceCount).map { _ in addVoice() }
        for sound in Sound.loops {
            let voice = addVoice()
            // Rolling is there all the time, so it sits well back.
            voice.volume = sound == .roll ? 0.3 : 0.7
            loopVoices[sound] = voice
        }
        voices.forEach { $0.volume = 0.7 }
    }

    /// Starts the engine if it isn't running (it stops for calls and the background).
    private func ready() -> Bool {
        prepare()
        if !engine.isRunning {
            do { try engine.start() } catch { return false }
        }
        return true
    }

    func play(_ sound: Sound) {
        guard !isMuted, ready(), let buffer = buffers[sound] else { return }
        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        voice.stop()
        voice.scheduleBuffer(buffer, at: nil)
        voice.play()
    }

    func startLoop(_ sound: Sound) {
        guard !isMuted, ready(), let buffer = buffers[sound], let voice = loopVoices[sound] else { return }
        voice.stop()
        voice.scheduleBuffer(buffer, at: nil, options: .loops)
        voice.play()
    }

    func stopLoop(_ sound: Sound) {
        loopVoices[sound]?.stop()
    }

    func stopAllLoops() {
        Sound.loops.forEach(stopLoop)
    }
}
