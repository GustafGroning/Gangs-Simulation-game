# Jobs, rising and falling, and public trials

## Jobs — the game's honest clock

Without something to actually *do* between plots, the game degenerates
into pure social maneuvering with no substrate underneath it. Jobs are that
substrate: a small board of available work refreshes most turns, and taking
a job is how most characters earn money and standing in the ordinary
course of things.

Each job has a **kind**, and the kind is what makes assignment a real
choice rather than a formality — different kinds trade risk for reward in
different ways:

| Kind | Risk | Payout | What it's for |
|---|---|---|---|
| Collection | Low | Low | The safe default |
| Delivery | Low | Modest | Physical evidence, hard to detect |
| Shakedown | Medium | Medium | Someone usually sees it |
| Heist | High | High | Fast climb, biggest trail — the reckless option |
| Negotiation | Medium | High standing, low money | No incriminating evidence at all — the patient option |
| Enforcement | High | Standing, low money | Generates heat |

Negotiation and Heist are meant to feel meaningfully different to play:
Negotiation is how a patient character climbs without much exposure at
all; Heist is the fast, loud, risky version of the same climb.

**Getting a job is a bet, not a guarantee.** How well it goes depends on
the worker's competence against the job's difficulty, a small bonus for
higher rank, and some randomness, landing in one of four outcome bands —
success, partial success, failure, or outright disaster. A disaster on a
violent job can additionally trigger an arrest.

**Two ways to get assigned work:** a character can pick the best-fitting
open job for themselves, or a superior can hand them one directly. Directed
assignment overrides self-selection, and it's deliberately double-edged —
a superior handing out work is also handing out an opportunity to either
help someone (give your favorite the easy, safe job) or quietly sabotage
them (give your rival the job you already suspect will fail). The scorer
picks this up for free: a character deciding who to assign work to weighs
their grudge against that person's odds of failing, without a single line
of code that treats "being spiteful with a job assignment" as a special
case.

**Failure is deliberately ambiguous.** A failed job always creates an event
blaming the assigned worker — that's the honest default reading, "you
weren't good enough." But if someone actually sabotaged it, a *separate*
event exists with the real saboteur as its actor, and whether that second
event's evidence ever surfaces is exactly as uncertain as any other piece
of evidence in the game. That asymmetry — the visible failure vs. the
hidden cause — is what makes Sabotage Job a genuinely strong, quiet move,
and what makes investigating a suspicious failure actually worth doing.

**An unfilled job costs someone.** A job that expires with nobody assigned
docks standing from whoever's responsible for keeping the board moving —
so a superior who spends every single assignment settling scores instead
of actually running the crew pays a real, visible cost for it.

## Standing, rank, and how you actually move up

Standing is what you accumulate, turn over turn, from lots of small
sources. Rank is what you eventually spend it on, and it changes rarely —
most turns move a number, only occasionally does the tree's actual shape
change.

**The one mechanism currently running:** when a slot goes empty — someone
died, got exiled, or got arrested — everyone one rank below it (plus
anyone at the same rank who might reasonably make a sideways move)
automatically competes for it at the end of that same turn. The winner is
essentially whoever has the highest standing, with a small bonus for having
already been part of that slot's crew, plus a little randomness so an
occasional upset can happen. **Losing a contest isn't neutral** — every
loser comes away with a fresh grudge against whoever won and a bump in
their own ambition. Every single promotion manufactures its own next
conflict, for free, without anyone having to write a new grudge by hand.

**Four other ways to change rank are designed but not yet built:** being
deliberately elevated by a superior who values you (Advocacy); publicly
claiming you deserve someone's position outright (Challenge); quietly
absorbing your patron's crew if they fall while you're well-positioned
(Succession); and moving laterally to a different patron who wants you more
(Defection). Each is meant to reward a different kind of character — a
patient, relationship-focused one thrives on Advocacy and Succession; a
loud, confident one uses Challenge; a mobile one uses Defection — but right
now, the only path to a new rank in this game is somebody dying or getting
removed. See `06_current_status.md` for what that narrowing likely does to
how a run actually feels.

## Judgment — public trials

