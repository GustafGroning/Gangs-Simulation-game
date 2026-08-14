#!/usr/bin/env bash
# CI grep (doc 5 phase 0 task 7): fail on nondeterministic calls under sim/.
# See CLAUDE.md "Determinism" — the global RNG and wall-clock time are banned.
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0

# Global RNG functions: a match not preceded by '.' is a bare @GlobalScope call.
# Method calls on an explicit RandomNumberGenerator (rng.randf(...)) are allowed,
# as are the definitions of the Rng.* helpers themselves (func lines filtered).
hits=$(grep -rnE '(^|[^.A-Za-z0-9_])(randi|randf|randi_range|randf_range|randfn|randomize)[[:space:]]*\(' \
        --include='*.gd' sim/ | grep -vE ':[[:space:]]*(static[[:space:]]+)?func[[:space:]]')
if [ -n "$hits" ]; then
  echo "$hits"
  echo "FAIL: global RNG call under sim/ — every roll goes through world.rng (use the Rng helpers)"
  fail=1
fi

# Array.shuffle() / Array.pick_random() take no arguments; Rng.shuffle(arr, rng)
# and Rng.pick(arr, rng) do — so empty parens identify the banned calls.
hits=$(grep -rnE '\.(shuffle|pick_random)[[:space:]]*\([[:space:]]*\)' --include='*.gd' sim/)
if [ -n "$hits" ]; then
  echo "$hits"
  echo "FAIL: Array.shuffle()/pick_random() under sim/ — use Rng.shuffle / Rng.pick"
  fail=1
fi

# Wall-clock time: turn number is the only clock.
hits=$(grep -rnE 'OS\.get_ticks|(^|[^A-Za-z0-9_])Time\.' --include='*.gd' sim/)
if [ -n "$hits" ]; then
  echo "$hits"
  echo "FAIL: wall-clock time under sim/ — turn number is the only clock"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "determinism bans: OK"
fi
exit "$fail"
