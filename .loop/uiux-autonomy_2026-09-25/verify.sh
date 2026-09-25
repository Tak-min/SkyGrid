#!/usr/bin/env bash
# .loop/uiux-autonomy_2026-09-25/verify.sh — closed-loop gate for the UI/UX autonomy loop.
#
# Same shape as .loop/verify.sh and .loop/backlog-triage_2026-09-24/verify.sh: the headless
# driver treats ANY zero exit from this script as "Definition of Done reached, stop the whole
# loop" — so this only exits 0 when the VISION.md "Definition of Done" checklist (NOT the
# open-ended TODO/ticket list, which is expected to keep growing as discovery finds more issues)
# is fully checked off AND the real xcodebuild gates are green AND restricted paths are untouched.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)" || exit 1

VISION=".loop/uiux-autonomy_2026-09-25/VISION.md"
STATE=".loop/uiux-autonomy_2026-09-25/state.json"

# Gate 1: no unchecked items in the "## Definition of Done" section specifically (the TODO
# ticket list below it is intentionally open-ended and must NOT gate loop termination).
dod_block="$(awk '/^## Definition of Done/{flag=1; next} /^## /{flag=0} flag' "$VISION")"
unchecked="$(printf '%s\n' "$dod_block" | grep -c '^- \[ \]' || true)"
unchecked="${unchecked:-0}"
if [ "$unchecked" -gt 0 ]; then
  echo "Gate 1 FAILED: Definition of Done in $VISION still has $unchecked unchecked item(s):"
  printf '%s\n' "$dod_block" | grep -n '^- \[ \]'
  exit 1
fi
echo "Gate 1 PASSED: Definition of Done fully checked in $VISION"

# Informational only (not gating): current generic-button-style count, for progress visibility.
btn_count="$(grep -rn '\.buttonStyle(\.\(bordered\|borderedProminent\|plain\|automatic\))' ios/SkyGrid/Sources 2>/dev/null | wc -l | tr -d ' ')"
echo "Info: generic .buttonStyle(...) usages remaining: $btn_count (baseline was 23 on 2026-09-25)"

# Gate 2: restricted paths untouched since base_commit.
if [ -f "$STATE" ]; then
  base_commit="$(jq -r '.base_commit // empty' "$STATE" 2>/dev/null || true)"
  if [ -z "$base_commit" ]; then
    base_commit="01ca34189d98e21e25a413b8f6fb9a29af18b772"
  fi
  restricted_diff="$(git diff --name-only "$base_commit"..HEAD -- ios/functions ios/firestore.rules ios/SkyGrid.xcodeproj/project.pbxproj videos/joespov-skygrid-remix 2>/dev/null || true)"
  if [ -n "$restricted_diff" ]; then
    echo "Gate 2 FAILED: changes detected in restricted paths:"
    echo "$restricted_diff"
    exit 1
  fi
  echo "Gate 2 PASSED: no changes to restricted paths"
else
  echo "Gate 2 SKIPPED: state.json not found"
fi

cd ios || exit 1

# Gate 3: xcodebuild test
echo "--- Gate 3: xcodebuild test ---"
xcodebuild test -project SkyGrid.xcodeproj -scheme SkyGrid -only-testing:SkyGridTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' > /tmp/skygrid_uiux_xctest.log 2>&1
test_rc=$?
tail -60 /tmp/skygrid_uiux_xctest.log
if [ "$test_rc" -ne 0 ]; then
  echo "Gate 3 FAILED: xcodebuild test FAILED (rc=$test_rc)"
  exit "$test_rc"
fi
echo "Gate 3 PASSED: xcodebuild test succeeded"

# Gate 4: xcodebuild build (Release)
echo "--- Gate 4: xcodebuild build (Release) ---"
xcodebuild build -project SkyGrid.xcodeproj -scheme SkyGrid -configuration Release \
  -destination 'generic/platform=iOS' > /tmp/skygrid_uiux_release.log 2>&1
build_rc=$?
tail -60 /tmp/skygrid_uiux_release.log
if [ "$build_rc" -ne 0 ]; then
  echo "Gate 4 FAILED: xcodebuild build FAILED (rc=$build_rc)"
  exit "$build_rc"
fi
echo "Gate 4 PASSED: xcodebuild build succeeded"

echo ""
echo "All gates passed!"
exit 0
