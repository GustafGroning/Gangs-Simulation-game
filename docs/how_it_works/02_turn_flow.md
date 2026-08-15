# What happens in a turn

Turns are the only clock in the game — there's no real-time anything, no
frame counter, nothing. Everything that happens, happens because a turn
advanced. Each turn runs the same fixed sequence of steps, in the same
order, for every character simultaneously. Here's that sequence, in plain
English, in the order it actually runs today:

```
1.  Upkeep — heat cools off a little, old evidence decays a little
1b. A chance of an outside shock (a rival gang hit, an arrest) —
    placed early so people can react to it THIS turn, not next turn
2.  The job board refreshes — new work becomes available
3.  Every active character, all at once, picks ONE action for the turn,
    based only on what THEY personally believe — never on the truth
4.  All those chosen actions actually happen, in a fixed priority order
5.  Whatever just happened leaves evidence behind
6.  People roll to notice that evidence
7.  Noticed evidence spreads by word of mouth to neighbors, one hop,
    drifting a little each time it's retold
8.  Some of what people just learned gets reported up the chain of command
9.  Any public accusation made this turn gets a verdict
10. Any now-empty slot in the tree gets contested and filled
11. Everyone's goals nudge in response to what just happened to them
12. The turn's log is written and the numbers for this turn are recorded
```

Each of the numbered steps below expands one line of that list.

## 1. Upkeep

Two things quietly wind down every turn: **heat** — a global "how much
attention is the organization attracting" dial that rises after violence
and falls on its own over time — and **evidence** — every piece of evidence
sitting in the world gets a little harder to find each turn, until
eventually it's too faint to matter and disappears. This is deliberate:
cold cases are supposed to go cold. If you want to investigate something,
waiting makes it harder, not easier.

## 1b. Outside shocks

Occasionally, something happens that has nothing to do with anyone's
scheming — a rival organization kills one of your people, or the police
sweep someone up. See `05_jobs_ranks_and_judgment.md` for the full list;
the point for the turn flow is that these fire early, so the rest of the
turn — the job board, everyone's decisions — reacts to a *fresh* event
rather than a stale one from last turn.

## 2. The job board

A couple of new jobs (see doc 5) become available to work. This is the
game's "honest clock" — without a day job to show up for, the game would be
pure social maneuvering with nothing underneath it.

## 3. Everyone decides, all at once

This is the step covered in full in `04_npc_decisions.md`. The short
version: every active character looks at *their own beliefs* — never the
simulation's private ground truth — and picks the single action that seems
best to them, factoring in what they want, what they risk, their
personality, and anything they're already in the middle of. The player,
once the player exists, will make this same choice through the same
machinery, with the same information limits. Nobody is exempt.

## 4. Resolution — actions happen, but not all at the same moment

Even though everyone *decided* simultaneously, the chosen actions don't
execute in a random jumble. They resolve in a fixed pecking order, so that
certain kinds of actions can meaningfully protect against or set up others
within the same turn:

```
Command  →  Cover  →  Earn  →  Strike  →  Court  →  Whisper  →  Learn
```

The intuition: an alibi bought this turn (Cover) protects against a strike
made later in this same turn. A job assignment (Command) has to land before
anything downstream can react to who's working what. Investigation (Learn)
goes last, so it sees the freshest possible evidence, including whatever
just got left behind by everything else that happened this turn.

Within that order, ties are broken by a pre-drawn random number, not by
whoever's id happens to be lowest — nobody gets a structural edge just for
being generated first.

One quiet but important rule: if a higher-priority action removes someone
from play this same turn (a Kill, for instance), any action that same
now-dead person had *also* queued up for later in the turn simply fizzles.
It doesn't execute posthumously.

## 5–6. Evidence and detection

Whatever just happened leaves behind evidence — see
`03_information_and_rumors.md` for the full mechanics. Then, still within
the same turn, other characters roll to notice that evidence, weighted by
how socially close they are to what happened, whether they have a trait
that makes them more observant, and how much heat is currently making
everyone jumpier.

## 7. Gossip

Anything a character learned recently can spread, once, to their immediate
neighbors in the tree — patron, crew, siblings under the same patron. Each
retelling can blur: confidence drops a little, and — this is the important
part — who gets blamed can *drift*, nudged toward whoever already looks
plausibly guilty. This is covered in detail in the next document; it's the
mechanism that actually produces misattribution.

## 8. Reporting up the chain

Separately from ordinary gossip, a character can pass something they just
learned up to a superior. Who they choose to tell isn't automatic — it's a
weighted pick, and it doesn't have to be their own direct patron. A
character with low loyalty toward their patron is more likely to route the
same information sideways, to a rival, instead. Nobody reports something
that would incriminate themselves, their own patron, or someone they're
personally loyal to. And every superior can only actually absorb a handful
of reports each turn — flooding them with more doesn't get more attention,
it just means some reports get dropped.

## 9. Judgment

If anyone was publicly accused this turn, that accusation gets adjudicated
now, by whoever is best positioned to judge it fairly. See
`05_jobs_ranks_and_judgment.md` for exactly how a verdict gets decided —
the short version worth knowing here is that the judge only ever consults
*their own* beliefs, never the truth, so a confident, well-corroborated
false accusation can win, and a true one with no evidence behind it can
lose.

## 10. Filling empty slots

Any slot in the tree that's currently empty — whether it just opened this
turn or has been open since the world was generated — gets contested and
(if anyone eligible exists) filled. More in `05_jobs_ranks_and_judgment.md`.

## 11. Goals shift

Nothing is scripted here ("Marco now wants revenge") — numbers move.
Getting passed over for a promotion nudges Ambition up and Vengeance
(toward whoever won) up. Surviving an attempted move against you nudges
Security up and Ambition down. Every one of these nudges also decays back
toward baseline over time, which is what keeps grudges from becoming
permanent and lets character arcs actually *resolve* instead of running
forever. More detail in `04_npc_decisions.md`.

## 12. The report

The turn's events get written out as a human-readable log line — this is
the **chronicle**, and it's meant to double as both a debugging tool and
the eventual player-facing end-of-turn report. Every consequential line
names its own top two reasons, e.g.:

```
T14 — Marco sabotages Vito's shipment, anonymously.
      (vengeance +0.60 · ambition +0.15)
      Traces: physical evidence at the warehouse.
```

and belief lines are printed distinct from ground truth, with a mark when
someone's belief is provably wrong:

```
▸ Sal believes Bruno sabotaged Vito's shipment (conf 0.62, hops 1) ✗ WRONG
```

If reading the chronicle ever feels like a chore, that's treated as a bug
in the game, not just the logging — this log is meant to be the shipped
end-of-turn report, not a debug dump nobody but a developer would read.
