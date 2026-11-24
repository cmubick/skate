// Renders the songs in skate/UI/Songs.swift to WAV files, to listen to outside the game.
//
//   swiftc -O skate/UI/Chiptune.swift skate/UI/Songs.swift tools/music/main.swift -o build/render-music
//   build/render-music <output folder>

import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
// Each song as the game plays it: the intro once, then the loop twice.
for song in Songs.all {
    for problem in Chiptune.problems(in: song) { print("PROBLEM: \(problem)") }
    let loop = Chiptune.renderLoop(song)
    let samples = Chiptune.renderIntro(song) + loop + loop
    let url = output.appendingPathComponent("\(song.name).wav")
    try Chiptune.wav(samples).write(to: url)
    print("\(song.name): \(String(format: "%.1f", Double(samples.count) / Chiptune.sampleRate)) s -> \(url.path)")
}
