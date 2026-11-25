# Skate backlog

The design doc is `skate-design-v0.1.md` (exported from the Claude Doc, which is the source of truth). This file tracks decisions made since, and what's next.

## Decided

- **Engine: SpriteKit**, same as Mahjong and Sevens (UIKit app, one `GameScene`, rules in `skate/Rules`, drawing and sound in `skate/UI`). Android is a port, as Sevens did (see below).
- **Landscape only, big chunky pixels.** The game is at least 180 x 96 game pixels, drawn at the largest whole-number scale that fits (12x on an iPhone 18 Pro, so 218 x 100). The street fills the lower half and the skater is about a third of the screen tall. Extra room shows more street ahead and more sky (`PixelLayout` in `GameViewController.swift`). This is zoomed in from the doc's 256 x 144, so update the doc.
- **The skater is a blocky kid** (18 px wide): yellow cap on backwards, black tee with a small white print, khakis, black shoes. The face has an outline at the back and chin, an ear, eye and mouth so it reads in profile. Final look still depends on which skaters we have.
- **Everyone is drawn at the same size and in the same style.** Walkers, joggers and people on bikes use the skaters' heads and 18 px wide bodies (`PeopleArt.swift`), two pixels taller so a grown-up's head lines up with a kid's on a board. Other skaters and Angie on a walk already use the skater drawings. Animals (penguins, goats) stay their own size.
- **The ollie pops the moment your thumb touches down.** Keeping it down makes gravity lighter while the board rises, up to the charged height (38 px); a tap gives the plain ollie (20 px). An up or down swipe within 0.15 s of the pop, by the same thumb, takes the ollie back (no points, no speed-up) and changes lanes. A press made in the air and still down at touchdown pops again on landing.
- **Clearing things scores.** Getting all the way over something in the air adds points to the combo: 20 + 3 per pixel of height + 1 per pixel of length, times 1.5 and up for moving things (plus 1x per 100 px/s), times the hardest trick done on the way over (grab 1.5, kickflip/heelflip/shove-it 2, 360 flip 3). A cone is 65, a moving car 235, a manhole 35; low curbs and tracks nothing. A popup names it ("CONE +65"). The points ride the combo multiplier and are lost on a bail.
- **Goals:** five per spot (score, the spot's letters ("FIND THE LETTER" or "FIND 2 LETTERS"), the spot's named gap, a trick over something, and one more). Listed before every run, announced with a banner the moment you get one, crossed out on the pause menu and the finish screen, and saved. The spot list shows a dot per goal. No clock yet: the finish line is the time limit.
- **Named gaps,** at least one per spot, worth a fat bonus on the combo: PIONEER GAP and DOUBLE CONE (Downtown), FOUNTAIN GAP (Skidmore), BURNSIDE GAP, ST JOHNS GAP, ESPLANADE GAP, SUNSET GAP (Zoo Bomb). A gap is either "over everything from here to there in one jump" or "grind this, land a grind on that".
  - 2026-11-23: ESPLANADE GAP (bench + manhole) and FOUNTAIN GAP were close to impossible: at the starting speed a held ollie had a 0–2 pixel window. The manhole moved in from x 2350 to 2338 and the first Skidmore fountain shrank from 56 to 44 long. A test now keeps every over gap doable with a held ollie at the starting speed.
  - 2026-11-23: nothing in the game said what a gap *is*, so each gap now has a short hint (RAIL TO RAIL, BENCH+MANHOLE, GRIND 2 BARRIERS...) shown in grey beside its goal on the goals and pause screens until it's done. Not on the results screen, where the goals share half the width.
