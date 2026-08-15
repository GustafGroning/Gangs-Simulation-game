# Where the project actually stands

The other documents in this folder mostly describe the game as a finished
system. This one is the honest accounting: what's real and running today,
what's genuinely still just a document, and what's unresolved enough that
it's sitting in `QUESTIONS.md` waiting on a decision. Nothing here should
be read as a complaint — a lot of this is exactly the point of building in
phases with hard exit tests, per `from_user/tasks/demo_tasks.md`. This is
that document's "what actually happened" counterpart.

## The build plan, and where it's up to

The build is organized into phases 0–7, each with its own pass/fail exit
test, specifically so that a silent, hard-to-notice mistake in an early
phase (the kind where the sim keeps running and the output just looks
slightly boring instead of visibly broken) gets caught immediately instead
of contaminating everything built afterward.

| Phase | What it built | Status |
|---|---|---|
| 0 — Skeleton | Project runs headless, deterministically, does nothing | Built |
| 1 — State | The world can be represented and checked for consistency | Built |
| 2 — Turn loop + jobs | A world that runs, with a working job economy, no politics yet | Built |
| 3 — Information layer | Evidence, detection, belief spread, misattribution | Built |
| 4 — Scorer | Characters actually choose actions via the utility/risk pipeline | Built |
| 5 — Planner | Characters invest across multiple turns instead of flip-flopping | Built |
| 6 — Demo verb set | The remaining five actions, public trials, promotions, two outside shocks | Built |
| 7 — Full generation + the decision point | Real procedural world generation, a sweep/regression harness, and the go/no-go read on whether the whole approach works | **Not started** |

So: the simulation that's described across documents 01–05 genuinely runs,
end to end, seven actions deep, today. What it's missing is phase 7's own
job — replacing the current placeholder world-builder with the full
generator described in `01_world_and_characters.md` (pre-simulated history,
planted narrative hooks, uneven starting knowledge), and then actually
sitting down and reading several full chronicles to answer the project's
central question honestly.

## The decision point hasn't happened yet

`demo_tasks.md` frames phase 7 as the actual point of the whole exercise:
read three chronicles and answer four questions — can you reconstruct why
things happened, did at least one misattribution cascade show up, did
anything genuinely surprise you, and — the one that actually matters —
does the belief layer make a measurable difference, or would the game be
just as good if the AI could see the truth? If the answer to that last one
is "the AI reading ground truth works just as well," the documented
instruction is to stop and rework the information model rather than push
forward, because that's the cheapest point in the whole project to find
that out. **That comparison hasn't been run.** Nobody currently knows the
answer, because phase 7 — including the sweep harness that would let this
kind of comparison run in the first place — hasn't been built.

## An important caveat about phases 5 and 6 specifically

Per `DECISIONS.md` and `QUESTIONS.md`, the work that finished phase 5 and
built all of phase 6 was done in an environment with no way to actually run
the Godot engine — no interactive terminal approval, no network access to
install anything. Every line of it was written and statically reviewed,
never executed, and neither of those phases' own exit tests
(`tests/phase5_exit_test.sh`, `tests/phase6_exit_test.sh`) has ever
actually been run. That's flagged prominently because it means anything in
documents 02–05 above that describes phase 5/6 behavior is describing
*intended* behavior that has been carefully reasoned through but not yet
verified against a real run. The honest recommendation on record is: the
first thing worth doing on a machine that actually has Godot installed is
running those two exit tests and seeing what the numbers say, particularly:

- **Whether the cast survives 200 turns at all.** With only one working
  way to change rank (violent removal → contest) and now several distinct
  ways to permanently remove someone (Kill, an Exiled or Killed verdict,
  an arrest, a rival hit), and nothing in the current build that ever adds
  a person back to the tree, a 16-person cast could plausibly shrink a lot
  over a long run. Nobody's measured this yet.
- **The death rate**, which was tuned by reasoning rather than by watching
  numbers come out of an actual run, and is flagged as plausibly wrong in
  either direction.
- **Whether the tree's one built-in starting vacancy behaves as intended**
  now that end-of-turn contests are the *only* thing that ever fills a
  slot — including that original one, from turn 1 onward, which is a
  genuine behavior change earlier phases' own tests were never re-checked
  against.

## Things flagged as judgment calls, not settled canon

A handful of places where the design documents were genuinely silent or
ambiguous enough that a specific reading had to be picked in order to keep
moving, rather than inventing new canon unilaterally. All of these are
logged in `QUESTIONS.md` awaiting a decision from Gustaf:

- **What "opportunity or instrument" means for who's allowed to attempt a
  Kill.** Currently read as: either you're structurally close to the
  target (same crew, or they're your patron), or your grudge against them
  has crossed a threshold. Right now that means any two people who share a
  crew can attempt to kill each other with literally zero grudge, as long
  as the numbers otherwise clear — worth a second look.
- **Investigation (Dig) currently only ever resolves *who did it*.** The
  original design describes digging into other fields too (the method
  used, the motive) but the game's data model doesn't yet have a slot for
  "motive" as a separate resolvable thing, so this was narrowed to the one
  field the design itself calls the most important anyway.
- **Being demoted with nowhere to demote to, and being arrested,** both
  currently fall back to a full, permanent removal from the tree, because
  the game's state model doesn't yet have a way to represent "still around,
  but temporarily without a real position" or "gone for a while, will be
  back." A proper fix needs a real mechanism, not just a bigger enum.
- **Where the two rare "outside shock" events sit in the turn order** —
  the original design didn't specify a numbered slot for them, so they
  were placed early in the turn (right after the daily housekeeping, before
  the job board), specifically so people's decisions later that same turn
  can react to a fresh shock immediately.

## What's fully out of scope for now

Documented in `BACKLOG.md`, not started, not currently planned until after
phase 7 decides the core approach is worth continuing:

- Six of the eight outside-shock event types (sustained police pressure, an
  exceptional big score, a stretch of lean times, an unidentified informant
  inside the organization, personal money trouble, an outside job offer).
- The ~28 actions beyond the seven-verb demo set — notably the entire
  **Court** and **Cover** groups (favors, alibis, buying silence, brokering
  peace), which the design specifically calls out as what makes a *quiet*
  turn a real, viable choice rather than just waiting.
- Advocacy, Challenge, Succession, and Defection — the four rank-change
  paths that don't involve someone dying.
- Any mechanism for population to ever grow back after deaths/exiles/
  arrests thin it out — nothing currently replaces a permanently lost
  character.
- The player. Right now this is, deliberately, a simulation nobody plays —
  a headless run that produces a log, read afterward by a person deciding
  whether the underlying idea works. Player input is explicitly phase 8+,
  gated on phase 7's decision point coming back positive.

## The honest one-paragraph summary

A real, running, seven-verb version of this game exists today: characters
with distinct personalities pick actions based only on their own
potentially-wrong beliefs, evidence gets left behind and found or missed,
rumors spread and drift toward whoever looks guilty, people get
investigated, publicly accused, judged, promoted, and killed, and it all
produces a readable turn-by-turn log. What doesn't exist yet is a world
that starts turn 1 already tense (the full generator), a validated
confirmation that any of this actually beats a simpler AI that just reads
the truth (the phase 7 decision point), or confirmation that phases 5 and 6
behave the way they're written on a machine that can actually run them.
Read `01`–`05` in this folder as an accurate description of the design that
is running; read this file as the reminder that "running" and "verified"
aren't the same word yet.