A character can publicly accuse someone of a specific past event they
personally believe that person committed. This is Denounce, and it doesn't
resolve on the spot — it gets queued and adjudicated at a fixed point later
in the same turn, by **Judgment**.

**Who judges:** whoever's highest-ranked among everyone *not* directly
involved — not the accuser, not the accused, not either one's own patron
(too invested to be trusted). If the accused happens to be the boss, the
case falls to the highest-ranked uninvolved subordinate instead, which is
exactly as dangerous a position to be in as it sounds, and that's
intentional.

**How the verdict actually gets decided — and the single most important
rule in this whole section:** the judge consults only *their own* belief
about the accused event. If the judge doesn't happen to hold any belief
about it at all, that part of the case is worth nothing, and the whole
thing rests on the accuser's standing versus the accused's standing instead
— meaning a powerful person can genuinely push through a weak case, and an
honest nobody with a true accusation can genuinely lose. **Whether the
accused person was actually guilty is never checked, anywhere in this
process.** The system adjudicates beliefs, exclusively, on both ends.

Roughly, the strength of a case comes from:

```
case strength = (how confident is the judge, personally)
              + (how many OTHER people also believe the same thing)
              + (accuser's standing)
              − (accused's standing)
              + (a little randomness)
```

and the strength lands in one of four bands:

| Case strength | Verdict | What happens |
|---|---|---|
| Weak | Dismissed | The accuser loses standing; the accused gets a fresh grudge against them |
| Moderate | Demoted | The accused drops a rank; their old slot goes to contest |
| Strong | Exiled | The accused is removed from the tree entirely |
| Overwhelming | Killed | The accused is removed, and it generates significant heat |

A dismissed accusation isn't free for the accuser — it costs them
credibility, meaning their future beliefs carry less weight when they
spread. Serial false accusers become people nobody listens to anymore,
which is both realistic and a genuine cost on the accusation itself, not
just a slap on the wrist.

Whatever the verdict, it becomes public knowledge immediately and reliably
— everyone active gets a strong belief about the outcome with no detection
roll needed. This is the one moment in the entire game where information
travels perfectly and instantly to everyone; every other channel is
partial, delayed, or lossy on purpose.

## Heat — the game's rhythm mechanism

One shared number, rising with violence (a killing raises it a lot,
lower-key violence a little) and job disasters, falling steadily on its
own and extra fast for anyone who spends a turn deliberately keeping a low
profile. While it's high: evidence gets easier to find, consequences feel
worse to everyone estimating their own risk, and outside pressure (police
attention, arrests) becomes more likely. The intent is a natural rhythm:
after a killing, the correct play for a while is to be boring, because
everyone's suddenly watching. If a run comes out reading like nonstop
violence with no lulls, this is the second thing worth checking, right
after how risk itself is being weighted.

## Shocks from outside the tree

Without some outside pressure, the social graph tends to settle into a
stable equilibrium and the late game goes flat — nobody has a reason to do
anything new. The design calls for eight different kinds of outside shock,
firing roughly once every 6–8 turns; **two are built today**:

- **A rival hit** — an outsider kills one of your people. Nobody inside the
  tree did this, and the evidence genuinely points nowhere — but the
  belief system doesn't know that, and characters with an existing grudge
  against the victim will still end up looking guilty to somebody. This is
  a clean, free misattribution cascade, and a direct test of whether the
  belief layer is actually working.
- **An arrest** — someone gets pulled out of the tree by outside law
  enforcement, either from generally sustained high heat or right after a
  violent job goes catastrophically wrong. Nobody is blamed for this one at
  all — it's the *only* way a slot opens up with no culprit whatsoever,
  which matters because without it, literally every promotion in the game
  would be downstream of somebody's crime, and the world would read as
  unrelentingly murderous. In the current build this removal is permanent,
  not the "gone for 5–15 turns and then back" the design calls for — there
  isn't currently a way to represent "temporarily out of the picture" in
  the game's state.

The other six designed shocks — sustained police pressure, an exceptionally
big score, a stretch of lean times, a leak inside the organization nobody
can identify, personal money trouble, and an outside offer that could pull
someone away entirely — are written down but not yet built.
