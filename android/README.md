# Skate for Android

The Android port of the iOS game in `../skate`. Kotlin, Gradle (Kotlin DSL), set up the same way as Sevens' Android port (`~/repos/sevens/sevens/android`). It plays and looks the same as the iOS game: the rules are the same code translated, and tests check every picture, sound, song and a scripted run on every spot against the Swift code itself.

Published by Tuesday Games. The app's ID, which Google Play and Android use to tell apps apart, is `com.tuesdaygames.skate`, the same as the iOS bundle ID. It cannot be changed once the app is on Google Play.

- **Android 8.0 (API 26) and later**, landscape only (either way round), full screen.
- **No game engine and no art or sound files**, as on iOS: everything is drawn and synthesized in code. The only libraries are AndroidX Activity and Core, and Google Play Billing.

## Layout

- `rules/` is the game itself: tuning, gestures, tricks, the run, levels and Portland's six spots, goals, the tutorial, skaters and outfits, saving, `PixelLayout` and the pixel font's letter shapes. Plain Kotlin with no Android in it, ported file for file from `../skate/Rules`. Its tests are in `rules/src/test`.
- `app/` is the Android app:
  - `art/` is every picture, ported file for file from `../skate/UI/*Art.swift` and `PixelArt.swift`. Plain Kotlin too: a `PixelCanvas` is an array of colors, so the tests can compare it with iOS.
  - `sound/` has the sound effects (`SoundSynth.kt`), the music synth and songs (`Chiptune.kt`, `Songs.kt`), and the players (`Sounds.kt`, `Music.kt`, and `Mixer.kt`, which mixes voices into an AudioTrack).
  - `game/` is what SpriteKit does on iOS, and the scenes. `Scene.kt` is a small stand-in for the parts of SpriteKit the game uses (nodes, sprites, z order, a camera, and the move, fade, wait, sequence, group and repeat actions). `GameView.kt` sizes the game in whole pixels, runs the frame loop, draws the nodes and passes touches on (the counterpart of `GameViewController.swift`). `GameScene.kt` and `MenuScene.kt` are ported line for line from `GameScene.swift` and `Menus.swift`.
  - `haptics/Haptics.kt`, `store/` (`Store.kt` is what the game knows about purchases, `PlayStore.kt` talks to Google Play), `Prefs.kt` (saving) and `MainActivity.kt`.
- `tools/parity/` builds the iOS rules, art and sound code as a little Mac program and writes the fingerprints the parity tests compare against. `tools/icon/` draws the launcher icon from the iOS one.
- `gradle/libs.versions.toml` holds every version number in one place.

## Running it from Android Studio

1. In Android Studio choose **Open** and pick this `android` folder (not the repository root). Wait for the Gradle sync to finish.
2. Pick the **Medium Phone** emulator (or a phone plugged in) and press the green **Run** arrow.

## Command line

Use Android Studio's own Java so the build does not depend on whatever Java the Mac has:

```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
./gradlew :rules:test              # the rules' tests (no Android SDK needed)
./gradlew :app:testDebugUnitTest   # the art, sound, music and store tests
./gradlew assembleDebug            # builds app/build/outputs/apk/debug/app-debug.apk
./gradlew installDebug             # installs it on a running emulator or plugged-in device
```

`local.properties` tells Gradle where the Android SDK is. It is specific to this Mac and is not committed; Android Studio recreates it if it is missing.

### Debug switches

Debug builds take the same switches as the iOS launch arguments, as intent extras:

```bash
ADB=~/Library/Android/sdk/platform-tools/adb
$ADB shell am start -n com.tuesdaygames.skate/.MainActivity --es page cities     # or spots, builder, tips, fullgame
$ADB shell am start -n com.tuesdaygames.skate/.MainActivity --es level waterfront # straight to a spot (any spot id)
$ADB shell am start -n com.tuesdaygames.skate/.MainActivity --ez fireworks true   # the all-goals fireworks on Downtown, saving nothing
$ADB shell am start -n com.tuesdaygames.skate/.MainActivity --ez hideFPS true     # no frame counter, for clean screenshots
$ADB shell am start -n com.tuesdaygames.skate/.MainActivity --ez unlocked true    # pretend the full game is owned
```

Close the app first (`$ADB shell am force-stop com.tuesdaygames.skate`) or the one already running carries on. Debug builds show frames per second in the bottom right corner, as SpriteKit does on iOS. The iOS `-marketing` switch (App Store screenshots) has no Android version yet.

