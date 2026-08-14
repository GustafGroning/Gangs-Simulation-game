#!/usr/bin/env bash
# Phase 4 exit test (doc 5): the scorer differentiates characters and stays
# inside the belief boundary.
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

echo "== 3/5 phase 1 + 3 regressions =="
"$GODOT_BIN" --headless --script tests/test_phase1.gd || fail=1
"$GODOT_BIN" --headless --script tests/test_phase3.gd || fail=1

echo "== 4/5 phase 4 scorer test (20 seeds x 100 turns) =="
"$GODOT_BIN" --headless --script tests/test_phase4.gd || fail=1

echo "== 5/5 CLI run under the scorer =="
rm -rf runs
./gangs --seed 3 --turns 50 --out runs/ >/dev/null || fail=1
# Scorer.top_terms formats each term as "name +0.12" / "name -0.12" joined by
# " · "; a bare "(" would also match Job.generate_board's unrelated posting
# lines, so anchor on the signed-magnitude format instead.
grep -Eq '[+-][0-9]+\.[0-9]{2}' runs/chronicle.txt || { echo "chronicle carries no contribution terms"; fail=1; }

if [ "$fail" -eq 0 ]; then
  echo "PHASE 4 EXIT TEST: PASS"
else
  echo "PHASE 4 EXIT TEST: FAIL"
fi
exit "$fail"
