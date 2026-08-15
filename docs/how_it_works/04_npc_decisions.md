# How a character decides what to do

Every character — the player will eventually be one of them, playing by
identical rules — runs through the exact same pipeline every turn to pick
their one action. There is no special-casing anywhere in here for any
specific verb; the machinery that makes this decision genuinely does not
know what "Kill" or "Take Job" *mean*. It only knows how to ask each action
"how good would you be for me right now, and how dangerous," and do
arithmetic with the answers. This separation is treated as close to sacred
in the design — it's what lets new actions get added later without ever
having to touch the decision-making code itself.

In plain terms, here's the whole pipeline for one character, one turn:

```
1. Notice roughly 6-8 people worth thinking about this turn (attention)
2. List every action that's actually legal right now, given only what
   I personally believe (candidates)
3. Score every candidate:
     score = (how much do I want this, weighted by how much I care
              about each thing it affects)
            − (how risky does this feel to ME)
            + (small personality bonus/veto)
            + (bonus if this continues a plan I'm already committed to)
4. Don't just take the best-scoring option — roll a weighted, slightly
   random pick among the handful of best options (selection)
5. Log the choice along with the two biggest reasons behind it
```

## 1. Attention — you don't think about everyone

Scoring every possible action against every other character in the cast
would be both slow and, more importantly, *wrong* — real people don't
constantly reason about everyone they've ever met. So each turn, every
character builds a short list of roughly 6–8 people worth paying attention
to, made up of (in priority order): their patron and their patron's
patron, their own crew, anyone they currently hold a grudge or a loyalty
toward (strongest first), anyone competing with them for a slot that just
opened up, anyone who showed up in something they recently learned, and
finally a couple of totally random slots thrown in so the social graph
never fully calcifies into the same few relationships forever.

A Paranoid character gets a wider list than everyone else — they're
watching more people, which is exactly why they generate more false
alarms. A character who genuinely hasn't put someone on their radar simply
never considers acting against them, even if that person is quietly
plotting three tree-nodes away. That's correct behavior for this design,
not a bug — some plots are supposed to go unnoticed for a while.

## 2. Candidates — what's actually legal right now

For each of those attended-to people (plus a few "no target needed"
actions like Take Job or lying low), the game checks which actions are
currently legal *against this character's own beliefs*. This is where the
"gate on social state, not cooldowns" idea lives: you can't Denounce
someone unless you personally hold a belief implicating them above some
confidence threshold; you can't sabotage a job unless you know when it's
assigned. There's no timer anywhere saying "you did this three turns ago,
wait five more" — what's available to you changes because the social graph
around you changed, not because a clock ticked.

## 3. Scoring — one number per candidate

Every action, when asked to evaluate itself against a specific target,
answers with a small set of magnitudes on a fixed scale (roughly −1 to 1)
saying how much it would move each of the character's goals. A hypothetical
Kill, for instance, might report back something like "this would satisfy
0.9 worth of my vengeance toward this person, and 0.3 worth of my
ambition, because they're standing between me and a promotion." Those
magnitudes then get multiplied by how much this character actually cares
about each of those goals right now, and summed — that's the utility half
of the score.

### Risk is never hand-authored per action

This is one of the firmer rules in the design: risk isn't a number someone
typed in for each action. It's *derived*, automatically, from what evidence
that action would leave behind:

```
perceived_risk = (chance someone notices) × (chance it lands on me)
                × (how bad would that be)
```

- **Chance someone notices** comes from how detectable the action's
  evidence naturally is, how socially close potential witnesses are, and
  the current heat level (an organization under scrutiny notices more).
- **Chance it lands on me** depends on whether this specific action would
  even reveal *who* did it (many don't — see the previous document),
  whether the character already has a known, public grudge against the
  target (having a motive makes you the default suspect even before
  anything happens), and — this is a nice emergent detail nobody had to
  author — how many *other* people also have a plausible motive against
  the same target. The more people who look guilty, the safer everyone
  individually is.
- **How bad would that be** scales with the kind of consequence the action
  could realistically trigger, and gets worse the more heat is already in
  the air.

All three of those are *estimates made by the character themselves*, not
objective truth — which is exactly where traits earn their keep. A Reckless
character's own estimate of "chance someone notices" is quietly too low;
a Craven character's estimate of "how bad would that be" is quietly too
high. Neither of them is lying to themselves on purpose, and neither of
them can tell they're doing it — from their own point of view, they're
making a perfectly rational call. The point isn't to make a Reckless
character reckless by fiat; it's to make them consistently, believably
wrong about their own safety in one specific direction, which produces far
more interesting mistakes than just "50% more likely to pick violence"
would.

### Personality nudges the choice without deciding it

On top of utility and risk, each character's traits add a small flat bonus
to actions that match their flavor — Brutal characters lean toward
violence, Sly characters lean toward deception — kept deliberately modest
so it colors a close decision without steamrolling it. There's exactly one
hard override in the whole system: a Loyal character has an absolute veto
on ever taking a hostile action against their own patron, no matter how
good it would otherwise score.

## 4. Plans — so nobody murders someone on turn one

Left alone, a system that only scores single turns in isolation has an
obvious failure mode: a high-value but currently-blocked action (say, Kill,
which needs some precondition met first) just gets discarded every turn in
favor of whatever's immediately available and legal, and nobody ever
invests in anything. The fix is that when a strong action is blocked only
by something recoverable — a missing job assignment, an opponent who isn't
currently vulnerable — the character doesn't drop it, they form a **plan**:
a short queue of steps that leads toward it, discounted so a distant payoff
is worth less right now than an immediate one, but still enough to
outcompete a mediocre immediate option:

```
step_value = (discount factor) ^ (steps still remaining) × (value of
             the eventual payoff)
```

Once a character has an active plan, its very next step gets a small
ongoing bonus so they don't flip-flop between it and something else every
single turn — but the whole thing is still re-scored fresh every turn, so
the bonus *biases* the decision, it doesn't lock it in. A plan gives up —
aborts — if its target dies or leaves, if its precondition becomes
permanently impossible, if something else now dominates by a wide margin,
or if the character's patience simply runs out.

If a plan keeps failing without formally aborting, frustration builds, and
past a threshold the character either **escalates** — moving up a fixed
ladder of increasingly severe options aimed at the same target (today:
assign them a bad job → sabotage their job outright → kill them) — or gives
up and re-plans from scratch. Escalation under frustration is called out in
the design as one of the best sources of memorable incidents in the whole
system, because it reads, from the outside, exactly like someone's patience
finally running out.

## 5. Selection — never just take the best option

Even after all of that scoring, the character doesn't automatically take
whatever scored highest. The top handful of candidates go into a weighted
random pick — better-scoring options are much more likely to be chosen, but
it's never guaranteed, and how "flat" or "peaked" that randomness is
depends on the character's own temperature (a calculating character's pick
is close to guaranteed to be their best option; an erratic one might
genuinely go with their third-best). Two reasons for this: an AI that
always takes the literal best option produces characters who feel like
spreadsheets, and — just as importantly — it makes every run from the same
starting seed play out identically, which kills replayability stone dead.

## The log tells you why

Whatever gets chosen, the two largest-magnitude contributing terms get
carried forward into the chronicle line for that action, so a line like

```
Marco sabotages Vito's shipment.  (vengeance +0.60 · ambition +0.15)
```

is meant to be a complete, honest explanation of the choice, not flavor
text bolted on afterward. If you ever read a chronicle line and can't
figure out why a character did what they did from the numbers next to it,
that's treated as a real problem with the design, not just a display
issue.
