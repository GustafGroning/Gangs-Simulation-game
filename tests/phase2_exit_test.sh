#!/usr/bin/env bash
# Phase 2 exit test (doc 5): content smoke test over 20 seeds × 100 turns.
# Also regression: phase 1 tests still pass, CLI single run produces outputs.
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

echo "== 4/5 phase 2 smoke test (20 seeds x 100 turns) =="
"$GODOT_BIN" --headless --script tests/test_phase2.gd || fail=1

echo "== 5/5 CLI single run writes outputs =="
rm -rf runs
./gangs --seed 3 --turns 50 --out runs/ >/dev/null || fail=1
for f in chronicle.txt metrics.json events.jsonl final_state.json world_summary.txt; do
  if [ ! -s "runs/$f" ]; then
    echo "missing output: runs/$f"
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "PHASE 2 EXIT TEST: PASS"
else
  echo "PHASE 2 EXIT TEST: FAIL"
fi
exit "$fail"
