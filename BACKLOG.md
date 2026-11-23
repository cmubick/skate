# Skate backlog

The design doc is `skate-design-v0.1.md` (exported from the Claude Doc, which is the source of truth). This file tracks decisions made since, and what's next.

## Decided

- **Engine: SpriteKit**, same as Mahjong and Sevens (UIKit app, one `GameScene`, rules in `skate/Rules`, drawing and sound in `skate/UI`). Android comes later as a port, as Sevens did.
- **Landscape only, big chunky pixels.** The game is at least 180 x 96 game pixels, drawn at the largest whole-number scale that fits (12x on an iPhone 18 Pro, so 218 x 100). The street fills the lower half and the skater is about a third of the screen tall. Extra room shows more street ahead and more sky (`PixelLayout` in `GameViewController.swift`). This is zoomed in from the doc's 256 x 144, so update the doc.
- **The skater is a blocky kid** (18 px wide): yellow cap on backwards, black tee with a small white print, khakis, black shoes. The face has an outline at the back and chin, an ear, eye and mouth so it reads in profile. Final look still depends on which skaters we have.
- **Swipe sideways on the ground to ollie straight into a flip**: left is a kickflip, right a heelflip. Swipes in the air still do every flip. Not in the doc yet.
- **Text uses a 5 x 7 pixel font**, about twice the old size.
- **Working name "Skate"**, bundle ID `com.tuesdaygames.skate`. The real title is still open.
- **Grinds lock on automatically** and last until the rail ends or you tap to hop off. No hold-to-balance meter for now; one could come back for long rails only.
- **Three skaters: Terry, Sam and Angie** (a black and grey aussiedoodle). The skater builder picks the skater and colors for shirt (Angie's bandana), pants (not for Angie), hat or no hat, and board. Saved between launches.
- **Cities:** Portland is free and open. San Francisco, Los Angeles, New York, Fresno, Sacramento, Austin, Seattle and Astoria show as coming soon.
- **City letters:** each spot hides one or two of its city's letters (Portland: P O at Downtown, R T at Skidmore Fountain, L at Burnside, A at North Portland, N at SE Waterfront, D on the Zoo Bomb). Found letters are saved and show in gold along the bottom left during a run.
- **Portland spots:** Downtown (the grey-box tutorial street), Skidmore Fountain, Burnside Skatepark, North Portland, SE Waterfront and Zoo Bomb. Moving things (people, bikes, trains, cars, animals) start moving as they come on screen, so a spot plays the same every time. The Zoo Bomb keeps speeding you up.
- **Goal runs have a clock; free skate doesn't.** Free skate opens on any unlocked spot, with no goals.
- **Skate ships before the Angie game**, so this game sets the shared palette, tiles and Portland spots.

## Milestone 1: feel prototype (in progress)

Built so far: six Portland spots (`Rules/Cities.swift`), menus (title, city picker, spot list, skater builder), automatic rolling, tap and hold-to-charge ollies, three lanes, kickflip / heelflip / shove-it / 360 flip, tap and held grabs, 50-50 and boardslide on rails and ledges, combos and multiplier, perfect landings, bails, a finish line with best score, haptics (including a Core Haptics rumble while grinding), and chip-style sounds made in code.

To do:

- [ ] **Play it on a real phone** and tune `Tuning.swift`: tap/hold split (0.12 s), swipe distance (30 pt), ollie heights, gravity, speeds, grind snap. The simulator can't judge feel or haptics.
- [ ] **Early presses in the air.** Pressing in the air and holding past 0.12 s starts a grab, so pressing early for a charged ollie just before landing bails you. Try buffering the press as an ollie instead if it bites in playtests.
- [ ] **Text size.** The 5 x 7 font is big now; the hints along the bottom nearly fill the width. Check on a phone whether the HUD wants to come down a little.
- [ ] **Second finger.** Only the first finger counts; a tap with another finger while one is down is ignored.
- [ ] A sound on/off control (`Sounds.shared.isMuted` is there, with no button yet).
- [ ] A quick in-game tuning panel (debug builds only), so numbers can be changed on the phone.
- [ ] **Play every Portland spot** and tune the layouts: when moving things meet you depends on your speed, so some stretches may be too crowded or too empty.
- [ ] **Zoo Bomb downhill look.** It speeds you up, and the hills in the backdrop slope down, but the road itself is flat. A real slope (stepped ground tiles) would sell it better.
- [ ] **Sam's look.** Sam has longer black hair and darker skin than Terry; change if you had someone else in mind.

## Milestone 2 and on

From the design doc: one real spot (Downtown square, final art style, letters, score, bail, clock), then the Portland vertical slice (first 3 spots, goals, city map, save data), full Portland, then ship.

- **Run clock** and free-skate mode (decided above).
- **Music**: one 4-voice chiptune loop per city plus a menu tune.
- **Store**: one $4.99 full-game unlock plus three tips, the same way as `Store.swift` in Mahjong. Product IDs to follow the `com.tuesdaygames.skate.*` pattern.
- **App Store material**: `AppStore/` (listing, checklist, export options) and `docs/` (support and privacy pages), copied from Mahjong when it's time to ship.
- **App icon**: a placeholder from `AppStore/icon/make_icon.swift`. Run `swift AppStore/icon/make_icon.swift <out.png> light|dark|tinted` for each of the three files in `AppIcon.appiconset`.

## Still open (from the design doc)

1. The title, and whether it shares a naming family with the Angie game.
2. Which cities after Portland, and whether both games add cities in lockstep.
3. Whether the free tier (3 spots) and $4.99 unlock sit right next to the other games' prices.
4. Manuals: swipe down on landing is close to the lane-switch swipe. Leaning toward cutting them (they're on the cut list).
