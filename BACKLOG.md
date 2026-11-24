# Skate backlog

The design doc is `skate-design-v0.1.md` (exported from the Claude Doc, which is the source of truth). This file tracks decisions made since, and what's next.

## Decided

- **Engine: SpriteKit**, same as Mahjong and Sevens (UIKit app, one `GameScene`, rules in `skate/Rules`, drawing and sound in `skate/UI`). Android comes later as a port, as Sevens did.
- **Landscape only, big chunky pixels.** The game is at least 180 x 96 game pixels, drawn at the largest whole-number scale that fits (12x on an iPhone 18 Pro, so 218 x 100). The street fills the lower half and the skater is about a third of the screen tall. Extra room shows more street ahead and more sky (`PixelLayout` in `GameViewController.swift`). This is zoomed in from the doc's 256 x 144, so update the doc.
- **The skater is a blocky kid** (18 px wide): yellow cap on backwards, black tee with a small white print, khakis, black shoes. The face has an outline at the back and chin, an ear, eye and mouth so it reads in profile. Final look still depends on which skaters we have.
- **Everyone is drawn at the same size and in the same style.** Walkers, joggers and people on bikes use the skaters' heads and 18 px wide bodies (`PeopleArt.swift`), two pixels taller so a grown-up's head lines up with a kid's on a board. Other skaters and Angie on a walk already use the skater drawings. Animals (penguins, goats) stay their own size.
- **The ollie pops the moment your thumb touches down.** Keeping it down makes gravity lighter while the board rises, up to the charged height (38 px); a tap gives the plain ollie (20 px). An up or down swipe within 0.15 s of the pop, by the same thumb, takes the ollie back (no points, no speed-up) and changes lanes. A press made in the air and still down at touchdown pops again on landing.
- **Clearing things scores.** Getting all the way over something in the air adds points to the combo: 20 + 3 per pixel of height + 1 per pixel of length, times 1.5 and up for moving things (plus 1x per 100 px/s), times the hardest trick done on the way over (grab 1.5, kickflip/heelflip/shove-it 2, 360 flip 3). A cone is 65, a moving car 235, a manhole 35; low curbs and tracks nothing. A popup names it ("CONE +65"). The points ride the combo multiplier and are lost on a bail.
- **Goals:** five per spot (score, letters, the spot's named gap, a trick over something, and one more). Listed before every run, announced with a banner the moment you get one, crossed out on the pause menu and the finish screen, and saved. The spot list shows a dot per goal. No clock yet: the finish line is the time limit.
- **Named gaps,** at least one per spot, worth a fat bonus on the combo: PIONEER GAP and DOUBLE CONE (Downtown), FOUNTAIN GAP (Skidmore), BURNSIDE GAP, ST JOHNS GAP, ESPLANADE GAP, SUNSET GAP (Zoo Bomb). A gap is either "over everything from here to there in one jump" or "grind this, land a grind on that".
- **Combo meter:** a clean landing keeps the combo open for 1.2 s (a bar under the combo). Another trick in that time keeps it going; a plain ollie doesn't count, so landing with nothing new, or letting the bar run out, banks it. Bailing loses it.
- **Big combos** get a callout (SICK! 1000, GNARLY! 2500, RADICAL! 5000, LEGENDARY! 10000) and half a second of slow motion. Bails shake the screen.
- **Quarter pipes** (two at Burnside): ride up one and fly off the lip about 46 px high.
- **Spelling a city wins something.** PORTLAND unlocks the PDX carpet board. The last letter sets off a celebration (the name hops in letter by letter, slow motion, sparks), and the finish screen of that run shows it again.
- **360 flip takes 0.46 s,** still the longest trick (shove-it 0.34, kickflip 0.32).
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

- [ ] **Play it on a real phone** and tune `Tuning.swift`: swipe distance (30 pt), the take-back window (0.15 s), ollie heights, gravity, speeds, grind snap. The simulator can't judge feel or haptics.
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
