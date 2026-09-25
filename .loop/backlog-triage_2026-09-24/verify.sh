#!/usr/bin/env bash
# .loop/backlog-triage_2026-09-24/verify.sh — closed-loop gate for the backlog-triage loop.
#
# This loop must not touch ios/functions, ios/firestore.rules, or ios/SkyGrid.xcodeproj/project.pbxproj.
# All .caf files must remain valid. All VISION.md TODOs must be checked, and tests/builds must pass.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)" || exit 1

VISION=".loop/backlog-triage_2026-09-24/VISION.md"
STATE=".loop/backlog-triage_2026-09-24/state.json"

# Gate 1: No unchecked TODO items
unchecked="$(grep -c '^- \[ \]' "$VISION" 2>/dev/null || true)"
unchecked="${unchecked:-0}"
if [ "$unchecked" -gt 0 ]; then
  echo "Gate 1 FAILED: $VISION still has $unchecked unchecked TODO item(s):"
  grep -n '^- \[ \]' "$VISION"
  exit 1
fi
echo "Gate 1 PASSED: no unchecked TODOs in VISION.md"

# Gate 5: Do not modify ios/functions, ios/firestore.rules, or ios/SkyGrid.xcodeproj/project.pbxproj
if [ -f "$STATE" ]; then
  base_commit="$(jq -r '.base_commit // empty' "$STATE" 2>/dev/null || true)"
  if [ -n "$base_commit" ]; then
    restricted_diff="$(git diff --name-only "$base_commit"..HEAD -- ios/functions ios/firestore.rules ios/SkyGrid.xcodeproj/project.pbxproj 2>/dev/null || true)"
    if [ -n "$restricted_diff" ]; then
      echo "Gate 5 FAILED: Changes detected in restricted paths:"
      echo "$restricted_diff"
      exit 1
    fi
    echo "Gate 5 PASSED: no changes to restricted paths (ios/functions, ios/firestore.rules, project.pbxproj)"
  else
    echo "Gate 5 SKIPPED: base_commit not set in state.json"
  fi
else
  echo "Gate 5 SKIPPED: state.json not found"
fi

# Gate 4: All .caf files must decode correctly via afinfo
echo "--- Gate 4: Checking .caf file integrity ---"
for caf_file in ios/SkyGrid/Resources/Sounds/*.caf; do
  if [ -f "$caf_file" ]; then
    if ! afinfo "$caf_file" > /dev/null 2>&1; then
      echo "Gate 4 FAILED: afinfo exited non-zero for $caf_file"
      exit 1
    fi
  fi
done
echo "Gate 4 PASSED: all .caf files decode correctly"

cd ios || exit 1

# Gate 2: xcodebuild test passes
echo "--- Gate 2: xcodebuild test ---"
xcodebuild test -project SkyGrid.xcodeproj -scheme SkyGrid -only-testing:SkyGridTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' > /tmp/skygrid_backlog_xctest.log 2>&1
test_rc=$?
tail -60 /tmp/skygrid_backlog_xctest.log
if [ "$test_rc" -ne 0 ]; then
  echo "Gate 2 FAILED: xcodebuild test FAILED (rc=$test_rc)"
  exit "$test_rc"
fi
echo "Gate 2 PASSED: xcodebuild test succeeded"

# Gate 3: xcodebuild build (Release) succeeds
echo "--- Gate 3: xcodebuild build (Release) ---"
xcodebuild build -project SkyGrid.xcodeproj -scheme SkyGrid -configuration Release \
  -destination 'generic/platform=iOS' > /tmp/skygrid_backlog_release.log 2>&1
build_rc=$?
tail -60 /tmp/skygrid_backlog_release.log
if [ "$build_rc" -ne 0 ]; then
  echo "Gate 3 FAILED: xcodebuild build FAILED (rc=$build_rc)"
  exit "$build_rc"
fi
echo "Gate 3 PASSED: xcodebuild build succeeded"

echo ""
echo "All gates passed!"
exit 0
