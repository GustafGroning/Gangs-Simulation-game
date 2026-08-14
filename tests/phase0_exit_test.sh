#!/usr/bin/env bash
# Phase 0 exit test (doc 5): "gangs --seed 1 --turns 0 runs headless and exits
# clean. The CI grep passes." Plus a parse check over every script.
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

echo "== 1/3 determinism grep =="
ci/check_determinism_bans.sh || fail=1

echo "== 2/3 all scripts parse =="
"$GODOT_BIN" --headless --script tests/check_scripts.gd || fail=1

echo "== 3/3 ./gangs --seed 1 --turns 0 exits clean =="
./gangs --seed 1 --turns 0 || fail=1

if [ "$fail" -eq 0 ]; then
  echo "PHASE 0 EXIT TEST: PASS"
else
  echo "PHASE 0 EXIT TEST: FAIL"
fi
exit "$fail"
