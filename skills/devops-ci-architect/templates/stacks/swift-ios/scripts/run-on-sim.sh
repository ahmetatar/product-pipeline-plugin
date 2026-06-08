#!/usr/bin/env bash
# Build the app for an iOS Simulator and install + launch it — run LOCALLY on your Mac to test a
# feat branch. CI canNOT do this: a cloud runner's simulator is not your simulator. This is the
# `local-simulator` delivery mode's hands-on step (CI only verified the build + moved the board).
#
# Usage:   scripts/run-on-sim.sh            # uses the defaults baked in below
#          SIMULATOR="iPhone 17 Pro" scripts/run-on-sim.sh   # override the device
#
# Real device instead of a simulator (Xcode 15+, device connected + provisioned):
#   build with -destination 'generic/platform=iOS', then:
#   xcrun devicectl device install app --device <udid> "$APP"   (list devices: xcrun devicectl list devices)
set -euo pipefail

SCHEME="${SCHEME:-<SCHEME>}"
SIMULATOR="${SIMULATOR:-<SIMULATOR_NAME>}"
BUNDLE_ID="${BUNDLE_ID:-<BUNDLE_ID>}"
DERIVED="build/sim"

echo "▸ Booting $SIMULATOR …"
xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
open -a Simulator

echo "▸ Building $SCHEME for the simulator …"
xcodebuild build \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$SIMULATOR" \
  -derivedDataPath "$DERIVED"

APP=$(find "$DERIVED/Build/Products" -maxdepth 2 -name '*.app' | head -1)
[ -z "$APP" ] && { echo "✗ No .app produced — check the scheme builds for the simulator."; exit 1; }

echo "▸ Installing $APP …"
xcrun simctl install "$SIMULATOR" "$APP"
xcrun simctl launch "$SIMULATOR" "$BUNDLE_ID"
echo "✓ Installed + launched $BUNDLE_ID on $SIMULATOR"
