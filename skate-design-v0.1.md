# Skate side-scroller: design doc v0.1

Exported 2026-11-22 from the Claude Doc: https://claude.ai/artifact/GSopCnuWoDyBs6MbG7k2gi
The Claude Doc is the source of truth. Re-export if it changes.

## Pitch and pillars

A one-thumb, 8-bit skate side-scroller where each level is a run through a real city, starting with Portland. You tap to ollie, swipe in the air to flip, land on rails to grind, and hop between three lanes to find lines. Runs are 60 to 90 seconds, so a session fits in a coffee line. It shares its cities, landmarks and a cameo cast with the Angie dungeon crawler.

Working title is a placeholder until you pick one (open question 1).

**Pillars**

- **One thumb, deep skill.** Every move is a tap, a hold or a swipe. Mastery comes from timing and chaining, not more buttons.
- **Short runs, long goals.** Each run is quick, but each city has a set of goals that takes a few days to clear.
- **Real places, pixel style.** Recognizable spots (bridges, food carts, a rainy waterfront) drawn in a strict retro palette.
- **Feels great in the hand.** Haptics on every land, grind and bail, a tight chiptune loop, and crisp pixel animation. Same polish bar you set for Solitaire.

**What it is not**

- Not a 3D or free-roam skate sim. The camera only scrolls right.
- Not an endless runner. Levels are hand-built, with a start, a finish line and a clock.
- No ads, no energy timers, no loot boxes.

The retro NES skate games you mentioned are the reference for feel (side view, lanes, chunky sprites). The levels, characters, art and music here are all our own.

## Core controls

The skater rolls right on their own, and the whole game is played with one thumb anywhere on the screen. Speed is automatic but rises with clean landings and drops after a bail, so good play feels faster.

| Input | On the ground | In the air | On a rail or ledge |
| --- | --- | --- | --- |
| Tap | Ollie (short hop) | Grab trick (quick, low points) | Hop off with a pop |
| Hold, then release | Charged ollie: longer hold, higher jump (max about 0.5 s) | Hold a grab for more points, release before landing | Balance: hold to stay on, release to hop off |
| Swipe left, right or down | Swipe down: switch lane down | Flip tricks (kickflip, heelflip, shove-it) | Switch grind type |
| Swipe up | Switch lane up | Spin or bigger flip | Ollie out to the lane above |
| Land near a rail or ledge | Auto-lock into a grind if the board is within a small window | | |

**Lanes.** Three lanes (back, middle, front) layered on the sidewalk and street. A swipe up or down on the ground moves one lane. Lanes hold different lines: rails in the back, gaps in the middle, ramps and traffic up front. This gives route choice without adding buttons.

**Landing.** You land clean if the trick animation finishes before the wheels touch. Land mid-trick and you bail: a short tumble, combo lost, speed drops, no lives lost. A *perfect* landing (finishing in the last few frames) adds a small bonus and a stronger haptic.

**Grinds.** Landing on a rail or ledge within a forgiving window snaps you on. Holding keeps balance with a small meter that wobbles. Swipe while grinding to switch between 50-50, boardslide and nosegrind for variety and points.

**Tuning guesses (to test on device).** Lane swipe threshold about 30 pt. Tap vs hold split at about 120 ms. Grind snap window about 8 px at game scale. These are starting numbers, not decisions.

**Skater state map** (a diagram in the Claude Doc):

| From | Input or event | To |
| --- | --- | --- |
| Rolling (auto-push right) | Swipe up or down | Rolling, one lane over |
| Rolling | Tap, or release a hold | Airborne |
| Airborne (swipe flip, hold grab) | Clean landing | Rolling, combo banks |
| Airborne | Land on rail | Grinding |
| Airborne | Land mid-trick | Bail |
| Grinding (hold to balance) | Tap, or rail ends | Airborne |
| Bail (time, combo, speed lost) | Get up | Rolling |

All scoring happens while airborne or grinding. A clean landing banks the combo, and only a bail costs anything.

## Tricks and scoring

About 12 tricks at launch is enough: few enough to draw well in 8-bit, varied enough to chain. Points reward chaining tricks without touching flat ground.

