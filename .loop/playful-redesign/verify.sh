#!/usr/bin/env bash
# .loop/playful-redesign/verify.sh — closed-loop gate for the playful-redesign loop.
#
# Mirrors .loop/verify.sh's design (any zero exit halts the driver, so "done" must mean
# the whole Definition of Done, not just green tests) but points at this loop's own
# VISION.md so it never collides with the older, already-halted root loop.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)" || exit 1

VISION=".loop/playful-redesign/VISION.md"

unchecked="$(grep -c '^- \[ \]' "$VISION" 2>/dev/null || true)"
unchecked="${unchecked:-0}"
if [ "$unchecked" -gt 0 ]; then
  echo "$VISION still has $unchecked unchecked TODO item(s):"
  grep -n '^- \[ \]' "$VISION"
  exit 1
fi

cd ios || exit 1

echo "--- xcodebuild test ---"
xcodebuild test -project SkyGrid.xcodeproj -scheme SkyGrid -only-testing:SkyGridTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' > /tmp/skygrid_playful_xctest.log 2>&1
test_rc=$?
tail -60 /tmp/skygrid_playful_xctest.log
if [ "$test_rc" -ne 0 ]; then
  echo "xcodebuild test FAILED (rc=$test_rc)"
  exit "$test_rc"
fi

echo "--- xcodebuild build (Release) ---"
xcodebuild build -project SkyGrid.xcodeproj -scheme SkyGrid -configuration Release \
  -destination 'generic/platform=iOS' > /tmp/skygrid_playful_release.log 2>&1
build_rc=$?
tail -60 /tmp/skygrid_playful_release.log
exit "$build_rc"
