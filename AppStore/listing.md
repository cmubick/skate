# App Store listing for Skate

Everything to paste into App Store Connect, field by field. Character limits are
Apple's, and counts are in brackets. Items marked **YOU** need a decision or a
detail only you have; nothing there is guessed.

Sources for the limits and rules: Apple's
[asset best practices](https://developer.apple.com/app-store/asset-best-practices/),
[product page](https://developer.apple.com/app-store/product-page/) guide, and the App
Store Connect help pages for screenshots, creative assets, platform version
information and in-app purchases (read 2026-11-23).

---

## App information (left side: General → App Information)

### Name (30 max)

Pick one, then check it's free when you create the app record. App Store Connect
says straight away if a name is taken, and plain "Skate" almost certainly is. **YOU**

| Option | Count | Why |
|---|---|---|
| `Skate: Tuesday Games` | [20] | Matches Mahjong and Sevens. Recommended. |
| `Skate: 8-Bit Skateboarding` | [26] | Puts "skateboarding" in the name, which search weighs most. |

Neither names a city: Portland is the first of the game's cities, not the game.

The name under the icon stays **Skate** (set in the project).

### Subtitle (30 max)

- With `Skate: Tuesday Games`: **`One-Thumb Pixel Skateboarding`** [29]
- With `Skate: 8-Bit Skateboarding`: **`One-Thumb Street Tricks`** [23]

### Category **YOU**

- **Primary:** Games
- **Game subcategories:** Sports, then Action. Skateboarding games are usually
  listed under Sports. The project's own setting is Action, which you can keep as
  the second.
- **Secondary category (optional):** leave blank, or Games → Arcade.

### Content Rights

App Store Connect asks: "Does your app contain, show, or access third-party
content?" **YOU**. Here are the facts to decide from:

- All the art, sound and code is original, drawn and synthesized in the app.
- The backdrops include pixel drawings of real Portland landmarks: Big Pink, the
  Hawthorne Bridge, Tilikum Crossing, the Steel Bridge, OMSI, Paul Bunyan, Mt Hood,
  the Chinatown gate, Skidmore Fountain, the Portland Building with the
  **Portlandia** statue, and the White Stag **"PORTLAND OREGON"** sign.
- **Flag:** as far as I know, Portlandia's sculptor holds its copyright and has
  enforced it, and the City of Portland holds a trademark on the White Stag
  sign's image. That's general knowledge I haven't checked here. Both are in the
  game itself (Downtown and Skidmore backdrops). I kept them out of the header
  and search art, but they appear small in two screenshots ("Grind real city
  spots" shows the sign; "Nail the big gaps" shows the statue). Decide whether
  to keep, redraw or remove them before release.

### Age rating questionnaire

Apple's current questionnaire, with the answers that match the game:

| Question | Answer | Why |
|---|---|---|
| Parental controls | No | None in the app. |
| Age assurance | No | None in the app. |
| Unrestricted web access | No | No web views or links. |
| User-generated content | No | |
| Social media / Messaging and chat | No | |
| Shared location | No | |
| Advertising | No | No ads. |
| Gambling / Simulated gambling | None | |
| Contests | None | Scores are your own; nothing is entered or won. |
| Loot boxes | No | Tips unlock nothing. |
| Cartoon or fantasy violence | None | Bails are a skater falling off their board. |
| Realistic violence, guns, weapons | None | |
| Mature or suggestive themes | None | **See the flag below.** |
| Profanity or crude humor | None | **See the flag below.** |
| Horror/fear themes | None | **See the flag below.** |
| Alcohol, tobacco, drugs | None | |
| Sexual content, nudity | None | |
| Medical or treatment information, health and wellness | None | |

Expected result: 4+.

**Flag (YOU):** Burnside Skatepark's wall has graffiti drawn in the backdrop:
"SK8 OR DIE", skulls, crossbones and anarchy symbols. It's in the game only, not
in any store image. If you'd rather not explain it, I can redraw the wall with
milder tags ("SK8", "PDX", "DIY", "THRASH" are fine already) before you submit.

### App Privacy

- **Do you or your third-party partners collect data from this app?** No.
- Shown on the store page: **Data Not Collected**.

Checked against the code: no network requests (only Apple's StoreKit for tips),
no analytics, ads, accounts or third-party SDKs, and `PrivacyInfo.xcprivacy`
declares no tracking. Progress is saved on the device only.

### App Accessibility (Accessibility Nutrition Labels)

Apple says these labels are voluntary for now ("providing these labels will be
voluntary to start") and will be required later. They're answered per device.
Honest answers for this version, the same for iPhone and iPad:

| Feature | Supported? | Why |
|---|---|---|
| VoiceOver | No | A SpriteKit game with no accessibility labels; it can't be played without sight. |
| Voice Control | No | Played by tap, hold and swipe; nothing is labeled for voice. |
| Larger Text | No | The pixel font is a fixed size. |
| Differentiate Without Color Alone | No | Found letters and done goals are shown gold against grey, by color only. |
| Reduced Motion | No | Parallax backdrops and spinning boards are motion triggers in Apple's criteria. |
| Captions | Not applicable | No video, speech or dialogue. Leave unselected. |
| Dark Interface, Sufficient Contrast, Audio Descriptions | Leave unselected | I couldn't read Apple's criteria pages for these, so I'm not saying yes. |

Recommendation: leave the section unanswered for 1.0, or answer as above.
Supporting "Differentiate Without Color Alone" would be a small change: mark
found letters some other way too.

### App Compliance **YOU**

This section is new. I couldn't find Apple's documentation for it, so these
are the compliance items Apple's help pages do describe, with how they apply:

- **EU Digital Services Act trader status:** required to sell in the EU. Whether
  you're a "trader" is a legal question about you, not the app. Selling in-app
  purchases as a business usually means yes, which shows your contact details on
  the EU store page. If you've answered it for Mahjong or Sevens, it's an account
  setting, so it may already be done.
- **Encryption (export compliance):** already handled. `Info.plist` sets
  `ITSAppUsesNonExemptEncryption` to NO, so uploads won't ask.
- **Korea (GRAC rating number):** not needed. Only for games rated 17+ or with
  gambling-like content.
- **China mainland and Vietnam:** games need a government license there. Leave
  those two countries out of Availability unless you get one.
- **Privacy Policy URL, Age Rating:** covered above and below.

If App Compliance asks something not covered here, screenshot it and send it to
me. I'll look it up rather than guess.

---

## Version page (iOS App 1.0)

### Promotional text (170 max) [162]

> Kickflip, grind and combo through real city spots with one thumb. Start in Portland: six spots, goals at every one and hidden letters to find. No ads, no account.

### Description (4000 max) [1284]

> Skate real city streets with one thumb.
>
> Tap to ollie, swipe to flip, and land on rails, ledges and benches to grind them. String tricks together into big combos, nail each spot's named gaps, and find the hidden letters that spell out the city's name.
>
> START IN PORTLAND
> • Six spots: Downtown, Skidmore Fountain, Burnside Skatepark, North Portland, the SE Waterfront and Zoo Bomb
> • Dodge or ollie light rail trains, joggers, bikes, shopping carts, goats, penguins and Zoobombers on little bikes
> • Bridges, Mt Hood, Big Pink, Paul Bunyan and the food carts roll by behind you
>
> ONE-THUMB TRICKS
> • Ollies, kickflips, heelflips, shove-its, 360 flips and grabs
> • 50-50s and boardslides on rails, ledges, benches, curbs and fountains
> • Quarter pipes that send you flying
> • Swipe to switch lanes
>
> GOALS AND SECRETS
> • Five goals at every spot, from high scores to named gaps
> • Hidden letters at every spot: find them all to spell out the city and win a special board
> • Skate as Pat, Sammy or Angie the dog, in the colors and board you pick
>
> PLAY ANYWHERE
> • A tutorial teaches every move, one at a time
> • Plays entirely offline
> • No ads, no account, no data collected
> • Retro 8-bit art and sound, with haptics
>
> The tip jar is optional and unlocks nothing. Every tip helps us keep making games.

### Keywords (100 max, commas, no spaces) [97]

`skateboard,skater,kickflip,ollie,grind,tricks,8-bit,retro,arcade,city,street,combo,runner,offline`

These assume the name `Skate: Tuesday Games` and subtitle `One-Thumb Pixel
Skateboarding`; Apple searches the name and subtitle too, so their words are
left out. With `Skate: 8-Bit Skateboarding` / `One-Thumb Street Tricks`, swap
`8-bit` and `street` for `pixel` and `sport`.

### What's New

Not asked for a first version.

### URLs

- **Support URL:** `https://cmubick.github.io/skate/` (the page is `docs/index.html`)
- **Privacy Policy URL:** `https://cmubick.github.io/skate/privacy.html`
- **Marketing URL:** optional; leave blank.

Both go live once GitHub Pages is on: in the repo's **Settings → Pages**, pick
**Deploy from a branch**, branch `main`, folder `/docs`. **YOU**

### Copyright

`2026 Tuesday Games` (App Store Connect adds the © itself)

### App Review Information

- **Sign-in required:** No.
- **Contact first and last name, phone, email:** **YOU**. The phone number needs
  `+` and the country code.
- **Notes:** paste the block in [Notes for App Review](#notes-for-app-review).
- **Attachment:** the screen recording (see below).

---

## Screenshots and art

All rendered from the game itself by `AppStore/make_assets.sh` (see
`skate/Marketing.swift`). PNG, no transparency, exact sizes:

| Slot in App Store Connect | Folder | Size |
|---|---|---|
| iPhone, Dynamic Island, medium (6.1"/6.3"): **required** | `upload/Screenshots iPhone 6.1in/` | 2556 × 1179 |
| iPhone, Dynamic Island, large (6.9"): optional | `upload/Screenshots iPhone 6.9in/` | 2868 × 1320 |
| iPad 13": **required** (the game runs on iPad) | `upload/Screenshots iPad 13in/` | 2752 × 2064 |

Upload in this order (the first three show in search results, so they lead with
the best features, as Apple's guide asks):

1. `1-flip`: **FLIP IT WITH ONE THUMB**: a kickflip over two cones Downtown.
2. `2-grind`: **GRIND REAL CITY SPOTS**: a 50-50 on Skidmore Fountain.
3. `3-combo`: **STACK UP HUGE COMBOS**: a 360 flip over a barrier on Zoo Bomb, four tricks deep.
4. `4-angie`: **SKATE AS ANGIE THE DOG**: Angie boardsliding a handrail on the waterfront.
5. `5-letters`: **SPELL OUT THE CITY**: grinding a bench for a letter by the food carts.
6. `6-gaps`: **NAIL THE BIG GAPS**: the Pioneer Gap, rail to rail.
7. `7-goals`: **5 GOALS AT EVERY SPOT**: the goals screen.
8. `8-skater`: **PICK YOUR SKATER**: the skater builder.

Captions are short phrases, as Apple suggests, with no prices, URLs or claims.

### Header and search results (General → Header and Search Results)

In `upload/Header and Search Results/`:

| Asset | File | Size | Notes |
|---|---|---|---|
| Header (21:9) | `header.png` | 3840 × 1646 | Skater inside the 1646 × 661 safe area |
| Universal (16:9) | `universal.png` | 5244 × 2950 | Skater inside the 1402 × 962 safe area. Use this if you want one image for both. |
| Search results (3:2) | `search-results.png` | 3840 × 2560 | Skater inside the 2168 × 1030 safe area |

All three are the same moment: Pat ollieing high over a bench on the waterfront,
on a white board so it stands out from the boardwalk, with
Tilikum Crossing, Mt Hood, the Steel Bridge and Big Pink behind. No text, since
Apple overlays the app's name. To see the safe areas drawn on, run
`swift AppStore/check_safe_areas.swift <folder>`. Use Apple's Preview in App
Store Connect to check on each device before publishing.

### App previews (video)

Optional, and none made yet: 15 to 30 seconds, 1920 × 886 for iPhone and
1600 × 1200 for iPad, up to 30 fps. Apple's guide says they play muted, so the
first seconds should hook without sound. I can record one from the simulator if
you want it.

---

## In-app purchases

Create the three tips under **Monetization → In-App Purchases** with exactly these
product IDs (the app looks them up by ID). Display names match the store file
and the tip jar's SMALL / GENEROUS / BIG, the same names as Mahjong and Sevens.

| Product ID | Type | Reference name | Price | Display name (30 max) | Description (45 max) |
|---|---|---|---|---|---|
| `skate.tip.small` | Consumable | Small tip | $0.99 | Small tip [9] | A small thank-you to Tuesday Games. [35] |
| `skate.tip.medium` | Consumable | Generous tip | $2.99 | Generous tip [12] | A generous thank-you to Tuesday Games. [38] |
| `skate.tip.large` | Consumable | Big tip | $4.99 | Big tip [7] | A very generous thank-you to Tuesday Games. [43] |

- **Promotional image** (optional, 1024 × 1024), in `upload/In-App Purchases/`:
  `promo-small-tip.png`, `promo-generous-tip.png` and `promo-big-tip.png`, one per tip,
  as Apple asks. A tip jar filling up; no text, nothing in the lower-left corner
  where Apple's frame can put the app icon. Remade by
  `AppStore/make_assets.sh`.
- **Review screenshot** for all three: `upload/In-App Purchases/review-screenshot-all-tips.png` (2556 × 1179,
  the tip jar screen). It goes under Review Information, not the promotional image.
- **Review notes** for all three: "Tap TIP JAR on the title screen (it's also on
  the city picker, the spot list and every finish screen). Tips are optional, can
  be given more than once and unlock nothing; the screen says THANK YOU! after a
  tip."
- **The full game** (`skate.fullgame`) is not on sale. Don't create it yet, or
  create it and leave it out of this submission.
- On the version page, under **In-App Purchases and Subscriptions**, select the
  three tips so they're reviewed with 1.0.
- Selling anything needs the Paid Apps agreement, with banking and tax details.

---

## Notes for App Review

Apple's first review of Sevens asked six questions ("Guideline 2.1 – Information
Needed"). These notes answer them up front. Paste into App Review Information →
Notes:

```
1. SCREEN RECORDING
See the attached video, recorded on an iPhone. It shows launching the app, the tutorial, choosing Portland and a spot, a run with tricks, grinds and a goal, the skater builder, and the tip jar with a tip.

2. PURPOSE AND AUDIENCE
Skate is a single-player, 8-bit skateboarding game for all ages, played with one thumb. The skater rolls on their own through real city spots, starting with six in Portland, Oregon; you tap, hold and swipe to ollie, flip, grind and change lanes, building combos for points and completing goals at each spot. No ads and no account.

3. SETUP AND ACCESS
No account, login or setup is needed, and the app works offline. From the title screen:
- PLAY: choose a city (Portland is open), tap GO, then pick one of six spots. Each spot lists its goals before the run.
- TUTORIAL: a practice street that teaches each move one at a time.
- SKATER: pick Pat, Sammy or Angie the dog, and their colors and board.
- TIP JAR: three optional tips (consumable in-app purchases). Tips unlock nothing.
The pause button (top right) during a run shows the goals and lets you quit.
Other cities in the city picker show "Coming soon in the full game". Nothing can be bought for them in this version; that purchase is not offered.

4. EXTERNAL SERVICES
None, other than Apple's In-App Purchase (StoreKit) for tips. The app makes no network requests of its own and uses no third-party SDKs, analytics, advertising, authentication, data providers or AI services. All art and sound is drawn and generated in the app.

5. REGIONAL DIFFERENCES
None. The app behaves the same in every region. It is in English only.

6. REGULATED INDUSTRY OR THIRD-PARTY MATERIAL
The app is not in a regulated industry, and there is no real-money play, betting or wagering. The backdrops include original pixel-art drawings of public Portland landmarks and streets. No third-party artwork, music or code is used.
```

**YOU, before pasting item 6:** decide about Portlandia and the White Stag sign
(see Content Rights above), and adjust that sentence to match.

**The screen recording (YOU):** 1 to 2 minutes on your iPhone, starting from the
home screen. Show: launch, Tutorial for a few steps, back, PLAY → Portland → GO →
Downtown, GO, a run with an ollie, a flip and a grind, the pause menu, the finish
screen, SKATER, then TIP JAR and a tip. Tips in a TestFlight build are free test
purchases.

**Flag (YOU):** the full game screen says "COMING SOON FOR $4.99" and locked cities
say "COMING SOON". App Review sometimes objects to features shown but not yet
available. Item 3 explains it, but the safest version hides the price, or the
locked cities, until the full game is on sale. Say if you want me to change it.
