//
//  Characters.swift
//  skate
//
//  Who skates and what they wear. The skater builder edits an `Outfit`;
//  the art in CharacterArt.swift draws it.
//

import Foundation

nonisolated enum SkaterKind: String, CaseIterable, Codable, Sendable {
    case terry, sam, angie

    var name: String { rawValue.uppercased() }

    /// Angie is a dog: she wears a bandana instead of a shirt, and no pants.
    var isDog: Bool { self == .angie }
    var wearsPants: Bool { !isDog }
}

/// The colors you can pick for clothes, hats and boards.
nonisolated enum ColorChoice: String, CaseIterable, Codable, Sendable {
    case black, white, grey, red, orange, yellow, green, teal, blue, navy, purple, pink, khaki, brown
    /// The PDX airport carpet: teal with little bits of color. Boards only, and only once
    /// you've spelled PORTLAND.
    case pdx

    var name: String { self == .pdx ? "PDX CARPET" : rawValue.uppercased() }

    /// The colors for shirts, pants and hats.
    static var clothes: [ColorChoice] { allCases.filter { $0 != .pdx } }

    /// The boards you can pick: the reward board joins the list once it's won.
    static func boards(pdxUnlocked: Bool) -> [ColorChoice] { pdxUnlocked ? clothes + [.pdx] : clothes }

    var hex: UInt32 {
        switch self {
        case .black: 0x1C1C1C
        case .white: 0xF0F0F0
        case .grey: 0x8C8C8C
        case .red: 0xD82800
        case .orange: 0xF87800
        case .yellow: 0xF8B800
        case .green: 0x00A844
        case .teal: 0x00A8A8
        case .blue: 0x0058F8
        case .navy: 0x24308C
        case .purple: 0x8C38C8
        case .pink: 0xF878B8
        case .khaki: 0xC8A870
        case .brown: 0x7C3C00
        case .pdx: 0x1C7470
        }
    }

    /// Light colors get dark trim and prints, dark ones light.
    var isLight: Bool {
        let r = (hex >> 16) & 0xFF, g = (hex >> 8) & 0xFF, b = hex & 0xFF
        return (r * 30 + g * 59 + b * 11) / 100 > 140
    }
}

nonisolated struct Outfit: Codable, Equatable, Sendable {
    var kind: SkaterKind = .terry
    var shirt: ColorChoice = .black
    var pants: ColorChoice = .khaki
    /// Nil for no hat.
    var hat: ColorChoice? = .yellow
    var board: ColorChoice = .brown

    static let standard = Outfit()

    /// The next choice in a list, wrapping around. `step` is +1 or -1.
    static func cycle<T: Equatable>(_ value: T, in all: [T], step: Int) -> T {
        guard let index = all.firstIndex(of: value) else { return all.first ?? value }
        return all[(index + step + all.count) % all.count]
    }

    /// Hats include "no hat" at the end of the list.
    static var hatChoices: [ColorChoice?] { ColorChoice.clothes.map { Optional($0) } + [nil] }
}
