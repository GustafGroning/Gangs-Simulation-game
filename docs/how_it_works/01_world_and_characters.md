# The world and the people in it

## The tree

The organization is a tree, not a network. There's one boss at the top
(rank 0), and each rank below branches out: a handful of lieutenants
(rank 1), each with their own crew (rank 2), each of those with their own
soldiers (rank 3). Every position in that tree — whether occupied or
vacant — is called a **slot**. A character's **rank** is just which level of
the tree their slot sits at; their **patron** is whoever occupies the slot
directly above them; their **crew** is whoever occupies the slots directly
below.

The design canon calls for four ranks and roughly 15–20 characters total,
with the branching intentionally uneven — one lieutenant might have five
soldiers under them, another only two — because that asymmetry is free
texture: those two lieutenants are visibly in different positions without
anyone having to write a line of story about it. The version running today
uses a fixed shape: 1 boss, 3 lieutenants, 7 crew-rank slots, 6 soldiers —
16 characters, one deliberately-empty crew-rank slot from the very first
turn, so there's something legal to compete over before anyone reaches for
violence.

## What makes a character a character

Every character — the player will eventually be one too, subject to
exactly the same menu — has:

**Standing.** A continuous number, roughly reputation. It rises and falls
constantly from lots of small sources: a job well done, a promotion lost, a
public accusation dismissed. This is the currency you spend climbing.

**Rank.** Discrete, changes rarely. You don't spend standing directly on
rank — you accumulate it, and rank changes when a slot opens up and you're
the one who wins the contest for it (see `05_jobs_ranks_and_judgment.md`).

**Money.** Can go negative. Buys you *out of trouble*, never buys you
standing directly — the design is explicit that money should convert quiet
turns into capability, not purchase what only the social graph can give.

**Traits.** One to three, drawn from a fixed list, each nudging how a
character *perceives* the world rather than what they're capable of doing
(see below and `04_npc_decisions.md`). Some pairs never co-occur — Reckless
and Craven are opposite reactions to risk, so a character is never both.

**Temperature.** How predictable a character is when picking between
several roughly-equally-good options. Low temperature: calculating,
near-optimal, plays the odds. High temperature: erratic, plays a wide
spread of options even when one is clearly better. This is a personality
knob, not a competence one — a Calculating character isn't smarter, just
steadier.

**Competence.** How good a character is at their job. Feeds into whether a
job they take succeeds, how well they garble a rumor as they pass it on, and
how good their own instinct for detecting evidence is.

**Goals.** Four numbers — Ambition, Security, Wealth, Standing — each
0 to 1, representing how much that character currently cares about that
thing. These aren't fixed personality; they drift over the course of a run
in response to what happens (being passed over spikes Ambition; losing
money spikes Wealth; see `04_npc_decisions.md`), but they always drift back
toward a personal baseline set at character creation, so the character stays
recognizably themselves even mid-arc.

**Loyalty and Vengeance.** Unlike the four goals above, these aren't single
numbers — they're *per person*. `Vengeance[Vito] = 0.8` means this character
specifically wants to hurt Vito, for as long as that number stays high.
These start completely empty for everyone and are earned (or provoked)
during play — nobody starts the game already hating somebody for no reason.

**Credibility.** How much weight this character's word carries when they
pass a belief to someone else. Starts at 1.0 (full weight) and takes a
lasting hit if they're ever caught out — a public accusation that gets
dismissed, or a lead they dug up that turned out to be nothing. A serial
accuser eventually becomes someone people stop listening to, which is both
realistic and a real cost on crying wolf.

### Traits and what they distort

