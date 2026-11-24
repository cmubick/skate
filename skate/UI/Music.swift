//
//  Music.swift
//  skate
//
//  Plays each spot's song (see Songs.swift): the intro once, then the rest on a
//  loop. A song is rendered the first time it's needed, off the main thread, and
//  kept for next time. Quieter while a menu is up. Silent when the player turns
//  music off (remembered between launches), or has their own music going.
//

import AVFoundation

final class Music {
    static let shared = Music()

    /// Under the sound effects, which play at 0.7.
    static let volume: Float = 0.45
    static let duckedVolume: Float = 0.18

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: Chiptune.sampleRate, channels: 1)!
    private var rendered: [String: (intro: AVAudioPCMBuffer, loop: AVAudioPCMBuffer)] = [:]
    private var rendering: Set<String> = []
    /// The song that should be playing, if any.
    private var wanted: Chiptune.Song?
    private var isDucked = false

    private static let offKey = "musicOff"

    /// The player's music setting. Separate from the sound effects.
    var isOn: Bool = !UserDefaults.standard.bool(forKey: Music.offKey) {
        didSet {
            UserDefaults.standard.set(!isOn, forKey: Self.offKey)
            if !isOn {
                if isSetUp { player.stop() }
            } else if let wanted {
                // Pick the song up again, at the volume it should be.
                if let buffers = rendered[wanted.name] { start(buffers) } else { render(wanted) }
            }
        }
    }

    private init() {}

    /// Audio is only set up once a song first plays, so reading or changing the
    /// setting (on the title screen, say) never waits on the audio hardware.
    private var isSetUp = false
    private func setUpAudio() {
        guard !isSetUp else { return }
        isSetUp = true
        Sounds.shared.prepare() // sets up the audio session
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    /// Each spot's song. The tutorial street is Downtown's.
    static func song(for level: Level) -> Chiptune.Song? {
        switch level.id {
        case "downtown", "tutorial": Songs.downtown
        case "skidmore": Songs.skidmore
        case "burnside": Songs.burnside
        case "northportland": Songs.northPortland
        case "waterfront": Songs.waterfront
        case "zoobomb": Songs.zooBomb
        default: nil
        }
    }

    /// Starts a song from its intro. It begins as soon as it's rendered.
    func play(_ song: Chiptune.Song) {
        wanted = song
        isDucked = false
        if isSetUp { player.stop() }
        guard canPlay else { return }
        if let buffers = rendered[song.name] {
            start(buffers)
        } else {
            render(song)
        }
    }

    /// Renders a song ahead of time, so it starts straight away when played.
    func prepare(_ song: Chiptune.Song) {
        if rendered[song.name] == nil { render(song) }
    }

    func stop() {
        wanted = nil
        if isSetUp { player.stop() }
    }

    /// Quieter under a menu; back up after. Picks the song up again if something
    /// (a phone call, going to the background) stopped it.
    func setDucked(_ ducked: Bool) {
        isDucked = ducked
        player.volume = ducked ? Self.duckedVolume : Self.volume
        if !ducked, isSetUp, let wanted, !player.isPlaying, canPlay, let buffers = rendered[wanted.name] { start(buffers) }
    }

    private var canPlay: Bool {
        isOn && !AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
    }

    private func render(_ song: Chiptune.Song) {
        guard !rendering.contains(song.name) else { return }
        rendering.insert(song.name)
        Task.detached(priority: .userInitiated) {
            let intro = Chiptune.renderIntro(song)
            let loop = Chiptune.renderLoop(song)
            await MainActor.run {
                self.rendering.remove(song.name)
                guard let introBuffer = self.buffer(intro), let loopBuffer = self.buffer(loop) else { return }
                self.rendered[song.name] = (introBuffer, loopBuffer)
                if self.wanted?.name == song.name, self.canPlay { self.start((introBuffer, loopBuffer)) }
            }
        }
    }

    private func buffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        return buffer
    }

    private func start(_ buffers: (intro: AVAudioPCMBuffer, loop: AVAudioPCMBuffer)) {
        setUpAudio()
        player.stop()
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        player.scheduleBuffer(buffers.intro, at: nil)
        player.scheduleBuffer(buffers.loop, at: nil, options: .loops)
        player.volume = isDucked ? Self.duckedVolume : Self.volume
        player.play()
    }
}
