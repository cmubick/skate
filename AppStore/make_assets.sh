#!/bin/zsh
# Renders the App Store screenshots and artwork from the game itself and copies
# them into AppStore/screenshots and AppStore/art. Needs Xcode and a simulator.
#
#   AppStore/make_assets.sh [simulator name or id]
#
# It builds a debug build, launches it with -marketing YES (see skate/Marketing.swift),
# waits for it to finish, then copies the PNGs out of the app's Documents folder.
set -e
cd "$(dirname "$0")/.."
DEVICE=${1:-"iPhone 15 Pro Max"}
BUNDLE=com.tuesdaygames.skate

# A simulator's id (from `xcrun simctl list devices`) or its name.
if [[ $DEVICE =~ ^[0-9A-F-]{36}$ ]]; then DEST="id=$DEVICE"; else DEST="platform=iOS Simulator,name=$DEVICE"; fi
xcodebuild -project skate.xcodeproj -scheme skate -configuration Debug \
  -destination "$DEST" -derivedDataPath build/marketing build -quiet
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" >/dev/null
xcrun simctl install "$DEVICE" build/marketing/Build/Products/Debug-iphonesimulator/skate.app
xcrun simctl terminate "$DEVICE" $BUNDLE 2>/dev/null || true

DATA=$(xcrun simctl get_app_container "$DEVICE" $BUNDLE data)
rm -rf "$DATA/Documents/AppStore"
LOG=$(mktemp)
xcrun simctl launch --console-pty "$DEVICE" $BUNDLE -marketing YES -hideFPS YES > "$LOG" 2>&1 &
LAUNCH=$!
for _ in {1..180}; do
  grep -q "MARKETING DONE" "$LOG" && break
  sleep 1
done
kill $LAUNCH 2>/dev/null || true
grep "MARKETING" "$LOG" || { echo "The export didn't finish. Log: $LOG"; exit 1; }
xcrun simctl terminate "$DEVICE" $BUNDLE 2>/dev/null || true

SRC="$DATA/Documents/AppStore"
rm -rf AppStore/screenshots AppStore/art
mkdir -p AppStore/screenshots AppStore/art
for dir in iphone-6.1in-2556x1179 iphone-6.9in-2868x1320 ipad-13in-2752x2064; do
  cp -R "$SRC/$dir" AppStore/screenshots/
done
for dir in header-3840x1646 universal-5244x2950 search-3840x2560 iap-review-2556x1179; do
  cp "$SRC/$dir"/*.png AppStore/art/
done
echo "Done: AppStore/screenshots and AppStore/art"