| Trait | What it does |
|---|---|
| Reckless | Underestimates how likely they are to get caught — acts boldly, gets caught constantly |
| Paranoid | Acts on beliefs even at low confidence — starts feuds over thin evidence, widens their own attention (they're watching more people) |
| Observant | Genuinely better at noticing evidence other people missed |
| Craven | Overestimates how bad getting caught would be — avoids anything traceable |
| Brutal | Extra pull toward violent options |
| Sly | Extra pull toward deceptive options |
| Loyal | Will never act against their own patron, no matter how good the opportunity looks, and reacts hard if their patron is harmed |
| Ambitious | Extra hunger for climbing |
| Greedy | Extra hunger for money |
| Calculating | Steadier, more predictable choices (low temperature) |

Notice most of these change what a character *thinks is true*, not what's
actually true. That's deliberate — a trait that makes a character wrong
generates a far better story than a trait that just makes them stronger.
Reckless and Paranoid in particular are what the design calls
"misattribution engines": a Reckless character gets caught doing things a
more careful person would've gotten away with, and a Paranoid character
starts pointing fingers on evidence a calmer person would shrug off.

## How the world comes to exist

This is the part where **design and reality currently diverge**, and it's
worth being precise about it.

### The full design (written, not yet built)

The canon describes an eight-step generation pipeline whose entire purpose
is to make sure the world is *already interesting* on turn 1, instead of
starting everyone as identical strangers and waiting 40 turns for
personality to emerge:

```
build the tree
generate characters (personality only, no positions yet)
assign characters to slots, roughly by fitness (not pure meritocracy —
    on purpose, so at least one visibly underqualified person holds a
    senior slot)
simulate ~15 turns of real history before turn 1 "officially" starts,
    with killing and public accusations turned off
derive relationships (opinions) from what happened in that history,
    plus a bit of personal chemistry noise
plant ~6 deliberate structural tensions, each backed by a real event
    from that simulated history — e.g. two siblings where one was
    promoted over the other, so the loser starts turn 1 already
    resentful
seed who-knows-what unevenly: the boss should know about most events
    but shallowly, soldiers should know their own neighborhood well,
    and — this is the important part — at least three characters should
    already hold a confidently wrong belief about who did something
```

That last point is called out as the single best predictor of whether a
full run will produce a good story: if the belief system can't manufacture
a confident falsehood during 15 turns of *pre-game* history, it won't
manufacture one during 100 turns of real play either, and that's worth
finding out before building anything on top of it.

### What actually runs today

A simpler, fixed **bootstrap**: it builds the same 16-slot tree shape, gives
each character randomized (but not history-derived) traits, temperature,
competence, and goals, assigns them to slots by a fitness score with some
randomness mixed in (again: not strictly meritocratic, on purpose), and sets
up starting relationships from tree structure alone — a patron feels
mild goodwill toward their crew, crew members feel mild goodwill back, and
siblings under the same patron start with a small built-in dislike, because
they're structurally competing for the same future advocacy.

What the bootstrap does **not** do yet: no pre-simulated history, no
planted hooks, no uneven starting knowledge, no starting falsehoods. Every
character begins turn 1 knowing essentially nothing about anyone, and every
relationship that isn't pure tree-structure has to be earned live, during
the run itself, rather than inherited from a backstory. This is a real gap
against the design's stated goal of a world with tension already in it —
see `06_current_status.md` for what that likely means for how the first
several turns of a run actually read.

## A worked example

Sixteen names are drawn from a small fixed pool (Rosa, Marco, Vito, Sal,
Nina, Enzo, Carla, Dante, Bruno, Livia, Paolo, Gia, Tony, Ada, Rocco, Mira,
Franco, Delia, Ugo, Zeta — the first 16 of these, in the current bootstrap).
Say Vito lands the boss slot — not because he's the most competent person in
the cast, but because his fitness score (a blend of competence, ambition,
and a little randomness) happened to come out on top. Marco and Sal both end
up as crew under the same lieutenant, Nina. Because they're siblings in the
tree, they start with a small mutual dislike baked in — nothing personal has
happened between them yet, but the game already knows they're rivals for
Nina's attention. Everyone else starts neutral toward everyone outside their
immediate tree neighborhood. Nobody knows anything about anyone's past.
Play begins.
