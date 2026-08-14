#!/usr/bin/env bash
# Phase 1 exit test (doc 5): fixture world passes invariants, serializes
# round-trip identical, each corrupted invariant fires exactly one assertion.
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

echo "== 1/4 determinism grep =="
ci/check_determinism_bans.sh || fail=1

echo "== 2/4 regenerate class cache (--import) =="
"$GODOT_BIN" --headless --import >/dev/null 2>&1 || fail=1

echo "== 3/4 all scripts parse =="
"$GODOT_BIN" --headless --script tests/check_scripts.gd || fail=1

echo "== 4/4 phase 1 tests =="
"$GODOT_BIN" --headless --script tests/test_phase1.gd || fail=1

if [ "$fail" -eq 0 ]; then
  echo "PHASE 1 EXIT TEST: PASS"
else
  echo "PHASE 1 EXIT TEST: FAIL"
fi
exit "$fail"
