#!/usr/bin/env bash
set -euo pipefail

# Build macuake-glass: translucent terminal + bundled Terminal.app-style defaults, themes and font.
# Usage: ./scripts/build-glass.sh [--install]
#   SIGN_ID="Developer ID Application: Name (TEAMID)"  sign for distribution (hardened runtime)
#   default SIGN_ID="-"                                 ad-hoc, fine for local use
# Needs: Xcode, vendor/ghostty/macos/GhosttyKit.xcframework (see README "macuake-glass").

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Macuake.app"
BIN="$APP/Contents/MacOS/Macuake"
SIGN_ID="${SIGN_ID:--}"
cd "$ROOT"

[ -d vendor/ghostty/macos/GhosttyKit.xcframework ] || { echo "Missing GhosttyKit.xcframework (see README)"; exit 1; }

echo "==> swift build (release, arm64, Swift 5 language mode: MCP swift-sdk fails strict concurrency on Xcode 27)"
swift build -c release --arch arm64 -Xswiftc -swift-version -Xswiftc 5

rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp .build/release/Macuake "$BIN"
cp MaQuake/Resources/Info.plist "$APP/Contents/Info.plist"
cp MaQuake/Resources/maquake.icns "$APP/Contents/Resources/" 2>/dev/null || true

echo "==> resource bundles, Sparkle, defaults, themes, font"
for b in .build/release/*.bundle; do
  [ -f "$b/Info.plist" ] || [ -f "$b/Contents/Info.plist" ] || continue
  cp -R "$b" "$APP/Contents/Resources/"
done
cp -R .build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework "$APP/Contents/Frameworks/"
cp MaQuake/Defaults/defaults.conf "$APP/Contents/Resources/defaults.conf"
cp -R MaQuake/Defaults/ghostty "$APP/Contents/Resources/ghostty"
cp -R MaQuake/Defaults/Fonts "$APP/Contents/Resources/Fonts"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$BIN" 2>/dev/null || true

PB=/usr/libexec/PlistBuddy; PL="$APP/Contents/Info.plist"
# No auto-update from upstream (it would replace this build); register bundled fonts (process-local).
$PB -c "Delete :SUFeedURL" "$PL" 2>/dev/null || true
$PB -c "Add :SUEnableAutomaticChecks bool false" "$PL" 2>/dev/null || true
$PB -c "Add :ATSApplicationFontsPath string Fonts" "$PL" 2>/dev/null || $PB -c "Set :ATSApplicationFontsPath Fonts" "$PL"

echo "==> signing as: $SIGN_ID"
OPTS=(); [ "$SIGN_ID" != "-" ] && OPTS=(--options runtime --timestamp)
S="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
for b in "$APP"/Contents/Resources/*.bundle; do codesign --force --sign "$SIGN_ID" "${OPTS[@]}" "$b"; done
for c in "$S/XPCServices/Installer.xpc" "$S/XPCServices/Downloader.xpc" "$S/Autoupdate" "$S/Updater.app" "$APP/Contents/Frameworks/Sparkle.framework"; do
  codesign --force --sign "$SIGN_ID" "${OPTS[@]}" "$c"
done
codesign --force --sign "$SIGN_ID" "${OPTS[@]}" --entitlements MaQuake/Resources/MaQuake.entitlements "$APP"
codesign --verify --deep --strict "$APP" && echo "Built and verified: $APP"

if [ "${1:-}" = "--install" ]; then
  osascript -e 'tell application "Macuake" to quit' 2>/dev/null || true
  for _ in $(seq 1 15); do pgrep -x Macuake >/dev/null || break; sleep 1; done
  pgrep -x Macuake >/dev/null && { echo "Macuake is still running; quit it and re-run"; exit 1; }
  rm -rf /Applications/Macuake.app && cp -R "$APP" /Applications/Macuake.app
  echo "Installed to /Applications/Macuake.app"
fi
