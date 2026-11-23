//
//  Haptics.swift
//  skate
//
//  A tap on every pop, a snap on every landing, a buzz along every grind and a
//  thud on every bail.
//

import CoreHaptics
import UIKit

enum Haptics {
    private static let selection = UISelectionFeedbackGenerator()
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notification = UINotificationFeedbackGenerator()

    /// Call when a run starts, so the first taps aren't late.
    static func prepare() {
        light.prepare()
        rigid.prepare()
        heavy.prepare()
        GrindRumble.shared.prepare()
    }

    /// The board popping off the ground.
    static func pop(charged: Bool) {
        light.impactOccurred(intensity: charged ? 1 : 0.7)
    }

    /// Switching lanes or grind type.
    static func tick() {
        selection.selectionChanged()
    }

    /// Wheels back on the ground. A perfect landing hits harder.
    static func land(perfect: Bool) {
        rigid.impactOccurred(intensity: perfect ? 1 : 0.75)
        if perfect {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(70))
                rigid.impactOccurred(intensity: 0.6)
            }
        }
    }

    static func bail() {
        heavy.impactOccurred(intensity: 1)
        notification.notificationOccurred(.error)
    }

    static func finish() {
        notification.notificationOccurred(.success)
    }

    static func startGrind() {
        rigid.impactOccurred(intensity: 0.6)
        GrindRumble.shared.start()
    }

    static func stopGrind() {
        GrindRumble.shared.stop()
    }
}

/// A steady buzz for as long as you're on a rail, using Core Haptics. Does nothing
/// on devices without haptics (and in the simulator).
final class GrindRumble {
    static let shared = GrindRumble()

    private var engine: CHHapticEngine?
    private var player: CHHapticAdvancedPatternPlayer?
    private var isRunning = false

    private init() {}

    func prepare() {
        guard engine == nil, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = true
            // If the system stops or resets the engine (the app going to the background,
            // say), the old player is gone: forget it so the next grind makes a fresh one.
            engine.stoppedHandler = { [weak self] _ in
                Task { @MainActor in
                    self?.player = nil
                    self?.isRunning = false
                }
            }
            engine.resetHandler = { [weak self] in
                Task { @MainActor in
                    self?.player = nil
                    self?.isRunning = false
                    try? self?.engine?.start()
                }
            }
            try engine.start()
            self.engine = engine
        } catch {
            engine = nil
        }
    }

    func start() {
        prepare()
        guard let engine, !isRunning else { return }
        do {
            if player == nil {
                let buzz = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25),
                ], relativeTime: 0, duration: 30)
                player = try engine.makeAdvancedPlayer(with: CHHapticPattern(events: [buzz], parameters: []))
                player?.loopEnabled = true
            }
            try engine.start()
            try player?.start(atTime: CHHapticTimeImmediate)
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    /// Safe to call any time, even when nothing is playing.
    func stop() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        isRunning = false
    }
}
