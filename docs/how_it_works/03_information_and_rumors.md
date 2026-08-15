# The information model: events, evidence, and beliefs

This is the part of the game everything else is built on top of. If you
only read one of these documents, read this one.

## Three separate things, kept strictly apart

### Events — what actually happened

An event is the simulation's private, permanent record: on turn 14, Marco
sabotaged the shipment Vito was working. This record is ground truth. It is
never wrong, never forgotten, and — this is the rule everything else
depends on — **no character in the game, and no piece of the AI that
controls them, is ever allowed to read it directly.** If you ever catch an
NPC "just knowing" who really did something, that's not a clever AI, that's
a bug that breaks the entire premise of the game.

### Evidence — what an event leaves behind

An event doesn't announce itself. It leaves scraps behind — evidence —
and evidence is genuinely the *only* channel by which anyone, ever, learns
anything. Each piece of evidence has:

- **a kind** — an eyewitness account, a physical trace, secondhand hearsay,
  and so on. Different kinds carry different default confidence when
  someone finds them; an eyewitness account is trusted more than hearsay.
- **what it reveals** — critically, most evidence reveals *what happened*
  and *to whom*, but **not** *who did it*. Everyone can see Vito's shipment
  burned. Almost nobody automatically knows who lit the match. That gap —
  visible consequence, invisible cause — is where the entire game lives.
  A public accusation is the one exception: it's evidence of everything,
  including who's accusing whom, because it's not a secret.
- **who it points to, if anyone** — evidence that does implicate someone
  usually points at the real culprit, but not always. This is the field
  that misattribution runs through.
- **how easy it is to find** — evidence starts detectable and fades over
  time. A few turns after the fact, a "cold case" really is colder: it's
  mechanically harder to ever pin down.

### Beliefs — what one specific character personally thinks

A belief belongs to exactly one character. It's their personal, possibly
partial, possibly outright wrong claim about what happened in some event:
who did it (if they have any idea), what the action was, who it was done
to, all attached with a confidence level from 0 (barely credit it) to 1
(certain). Two characters can — and routinely do — hold two different
beliefs about the exact same event, one of them provably false, both held
with total sincerity.

## The one rule that makes the whole system honest

**No belief may exist without either a real event backing it, or a
deliberate act of fabrication.** Nothing is ever pulled from a random
"rumor table." Every single thing anyone believes traces back, however
distantly and however garbled, to something that genuinely happened (or to
someone who chose to lie). This is what makes the world feel causal instead
of arbitrary — if you're patient and lucky enough to trace a rumor all the
way back, there's always a real answer at the other end, even when that
answer is "someone made this up."

## How a character actually comes to believe something

There are several separate paths in:

**You know what you did.** The person who committed an event, and the
target of a direct assignment, automatically know it happened — no
detection roll needed.

**You find evidence yourself.** Every turn, each piece of evidence still
sitting in the world gets a chance to be noticed by nearby characters —
weighted by how close they are in the tree to what happened, whether
they're the Observant type, and how much general heat is making everyone
watchful. Finding a piece of evidence gives you a belief containing
*exactly* what that evidence reveals — no more. Find a trace that only
reveals "what" and "to whom," and you get a belief with a *blank* for who
did it. That blank is not a bug; per the design, it's "the crux of the
entire design."

**Someone tells you, in passing.** At the end of a turn, any belief a
character acquired recently has a chance to spread to their immediate
neighbors — patron, crew, tree-siblings — weighted partly by how well they
get along. Each retelling: confidence drops a little, and the story can
*mutate*. If the belief already names a suspect, there's a chance the name
changes. If it doesn't name anyone yet, there's a (smaller) chance one gets
invented on the spot. Either way, the replacement name is never random —
it's drawn from whoever already has a plausible, known grudge or public
rivalry against the victim. **Rumors drift toward whoever already looks
guilty.** This is realistic, and it's exactly the exploit the game wants a
sharp player to eventually notice and use.

**Someone deliberately tells you.** This is the Spread Rumor action — a
character choosing, on purpose, to hand a specific belief they hold to a
specific other character, usually because it'll hurt someone they resent.
Mechanically similar to ordinary gossip (same drift logic can apply) but a
direct, chosen telling degrades a little less than an overheard chain does.

**Someone reports it up the chain.** Separately from gossip between
neighbors, subordinates periodically pass what they've learned up toward a
superior — not necessarily their *own* superior; see `02_turn_flow.md` for
why a disloyal subordinate's report can end up somewhere else entirely.

**A verdict is announced.** When a public accusation (Denounce) gets
adjudicated, the verdict itself is treated as common knowledge — everyone
active gets a strong, direct belief about the outcome, no detection or
gossip roll required. This is the one genuinely reliable broadcast channel
in the whole game.

**You dig for it.** Covered on its own below — investigation is different
enough from all of the above to deserve its own section.

## What happens when a new belief meets an old one

If a character already has a belief about the same event and a new claim
comes in:

- Any field they didn't already have gets filled in.
- If the new claim names the **same** suspect they already believed:
  confidence goes **up**. Hearing the same name from a second, independent
  source hardens it. This is exactly how a confident falsehood gets born —
  nobody involved is lying maliciously at any single step, the story just
  keeps getting corroborated by people who all ultimately heard it from
  slightly-mutated versions of the same original rumor.
- If the new claim names a **different** suspect: whichever version is
  currently more confident wins the name, but overall certainty takes a
  hit either way — conflicting testimony should make you less sure, not
  more, even about the version that "won."

## Investigation — Dig

If you hold a belief with a gap in it — usually the "who" — you can
deliberately investigate. This costs nothing but the turn, but it is not
free of consequences: **investigating leaves its own trace.** "Marco has
been asking around about the warehouse fire" is itself a piece of evidence,
and if the real culprit ever hears about it, they now know someone's
closing in on them and have a very specific reason to move against that
someone first. Investigation is meant to be a visible, dangerous act, not a
free lookup.

A dig resolves to one of four outcomes:

1. **Resolve** — the true answer comes in, confidence jumps way up.
2. **Corroborate** — no new information, but confidence rises anyway (you
   didn't learn anything new, but you didn't find anything to doubt it
   either).
3. **Collapse** — no supporting evidence exists (either it decayed away, or
   there genuinely wasn't any, or you were chasing a fabrication).
   Confidence craters, and — notably — whoever originally told you this
   belief takes a lasting credibility hit for having pointed you at a dead
   end.
4. **False resolve** — you come away with a confident, plausible answer
   that is simply **wrong**. This uses the exact same "who looks guilty"
   weighting as ordinary rumor drift — a failed dig doesn't return "nothing
   found," it returns a wrong name, biased toward whoever already has a
   known motive.

The game today scopes digging to resolving *who did it* specifically —
that field is, again, the one the design calls "the crux of the entire
design," so it's the one that got built first.

## What this buys the game

Put together, this system is what makes the following genuinely possible,
without a single line of authored "story":

- **Revenge that's aimed at the wrong person**, because that's who the
  rumor drifted toward.
- **A confident public accusation that turns out to be completely false**,
  because enough independent-seeming retellings all happened to converge on
  the same wrong name.
- **A cold case that goes permanently cold**, because the evidence decayed
  before anyone thought to look.
- **A serial accuser nobody believes anymore**, because their credibility
  took repeated hits from accusations that didn't hold up.

The single metric the design cares about most, more than any other number
the simulation produces, is whether this actually happens at a healthy
rate — a run where nobody is ever wrongly blamed for anything is, by this
design's own standard, a failed run, no matter how much else in it looks
fine.