## Tests

- **The rules** (`rules/src/test`): every test from `skateTests/skateTests.swift` about the rules, ported with the same names and numbers.
- **The app** (`app/src/test`): the iOS tests about art, food cart signs, songs and the store.
- **Parity with iOS** (`ParityTests.kt`, in both modules): every skater, board, spin frame, feature on every spot, backdrop, ground, letter token, icon and text sample must come out **pixel for pixel** the same as on iOS; every sound and song **sample for sample** (to within rounding); and a scripted player on every spot must see **exactly the same things happen, step for step**. The iOS side is in `src/test/resources/parity`.

**After changing the iOS art, sounds, songs or rules**, rebuild the fingerprints from the Swift code, then make the Kotlin match until the tests pass:

```bash
sh android/tools/parity/make_fixtures.sh   # from the repository root; needs Xcode
```

What the tests don't cover is feel, as on iOS: that needs a real phone.

## How the Kotlin differs from the Swift

The names and comments follow the Swift code. The differences are the ones Kotlin forces:

- Swift's `name` on enums is `displayName` (`Trick.Kickflip.displayName` is "KICKFLIP"), because every Kotlin enum already has a `name`. `ColorChoice`'s raw value is its `@SerialName`.
- Enum cases are capitalised: `Lane.Back`, `Trick.ThreeSixtyFlip`.
- Two cases are renamed: the goal `.gap(name)` is `Goal.Kind.GapNamed`, and the run event `.gap(name, points)` is `RunEvent.GapDone`.
- Swift structs are copied when assigned. `Level`, `Feature`, `Outfit` and the others are data classes, changed with `copy(...)`; `outfit.switchSkater(to:)` is `outfit.switchingSkater(kind)` and returns the new outfit. `Run`, `Combo`, `GoalTracker`, `Tutorial` and `GestureReader` change in place, and `Combo.copy()` makes the copy the Swift code got for free.
- Swift rounds halves away from zero and Kotlin rounds them to even, so `rounded()` in `rules/SwiftMath.kt` does it Swift's way. `SeededGenerator` copies Swift's own random methods (`Int.random(in:using:)`, `Bool.random(using:)`, `randomElement(using:)`), so the same seed draws the same buildings, people and drips.
- Art functions return a `PixelCanvas` instead of an `SKTexture`; the game turns it into a `Texture` (an Android bitmap) with `.texture()`.

## Pixels and the screen

As on iOS: the game is at least 180 x 96 game pixels, each drawn as the largest whole number of screen pixels that fits (`PixelLayout`). A 2400 x 1080 phone gets 11 screen pixels per game pixel and a 218 x 98 game; an iPhone 18 Pro gets 218 x 100. The game draws edge to edge, under the camera cutout, with the system bars hidden (a swipe from the edge shows them for a moment). Buttons and the HUD keep inside the **safe area**: the cutout and any bars showing, with the same margins as on iOS.

Pictures are drawn with nearest-neighbour scaling, so the pixels stay square and sharp.

## Controls

The same as on iOS (see the main README). Swipes are measured in dp (Android's points), so a swipe is 30 dp, about the same distance on the glass as 30 points on an iPhone.

Android has a **back button** (or back gesture), which iOS doesn't: during a run it pauses; on the pause or goals screen it leaves for the spot list; on a menu it goes back a page, as that page's BACK button does; on the title it puts the app in the background. Going to the home screen mid-run pauses it, as on iOS.

## What the app saves

Android's SharedPreferences, the counterpart of iOS's UserDefaults, in `shared_prefs/skate.xml` in the app's private folder, under **the same keys as iOS**: `outfit` (JSON, in the iOS shape, so Pat and Sammy still save as `"terry"` and `"sam"`), `letters.<cityID>`, `bestScore.<levelID>`, `goals.<levelID>`, `soundMuted`, `musicOff` and `fullGameUnlocked`. Lists (letters, goals) are kept as one string of items joined by commas, where iOS keeps an array, so the files are not interchangeable with iOS, and needn't be. Don't rename the keys or IDs: they're on players' phones.

```bash
$ADB shell run-as com.tuesdaygames.skate cat shared_prefs/skate.xml
$ADB shell pm clear com.tuesdaygames.skate      # wipes everything the app has saved
```

Android deletes it all when the app is uninstalled. Backups are on (`allowBackup`), so a new phone gets progress back from the player's Google backup.

## Purchases

As on iOS: three tips, which unlock nothing, and the full game (`skate.fullgame`), which isn't on sale yet (`Store.fullGameOnSale` is false; the locked cities say coming soon). Google takes the payment; the app only asks Google Play what was bought.

| Product ID | Name in the Play Console | Price | Shown as |
| --- | --- | --- | --- |
| `skate.tip.small` | Small tip | $0.99 | SMALL |
| `skate.tip.medium` | Generous tip | $2.99 | GENEROUS |
| `skate.tip.large` | Big tip | $4.99 | BIG |
| `skate.fullgame` | (not on sale yet) | $4.99 | |

Until the products exist in the Google Play Console, the tip jar shows US prices and a tap says TIPS AREN'T SET UP YET. What has to be set up before a real purchase can be tested (Google's process; not tried with this app yet, and the same steps as Sevens):

