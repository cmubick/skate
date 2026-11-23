# Skate backlog

The design doc is `skate-design-v0.1.md` (exported from the Claude Doc, which is the source of truth). This file tracks decisions made since, and what's next.

## Decided

- **Engine: SpriteKit**, same as Mahjong and Sevens (UIKit app, one `GameScene`, rules in `skate/Rules`, drawing and sound in `skate/UI`). Android comes later as a port, as Sevens did.
- **Landscape only.** The game is at least 256 x 144 game pixels, drawn at the largest whole-number scale that fits (8x on an iPhone 18 Pro, so 327 x 150). Extra room shows more street ahead and more sky (`PixelLayout` in `GameViewController.swift`).
- **Working name "Skate"**, bundle ID `com.tuesdaygames.skate`. The real title is still open.
- **Grinds lock on automatically** and last until the rail ends or you tap to hop off. No hold-to-balance meter for now; one could come back for long rails only.
- **A few skaters to pick from** (2 to 4). Each needs every trick animation, so the art budget grows per skater. Angie as a skater is still planned on top.
- **Goal runs have a clock; free skate doesn't.** Free skate opens on any unlocked spot, with no goals.
- **Skate ships before the Angie game**, so this game sets the shared palette, tiles and Portland spots.

## Milestone 1: feel prototype (in progress)

Built so far: one grey-box street (`Level.feelStreet`), automatic rolling, tap and hold-to-charge ollies, three lanes, kickflip / heelflip / shove-it / 360 flip, tap and held grabs, 50-50 and boardslide on rails and ledges, combos and multiplier, perfect landings, bails, a finish line with best score, haptics (including a Core Haptics rumble while grinding), and chip-style sounds made in code.

To do:

- [ ] **Play it on a real phone** and tune `Tuning.swift`: tap/hold split (0.12 s), swipe distance (30 pt), ollie heights, gravity, speeds, grind snap. The simulator can't judge feel or haptics.
- [ ] **Early presses in the air.** Pressing in the air and holding past 0.12 s starts a grab, so pressing early for a charged ollie just before landing bails you. Try buffering the press as an ollie instead if it bites in playtests.
- [ ] **Second finger.** Only the first finger counts; a tap with another finger while one is down is ignored.
- [ ] A sound on/off control (`Sounds.shared.isMuted` is there, with no button yet).
- [ ] A quick in-game tuning panel (debug builds only), so numbers can be changed on the phone.

## Milestone 2 and on

From the design doc: one real spot (Downtown square, final art style, letters, score, bail, clock), then the Portland vertical slice (first 3 spots, goals, city map, save data), full Portland, then ship.

- **Run clock** and free-skate mode (decided above).
- **Skater select**: decide how many and who they are before final art.
- **Music**: one 4-voice chiptune loop per city plus a menu tune.
- **Store**: one $4.99 full-game unlock plus three tips, the same way as `Store.swift` in Mahjong. Product IDs to follow the `com.tuesdaygames.skate.*` pattern.
- **App Store material**: `AppStore/` (listing, checklist, export options) and `docs/` (support and privacy pages), copied from Mahjong when it's time to ship.
- **App icon**: a placeholder from `AppStore/icon/make_icon.swift`. Run `swift AppStore/icon/make_icon.swift <out.png> light|dark|tinted` for each of the three files in `AppIcon.appiconset`.

## Still open (from the design doc)

1. The title, and whether it shares a naming family with the Angie game.
2. Which skaters, now that there will be a few.
3. Which cities after Portland, and whether both games add cities in lockstep.
4. Whether the free tier (3 spots) and $4.99 unlock sit right next to the other games' prices.
5. Manuals: swipe down on landing is close to the lane-switch swipe. Leaning toward cutting them (they're on the cut list).
