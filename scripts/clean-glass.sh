#!/usr/bin/env bash
set -euo pipefail
# Free disk after building: SwiftPM cache, build outputs, downloaded GhosttyKit. All regenerated on demand.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
before=$(du -sk . | cut -f1)
rm -rf "$ROOT/.build" "$ROOT/build" "$ROOT/vendor/ghostty/macos/GhosttyKit.xcframework"
after=$(du -sk . | cut -f1)
echo "Freed $(( (before - after) / 1024 )) MB"