1. Create the app in the Play Console with the package name `com.tuesdaygames.skate`.
2. Upload a signed release build to the **Internal testing** track. Google only lets an app sell things once a build that includes the billing library has been uploaded.
3. Under Monetize, create three one-time products with exactly the IDs above, and activate them.
4. Add your Google account as a **license tester** (Play Console settings), so purchases are free test purchases, and as a tester on the internal track.
5. Run the app on a phone or emulator that has the Play Store and is signed in with that account.

Differences from the iOS store: tips are "consumed" straight away so they can be bought again, as Google requires (see the top of `PlayStore.kt`), and the full game will be "acknowledged" once it's on sale. Purchases aren't checked against a server, the same as on iOS. Prices in currencies other than `$` show `?` in the pixel font, as on iOS.

**Putting the full game on sale** is the same as on iOS (turn on `Store.fullGameOnSale`, open the cities, add Restore Purchases), plus a Redeem Code button that opens the Play Store's redeem page, as Sevens does.

## Sound and music

The same sounds and songs as iOS, generated by the same recipes (the parity tests check). `Mixer.kt` mixes them into one AudioTrack: six voices take turns with the one-off sounds, each looping sound (rolling, the three grinds) has its own, and music plays on a second one. Volumes are the iOS ones.

- **Switches:** the music note and speaker in the top left of the title, goals and pause screens, separate and remembered, as on iOS.
- **Silent mode:** unlike an iPhone's silent switch, an Android phone on silent doesn't mute a game; the switches do. The game follows the media volume.
- **Other apps' music:** the game never asks to take over the sound, so music from another app keeps playing under it, and the game's own music stays off if something else is already playing music when a spot starts (as on iOS). Android only says whether any music is playing, so while the game's own sound is going it assumes that's all there is.
- Songs are rendered on a background thread the first time a spot needs them, then kept.

## Haptics

The vibration motor, which is why `AndroidManifest.xml` asks for the `VIBRATE` permission (Android grants it without asking). The same moments as iOS: a tap on every pop, a snap on landings (a double one for a perfect landing, a goal or a gap), a thud on bails, a double tap at the finish, and a buzz all along a grind. Android 11 and later play its "primitives" (click, tick, thud) at a strength, the nearest thing to iOS's kinds of tap; older phones get short buzzes. A phone has one motor, so the grind's lock-on knock and buzz are one pattern, and other taps are skipped while the grind buzz is on. From Android 13 they follow the phone's own Touch feedback setting. The emulator has no motor, so this can only be judged on a real phone.

## The launcher icon

The iOS icon, drawn by `tools/icon/make_icons.swift` as an adaptive icon: the 32 x 32 picture at a whole number of screen pixels per pixel in the middle, its edges stretched out, so whatever shape a phone crops it to cuts sky and street rather than the skater. To redraw it after changing the iOS icon:

```bash
swift AppStore/icon/make_icon.swift /tmp/icon.png light
swift android/tools/icon/make_icons.swift /tmp/icon.png android/app/src/main/res
```

## Not done yet

- **Play it on a real Android phone:** feel, haptics and sound latency can't be judged in the emulator.
- **Google Play Console:** the app record, the three tip products, the store listing, screenshots and feature graphic, the data safety form and content rating. The iOS listing text in `AppStore/listing.md` is a starting point.
- **Release signing:** an upload key, kept out of the repository (`*.jks` and `*.keystore` are ignored).
- **Store screenshots from the game**, like the iOS `-marketing` switch.
- Everything on the iOS to-do list (`BACKLOG.md`) applies here too, Game Center aside: its Android counterpart would be Google Play Games.
