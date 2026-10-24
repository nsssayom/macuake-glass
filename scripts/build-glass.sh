#!/usr/bin/env bash
set -euo pipefail

# Build macuake-glass: a locally signed (ad-hoc) Macuake.app with a translucent terminal
# and bundled Terminal.app-style defaults. No Developer ID needed.
# Usage: ./scripts/build-glass.sh [--install]     (--install copies to /Applications)
# Needs: Xcode, and vendor/ghostty/macos/GhosttyKit.xcframework (see README "macuake-glass").

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Macuake.app"
BIN="$APP/Contents/MacOS/Macuake"
cd "$ROOT"

[ -d vendor/ghostty/macos/GhosttyKit.xcframework ] || { echo "Missing GhosttyKit.xcframework: run ./scripts/download-ghosttykit.sh"; exit 1; }

echo "==> swift build (release, arm64, Swift 5 language mode: MCP swift-sdk fails strict concurrency on Xcode 27)"
swift build -c release --arch arm64 -Xswiftc -swift-version -Xswiftc 5

rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp .build/release/Macuake "$BIN"
cp MaQuake/Resources/Info.plist "$APP/Contents/Info.plist"
cp MaQuake/Resources/maquake.icns "$APP/Contents/Resources/" 2>/dev/null || true

echo "==> resource bundles, Sparkle, defaults"
for b in .build/release/*.bundle; do
  [ -f "$b/Info.plist" ] || [ -f "$b/Contents/Info.plist" ] || continue
  cp -R "$b" "$APP/Contents/Resources/"
done
cp -R .build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework "$APP/Contents/Frameworks/"
cp MaQuake/Defaults/defaults.conf "$APP/Contents/Resources/defaults.conf"
cp -R MaQuake/Defaults/ghostty "$APP/Contents/Resources/ghostty"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$BIN" 2>/dev/null || true

# The fork must not auto-update from upstream (that would replace the patched build).
/usr/libexec/PlistBuddy -c "Delete :SUFeedURL" "$APP/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :SUEnableAutomaticChecks bool false" "$APP/Contents/Info.plist" 2>/dev/null || true

echo "==> ad-hoc signing"
codesign --force --deep --sign - --options runtime --entitlements MaQuake/Resources/MaQuake.entitlements "$APP"
codesign --verify --deep --strict "$APP" && echo "Built: $APP"

if [ "${1:-}" = "--install" ]; then
  osascript -e 'tell application "Macuake" to quit' 2>/dev/null || true
  for _ in $(seq 1 15); do pgrep -x Macuake >/dev/null || break; sleep 1; done
  pgrep -x Macuake >/dev/null && { echo "Macuake is still running; quit it and re-run"; exit 1; }
  rm -rf /Applications/Macuake.app && cp -R "$APP" /Applications/Macuake.app
  echo "Installed to /Applications/Macuake.app"
fi
