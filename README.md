# Skate

An 8-bit, one-thumb skateboarding side-scroller for iPhone, iPad and Android,
set in Portland, Oregon. Made by Tuesday Games.

You roll automatically from left to right down a street with three lanes. Tap to
ollie, hold for a higher one, swipe to change lanes and to flip, grind rails and
ledges, chain tricks into combos, clear things for points, find the city's
letters, and work through each spot's goals.

- **App Store:** live since 2026-11-24 as "Skate: Tuesday Games",
  <https://apps.apple.com/app/id6838565677> (Apple ID 6838565677).
- **Platform:** iOS and iPadOS 16 and later, landscape only. The Android version
  is in `android/` (see [Android](#android)).
- **Engine:** Apple's **SpriteKit** inside a small **UIKit** app. No other game
  engine and no third-party code: no Swift packages, no CocoaPods.
- **Language:** Swift. Tests use **Swift Testing**, not XCTest.
- **Art and sound:** all drawn and generated **in code**. The repo has no image
  or audio files apart from the app icon, which a script also draws.
- **License:** MIT (see `LICENSE`).

---

## Quick start

1. Open `skate.xcodeproj` in Xcode. It was last built with **Xcode 27.2**.
2. Pick the **skate** scheme and an iPhone, real or simulator, and run.
3. To run the tests: **Product > Test**, or from the command line:

   ```sh
   xcodebuild -project skate.xcodeproj -scheme skate \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
   ```

   Swap in any iPhone simulator you have installed (`xcrun simctl list devices`).
   The tests run in well under a second.

**Signing:** the project is set to the Tuesday Games team (`ZYW8AH3KQP`) with
automatic signing. On another account, change the team in the target's
**Signing & Capabilities** tab. The bundle ID is `com.tuesdaygames.skate`.

**Debug launch arguments** (Run > Arguments in the scheme, or after the bundle
ID in `xcrun simctl launch`). They only work in debug builds:

- `-page cities|spots|builder|tips|fullgame` opens on that menu page.
- `-hideFPS YES` turns the frame counter off, for clean screenshots.
- `-level <spot id>` (say `-level waterfront`) opens straight on that spot.
- `-fireworks YES` shows the all-goals fireworks on Downtown, without saving.
- `-marketing YES` renders the App Store screenshots and art into the app's
  Documents folder (`AppStore/make_assets.sh` does this for you).

**Tips from Xcode:** the shared scheme's **Run > Options > StoreKit
Configuration** points at `skateTests/Skate.storekit`. That's a local test store,
so the tip jar works from Xcode without App Store Connect. See [Store](#store).

---

## Android

The Android version lives in `android/`, set up like Sevens' Android port: Kotlin
and Gradle, a plain-Kotlin `rules` module ported file for file from `skate/Rules`,
and an `app` module with the art, sound, scenes, haptics and Google Play store.
It plays and looks the same as the iOS game: tests check every picture pixel for
pixel, every sound and song, and a scripted run on every spot against the Swift
code itself. **`android/README.md` has everything else**: building, running,
debug switches, saved data, purchases and how the Kotlin differs from the Swift.

To build and run it, open the `android` folder in Android Studio and press Run, or:

```sh
cd android
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
./gradlew :rules:test :app:testDebugUnitTest   # all the Android tests
./gradlew installDebug                         # onto a running emulator or phone
```

**Changing the game:** make the change on iOS, then the same change in the Kotlin
(the files have the same names), then run `sh android/tools/parity/make_fixtures.sh`
and the Android tests. If a picture, sound, song or rule now differs between the two,
the parity tests say which.

---

## Where to read first

| File | What it is |
| --- | --- |
| `BACKLOG.md` | **The decision log and to-do list.** Every design decision since the start, and what's left. If something here and the design doc disagree, the backlog is newer and wins. |
| `skate-design-v0.1.md` | The original design doc: the pitch, the controls and the plan. Partly out of date; see `BACKLOG.md`. |
| `skate/Rules/Tuning.swift` | Every feel number in one place: gravity, ollie heights, speeds, timing windows, scoring. |
| `skate/Rules/Cities.swift` | The cities and every Portland spot: what's in each lane, the letters, the named gaps and the goals. |

---

## How the code is laid out

```
skate/
  AppDelegate.swift, SceneDelegate.swift   Standard UIKit app shell.
  GameViewController.swift                 Holds the SKView, sizes it in whole pixels
                                           (PixelLayout), and switches between scenes.
  GameScene.swift                          A run: drawing, HUD, touches, sounds, haptics,
                                           the pause menu, the finish screen, the tutorial box.
  Rules/                                   The game's rules. No SpriteKit in here.
    Run.swift          One run: the skater, physics, tricks, combos, scoring, collisions.
    Gestures.swift     Turns touches into press / hold / release / swipe.
    Tricks.swift       The tricks and the combo.
    Level.swift        Features (things on the street), letters, gaps, the Level type.
    Cities.swift       The cities and Portland's six spots.
    Goals.swift        Goal types and the tracker that watches a run.
    Tutorial.swift     The tutorial's steps and its practice street.
    Characters.swift   Skaters (Pat, Sammy, Angie) and outfits.
    Progress.swift     Everything saved between launches (UserDefaults).
    Tuning.swift       The numbers.
  UI/                                      Everything you see and hear.
    PixelArt.swift     The pixel canvas, sprites, palette and 5x7 font.
    CharacterArt.swift The skaters and their boards.
    PeopleArt.swift    Walkers, runners, bikers and Zoobombers.
    ObstacleArt.swift  Rails, cones, cars, trains, manholes, quarter pipes...
    ThemeArt.swift     Each spot's sky, backdrops and ground; graffiti; the 3x5 sign font.
    LandmarkArt.swift  Portland landmarks in the backdrops.
    Menus.swift        The title, city picker, spot list, skater builder, full game
                       screen and tip jar (MenuScene), plus the pixel button.
    Sounds.swift       Chip-style sound effects, generated as WAV data in code.
    Chiptune.swift     The music synth and sequencer.
    Songs.swift        The soundtrack: a song per spot, written as text.
    Music.swift        Plays a spot's song: intro once, then the loop.
    Haptics.swift      Taps, thuds and the grind rumble (Core Haptics).
    Store.swift        In-app purchases (StoreKit 2).
  Marketing.swift      Debug builds only: renders the App Store screenshots and art.
skateTests/
  skateTests.swift     All the tests.
  Skate.storekit       The local StoreKit test store.
AppStore/
  listing.md           Every App Store Connect field, ready to paste, and the
                       decisions still open.
  checklist.md         Step by step: support pages, app record, upload, submit.
  make_assets.sh       Re-renders the screenshots and art from the game.
  check_safe_areas.swift  Draws Apple's safe areas on the header and search art.
  make_tip_images.swift   Draws the three tips' 1024 x 1024 promotional images.
  upload/              Everything to upload, a folder per App Store Connect section.
  ExportOptions.plist, UploadOptions.plist   Settings for exporting or uploading.
  icon/make_icon.swift Draws the app icon PNGs.
docs/                  The support and privacy pages (GitHub Pages, from /docs).
```

### The big idea: rules apart from drawing

All the game rules live in `skate/Rules/` and don't import SpriteKit. A run is a
plain struct, `Run`:

- `run.handle(gesture)` takes a touch gesture and returns what happened, as
  `RunEvent`s.
- `run.step(dt)` moves time forward and returns what happened.

`GameScene` feeds it touches and time, then turns the events into pixels, sounds
and haptics. Because of this split, nearly every rule is unit tested without a
screen, and the game plays the same at any frame rate.

- **Fixed time steps:** the scene advances the run in fixed **1/120 s** steps.
- **Gestures:** `GestureReader` turns UIKit touches into press, hold, release and
  swipe events. Only one finger counts.
- **Events:** `GameScene.process(_:dt:)` passes every event through goal tracking,
  then tutorial tracking, then `react(_:)` (sounds, popups and so on).

### Swift concurrency settings

The app target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and "approachable
concurrency", with the Swift 5 language mode. In practice:

- **App code** is main-actor by default.
- **Rule types** are marked `nonisolated` (for example `nonisolated struct Run`),
  so plain tests can use them.
- **Test structs** are marked `@MainActor`.
- **New rule types** need `nonisolated` too, or the tests won't compile against
  them.

---

## Pixels and coordinates

- **Game pixels:** the game is drawn at a small size, at least **180 x 96** game
  pixels, and scaled up by the largest whole number that fits the screen. That's
  12x on an iPhone 18 Pro, giving 218 x 100. `PixelLayout` in
  `GameViewController.swift` works this out. Everything snaps to whole pixels so
  the art stays crisp.
- **Coordinates:** the origin is bottom left and y goes up, in game pixels.
  - **Lanes:** 0 is the back lane (top of the screen) and 2 the front. Feet stand
    at `StreetArt.baseline(forLane:)`, which gives 45, 30 and 15.
  - **Backdrops:** they sit on the back sidewalk, which tops out at
    `StreetArt.groundTop` = 54.
- **The HUD:**
  - **Top row:** score and best. Keep backdrop lettering (signs) below it. The
    downtown landmark signs are deliberately low for this.
  - **Second row:** combos, or tips on Downtown.
  - **Third row:** the combo multiplier.
- **Menus and the safe area:** menus lay out inside `safeFrame` (the screen minus
  the notch, Dynamic Island and home bar), so how much room they get varies by
  phone. Anything that might not fit should measure itself and shrink. The spot
  list (`SpotsList` in `Menus.swift`) does this: it works out its natural size,
  then scales down in whole screen-pixel steps (`PixelFont.fittingScale`) so it
  stays sharp. Its letters, goal dots and best scores line up in columns sized
  to what's in them. Check menu changes on a small phone (iPhone SE) and a
  Dynamic Island phone.

## How the art works

There are no image files. Everything is drawn into a `PixelCanvas`, a small RGBA
buffer, and turned into an `SKTexture` with nearest-neighbour filtering.

- **`PixelSprite`:** an array of strings plus a map from letters to colors. The
  skaters are templates where some letters mean outfit colors. For example `t` is
  the shirt, `p` the pants and `c` the hat, so one drawing makes every outfit. The
  letter key is at the top of `CharacterArt.swift`.
- **Backdrops** (`ThemeArt`, `LandmarkArt`): wide strips that repeat sideways and
  scroll slower than the street (parallax). Each spot has two or three. North
  Portland's food carts each get a sign from `ThemeArt.foodCartSigns`.
- **Fonts:**
  - `PixelFont` is 5x7, for all on-screen text.
  - `SignFont` is 3x5, for lettering inside the art.

  Both only have the characters they need. A missing character draws as `?`, so
  add a glyph when you use a new one; there's a test that checks the common ones.
- **The app icon:** `swift AppStore/icon/make_icon.swift <out.png> light|dark|tinted`
  draws it. Run it for each of the three files in
  `skate/Assets.xcassets/AppIcon.appiconset`.

To see a new piece of art without playing to it, write a throwaway test that
draws the canvas with `cgImage()` to a PNG.

## Sound and haptics

- **Sounds:** generated as square, triangle and noise waves in `Sounds.swift`,
  kept as buffers in memory and played through an `AVAudioEngine`: six voices
  take turns with one-off sounds, and each looping sound has its own. (One
  `AVAudioPlayer` per sound took about 9 seconds to set up in the simulator.)
  Nothing is built until a spot starts or a sound first plays. The audio session
  is `.ambient`, so the silent switch silences the game and the player's own
  music keeps playing.
- **Which sound for what:**
  - Rolling: a quiet loop of wheels and pavement clacks.
  - Tricks: flips whir, spins whoosh and grabs fwip.
  - Grinds: a clank when you lock on, then a loop for metal (rails), concrete or
    wood (ledges, benches, curbs) or a boardslide.
  - Rewards: chimes for clearing something, banking a combo, a gap and a goal.
  - Also: a launch off quarter pipes, a whistle and thud down a manhole, and
    crackle for the fireworks.
- **Music and sound switches:** a music note and a speaker in the top-left corner
  of the title screen, the goals screen and the pause menu. Each crosses out in
  red when off. They're separate (`Music.shared.isOn`, saved as `musicOff`;
  `Sounds.shared.isMuted`, saved as `soundMuted`), so you can keep the skate
  sounds without the songs.
- **Music:** each spot has its own song: 90s skate punk played on an NES.
  - `Chiptune.swift` is a little sound chip and sequencer: a pulse lead, clipped
    power chords, a stepped triangle bass and noise drums.
  - `Songs.swift` has the songs, written as text a bar at a time (the format is
    at the top of `Chiptune.swift`). A test checks every bar is the right length.
  - `Music.swift` plays them: the intro once, then the rest loops. A song is
    rendered in the background the first time it's needed, then kept. It's
    quieter under menus, stops on the menus, and stays silent if the player
    already has their own music playing.
  - To listen outside the game, build `tools/music/main.swift` (the command is at
    its top) and render the songs to WAV files.
  - Tempos run from the waterfront's 124 BPM to Zoo Bomb's 232.
- **Haptics:** a continuous Core Haptics rumble runs while grinding. The scene
  stops it whenever the skater isn't grinding, as a safety net against it
  getting stuck.

---

## Game content

### Cities and spots

`City.all` lists nine cities. Only **Portland** is open; the rest say "coming
soon" and belong to the full game. Portland has six spots:

1. Downtown, the tutorial street
2. Skidmore Fountain
3. Burnside Skatepark
4. North Portland
5. SE Waterfront
6. Zoo Bomb, downhill: you keep speeding up

A `Level` is a list of `Feature`s, things on the street. Each has a kind (rail,
ledge, block, hole, ramp or decor), a style for how it's drawn, a lane, an x
position, a length, a height and an optional speed. There are also letters,
named gaps and goals.

**Adding or changing a spot:**

- **Order:** keep `features` sorted by `x`. A test checks this.
- **Moving things** (people, bikes, cars, trains) start moving when they're about
  to come on screen, so a spot plays the same every time.
- **Letters:** each spot hides one or two of the city's letters. A city's letters
  are its name without spaces, and each letter index must appear exactly once in
  the city. A test checks this.
- **Gaps:**
  - **Over:** clear everything that starts in a lane between two x positions, in
    one jump.
  - **Transfer:** grind one thing, then land a grind on the next.

  Gaps find their features by lane and starting x, so if you move a feature in a
  gap, move the gap too. A test checks every gap still finds its features.

  Each gap has a `hint` ("BENCH+MANHOLE"). It shows in grey beside the gap's
  goal on the goals and pause screens until that goal is done. A test checks it
  fits beside the name on the narrowest screen.

  Another test (`GapFairnessTests`) checks that every "over" gap can be done
  with a held ollie at the starting speed, with some room for timing. If you
  make an over gap longer, run it. Over about 66 game pixels, from the first
  thing's start to the last thing's end, is too far.

  The same suite checks that nothing moving (bikes, goats, trains) can be in
  a gap's way when you reach it, at any speed from 70 up. Things start moving
  when you're 200 pixels away, so moving one changes where it ends up.
- **Goals:** five per spot. Their text must fit half the narrowest screen, which
  a test checks. The letters goal counts letters found on any run, not just this
  one (`Progress.completeEarnedLetterGoals` also fixes older saves at launch).
  Finishing a city's last goal sets off fireworks that spell the city's name,
  then the results come up with more going off behind.
  A grind goal ("GRIND FOUNTAIN", 1 s) needs a feature of that kind long enough
  to grind that long at the spot's top speed. A test checks this too, so if you
  shorten a feature or raise a goal's seconds, run it.
- **Look:** a new spot needs a `Theme` case and a look in `ThemeArt.look(for:)`.

### Scoring, in short

- **Tricks:** each trick has points. The combo multiplier is the number of tricks.
- **Combo meter:** after a clean landing the combo stays open for 1.2 s. Another
  trick in that time keeps it going; a plain ollie doesn't count. Otherwise it
  banks. A bail loses it.
- **Clearing:** getting all the way over something in the air adds points to
  the combo. Bigger and moving things are worth more, times the trick you did
  over it.
- **Named gaps** add a fixed bonus to the combo.

### The controls, in short

- **The ollie pops on touch-down.** Holding makes gravity lighter while rising,
  so you go higher.
- **An up or down swipe within 0.15 s of the pop** takes the ollie back and
  changes lanes instead.
- **On the ground:** a sideways swipe ollies straight into a kickflip (left) or
  heelflip (right).
- **In the air:**
  - tap: grab
  - hold: long grab
  - swipe left: kickflip
  - swipe right: heelflip
  - swipe down: shove-it
  - swipe up: 360 flip
- **Grinds** lock on when you land on a rail or ledge (a 50-50). On the rail:
  - tap: hop off
  - swipe up: ollie out into the lane above
  - swipe down or sideways: switch to a boardslide, and back. The board turns
    across the rail and the skater holds their arms out, wobbling.
- **After a bail,** an up or down swipe gets up in another lane.

---

## Saved data

Everything is in `UserDefaults` (see `Progress.swift` and `Store.swift`). **These
keys and IDs are saved on players' phones: don't rename them.**

| Key | What |
| --- | --- |
| `outfit` | The skater and colors, as JSON. |
| `letters.<cityID>` | Letters found in a city, by index. |
| `bestScore.<levelID>` | Best score at a spot. |
| `goals.<levelID>` | Goal IDs done at a spot. |
| `soundMuted` | Sound effects off. |
| `musicOff` | Music off. |
| `fullGameUnlocked` | Cached full-game ownership. The App Store is the source of truth. |

Watch out for:

- **Old skater names:** Pat and Sammy were renamed from Terry and Sam, so their
  saved names are still `"terry"` and `"sam"` (`case pat = "terry"` in
  `Characters.swift`). A test makes sure old saves still load.
- **IDs:** level IDs (`"downtown"`, `"skidmore"`...), city IDs (`"portland"`...)
  and goal IDs (`"downtown.score"`...) are part of saved data. Change the
  on-screen text freely, but keep the IDs.

---

## Store

`Store.swift` is StoreKit 2, the same shape as the other Tuesday Games apps.

| Product ID | Type | Price | Status |
| --- | --- | --- | --- |
| `com.tuesdaygames.smalltip` | Consumable | $0.99 | Live in the app |
| `com.tuesdaygames.mediumtip` | Consumable | $2.99 | Live in the app |
| `com.tuesdaygames.largetip` | Consumable | $4.99 | Live in the app |
| `skate.fullgame` | Non-consumable | $4.99 | **Not on sale yet** |

- **The tip jar** is meant to be easy to find: a pink TIP JAR button sits on the
  title, the city picker, the spot list, every finish screen and the full game
  screen. It always shows all three tips, using the App Store's prices once
  they load.
- **The full game** goes on sale when the other cities are ready. Until then
  `Store.fullGameOnSale` is `false`: the locked cities show a padlock and a
  FULL GAME button that opens a "coming soon for $4.99" screen.
- **Putting the full game on sale:**
  1. Turn the flag on.
  2. Make the cities it unlocks open when `Store.shared.isUnlocked`.
  3. Add Restore Purchases and Redeem Code, as in Sevens.
- **App Store Connect:** the products must exist there with exactly these IDs
  before TestFlight or App Store builds can sell them. Running from Xcode uses
  `skateTests/Skate.storekit` instead.
- **Debug builds:** `Store.shared.debugOverride` can pretend the full game is
  owned.

---

## Testing

- **Where:** all the tests are in `skateTests/skateTests.swift`, in suites:
  gestures, combos, the run, goals, the tutorial, rewards, characters and the
  store.
- **Tools:** `@Test` and `#expect` from Swift Testing.
- **Helpers:** the top of the file has a few:
  - `street(...)` builds a test level.
  - `play(&run) { until }` steps a run until a condition is true.
  - `tap(&run)` taps.
  - `rollUntilBanked(&run)` plays on until the combo banks.
- **Placing things:** tests put features relative to `ollieTopX`, where a tapped
  ollie peaks, so they keep working if the tuning numbers change.

What the tests don't cover is **feel**: timing, gravity, how hard the spots are.
That needs a real phone. The simulator can't judge it, and haptics don't work
there at all.

---

## If you're coming back after a long time

- **Read `BACKLOG.md` first.** Its "Decided" list explains why things are the
  way they are, and its to-dos say what was next.
- **Xcode:** the project was written by Xcode 27.2 in its newer project format,
  `skate.xcodeproj/project.xcproj`. If a much newer Xcode wants to upgrade it,
  let it. If an older one can't open it, that's why.
  - **Files:** folders are synced, so any `.swift` file you add under `skate/`
    or `skateTests/` is in the build automatically.
  - **Scheme:** the shared scheme in `skate.xcodeproj/xcshareddata/xcschemes`
    carries the StoreKit test setting.
- **Landscape only, and full screen on iPad.** The App Store rejects an iPad app
  that supports only some orientations unless it opts out of iPad multitasking,
  so the project sets `UIRequiresFullScreen` (`INFOPLIST_KEY_UIRequiresFullScreen`).
  Apple deprecated that key in iPadOS 26 and says it will be ignored one day. When
  it is, the game must handle portrait and any window size on iPad, which
  `PixelLayout` mostly does already.
- **The minimum iOS version (16)** is the oldest one this code is known to build
  for, and the only reason it's that low. Raising it is safe. Some code checks
  `#available(iOS 17.0, *)` for StoreKit's purchase sheet and can be simplified
  once 17 is the minimum.
- **APIs that tend to change between iOS versions:**
  - StoreKit 2 (`Product`, `Transaction`)
  - Core Haptics
  - `AVAudioSession`
  - SpriteKit, which has been stable for years

  If something breaks after an OS update, look at `Store.swift`, `Haptics.swift`
  and `Sounds.swift` first.
- **App Store listing:** `AppStore/listing.md` has every field and
  `AppStore/checklist.md` the steps. The support and privacy pages are in
  `docs/`, served by GitHub Pages at `https://cmubick.github.io/skate/`.
- **Screenshots and store art** come from the game itself: `AppStore/make_assets.sh`
  runs a debug build with `-marketing YES`, which stages moments in real spots
  (`Run.stage`, `GameScene.stageForMarketing`), captures them at one pixel per
  game pixel and scales them up by whole numbers to Apple's exact sizes. Change
  shots or captions in `skate/Marketing.swift`. If the game's look changes,
  re-run it.
- **The privacy manifest** (`skate/PrivacyInfo.xcprivacy`) declares UserDefaults
  use. Update it if you add tracking, analytics or other required-reason APIs.
- **Not done yet** (see `BACKLOG.md`):
  - a real downhill slope on the Zoo Bomb
  - the other eight cities
  - the full game purchase
  - prices in currencies other than `$` in the pixel font
  - slow motion on big combos (built, switched off)
  - on Android: the Play Console setup and listing, and a playtest on a phone
    (see `android/README.md`)

## Contributing

- **Rules vs drawing:** keep rules in `Rules/` with no SpriteKit, and drawing in
  `UI/` or the scenes.
- **Tests:** add a test for any rule you change. Run the whole suite before
  committing.
- **Android:** make every change in `android/` too, and keep the parity tests
  passing (see [Android](#android)).
- **Tuning:** put feel numbers in `Tuning.swift`, not inline.
- **Decisions:** write new design decisions into `BACKLOG.md` as you make them.
- **Keep this README current.** Update the sections a change affects (layout,
  controls, scoring, spots, saved data, store, testing, what's not done yet) in
  the same commit as the change.
- **Saved data:** don't rename saved IDs or UserDefaults keys (see
  [Saved data](#saved-data)).
- **Commit messages:** a short summary line, a blank line, then bullet points.
