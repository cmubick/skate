//
//  Cities.swift
//  skate
//
//  The cities and their spots. Portland is the one you can skate; the rest are
//  coming soon. Each spot hides a couple of the city's letters.
//

import CoreGraphics

nonisolated struct City: Equatable, Sendable {
    var id: String
    var name: String
    var isOpen: Bool
    var levels: [Level]

    /// The letters to find: the city's name without spaces.
    var letters: [Character] { name.filter { $0 != " " }.map { $0 } }

    static let portland = City(id: "portland", name: "PORTLAND", isOpen: true, levels: [
        .downtown, .skidmoreFountain, .burnsideSkatepark, .northPortland, .southeastWaterfront, .zooBomb,
    ])

    static let all: [City] = [
        portland,
        City(id: "sanfrancisco", name: "SAN FRANCISCO", isOpen: false, levels: []),
        City(id: "losangeles", name: "LOS ANGELES", isOpen: false, levels: []),
        City(id: "newyork", name: "NEW YORK", isOpen: false, levels: []),
        City(id: "fresno", name: "FRESNO", isOpen: false, levels: []),
        City(id: "sacramento", name: "SACRAMENTO", isOpen: false, levels: []),
        City(id: "austin", name: "AUSTIN", isOpen: false, levels: []),
        City(id: "seattle", name: "SEATTLE", isOpen: false, levels: []),
        City(id: "astoria", name: "ASTORIA", isOpen: false, levels: []),
    ]
}

nonisolated private func letter(_ index: Int, _ lane: Lane, at x: CGFloat, height: CGFloat) -> LetterPickup {
    LetterPickup(index: index, letter: Array("PORTLAND")[index], lane: lane, x: x, height: height)
}

// MARK: - Portland

