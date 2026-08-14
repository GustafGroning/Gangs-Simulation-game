#!/usr/bin/env bash
# Phase 3 exit test (doc 5): the information layer manufactures uneven,
# sometimes confidently wrong beliefs from scripted sabotages.
set -uo pipefail
cd "$(dirname "$0")/.."

GODOT_BIN="${GODOT:-}"
if [ -z "$GODOT_BIN" ]; then
  if command -v godot >/dev/null 2>&1; then
    GODOT_BIN=godot
  else
    GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
  fi
fi

fail=0

echo "== 1/5 determinism grep =="
ci/check_determinism_bans.sh || fail=1

echo "== 2/5 class cache + parse =="
"$GODOT_BIN" --headless --import >/dev/null 2>&1
"$GODOT_BIN" --headless --script tests/check_scripts.gd || fail=1

echo "== 3/5 phase 1 regression =="
"$GODOT_BIN" --headless --script tests/test_phase1.gd || fail=1

echo "== 4/5 phase 2 regression =="
"$GODOT_BIN" --headless --script tests/test_phase2.gd || fail=1

echo "== 5/5 phase 3 information-layer test (20 seeds x 100 turns) =="
"$GODOT_BIN" --headless --script tests/test_phase3.gd || fail=1

if [ "$fail" -eq 0 ]; then
  echo "PHASE 3 EXIT TEST: PASS"
else
  echo "PHASE 3 EXIT TEST: FAIL"
fi
exit "$fail"
