# Backlog

Side findings and everything out of current scope.

- **`Character.beliefs` is keyed by event_id (doc 1 §3), so two fabrications
  held by the same character collide at key -1.** Harmless until Fabricate
  exists (post-demo verb), but the Fabricate implementation must pick a keying
  scheme (e.g. synthetic negative ids) and update invariant I1 accordingly.

- **Wire CI into GitHub Actions once the repo is `git init`'d.** The determinism grep (`ci/check_determinism_bans.sh`) and, from phase 2 on, the same-seed → identical-event-ledger-hash check are meant to run on every commit (doc 4 §3). They exist as local scripts today because this isn't a git repository yet.
- ~~`heat.gd` placement~~ — resolved in phase 2: `sim/content/heat.gd` (doc 3 specs heat; content owns it). See DECISIONS.md.