- **Combo meter:** a clean landing keeps the combo open for 1.2 s (a bar under the combo). Another trick in that time keeps it going; a plain ollie doesn't count, so landing with nothing new, or letting the bar run out, banks it. Bailing loses it.
- **Big combos** get a callout (SICK! 1000, GNARLY! 2500, RADICAL! 5000, LEGENDARY! 10000). Bails shake the screen. Slow motion is built but switched off (`slowMotionOn` in `GameScene.swift`): it felt jarring.
- **Quarter pipes** (two at Burnside): ride up one and fly off the lip about 46 px high.
- **Spelling a city wins something.** PORTLAND unlocks the PDX carpet board. The last letter sets off a celebration (the name hops in letter by letter, slow motion, sparks), and the finish screen of that run shows it again.
- **360 flip takes 0.46 s,** still the longest trick (shove-it 0.34, kickflip 0.32).
- **Tutorial:** a TUTORIAL button on the title screen opens a practice street (rails in the back lane, cones in the front) with ten steps, one at a time, each waiting until you do it: ollie, high ollie, lanes, kickflip, grab, spin, grind, hop off, a x3 combo, and clearing a cone. Then "YOU'RE READY!" and a button into Downtown.
- **Portland landmarks:** Downtown has Pioneer Courthouse Square (signpost and courthouse), the Portland Building with Portlandia, the White Stag sign, a full-block bookstore, Big Pink and Montgomery Park, plus Benson Bubblers to ollie and Mill Ends Park. Skidmore has the Chinatown gate, Saturday Market and the White Stag sign. Burnside shows the Burnside Bridge's arches and towers. North Portland has Paul Bunyan, Cathedral Park's arches and Mount St. Helens. SE Waterfront has the Hawthorne Bridge, Tilikum Crossing, Big Pink, OMSI, the Blueback and Mount Hood. Zoo Bomb has Mount Hood, Pittock Mansion, the zoo train and Zoobombers on little bikes.
- **Swipe sideways on the ground to ollie straight into a flip**: left is a kickflip, right a heelflip. Swipes in the air still do every flip. Not in the doc yet.
- **Text uses a 5 x 7 pixel font**, about twice the old size.
- **Working name "Skate"**, bundle ID `com.tuesdaygames.skate`. The real title is still open.
- **Grinds lock on automatically** and last until the rail ends or you tap to hop off. No hold-to-balance meter for now; one could come back for long rails only.
- **Three skaters: Pat, Sammy and Angie** (a black and grey aussiedoodle). The skater builder picks the skater and colors for shirt (Angie's bandana), pants (not for Angie), hat or no hat, and board. Saved between launches.
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
- [x] **App Store Connect products.** The tips were created as `com.tuesdaygames.smalltip`, `com.tuesdaygames.mediumtip` and `com.tuesdaygames.largetip`, not the `skate.tip.*` IDs the app first used, so 1.0 showed TIPS AREN'T SET UP YET. Product IDs can't be changed or reused in App Store Connect, so 1.0.1 (build 2) switches the app to those IDs. When `skate.fullgame` is created, use exactly that ID (or change `Store.fullGameID` to match). Running from Xcode uses `skateTests/Skate.storekit` (the shared `skate` scheme's Run > Options > StoreKit Configuration).
- [ ] **Full game on sale** when the next city is ready: turn on `Store.fullGameOnSale`, open the cities the purchase unlocks, and add Restore Purchases (and Redeem Code, like Sevens) to the full game screen.
- [ ] **Prices in other currencies** show as `?` where the pixel font has no symbol (only `$` so far).
- [ ] **Slow motion, take two.** Big combos and spelling a city used to drop to 35% speed for half a second, which felt jarring mid-run. Ideas: a much gentler slowdown (70-80%), easing in and out instead of snapping, only on landing rather than in the air, or a freeze-frame on the callout only. Switch `slowMotionOn` back on to try them.
- [ ] **Sammy's look.** Sammy has longer black hair and darker skin than Pat; change if you had someone else in mind.

## Milestone 2 and on

From the design doc: one real spot (Downtown square, final art style, letters, score, bail, clock), then the Portland vertical slice (first 3 spots, goals, city map, save data), full Portland, then ship.

- **Run clock** and free-skate mode (decided above).
- **Music**: one 4-voice chiptune loop per city plus a menu tune.
- **Store** (built): tips now (`com.tuesdaygames.smalltip` $0.99, `com.tuesdaygames.mediumtip` $2.99, `com.tuesdaygames.largetip` $4.99), and the full game (`skate.fullgame`, $4.99, every city after Portland) once the other cities are ready. Until then `Store.fullGameOnSale` is off: the locked cities show a padlock and a FULL GAME button that opens a coming-soon screen with a link to the tip jar. Same shape as Sevens' `Store.swift`. The tip jar is loud on purpose: a pink TIP JAR button right under PLAY (with a jar of coins), and on the city picker, the spot list, the full game screen, every finish screen and the end of the tutorial. The three tips always show, with US prices until the App Store answers.
- **App Store material**: `AppStore/` (listing, checklist, export options) and `docs/` (support and privacy pages), copied from Mahjong when it's time to ship.
- **App icon**: a placeholder from `AppStore/icon/make_icon.swift`. Run `swift AppStore/icon/make_icon.swift <out.png> light|dark|tinted` for each of the three files in `AppIcon.appiconset`.

## Still open (from the design doc)

1. The title, and whether it shares a naming family with the Angie game.
2. Which cities after Portland, and whether both games add cities in lockstep.
3. Whether the free tier (3 spots) and $4.99 unlock sit right next to the other games' prices.
4. Manuals: swipe down on landing is close to the lane-switch swipe. Leaning toward cutting them (they're on the cut list).

- **Boardslides** (2026-11-23): they always worked (swipe down or sideways on a rail), but the only sign was the board squashed under the same crouch, so nobody noticed. Now the board turns across the rail, seen end-on with its wheels hanging, and the skater balances with arms out, wobbling (two frames). The tutorial has a new step: ON RAIL, SWIPE DOWN: SLIDE.

- **GRIND FOUNTAIN was impossible** (2026-11-23): it wanted one 1.5 s grind on a fountain, but the longest fountain (80) gives under 1.1 s even landing right at its start. The middle Skidmore fountain is now a long basin (132) and the goal is 1 s. A test now checks every grind goal against its longest feature at top speed.

- **North Portland food cart signs** (2026-11-23): each cart has a sign on its roof saying what it sells: PIZZA, TACOS, SANDOS, THAI, BURGER, RAMEN, PHO, CREPES, CURRY (`ThemeArt.foodCartSigns`, in turn). The sign font gained C, H, I, U and Z. A test checks each sign fits.

- **SUNSET GAP was blocked** (2026-11-23): the Zoobomber in Zoo Bomb's back lane (x 1300, going 60) rode through the gap's barriers just as you arrived, at the speeds you're likely going (80-95). It's in the front lane now, and a test checks that nothing moving can be in any gap's way.

- **Letters goal counts every letter you've found** (2026-11-23): it used to need all of a spot's letters in one run. Now letters from earlier runs count, and older saves get the goal at launch.
- **Fireworks for finishing a city** (2026-11-23): the run that completes a city's last goal dims the screen, fires a rocket that bursts into the city's name in sparks, then shows the results ("ALL PORTLAND GOALS!") with fireworks going off behind until you leave.
- **App Store assets** (2026-11-23): screenshots, header, universal and search art and the tip jar review screenshot are rendered from the game by `AppStore/make_assets.sh` (`skate/Marketing.swift`, debug only). The listing text and form answers are in `AppStore/listing.md`.
  - Key art is on the waterfront, not Downtown: Portlandia (copyright held by the sculptor) and the White Stag PORTLAND OREGON sign (a City of Portland trademark) are kept out of it.
  - To decide before release: Portlandia and the White Stag sign in the game itself; Burnside's "SK8 OR DIE"/skull graffiti for a 4+ rating; whether to hide "COMING SOON FOR $4.99" until the full game is on sale.
  - Maybe: an App Preview video (15-30 s); Accessibility Nutrition Labels (voluntary for now; "Differentiate Without Color Alone" would need found letters marked some way other than color).

- **Music** (2026-11-23): each spot has its own original song, 90s skate punk played on an NES, generated in code (`Chiptune.swift`, `Songs.swift`, `Music.swift`). Downtown 184 BPM bouncy skate punk; Skidmore 152 ska-punk; Burnside 200 dark and fast; North Portland 168 pop-punk anthem; SE Waterfront 124 slow and melodic; Zoo Bomb 232 hardcore, the fastest. The intro plays once, then the rest loops. Quieter under menus; none on the menus themselves yet.
  - To do: menu or title music, and songs for each new city.
- **Sounds for every skate move** (2026-11-23): rolling wheels, flips, spins, grabs, a lock-on clank, three grind loops (metal rails, concrete and wood, boardslides), quarter-pipe launches, clears, banked combos, gaps, goals, manhole falls and firework crackle.
- **Music and sound switches** (2026-11-23): a note and a speaker icon in the top-left of the title, goals and pause screens; separate settings, remembered. Sound effects now play through an audio engine from in-memory buffers, which also fixed a slow first load of each spot.
- **iPad full screen** (2026-11-23): the first App Store upload failed because a landscape-only iPad app must opt out of multitasking. The project now sets `UIRequiresFullScreen`. That key is deprecated since iPadOS 26; supporting portrait and resizable windows on iPad is the long-term fix.

- **Game Center leaderboards: version 1.1** (decided 2026-11-23; 1.0 ships without them).
  - App: Game Center capability; sign the player in at launch (the game works the same if they decline); send each run's score to its spot's leaderboard; a LEADERBOARD button on the finish screen and the spot list opening Apple's leaderboard screen.
  - Leaderboards: one per spot (high score, highest first, integer), IDs like `skate.portland.downtown`; maybe a "Portland total" for the sum of the six best scores.
  - App Store Connect (Chris): create the leaderboards with matching IDs, tick Game Center on the 1.1 version and add them.
  - Check Apple's docs first: whether Game Center changes the App Privacy answer ("Data Not Collected") or the age rating questions.

- **Android port** (2026-11-24): in `android/`, set up like Sevens' (Kotlin, Gradle, a plain-Kotlin `rules` module and an `app` module), package `com.tuesdaygames.skate`, Android 8.0 and later, landscape. Everything from iOS: the six Portland spots, letters, gaps, goals, tutorial, skater builder, tip jar (Google Play Billing, as `skate.tip.small`, `.medium` and `.large`: the iOS tips ended up as `com.tuesdaygames.*tip` because App Store Connect can't rename products, but nothing exists on Play yet, so Android keeps the `<app>.tip.*` pattern the other apps use), coming-soon cities, music, sounds, switches, haptics and the fireworks.
  - Drawn on a plain Android View with a small stand-in for the bits of SpriteKit the game uses, so the scenes port line for line. Not Compose (Sevens' choice): every screen here is pixel art, menus included.
  - Parity tests compare every picture, sound, song and a scripted run on each spot with the Swift code itself (`android/tools/parity/make_fixtures.sh` builds it), so the two can't drift apart unnoticed.
  - Android extras: the back button pauses a run or goes back a menu page; a phone on silent doesn't mute the game (the switches do), as in Sevens.
  - Music fix (2026-11-24): on a cheap tablet the song often didn't start until music was switched off and on. The game asked Android whether any music was playing, and the click of the button that starts a run counted. It now only counts other apps' media, and the intro starts while the rest of the song renders (a debug build took 36 s per song there).
  - Release signing (2026-11-24): `./gradlew bundleRelease` signs with the upload key in iCloud Drive, read from `~/.gradle/gradle.properties` (see `android/README.md`, Releasing on Google Play).
  - To do: the Play Console app, tip products, listing and data safety form; store screenshots; a play on a real phone (the tablet has no vibration motor).