| Trick | Input | Base points | Unlock |
| --- | --- | --- | --- |
| Ollie | Tap | 50 | Start |
| Grab | Tap in air | 100 | Start |
| Kickflip | Swipe left in air | 150 | Start |
| Heelflip | Swipe right in air | 150 | Start |
| Shove-it | Swipe down in air | 150 | Portland goal |
| 360 flip | Swipe up in air | 300 | Portland goal |
| Long grab | Hold in air | 100 + per 0.1 s | Start |
| 50-50 grind | Land on rail | 100 + per second | Start |
| Boardslide | Swipe while grinding | 150 + per second | Portland goal |
| Nosegrind | Swipe again while grinding | 200 + per second | Second city |
| Manual | Swipe down on landing | 50 + per second | Second city |
| Special | Fill the style meter, then swipe up twice | 1,000 | One per city |

**Combos.** Every trick in one chain adds +1 to the multiplier. Grinds and manuals link chains across the ground. Bail and the whole chain is lost. Land and it banks. This is the core risk-reward loop.

**Style meter.** Fills with clean landings and drains on bails. When full, the next special trick is available and haptics get stronger. Each city teaches its own special, so new cities feel new.

**Bails.** No health. A bail costs time on the clock, your combo and some speed. Runs end when the clock runs out or you cross the finish line.

All point values are first guesses to tune in playtests.

## Cities and levels

Each city is a map of about 10 spots, and each spot is one hand-built run of 60 to 90 seconds. Portland ships first. The same 10 spots are the locations in the Angie game, so both games share one city layout and one art set.

**Goals at each spot (5 per spot, 50 per city):**

