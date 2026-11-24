//
//  Chiptune.swift
//  skate
//
//  The music: a little NES-style sound chip and a sequencer, so every song is
//  written as text in code and rendered when it's needed. No audio files.
//
//  Four voices, like the NES:
//  - lead: a narrow pulse wave, with vibrato on long notes
//  - rhythm: power chords on pulse waves, clipped hard for a punk crunch,
//    palm-muted (short) or left ringing
//  - bass: the stepped NES triangle
//  - drums: noise and a falling triangle for the kick
//
//  Songs are written a bar at a time. Pitched parts use one token per eighth note
//  (`E4`, `C#5`; a `*` makes it a power chord: root, fifth and octave), `-` holds
//  the note before, `.` is silence. Drum parts use one token per sixteenth:
//  `k` kick, `s` snare, `h` hi-hat, `o` open hat, `c` crash (with a kick), `.` rest.
//  No SpriteKit or audio APIs in here, so it renders the same anywhere.
//

import Foundation

nonisolated enum Chiptune {
    static let sampleRate = 32_000.0

    struct Section: Sendable {
        var lead: [String] = []
        var rhythm: [String] = []
        var bass: [String] = []
        var drums: [String] = []
        /// Short, choked power chords (verses) instead of ringing ones (choruses).
        var palmMuted = false
        /// How many times the section plays in a row.
        var repeats = 1
    }

    struct Song: Sendable {
        var name: String
        var bpm: Double
        var sections: [Section]
    }

    // MARK: Reading the notes

    private struct Note {
        var step: Int
        var length: Int
        var frequencies: [Double]
    }

    private static let names: [String: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]

    static func frequency(_ name: String) -> Double? {
        var text = Substring(name)
        guard let letter = text.first, let base = names[String(letter)] else { return nil }
        text = text.dropFirst()
        var semitone = base
        if text.first == "#" { semitone += 1; text = text.dropFirst() }
        if text.first == "b" { semitone -= 1; text = text.dropFirst() }
        guard let octave = Int(text) else { return nil }
        let midi = 12 * (octave + 1) + semitone
        return 440 * pow(2, Double(midi - 69) / 12)
    }

    /// Pitched tokens (one per eighth note) into notes, in sixteenths.
    private static func notes(_ bars: [String], from start: Int) -> [Note] {
        var notes: [Note] = []
        var step = start
        for token in bars.joined(separator: " ").split(separator: " ").map(String.init) {
            defer { step += 2 }
            switch token {
            case "-": if !notes.isEmpty { notes[notes.count - 1].length += 2 }
            case ".": break
            default:
                let chord = token.hasSuffix("*")
                guard let root = frequency(chord ? String(token.dropLast()) : token) else { continue }
                notes.append(Note(step: step, length: 2, frequencies: chord ? [root, root * 1.4983, root * 2] : [root]))
            }
        }
        return notes
    }

    // MARK: Rendering

    /// The song's intro (its first section), played once.
    static func renderIntro(_ song: Song) -> [Float] {
        render(Song(name: song.name, bpm: song.bpm, sections: Array(song.sections.prefix(1))))
    }

    /// The rest of the song, which loops.
    static func renderLoop(_ song: Song) -> [Float] {
        render(Song(name: song.name, bpm: song.bpm, sections: Array(song.sections.dropFirst())))
    }

    /// Anything wrong with how a song is written: a bar with the wrong number of
    /// tokens, a note that doesn't read, or parts of different lengths.
    static func problems(in song: Song) -> [String] {
        var problems: [String] = []
        for (number, section) in song.sections.enumerated() {
            let parts = [("lead", section.lead, 8), ("rhythm", section.rhythm, 8), ("bass", section.bass, 8), ("drums", section.drums, 16)]
            let lengths = Set(parts.map(\.1.count).filter { $0 > 0 })
            if lengths.count > 1 { problems.append("\(song.name) section \(number): parts have \(lengths.sorted()) bars") }
            for (part, bars, perBar) in parts {
                for (bar, text) in bars.enumerated() {
                    let tokens = text.split(separator: " ").map(String.init)
                    if tokens.count != perBar {
                        problems.append("\(song.name) section \(number) \(part) bar \(bar + 1): \(tokens.count) tokens, not \(perBar)")
                    }
                    for token in tokens where !["-", "."].contains(token) {
                        if part == "drums" {
                            if !token.allSatisfy({ "kshoc".contains($0) }) { problems.append("\(song.name): unknown drum \(token)") }
                        } else if frequency(token.hasSuffix("*") ? String(token.dropLast()) : token) == nil {
                            problems.append("\(song.name): unknown note \(token)")
                        }
                    }
                }
            }
        }
        return problems
    }

    /// The whole song once through, as samples from -1 to 1.
    static func render(_ song: Song) -> [Float] {
        let stepSeconds = 60 / song.bpm / 4
        let stepSamples = stepSeconds * sampleRate
        var lead: [Note] = [], bass: [Note] = []
        var rhythm: [(Note, Bool)] = []
        var drums: [(step: Int, hit: Character)] = []
        var step = 0
        for section in song.sections {
            for _ in 0..<section.repeats {
                let bars = max(section.lead.count, section.rhythm.count, section.bass.count, section.drums.count)
                lead += notes(section.lead, from: step)
                bass += notes(section.bass, from: step)
                rhythm += notes(section.rhythm, from: step).map { ($0, section.palmMuted) }
                var drumStep = step
                for token in section.drums.joined(separator: " ").split(separator: " ") {
                    for hit in token where hit != "." { drums.append((drumStep, hit)) }
                    drumStep += 1
                }
                step += bars * 16
            }
        }
        let total = Int(Double(step) * stepSamples)
        var mix = [Float](repeating: 0, count: total)
        var crunch = [Float](repeating: 0, count: total)

        func samples(of note: Note) -> Range<Int> {
            let start = Int(Double(note.step) * stepSamples)
            let end = min(total, Int(Double(note.step + note.length) * stepSamples))
            return start..<max(start, end)
        }

        // Lead: 25% pulse, a little punch at the start, vibrato once a note is held.
        for note in lead {
            let range = samples(of: note)
            var phase = 0.0
            for index in range {
                let t = Double(index - range.lowerBound) / sampleRate
                let left = Double(range.upperBound - index) / sampleRate
                let vibrato = t > 0.16 ? 1 + 0.006 * sin(2 * .pi * 6 * t) : 1
                phase += note.frequencies[0] * vibrato / sampleRate
                let wave: Double = phase.truncatingRemainder(dividingBy: 1) < 0.25 ? 1 : -1
                let level = (t < 0.03 ? 1 : 0.75 + 0.25 * exp(-(t - 0.03) / 0.1)) * min(1, left / 0.01)
                mix[index] += Float(wave * level * 0.15)
            }
        }

        // Rhythm: power chords on 50% pulses, summed then clipped for the crunch.
        for (note, muted) in rhythm {
            let range = samples(of: note)
            var phases = [Double](repeating: 0, count: note.frequencies.count)
            for index in range {
                let t = Double(index - range.lowerBound) / sampleRate
                let left = Double(range.upperBound - index) / sampleRate
                var sum = 0.0
                for (voice, frequency) in note.frequencies.enumerated() {
                    // A hair out of tune with each other, like two guitars.
                    phases[voice] += frequency * (1 + Double(voice) * 0.0015) / sampleRate
                    sum += phases[voice].truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : -1
                }
                let level = (muted ? exp(-t / 0.07) : 0.55 + 0.45 * exp(-t / 0.25)) * min(1, left / 0.008)
                crunch[index] += Float(sum * level)
            }
        }
        for index in 0..<total { mix[index] += tanhf(crunch[index] * 0.9) * 0.16 }

        // Bass: the NES triangle, 16 steps a cycle.
        for note in bass {
            let range = samples(of: note)
            var phase = 0.0
            for index in range {
                let left = Double(range.upperBound - index) / sampleRate
                phase += note.frequencies[0] / sampleRate
                let p = phase.truncatingRemainder(dividingBy: 1)
                let smooth = p < 0.5 ? 4 * p - 1 : 3 - 4 * p
                let stepped = (smooth * 7.5).rounded() / 7.5
                mix[index] += Float(stepped * 0.3 * min(1, left / 0.006))
            }
        }

        // Drums: a 15-bit noise register like the NES's, and a falling triangle kick.
        var lfsr: UInt16 = 1
        func noise(short: Bool) -> Double {
            let tap: UInt16 = short ? 6 : 1
            let bit = (lfsr ^ (lfsr >> tap)) & 1
            lfsr = (lfsr >> 1) | (bit << 14)
            return lfsr & 1 == 0 ? 1 : -1
        }
        func kick(at start: Int) {
            var phase = 0.0
            for index in start..<min(total, start + Int(0.16 * sampleRate)) {
                let t = Double(index - start) / sampleRate
                phase += (45 + 110 * exp(-t / 0.025)) / sampleRate
                let p = phase.truncatingRemainder(dividingBy: 1)
                mix[index] += Float((p < 0.5 ? 4 * p - 1 : 3 - 4 * p) * 0.5 * exp(-t / 0.07))
            }
        }
        func crash(at start: Int) {
            var held = 0.0
            for index in start..<min(total, start + Int(0.9 * sampleRate)) {
                let t = Double(index - start) / sampleRate
                if index % 2 == 0 { held = noise(short: false) }
                mix[index] += Float(held * 0.13 * exp(-t / 0.3))
            }
        }
        func snare(at start: Int) {
            var held = 0.0, phase = 0.0
            for index in start..<min(total, start + Int(0.2 * sampleRate)) {
                let t = Double(index - start) / sampleRate
                if index % 3 == 0 { held = noise(short: false) }
                phase += 185 / sampleRate
                let p = phase.truncatingRemainder(dividingBy: 1)
                let body = (p < 0.5 ? 4 * p - 1 : 3 - 4 * p) * exp(-t / 0.03)
                mix[index] += Float(held * 0.3 * exp(-t / 0.07) + body * 0.15)
            }
        }
        func hat(at start: Int, open: Bool) {
            let length = open ? 0.14 : 0.035
            for index in start..<min(total, start + Int(length * sampleRate)) {
                let t = Double(index - start) / sampleRate
                mix[index] += Float(noise(short: true) * 0.07 * exp(-t / (length / 3)))
            }
        }
        for (hitStep, hit) in drums {
            let start = Int(Double(hitStep) * stepSamples)
            switch hit {
            case "k": kick(at: start)
            case "c": kick(at: start); crash(at: start)
            case "s": snare(at: start)
            case "h": hat(at: start, open: false)
            case "o": hat(at: start, open: true)
            default: break
            }
        }

        // Keep it under full scale without squashing it.
        return mix.map { tanhf($0 * 1.1) * 0.92 }
    }

    /// 16-bit mono WAV data.
    static func wav(_ samples: [Float]) -> Data {
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        let bytes = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + bytes))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(sampleRate)); append(UInt32(sampleRate * 2)); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(bytes)
        for sample in samples { append(Int16(max(-1, min(1, sample)) * 32_000)) }
        return data
    }
}