nonisolated extension Level {
    /// The grey-box street from the feel prototype, now the tutorial spot.
    static let downtown = Level(id: "downtown", name: "DOWNTOWN", theme: .downtown, length: 2960, features: [
        .cone(.middle, at: 240),
        .cone(.front, at: 352),
        .rail(.back, at: 448, length: 80),
        .ledge(.middle, at: 608, length: 56),
        .cone(.front, at: 720),
        // A Benson Bubbler on the sidewalk.
        .bubbler(.back, at: 760),
        .cone(.front, at: 768),
        .rail(.middle, at: 864, length: 104),
        .cone(.back, at: 896),
        .ledge(.back, at: 1056, length: 80),
        .cone(.front, at: 1072),
        // Mill Ends Park, the world's smallest: too small to trip over.
        .millEnds(.middle, at: 1080),
        // A pair of cones close together: needs a charged ollie, or a lane switch.
        .cone(.middle, at: 1216), .cone(.middle, at: 1245),
        .rail(.front, at: 1344, length: 128),
        // Two short rails with a gap: transfer from one to the other.
        .rail(.back, at: 1536, length: 56),
        .bubbler(.front, at: 1600),
        .rail(.back, at: 1624, length: 56),
        .planter(.middle, at: 1760),
        .ledge(.middle, at: 1888, length: 104),
        .cone(.back, at: 1904), .cone(.front, at: 1928),
        .rail(.back, at: 2096, length: 160),
        .cone(.front, at: 2272), .cone(.front, at: 2320),
        .bubbler(.middle, at: 2350),
        .cone(.front, at: 2368),
        .rail(.middle, at: 2448, length: 80),
        .ledge(.middle, at: 2576, length: 80),
        // Cones across every lane: no way round, ollie it.
        .cone(.back, at: 2752), .cone(.middle, at: 2768), .cone(.front, at: 2784),
    ], letters: [
        // P floats over the first rail: grind it to get it.
        letter(0, .back, at: 488, height: 28),
        letter(1, .middle, at: 1310, height: 6),
    ], showsHints: true, gaps: [
        Gap(name: "PIONEER GAP", points: 500, kind: .transfer(.back, from: 1536, to: 1624)),
        Gap(name: "DOUBLE CONE", points: 300, kind: .over(.middle, from: 1216, to: 1245)),
    ], goals: [
        Goal(id: "downtown.score", text: "SCORE 2000", kind: .score(2000)),
        Goal(id: "downtown.letters", text: "FIND 2 LETTERS", kind: .letters),
        Goal(id: "downtown.gap", text: "PIONEER GAP", kind: .gap("PIONEER GAP")),
        Goal(id: "downtown.flip", text: "FLIP A CONE", kind: .clear(.cone, style: 2)),
        Goal(id: "downtown.clean", text: "NO BAILS", kind: .noBails),
    ])

    /// Old Town: light rail trains down the tracks, people on the plaza, and the fountain.
    static let skidmoreFountain = Level(id: "skidmore", name: "SKIDMORE FOUNTAIN", theme: .skidmore, length: 3050, features: [
        .tracks(.middle, at: 200, length: 260),
        .pedestrian(.back, at: 420),
        // Short enough to clear with a held ollie: the FOUNTAIN GAP.
        .fountain(.back, at: 560, length: 56),
        .pedestrian(.front, at: 640),
        // The first train comes down the middle lane: get out of its way.
        .train(.middle, at: 980),
        .tracks(.middle, at: 1240, length: 280),
        .pedestrian(.back, at: 1320),
        .pedestrian(.front, at: 1420),
        .fountain(.back, at: 1600, length: 80),
        .train(.middle, at: 2000),
        .pedestrian(.front, at: 2050),
        .tracks(.middle, at: 2250, length: 320),
        .fountain(.front, at: 2650),
        .pedestrian(.back, at: 2700),
        .pedestrian(.middle, at: 2860),
    ], letters: [
        letter(2, .back, at: 1640, height: 26),
        letter(3, .front, at: 2690, height: 26),
    ], gaps: [
        Gap(name: "FOUNTAIN GAP", points: 600, kind: .over(.back, from: 560, to: 560)),
    ], goals: [
        Goal(id: "skidmore.score", text: "SCORE 3000", kind: .score(3000)),
        Goal(id: "skidmore.letters", text: "FIND 2 LETTERS", kind: .letters),
        Goal(id: "skidmore.gap", text: "FOUNTAIN GAP", kind: .gap("FOUNTAIN GAP")),
        Goal(id: "skidmore.grind", text: "GRIND FOUNTAIN", kind: .grind(.fountain, seconds: 1.5)),
        Goal(id: "skidmore.walker", text: "OLLIE A WALKER", kind: .clear(.pedestrian)),
    ])

    /// Under the bridge: rails, funboxes, holes, and other skaters in the way.
    static let burnsideSkatepark = Level(id: "burnside", name: "BURNSIDE SKATEPARK", theme: .burnside, length: 3000, features: [
        .funbox(.middle, at: 220),
        .skater(.front, at: 300),
        .rail(.back, at: 420, length: 96),
        .hole(.middle, at: 560),
        .funbox(.back, at: 700),
        .rail(.middle, at: 860, length: 120),
        .skater(.back, at: 1000),
        .quarterPipe(.middle, at: 1010),
        .hole(.front, at: 1080),
        .ledge(.front, at: 1250, length: 80),
        .funbox(.middle, at: 1420, length: 72),
        // Two rails with a gap: L hangs over the gap.
        .rail(.back, at: 1560, length: 64), .rail(.back, at: 1660, length: 64),
        .hole(.middle, at: 1800),
        .skater(.middle, at: 1900),
        .quarterPipe(.front, at: 1960),
        .funbox(.front, at: 2100),
        .rail(.middle, at: 2300, length: 140),
        .hole(.back, at: 2350),
        .skater(.front, at: 2500),
        .funbox(.back, at: 2600, length: 72),
        .hole(.middle, at: 2780), .hole(.front, at: 2800),
    ], letters: [
        letter(4, .back, at: 1642, height: 30),
    ], gaps: [
        Gap(name: "BURNSIDE GAP", points: 500, kind: .transfer(.back, from: 1560, to: 1660)),
    ], goals: [
        Goal(id: "burnside.score", text: "SCORE 4000", kind: .score(4000)),
        Goal(id: "burnside.letters", text: "FIND THE LETTER", kind: .letters),
        Goal(id: "burnside.gap", text: "BURNSIDE GAP", kind: .gap("BURNSIDE GAP")),
        Goal(id: "burnside.manholes", text: "3 MANHOLES", kind: .clears(.hole, count: 3)),
        Goal(id: "burnside.360", text: "LAND A 360 FLIP", kind: .land(.threeSixtyFlip)),
    ])

    /// Shopping carts and broken-down cars; curbs and park benches to grind.
    static let northPortland = Level(id: "northportland", name: "NORTH PORTLAND", theme: .northPortland, length: 3100, features: [
        .curb(.back, at: 200, length: 200),
        .cart(.middle, at: 330),
        .bench(.back, at: 520),
        .brokenCar(.front, at: 600),
        .cart(.back, at: 760),
        .bench(.back, at: 1000),
        .cart(.middle, at: 1040),
        .brokenCar(.middle, at: 1250),
        .curb(.front, at: 1300, length: 220),
        .bench(.back, at: 1480, length: 44),
        .cart(.front, at: 1650),
        .cart(.middle, at: 1700),
        .brokenCar(.front, at: 1900),
        .bench(.back, at: 2050),
        .bench(.back, at: 2120),
        .curb(.middle, at: 2300, length: 200),
        .cart(.back, at: 2450),
        .brokenCar(.middle, at: 2600),
        .bench(.front, at: 2750),
        .cart(.back, at: 2850),
        .cart(.middle, at: 2880),
    ], letters: [
        letter(5, .back, at: 1500, height: 24),
    ], gaps: [
        Gap(name: "ST JOHNS GAP", points: 500, kind: .transfer(.back, from: 2050, to: 2120)),
    ], goals: [
        Goal(id: "north.score", text: "SCORE 3000", kind: .score(3000)),
        Goal(id: "north.letters", text: "FIND THE LETTER", kind: .letters),
        Goal(id: "north.gap", text: "ST JOHNS GAP", kind: .gap("ST JOHNS GAP")),
        Goal(id: "north.cart", text: "FLIP A CART", kind: .clear(.cart, style: 2)),
        Goal(id: "north.curb", text: "GRIND A CURB", kind: .grind(.curb, seconds: 1.5)),
    ])

    /// The esplanade along the river: runners, bikes, dogs, and open manholes.
    static let southeastWaterfront = Level(id: "waterfront", name: "SE WATERFRONT", theme: .waterfront, length: 3150, features: [
        .handrail(.back, at: 220, length: 120),
        .runner(.middle, at: 300),
        .bench(.front, at: 520),
        .hole(.back, at: 600),
        .dog(.middle, at: 700),
        .biker(.front, at: 760),
        .handrail(.back, at: 900, length: 160),
        .hole(.middle, at: 1150),
        .runner(.back, at: 1200),
        .bench(.middle, at: 1380),
        .hole(.back, at: 1500),
        .biker(.middle, at: 1550),
        .handrail(.back, at: 1700, length: 200),
        .dog(.front, at: 1900),
        .hole(.front, at: 2050),
        .runner(.middle, at: 2200),
        .bench(.back, at: 2300),
        .hole(.back, at: 2350),
        .biker(.front, at: 2500),
        .handrail(.back, at: 2600, length: 140),
        .dog(.middle, at: 2800),
        .hole(.middle, at: 2900),
    ], letters: [
        letter(6, .back, at: 1800, height: 30),
    ], gaps: [
        Gap(name: "ESPLANADE GAP", points: 400, kind: .over(.back, from: 2300, to: 2350)),
    ], goals: [
        Goal(id: "waterfront.score", text: "SCORE 4000", kind: .score(4000)),
        Goal(id: "waterfront.letters", text: "FIND THE LETTER", kind: .letters),
        Goal(id: "waterfront.gap", text: "ESPLANADE GAP", kind: .gap("ESPLANADE GAP")),
        Goal(id: "waterfront.angie", text: "OLLIE ANGIE", kind: .clear(.dog)),
        Goal(id: "waterfront.rail", text: "GRIND HANDRAIL", kind: .grind(.handrail, seconds: 1.5)),
    ])

    /// Down the hill from the zoo, with Zoobombers on little bikes and the zoo train.
    /// You keep speeding up the whole way: the hardest spot.
    static let zooBomb = Level(id: "zoobomb", name: "ZOO BOMB", theme: .zooBomb, length: 3500, features: [
        .curb(.back, at: 240, length: 200),
        .miniBike(.front, at: 360, speed: 45),
        .penguin(.middle, at: 520),
        .barrier(.back, at: 640),
        .car(.front, at: 860),
        .goat(.middle, at: 900),
        .curb(.front, at: 1050, length: 240),
        .zooTrain(.back, at: 1150),
        .barrier(.middle, at: 1200),
        .miniBike(.back, at: 1300),
        .penguin(.front, at: 1500),
        .goat(.back, at: 1560),
        .barrier(.back, at: 1750, length: 48),
        .barrier(.back, at: 1830),
        .car(.middle, at: 1900),
        .curb(.back, at: 2050, length: 260),
        .miniBike(.front, at: 2150),
        .goat(.middle, at: 2400),
        .barrier(.front, at: 2500),
        .car(.middle, at: 2700),
        .penguin(.back, at: 2800),
        .zooTrain(.middle, at: 2950),
        .cone(.back, at: 3000), .cone(.front, at: 3020),
        .barrier(.middle, at: 3160, length: 48),
        .goat(.front, at: 3300),
    ], letters: [
        letter(7, .middle, at: 3190, height: 26),
    ], acceleration: 4, maxSpeed: 170, gaps: [
        Gap(name: "SUNSET GAP", points: 600, kind: .transfer(.back, from: 1750, to: 1830)),
    ], goals: [
        Goal(id: "zoobomb.score", text: "SCORE 5000", kind: .score(5000)),
        Goal(id: "zoobomb.letters", text: "FIND THE LETTER", kind: .letters),
        Goal(id: "zoobomb.gap", text: "SUNSET GAP", kind: .gap("SUNSET GAP")),
        Goal(id: "zoobomb.car", text: "FLIP A CAR", kind: .clear(.car, style: 2)),
        Goal(id: "zoobomb.penguin", text: "OLLIE A PENGUIN", kind: .clear(.penguin)),
    ])
}
