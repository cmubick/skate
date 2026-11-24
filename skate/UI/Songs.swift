//
//  Songs.swift
//  skate
//
//  The soundtrack, one song per spot, written for `Chiptune`. Portland's songs
//  are 90s skate punk played on an NES: fast, palm-muted verses, big open
//  choruses, a snotty lead. All original.
//
//  Pitched parts: one token per eighth note, 8 a bar. Drums: one per sixteenth, 16 a bar.
//  The first section of each song is its intro, played once; the rest loops.
//

import Foundation

nonisolated enum Songs {
    /// Eight eighth notes of the same power chord.
    private static func chug(_ chord: String) -> String {
        Array(repeating: chord, count: 8).joined(separator: " ")
    }

    // MARK: Downtown: bright, bouncy skate punk in E

    static let downtown: Chiptune.Song = {
        let beat = "k h s h k h s h k h s h k k s h"
        let fill = "k h s h k h s h s s s s s s s s"
        let intro = Chiptune.Section(
            rhythm: [". . . . . . . .", "E3* - - - - - - -"],
            bass: [". . . . . . . .", "E3 - - - - - - -"],
            drums: ["s . s . s . s . s s s s s s s s", "c . . . . . . . s . s . s s s s"])
        let verse = Chiptune.Section(
            lead: [
                "B4 - G#4 - E4 - G#4 B4",
                "D#5 - C#5 B4 - - A4 B4",
                "C#5 - B4 - G#4 - E4 -",
                "F#4 - E4 - C#4 - . .",
                "B4 - G#4 - E4 - G#4 B4",
                "D#5 - E5 - F#5 - D#5 -",
                "E5 - D#5 - C#5 - B4 -",
                "C#5 - - - B4 - . .",
            ],
            rhythm: ["E3*", "B2*", "C#3*", "A2*", "E3*", "B2*", "C#3*", "A2*"].map(chug),
            bass: ["E3", "B2", "C#3", "A2", "E3", "B2", "C#3"].map(chug) + ["A2 A2 A2 A2 B2 B2 B2 B2"],
            drums: Array(repeating: beat, count: 7) + [fill],
            palmMuted: true)
        let open = "A2* - A2* - A2* A2* A2* -"
        let chorus = Chiptune.Section(
            lead: [
                "E5 E5 - C#5 E5 - F#5 -",
                "F#5 F#5 - D#5 F#5 - G#5 -",
                "G#5 - F#5 - E5 - C#5 -",
                "D#5 - - - F#5 - - -",
                "E5 E5 - C#5 E5 - F#5 -",
                "F#5 F#5 - D#5 F#5 - B5 -",
                "G#5 - - - E5 - - -",
                "- - - - . . . .",
            ],
            rhythm: [open, open.replacingOccurrences(of: "A2", with: "B2"), open.replacingOccurrences(of: "A2", with: "C#3"),
                     open.replacingOccurrences(of: "A2", with: "B2"), open, open.replacingOccurrences(of: "A2", with: "B2"),
                     "E3* - E3* - E3* E3* E3* -", "E3* - - - B2* - - -"],
            bass: ["A2", "B2", "C#3", "B2", "A2", "B2", "E3"].map(chug) + ["E3 E3 E3 E3 B2 B2 B2 B2"],
            drums: ["c h s h k h s h k h s h k h s h"] + Array(repeating: "k h s h k h s h k k s h k h s o", count: 6)
                + ["k h s h k h s h s . s . s s s s"])
        return Chiptune.Song(name: "Downtown", bpm: 184, sections: [intro, verse, chorus])
    }()

    // MARK: Burnside: faster, darker, under the bridge, in E minor

    static let burnside: Chiptune.Song = {
        let stomp = "k h h h s h h h k h k h s h h h"
        let polka = "k h s h k h s h k h s h k h s h"
        let intro = Chiptune.Section(
            rhythm: ["E3* E3* . E3* E3* . E3* E3*", "E3* E3* . E3* G3* - A3* -"],
            bass: [". . . . . . . .", "E3 E3 . E3 G3 - A3 -"],
            drums: [". . . . . . . . . . . . s s s s", "c . . . k . . . k . k . s s s s"],
            palmMuted: true)
        let riff1 = "E3* E3* . E3* G3* - A3* -"
        let riff2 = "E3* E3* . E3* A#3* - A3* -"
        let riff3 = "C3* C3* . C3* C3* - D3* -"
        let riff4 = "D3* D3* . D3* D3* . D3* D3*"
        let bassOf = { (riff: String) in riff.replacingOccurrences(of: "*", with: "") }
        let verse = Chiptune.Section(
            lead: [
                ". . . . . . . .", ". . . . . . B4 -",
                ". . . . . . . .", "D5 E5 F#5 G5 F#5 E5 D5 B4",
                ". . . . . . . .", ". . . . . . B4 -",
                ". . . . . . . .", "G5 F#5 E5 D5 E5 - B4 -",
            ],
            rhythm: [riff1, riff2, riff3, riff4, riff1, riff2, riff3, riff4],
            bass: [riff1, riff2, riff3, riff4, riff1, riff2, riff3, riff4].map(bassOf),
            drums: Array(repeating: stomp, count: 7) + ["k h s h k h s h s s s s k . k ."],
            palmMuted: true)
        let strum = { (chord: String) in "\(chord) - \(chord) - \(chord) - \(chord) -" }
        let chorus = Chiptune.Section(
            lead: [
                "B4 - D5 - G5 - - -",
                "F#5 - E5 - D5 - A4 -",
                "B4 - E5 - G5 - E5 -",
                "G5 - - - E5 - - -",
                "B4 - D5 - G5 - - -",
                "A5 - G5 - F#5 - D5 -",
                "E5 - - - B4 - E5 -",
                "E5 - - - - - . .",
            ],
            rhythm: ["G3*", "D3*", "E3*", "C3*", "G3*", "D3*", "E3*", "C3*"].map(strum),
            bass: ["G2", "D3", "E3", "C3", "G2", "D3", "E3", "C3"].map(chug),
            drums: ["c h s h k h s h k h s h k h s h"] + Array(repeating: polka, count: 6) + ["s s s s s s s s c . . . s s s s"])
        return Chiptune.Song(name: "Burnside", bpm: 200, sections: [intro, verse, chorus])
    }()

    // MARK: Skidmore Fountain: ska-punk, upstrokes in the verse, punk in the chorus

    static let skidmore: Chiptune.Song = {
        let ska = "k . h . s . h . k . h . s . h ."
        let skank = { (chord: String) in ". \(chord) . \(chord) . \(chord) . \(chord)" }
        let walk = { (a: String, b: String, c: String) in "\(a) - \(b) - \(c) - \(b) -" }
        let intro = Chiptune.Section(
            rhythm: [skank("A3*"), ". E4* . E4* . E4* E4* E4*"],
            bass: [walk("A2", "C#3", "E3"), "E3 - E3 - B2 - B2 -"],
            drums: [ska, "k . h . s . h . s s s s s . s ."],
            palmMuted: true)
        let verse = Chiptune.Section(
            lead: [
                "E5 - C#5 - E5 - F#5 E5",
                "D5 - - - F#5 - - -",
                "E5 - B4 - G#4 - B4 -",
                "A4 - - - . . . .",
                "E5 - C#5 - E5 - F#5 E5",
                "F#5 - A5 - F#5 - D5 -",
                "E5 - D5 - C#5 - B4 -",
                "A4 - - - - - . .",
            ],
            rhythm: ["A3*", "D4*", "E4*", "D4*", "A3*", "D4*", "E4*", "E4*"].map(skank),
            bass: [walk("A2", "C#3", "E3"), walk("D3", "F#3", "A3"), walk("E3", "G#3", "B3"), walk("D3", "F#3", "A3"),
                   walk("A2", "C#3", "E3"), walk("D3", "F#3", "A3"), walk("E3", "G#3", "B3"), "E3 - E3 - E3 E3 E3 E3"],
            drums: Array(repeating: ska, count: 7) + ["k . h . s . h . s s s s s s s s"],
            palmMuted: true)
        let strum = { (chord: String) in "\(chord) - \(chord) \(chord) - \(chord) \(chord) -" }
        let chorus = Chiptune.Section(
            lead: [
                "A5 - - - E5 - C#5 -",
                "B4 - C#5 - E5 - - -",
                "F#5 - E5 - C#5 - A4 -",
                "A4 - B4 - C#5 - D5 -",
                "A5 - - - E5 - C#5 -",
                "B4 - C#5 - E5 - G#5 -",
                "A5 - G#5 - F#5 - E5 -",
                "D5 - - - C#5 - - -",
            ],
            rhythm: ["A2*", "E3*", "F#3*", "D3*", "A2*", "E3*", "F#3*", "D3*"].map(strum),
            bass: ["A2", "E3", "F#3", "D3", "A2", "E3", "F#3", "D3"].map(chug),
            drums: ["c h s h k h s h k h s h k h s h"] + Array(repeating: "k h s h k h s h k h s h k h s h", count: 6)
                + ["k h s h k h s h s s s s s s s s"])
        return Chiptune.Song(name: "Skidmore", bpm: 152, sections: [intro, verse, chorus])
    }()

    // MARK: North Portland: a pop-punk anthem in D

    static let northPortland: Chiptune.Song = {
        let beat = "k h s h k h s h k h s h k k s h"
        let intro = Chiptune.Section(
            rhythm: ["D3* - - D3* - - D3* -", "A2* - - A2* - - A2* A2*"],
            bass: ["D3 - - D3 - - D3 -", "A2 - - A2 - - A2 A2"],
            drums: ["c . . . . . s . . . s . . . . .", "k . . . . . s . . . s . s s s s"])
        let verse = Chiptune.Section(
            lead: [
                "F#4 - F#4 - A4 - F#4 -",
                "E4 - E4 - A4 - E4 -",
                "D4 - F#4 - B4 - A4 -",
                "G4 - - - . . . .",
                "F#4 - F#4 - A4 - F#4 -",
                "E4 - A4 - C#5 - A4 -",
                "B4 - A4 - F#4 - D4 -",
                "E4 - - - F#4 G4 A4 -",
            ],
            rhythm: ["D3*", "A2*", "B2*", "G2*", "D3*", "A2*", "B2*", "G2*"].map(chug),
            bass: ["D3", "A2", "B2", "G2", "D3", "A2", "B2", "G2"].map(chug),
            drums: Array(repeating: beat, count: 7) + ["k h s h k h s h s s s s s s s s"],
            palmMuted: true)
        let anthem = { (chord: String) in "\(chord) - - \(chord) - - \(chord) -" }
        let chorus = Chiptune.Section(
            lead: [
                "B4 - D5 - D5 - B4 -",
                "A4 - D5 - F#5 - - -",
                "E5 - - - C#5 - A4 -",
                "B4 - D5 - F#5 - E5 -",
                "D5 - B4 - D5 - G5 -",
                "F#5 - - - D5 - A4 -",
                "E5 - - - - - C#5 -",
                "D5 - - - - - . .",
            ],
            rhythm: ["G2*", "D3*", "A2*", "B2*", "G2*", "D3*", "A2*", "A2*"].map(anthem),
            bass: ["G2", "D3", "A2", "B2", "G2", "D3", "A2", "A2"].map(anthem),
            drums: ["c h s h k k s h k h s h k k s o"] + Array(repeating: "k h s h k k s h k h s h k k s o", count: 6)
                + ["k h s h k h s h s . s . s s s s"])
        return Chiptune.Song(name: "North Portland", bpm: 168, sections: [intro, verse, chorus])
    }()

    // MARK: SE Waterfront: slow and melodic, arpeggios by the river

    static let waterfront: Chiptune.Song = {
        let easy = "k . h . s . h . k . h . s . h ."
        let arp = { (a: String, b: String, c: String) in "\(a) \(b) \(c) \(b) \(a) \(b) \(c) \(b)" }
        let pulse = { (chord: String) in "\(chord) . \(chord) . \(chord) . \(chord) ." }
        let intro = Chiptune.Section(
            lead: [arp("G4", "B4", "D5"), arp("D4", "F#4", "A4")],
            bass: ["G2 - - - - - - -", "D3 - - - - - - -"],
            drums: ["k . . . . . . . k . . . . . . .", "k . . . s . . . k . . . s . s s"])
        let verse = Chiptune.Section(
            lead: [arp("G4", "B4", "D5"), arp("E4", "G4", "B4"), arp("C4", "E4", "G4"), arp("D4", "F#4", "A4"),
                   arp("G4", "B4", "D5"), arp("E4", "G4", "B4"), arp("C4", "E4", "G4"), "D4 F#4 A4 D5 C5 B4 A4 F#4"],
            rhythm: ["G3*", "E3*", "C3*", "D3*", "G3*", "E3*", "C3*", "D3*"].map(pulse),
            bass: ["G2 - G2 - G2 - D3 -", "E3 - E3 - E3 - B2 -", "C3 - C3 - C3 - G2 -", "D3 - D3 - D3 - A2 -",
                   "G2 - G2 - G2 - D3 -", "E3 - E3 - E3 - B2 -", "C3 - C3 - C3 - G2 -", "D3 - D3 - D3 D3 D3 D3"],
            drums: Array(repeating: easy, count: 7) + ["k . h . s . h . s . s . s s s s"],
            palmMuted: true)
        let ring = { (chord: String) in "\(chord) - \(chord) - \(chord) - \(chord) -" }
        let chorus = Chiptune.Section(
            lead: [
                "E5 - - - G5 - - -",
                "D5 - - - B4 - - -",
                "A4 - B4 - D5 - - -",
                "B4 - - - . . . .",
                "E5 - - - G5 - A5 -",
                "B5 - - - A5 - G5 -",
                "F#5 - - - A5 - - -",
                "F#5 - - - E5 - D5 -",
            ],
            rhythm: ["C3*", "G2*", "D3*", "E3*", "C3*", "G2*", "D3*", "D3*"].map(ring),
            bass: ["C3", "G2", "D3", "E3", "C3", "G2", "D3", "D3"].map(chug),
            drums: ["c h s h k h s h k h s h k h s h"] + Array(repeating: "k h s h k h s h k h s h k h s h", count: 6)
                + ["k h s h k h s h s . s . s s s s"])
        return Chiptune.Song(name: "SE Waterfront", bpm: 124, sections: [intro, verse, chorus])
    }()

    // MARK: Zoo Bomb: the fastest, hardcore punk all the way down the hill

    static let zooBomb: Chiptune.Song = {
        let dbeat = "k . s k k . s . k . s k k . s ."
        let intro = Chiptune.Section(
            lead: ["B5 - - - A#5 - - -", "B5 - - - . . . ."],
            rhythm: [". . . . . . . .", "B2* . B2* . B2* B2* B2* B2*"],
            bass: [". . . . . . . .", "B2 . B2 . B2 B2 B2 B2"],
            drums: ["s . . . s . . . s . s . s s s s", "c . . . c . . . s s s s s s s s"])
        let riff1 = "B2* B2* B2* B2* D3* D3* C#3* C#3*"
        let riff2 = "B2* B2* B2* B2* E3* E3* F3* F#3*"
        let bassOf = { (riff: String) in riff.replacingOccurrences(of: "*", with: "") }
        let verse = Chiptune.Section(
            lead: [
                ". . . . . . . .", ". . . . . . . .", ". . . . . . . .", ". . . . . . . .",
                ". . F#5 - . . F#5 -", ". . G5 - . . A5 -", ". . F#5 - . . F#5 -", "B5 - A5 - G5 - F#5 -",
            ],
            rhythm: [riff1, riff2, riff1, riff2, riff1, riff2, riff1, riff2],
            bass: [riff1, riff2, riff1, riff2, riff1, riff2, riff1, riff2].map(bassOf),
            drums: Array(repeating: dbeat, count: 7) + ["s s s s s s s s s s s s s s s s"],
            palmMuted: true)
        let chorus = Chiptune.Section(
            lead: [
                "B5 - - - A5 - - -",
                "C#6 - - - B5 - A5 -",
                "B5 - - - - - - -",
                "F#5 - - - D5 - - -",
                "B5 - - - A5 - - -",
                "C#6 - - - E6 - - -",
                "D6 - C#6 - B5 - A5 -",
                "B5 - - - - - . .",
            ],
            rhythm: ["G3*", "A3*", "B2*", "B2*", "G3*", "A3*", "B2*", "B2*"].map(chug),
            bass: ["G2", "A2", "B2", "B2", "G2", "A2", "B2", "B2"].map(chug),
            drums: ["c h s h k h s h k h s h k h s h"] + Array(repeating: "k h s h k h s h k h s h k h s h", count: 6)
                + ["c . c . s s s s s s s s s s s s"])
        return Chiptune.Song(name: "Zoo Bomb", bpm: 232, sections: [intro, verse, chorus])
    }()

    /// Every song, for the tests and the preview renderer.
    static let all: [Chiptune.Song] = [downtown, skidmore, burnside, northPortland, waterfront, zooBomb]
}
