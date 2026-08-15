# How the game works — plain-English overview

This is a companion to the design canon in `from_user/`, written for reading
rather than for implementing. **No code, no GDScript.** Where it helps, logic
is shown as pseudo code (`IF this THEN that`), not real syntax.

It exists because "explaining the game" and "specifying the game" are
different jobs. The `from_user/` documents are the contract the code is built
against — precise, cross-referenced, full of constants. These documents are
the tour: what the game *is*, why it works the way it does, and — this is the
part the design docs can't tell you — **what of all that is actually built
right now**, versus what's still just written down.

Read these in order if you're starting cold. Skip around if you already know
the shape and just want one piece refreshed.

| # | File | What it covers |
|---|---|---|
| 1 | `01_world_and_characters.md` | The org chart, who's in it, what makes each character different, how "the world" gets built today vs. the full plan |
| 2 | `02_turn_flow.md` | What happens, in order, every single turn |
| 3 | `03_information_and_rumors.md` | The heart of the game: who knows what, how they find out, how rumors drift and lie |
| 4 | `04_npc_decisions.md` | How a character — any character, including eventually the player — picks what to do |
| 5 | `05_jobs_ranks_and_judgment.md` | The day job, how people rise and fall, public trials |
| 6 | `06_current_status.md` | What's real today, what's still paper, what's genuinely unresolved |

---

## The game in one paragraph

You are a member of a criminal organization drawn as a tree: a boss at the
top, crews branching below. The only goal is to climb the ranks and then
survive holding your place. There's no map, no shops, no combat minigame —
the tree of people **is** the entire game. Every character, the player
included, gets one action per turn, chosen from the same rulebook everyone
else uses. Nobody is special-cased. What makes it interesting is not the
actions themselves — there are only a handful — but that **nobody knows the
full truth about anything**, including you.

## The one idea everything else hangs off

Split "what happened" from "what people think happened," and never let
those merge back together.

- **Ground truth** — the simulation's private ledger of what actually
  occurred. A character was actually killed by a specific person for a
  specific reason. This ledger is never wrong and nobody in the game can
  read it directly.
- **Evidence** — the scraps of that truth that leak into the world: a body,
  a rumor, a suspicious absence. Evidence is almost always incomplete. It
  usually tells you *what* happened and *who it happened to*, but not *who
  did it*. That gap — a burned warehouse everyone can see, a culprit nobody
  can name — is where the entire game lives.
- **Belief** — what a specific character personally thinks happened, built
  from whatever evidence reached them, possibly garbled by the time it did.
  Two characters can hold two different, contradictory, equally confident
  beliefs about the same event, and both can be wrong.

Every character in the simulation — and this is a hard rule the code
enforces, not a suggestion — acts **only** on their own beliefs. An NPC can't
"cheat" by knowing who really killed someone. If a decision would require
peeking at ground truth, that decision is off the table and the design
around it needs rethinking, not a workaround. This one rule is why
misattribution — someone getting blamed, punished, or killed for something
they didn't do — is possible at all, and it's the single most important
thing to look for when reading a chronicle (the turn-by-turn log a run
produces): does at least one person, at some point, suffer for someone
else's crime?

## Why "climb, then hold" is two different games

The verbs you can use depend on your rank. At the bottom you have no
authority — you earn, you gossip, you attach yourself to someone who can
protect you. In the middle you can hand out work assignments, which means
you can quietly sabotage a rival by giving them the job you know will fail.
At the top the whole shape inverts: you're no longer climbing, you're
managing everyone below you who *is* — every promotion you hand out is a
future problem you created yourself.

## What's built vs. what's designed

The design documents describe the full intended game. The code currently
implements a slice of it — enough to run the "falsification demo": a
headless simulation with no player and no graphics, 16 characters, seven
actions, that either produces a readable, causally-connected story or
doesn't. `06_current_status.md` is the honest, detailed version of this; the
short version, so you're not misled while reading documents 1–5:

- **Built and running:** the tree, characters with traits/goals/standing/
  money, the turn loop, jobs, the belief/rumor system, the NPC scorer
  (attention → candidates → score → risk → softmax choice), multi-turn plans,
  seven actions (Take Job, Assign Job, Sabotage Job, Dig, Spread Rumor, Kill,
  Denounce), public trials (Judgment), promotions-by-contest, heat, and two
  of the eight "outside shock" event types (a rival gang's hit, an arrest).
- **Designed but not yet built:** the full procedural world generator
  (history simulation, planted narrative hooks, six more exogenous event
  types), the other ~28 actions from the full verb list (Court and Cover
  actions especially — the ones that make a quiet turn viable), the other
  four ways to change rank besides violent removal (Advocacy, Challenge,
  Succession, Defection), money-laundering-adjacent actions (Buy Alibi, Buy
  Silence, debt-as-motive), and — last of all — the player. Right now nobody
  plays; the simulation just runs and writes a log.

Nothing below describes wishful thinking as fact. Where a document explains
something that isn't running code yet, it says so.
