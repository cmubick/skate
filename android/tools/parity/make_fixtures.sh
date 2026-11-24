#!/bin/sh
#
# Builds the iOS game's rules, art and sound code (straight from ../skate) as a
# little Mac program, and has it write down a fingerprint of every picture, sound,
# song and a scripted run on each spot. ParityTests in the Android port check
# their own against these, so the two games stay the same.
#
# Run it again after changing the iOS art, sounds, songs or rules:
#   sh android/tools/parity/make_fixtures.sh
#
set -e
cd "$(dirname "$0")/../../.."
ROOT=$(pwd)
IOS="$ROOT/skate"
OUT="$ROOT/android"
BUILD=$(mktemp -d)
trap 'rm -rf "$BUILD"' EXIT

cp "$IOS"/Rules/*.swift "$BUILD/"
for f in PixelArt CharacterArt PeopleArt ObstacleArt ThemeArt LandmarkArt Chiptune Songs; do
    cp "$IOS/UI/$f.swift" "$BUILD/"
done
# The sound recipes, without the part that plays them (it needs iOS's audio session).
awk '/^\/\/\/ Plays the sound effects/ { exit } { print }' "$IOS/UI/Sounds.swift" > "$BUILD/SoundSynth.swift"
# The menus' pictures, without the menus.
awk '/^enum UIArt \{/ { on = 1 } /^\/\/ MARK: - Menus/ { on = 0 } on { print }' "$IOS/UI/Menus.swift" > "$BUILD/UIArt.swift"
sed -i '' 's/^import AVFoundation$/import Foundation/' "$BUILD/SoundSynth.swift"
printf 'import SpriteKit\n' | cat - "$BUILD/UIArt.swift" > "$BUILD/UIArt2.swift" && mv "$BUILD/UIArt2.swift" "$BUILD/UIArt.swift"
# Let the harness see each canvas as it's turned into a texture, and read its pixels.
sed -i '' 's/^    private var pixels: \[UInt8\]$/    var pixels: [UInt8]/' "$BUILD/PixelArt.swift"
sed -i '' 's/^    func texture() -> SKTexture {$/    func texture() -> SKTexture { Recorder.canvases.append(self)/' "$BUILD/PixelArt.swift"
cp "$OUT/tools/parity/main.swift" "$BUILD/main.swift"

xcrun swiftc -O -swift-version 5 -o "$BUILD/parity" "$BUILD"/*.swift
cd "$BUILD"
./parity
cp art.txt sounds.txt "$OUT/app/src/test/resources/parity/"
cp runs.txt "$OUT/rules/src/test/resources/parity/"
echo "Wrote the parity fixtures."