1. Hit the score target.
2. Hit the high score target.
3. Collect the city's letters, scattered through the run (P-O-R-T-L-A-N-D). Longer city names mean longer hunts, which is a nice natural difficulty curve.
4. Find the hidden item (in Portland, one of Angie's tennis balls).
5. Finish a local's request: an NPC on the map asks for something specific, like "grind the whole waterfront rail" or "deliver this zine before the clock runs out."

Clearing goals opens the next spots and unlocks tricks, boards and outfits. Clearing 40 of 50 opens the next city.

**Draft Portland spots (guesses, swap freely):**

| # | Spot | What the run is about |
| --- | --- | --- |
| 1 | Downtown square | Tutorial: stairs, planters, benches |
| 2 | Waterfront park | Long rails along the river, joggers in the front lane |
| 3 | DIY skatepark under a bridge | Bowls and banks, the score run |
| 4 | Food cart pod | Tight lane switching around carts and lines |
| 5 | Giant bookstore block | Ledges, delivery-themed request goal |
| 6 | Old train station | Long platforms and luggage carts |
| 7 | Pedestrian bridge | Cables, no cars, a fast straight line |
| 8 | Arts district street | Murals, a street fair in the front lane |
| 9 | Rose garden hills | Terraces and drops |
| 10 | Volcano park hill bomb | Downhill speed run, the city finale |

These are described generically on purpose. We should draw real public places (parks, bridges, streets) and avoid business names and logos unless we get permission.

**Later cities.** Seattle and San Francisco are natural next picks for hills and rain, but that's your call (open question 3).

## Art and audio

NES-style rules, shared with the Angie game so one set of tiles and one palette serves both.

| Element | Spec (starting point) |
| --- | --- |
| Game resolution | 256 x 144 base, scaled up in whole steps, landscape. Close to the old 256 x 240 width but wide for phones |
| Palette | One fixed palette of about 54 colors, 4 colors per sprite or tile including clear |
| Tiles | 16 x 16 px, shared tile sheet per city with the Angie game |
| Skater sprite | 16 x 32 px, about 8 frames per trick, 4 for push and idle |
| Angie sprite | 16 x 16 px, reused from her game |
| Parallax | 3 layers: skyline, mid buildings, street |
| Music | Chiptune, 4 voices (2 square, 1 triangle, 1 noise). One loop per city plus a menu tune |
| Sound | Pop, land, grind hum, bail crunch, letter pickup chime. All toggleable |
| Haptics | Light tap on ollie, sharp tap on clean land, rolling buzz on grind, heavy on bail |

The orientation is landscape (a guess, see open question 4). Landscape gives more road to read ahead. Portrait would match one-hand play better but shows less of the run.

## Angie crossovers

The two games should feel like one world seen from two angles: top-down on foot (Angie) and side-on on a board (skater). Crossovers in order of cost:

1. **Shared places and NPCs (free, comes from shared art).** The same food cart owner or bookshop clerk appears in both games.
2. **Angie cameos.** Angie shows up in the background of runs. Find her in a run to clear a hidden goal.
3. **Angie rides.** Unlock Angie on her own little board as a playable skater. Dogs on skateboards is a proven delight.
4. **Story link.** The skater is Angie's owner. In the Angie game, a mission is to find the skater's lost board. In the skate game, a request is to find Angie after she runs off. Each game teases the other.
5. **Cross-game unlocks.** Owning both games unlocks a costume in each. Needs a shared account or iCloud key-value check, so it's a later step.

I'd ship 1 to 3 in the first version and save 4 and 5 for when both games are out.

## Business model

Same model as your other games: a real free game, a paid full game, a tip jar, and never ads.

| Tier | What's in it | Price (guess) |
| --- | --- | --- |
| Free | First 3 Portland spots, all goals in them, core tricks | Free |
| Full game | All of Portland, every later city as a free update, all tricks and unlocks, Angie as a skater | $4.99 one-time unlock |
| Tip jar | Three tip sizes, each adds a small thank-you sticker to the skater's board | $0.99, $2.99, $4.99 |

One in-app purchase for the full game keeps it simple to build and explain. Future cities stay free for owners, which rewards early buyers and makes each update a reason to come back.

## Scope for one developer

The first release is Portland only: 10 spots, 12 tricks, one skater plus Angie, one music loop. My rough guess is 4 to 6 months of part-time solo work, mostly in level building and art. Treat that as a guess until the prototype tells us how fast levels go.

**Engine.** Pick one engine for this and the Angie game so tiles, palette and tools carry over. Godot is a good fit: free, strong at pixel-perfect 2D, and exports to iOS and Android from one project. SpriteKit is faster if you stay iOS-only. Which one you use today matters most (open question 5).

**Milestones (in order, each ends with a playable build):**

1. **Feel prototype (2 to 3 weeks).** Grey boxes, one flat street. Ollie, lanes, one flip, one rail, haptics. Only goal: does it feel great with one thumb?
2. **One real spot (3 to 4 weeks).** Downtown square with final art style, letters, score, bail and clock. Use this as the style test for both games.
3. **Portland vertical slice (6 to 8 weeks).** First 3 spots, goals, the city map, save data. This is the free tier.
4. **Full Portland (6 to 8 weeks).** Remaining 7 spots, all tricks, Angie cameos and Angie as a skater, music.
5. **Ship (2 to 3 weeks).** Purchase and tip jar, TestFlight, store page, release on iOS. Android follows the same pattern as your other games.

**Cut list if time runs short:** manuals, the style meter, switching grind types mid-rail, and the hidden-item goal. The game still works without any of them.

## Open questions for Chris

- [ ] 1. What's the title? Same naming family as the Angie game, or its own thing?
- [ ] 2. Who is the skater? Your stand-in, a new character, or a choice of a few?
- [ ] 3. Which cities after Portland, and in what order? Should both games add cities in lockstep?
- [ ] 4. Landscape or portrait?
- [ ] 5. Which engine do Mahjong, Sevens and Beat Synth use, and do you want to reuse it here?
- [ ] 6. Which game ships first, skate or Angie? The first one pays for the shared art.
- [ ] 7. Is a clock on every run OK, or do you want a relaxed free-skate mode too?
- [ ] 8. Are the free tier (3 spots) and $4.99 unlock about right next to your other games' prices?
- [ ] 9. Manual is mapped to swipe down on landing, which is close to the lane-switch swipe. Keep it, or cut manuals?
