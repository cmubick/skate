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
}

/// Builds each sound as 16-bit mono WAV data.
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
        }
    }

    /// Wraps samples in a WAV file header.
    static func wav(for sound: Sound) -> Data {
        let pcm = samples(for: sound).map { Int16(max(-1, min(1, $0)) * 32_000) }
        let byteCount = pcm.count * 2
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + byteCount))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        append(UInt32(16))                    // size of the format block
        append(UInt16(1))                     // PCM
        append(UInt16(1))                     // mono
        append(UInt32(sampleRate))
        append(UInt32(sampleRate) * 2)        // bytes per second
        append(UInt16(2))                     // bytes per sample
        append(UInt16(16))                    // bits per sample
        data.append(contentsOf: Array("data".utf8))
        append(UInt32(byteCount))
        for sample in pcm { append(sample) }
        return data
    }
}

/// Plays the sound effects. Muting is remembered between launches.
final class Sounds {
    static let shared = Sounds()
    private static let mutedKey = "soundMuted"

    private var players: [Sound: AVAudioPlayer] = [:]

    var isMuted: Bool {
        didSet {
            UserDefaults.standard.set(isMuted, forKey: Sounds.mutedKey)
            if isMuted { stopLoop(.grind) }
        }
    }

    private init() {
        isMuted = UserDefaults.standard.bool(forKey: Sounds.mutedKey)
        // Ambient: the silent switch mutes the game, and the player's own music keeps playing.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        for sound in Sound.allCases {
            guard let player = try? AVAudioPlayer(data: SoundSynth.wav(for: sound)) else { continue }
            player.volume = 0.7
            player.prepareToPlay()
            players[sound] = player
        }
    }

    func play(_ sound: Sound) {
        guard !isMuted, let player = players[sound] else { return }
        player.numberOfLoops = 0
        player.currentTime = 0
        player.play()
    }

    func startLoop(_ sound: Sound) {
        guard !isMuted, let player = players[sound] else { return }
        player.numberOfLoops = -1
        player.currentTime = 0
        player.play()
    }

    func stopLoop(_ sound: Sound) {
        players[sound]?.stop()
    }
}
