# Backlog

Side findings and everything out of current scope.

- **Six of doc 3 §3's exogenous event kinds are unbuilt**: police pressure,
  the big score, lean times, the informant, family trouble, outside offer.
  Only Rival Hit and Arrest exist (phase 6, per doc 5 phase 6 task 7's
  explicit prioritization). `Exogenous.gd`'s structure (a `maybe_fire`
  dispatcher, cooldown derived from the event ledger) should extend
  cleanly — each new kind just needs its own roll + effect + optional trace
  template in `traces.gd`.
- **Dig doesn't cover the "who else holds this belief" meta-knowledge**
  design_doc.md mentions ("a dig may also reveal who else holds this
  belief... what tells you whether a secret is still worth blackmailing
  over") — not in doc 5 phase 6's task list for Dig, so left out.
- **Arrest has no return mechanism** — doc 3 says 5-15 turns temporary;
  implemented as permanent (EXILED) since the schema has no "temporarily
  absent" CharState. A real fix needs either a new CharState + scheduled
  return, or a dedicated field tracking a return turn plus re-entry into a
  slot (not necessarily via contest, since doc 3 implies they get their old
  position back rather than competing for it).
- **Judgment DEMOTED with no vacant lower slot falls back to EXILED** —
  same CharState gap. A real "demoted but still active, awaiting a slot"
  state would need the same modeling work as Arrest's return mechanism.
- **`Job.resolve()`'s abandoned-job path (worker died mid-flight) isn't
  counted in `job_fill_rate`** — it's excluded from both the "resolved" and
  "leaked/open" buckets in `Metrics.finalize`, so an abandoned job is
  invisible to that metric rather than explicitly penalized or credited.
  Tracked separately via `jobs_abandoned`, just not folded into fill rate.
- **No population floor/ceiling** — Kill, Judgment (KILLED/EXILED), arrests
  and Rival Hit can all permanently remove characters; nothing in the demo
  ever adds one back (Expansion is out of scope per design_doc.md's "one
  rank-change mechanism" demo constraint). Over a long run the cast could
  shrink substantially; worth watching once phase 6's exit test actually
  runs (see QUESTIONS.md).

- **`Character.beliefs` is keyed by event_id (doc 1 §3), so two fabrications
  held by the same character collide at key -1.** Harmless until Fabricate
  exists (post-demo verb), but the Fabricate implementation must pick a keying
  scheme (e.g. synthetic negative ids) and update invariant I1 accordingly.

- **Wire CI into GitHub Actions once the repo is `git init`'d.** The determinism grep (`ci/check_determinism_bans.sh`) and, from phase 2 on, the same-seed → identical-event-ledger-hash check are meant to run on every commit (doc 4 §3). They exist as local scripts today because this isn't a git repository yet.
- ~~`heat.gd` placement~~ — resolved in phase 2: `sim/content/heat.gd` (doc 3 specs heat; content owns it). See DECISIONS.md.
