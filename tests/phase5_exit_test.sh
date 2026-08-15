#!/usr/bin/env bash
# Phase 5 exit test (doc 5): plan mechanics measurably shape behavior.
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

echo "== 1/6 determinism grep =="
ci/check_determinism_bans.sh || fail=1

echo "== 2/6 class cache + parse =="
"$GODOT_BIN" --headless --import >/dev/null 2>&1
"$GODOT_BIN" --headless --script tests/check_scripts.gd || fail=1

echo "== 3/6 phase 1 regression =="
"$GODOT_BIN" --headless --script tests/test_phase1.gd || fail=1

echo "== 4/6 phase 3 regression =="
"$GODOT_BIN" --headless --script tests/test_phase3.gd || fail=1

echo "== 5/6 phase 4 regression =="
"$GODOT_BIN" --headless --script tests/test_phase4.gd || fail=1

echo "== 6/6 phase 5 planner test (20 seeds x 100 turns) =="
"$GODOT_BIN" --headless --script tests/test_phase5.gd || fail=1

if [ "$fail" -eq 0 ]; then
  echo "PHASE 5 EXIT TEST: PASS"
else
  echo "PHASE 5 EXIT TEST: FAIL"
fi
exit "$fail"
