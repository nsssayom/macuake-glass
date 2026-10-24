#!/usr/bin/env bash
set -euo pipefail

# Build, Developer-ID sign, notarize, staple and publish a macuake-glass release.
# One-time setup (stores an app-specific password in your keychain, nothing in this repo):
#   xcrun notarytool store-credentials macuake-notary --apple-id <you> --team-id <TEAMID>
# Usage: SIGN_ID="Developer ID Application: Name (TEAMID)" ./scripts/release-glass.sh v0.3.1-glass.1 [--publish]

TAG="${1:?usage: release-glass.sh <tag> [--publish]}"
PROFILE="${NOTARY_PROFILE:-macuake-notary}"
: "${SIGN_ID:?set SIGN_ID to your 'Developer ID Application: ...' identity}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"

SIGN_ID="$SIGN_ID" ./scripts/build-glass.sh
DMG="build/Macuake-glass-${TAG}.dmg"
rm -rf build/dmg "$DMG"; mkdir build/dmg
cp -R build/Macuake.app build/dmg/ && ln -s /Applications build/dmg/Applications
hdiutil create -quiet -volname "Macuake glass" -srcfolder build/dmg -ov -format UDZO "$DMG"
codesign --force --sign "$SIGN_ID" --timestamp "$DMG"

echo "==> notarizing (waits for Apple)"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
spctl -a -t open --context context:primary-signature -v "$DMG"
shasum -a 256 "$DMG" | tee "$DMG.sha256"

if [ "${2:-}" = "--publish" ]; then
  gh release create "$TAG" "$DMG" "$DMG.sha256" --title "macuake-glass $TAG" \
    --notes "Signed with Developer ID and notarized. Translucent terminal, Terminal.app-style defaults, bundled themes and Meslo font. See README."
fi
