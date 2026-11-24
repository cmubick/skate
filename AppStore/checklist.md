# App Store Connect checklist for Skate

Steps marked **You** need your Apple sign-in at
[appstoreconnect.apple.com](https://appstoreconnect.apple.com). Steps marked
**Claude** can be run from this repo. All the text to paste is in `listing.md`.

## 1. Turn on the support pages (You)

GitHub → `cmubick/skate` → **Settings → Pages** → Deploy from a branch → `main`,
folder `/docs`. Then check that `https://cmubick.github.io/skate/` and
`/privacy.html` load. App Store Connect needs both URLs.

## 2. Create the app record (You)

1. Apps → **+** → **New App**.
2. Platform **iOS**. Name: your pick from `listing.md` (App Store Connect says if
   it's taken).
3. Primary language **English (U.S.)**.
4. Bundle ID **com.tuesdaygames.skate**. If it isn't in the list yet, archiving
   (step 3) registers it.
5. SKU: anything unique to you, e.g. `skate-ios`.
6. User access: Full Access.

## 3. Archive and upload the build (Claude)

```bash
xcodebuild -project skate.xcodeproj -scheme skate -configuration Release -destination 'generic/platform=iOS' -archivePath build/archive/skate.xcarchive archive -allowProvisioningUpdates
```

```bash
xcodebuild -exportArchive -archivePath build/archive/skate.xcarchive -exportOptionsPlist AppStore/UploadOptions.plist -exportPath build/upload -allowProvisioningUpdates
```

`UploadOptions.plist` sends the build to App Store Connect; `ExportOptions.plist`
only writes the `.ipa` locally. Each later upload needs a higher build number
(`CURRENT_PROJECT_VERSION`). Processing takes 5 to 30 minutes.

The marketing exporter and the `-page`, `-level`, `-fireworks` launch options are
`#if DEBUG` only, so they're not in this Release build.

## 4. In-app purchases (You)

**Monetization → In-App Purchases**: the three tips from `listing.md`, with
exactly those product IDs, prices, names and descriptions. Add the review
screenshot `art/iap-review-tip-jar.png` and the review note to each. Don't create
the full game yet. The Paid Apps agreement, banking and tax must be done.

## 5. TestFlight (You)

1. **TestFlight → Internal Testing → +**, add yourself.
2. Add build 1.0 (1). Internal builds skip Beta App Review.
3. Install with the TestFlight app. Tips there are free test purchases.

What to try on the phone:

- [ ] The tutorial, start to finish.
- [ ] Each Portland spot: goals list, a run, the finish screen.
- [ ] A tip from the title screen: THANK YOU!, nothing unlocked.
- [ ] Sound with the silent switch off, and haptics.
- [ ] The spot list on your phone: nothing overlaps.
- [ ] Record the 1–2 minute screen recording for App Review (see `listing.md`).

## 6. Fill in the product page (You)

1. **General → App Information:** subtitle, category, content rights, age rating,
   privacy policy URL, from `listing.md`.
2. **App Privacy:** Data Not Collected.
3. **App Accessibility:** optional for now; answers are in `listing.md`.
4. **App Compliance:** see `listing.md`; DSA trader status is your call.
5. **Header and Search Results:** `art/header.png` and `art/search.png` (or
   `art/universal.png` for both). Check them in Preview.
6. **Pricing and Availability:** Free. Leave out China mainland and Vietnam
   unless you have a game license there.

## 7. The version page and submit (You)

1. **Screenshots:** `screenshots/iphone-6.1in-2556x1179/` into the 6.1" iPhone
   slot, optionally `iphone-6.9in-2868x1320/` into 6.9", and
   `ipad-13in-2752x2064/` into 13" iPad, in file order 1–8.
2. **Promotional text, description, keywords, support URL, copyright:** from
   `listing.md`.
3. **Build:** the TestFlight build.
4. **App Review Information:** your contact details, no sign-in, the notes and
   the screen recording.
5. **In-App Purchases and Subscriptions:** select the three tips.
6. **Add for Review**, then **Submit to App Review**.

## Decide before submitting

- [ ] Portlandia and the White Stag sign in the game (Content Rights in `listing.md`).
- [ ] Burnside graffiti ("SK8 OR DIE", skulls) for a 4+ rating.
- [ ] "COMING SOON FOR $4.99" on the full game screen.
- [ ] DSA trader status, if not already set on your account.

## Remaking the screenshots and art (Claude)

```bash
AppStore/make_assets.sh
```

It builds a debug build, runs it in the simulator with `-marketing YES`, and
copies everything into `AppStore/screenshots/` and `AppStore/art/`. The shots,
captions and sizes are in `skate/Marketing.swift`.
