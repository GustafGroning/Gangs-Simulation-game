#!/usr/bin/env bash
# Phase 6 exit test (doc 5): the full 7-verb demo set, doc 4 §7 criteria.
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

echo "== 1/7 determinism grep =="
ci/check_determinism_bans.sh || fail=1

echo "== 2/7 class cache + parse =="
"$GODOT_BIN" --headless --import >/dev/null 2>&1
"$GODOT_BIN" --headless --script tests/check_scripts.gd || fail=1

echo "== 3/7 phase 1 regression =="
"$GODOT_BIN" --headless --script tests/test_phase1.gd || fail=1

echo "== 4/7 phase 3 regression =="
"$GODOT_BIN" --headless --script tests/test_phase3.gd || fail=1

echo "== 5/7 phase 4 regression =="
"$GODOT_BIN" --headless --script tests/test_phase4.gd || fail=1

echo "== 6/7 phase 5 regression =="
"$GODOT_BIN" --headless --script tests/test_phase5.gd || fail=1

echo "== 7/7 phase 6 demo-verb-set test (20 seeds x 200 turns) =="
"$GODOT_BIN" --headless --script tests/test_phase6.gd || fail=1

if [ "$fail" -eq 0 ]; then
  echo "PHASE 6 EXIT TEST: PASS"
else
  echo "PHASE 6 EXIT TEST: FAIL"
fi
exit "$fail"
