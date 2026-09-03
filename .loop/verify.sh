#!/usr/bin/env bash
# .loop/verify.sh — the loop's real closed-loop gate.
#
# loop-engine.sh treats *any* zero exit from LOOP_VERIFY_CMD as "Definition of Done reached"
# and stops the whole loop immediately (see its "VERIFY PASSED" -> "exit 0" branch). Our actual
# Definition of Done in VISION.md is a long checklist (research, redesign, buddy/alarm/share
# work, ASO), not merely "tests pass" -- a naive `xcodebuild test` verify command would let the
# driver declare victory after the very first green test run, which already happened twice
# before this script existed. This script is exit-0 only when BOTH the VISION.md checklist is
# fully checked off AND the project's own test/build gates are green, so the driver's "done"
# actually means done.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1

unchecked="$(grep -c '^- \[ \]' .loop/VISION.md 2>/dev/null || true)"
unchecked="${unchecked:-0}"
if [ "$unchecked" -gt 0 ]; then
  echo "VISION.md still has $unchecked unchecked TODO item(s):"
  grep -n '^- \[ \]' .loop/VISION.md
  exit 1
fi

cd ios || exit 1

echo "--- xcodebuild test ---"
xcodebuild test -project SkyGrid.xcodeproj -scheme SkyGrid -only-testing:SkyGridTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' > /tmp/skygrid_xctest.log 2>&1
test_rc=$?
tail -60 /tmp/skygrid_xctest.log
if [ "$test_rc" -ne 0 ]; then
  echo "xcodebuild test FAILED (rc=$test_rc)"
  exit "$test_rc"
fi

echo "--- xcodebuild build (Release) ---"
xcodebuild build -project SkyGrid.xcodeproj -scheme SkyGrid -configuration Release \
  -destination 'generic/platform=iOS' > /tmp/skygrid_release.log 2>&1
build_rc=$?
tail -60 /tmp/skygrid_release.log
exit "$build_rc"
