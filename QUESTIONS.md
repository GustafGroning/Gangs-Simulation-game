# Questions awaiting Gustaf

Single place for open questions. When answered: harvest into DECISIONS.md/canon/code, then delete the entry.

## 2026-08-14 — Job outcome bands vs. the resolution formula (doc 3)
Doc 3 §6 targets "roughly 30/30/30/10" across SUCCESS/PARTIAL/FAILURE/DISASTER,
but the §1 resolution formula (0.5 + (competence−difficulty)×weight + noise,
banded at 0.75/0.45/0.15) can't produce that split while competence stays
meaningful — hitting it needs noise so large that competence stops mattering.
Current tuning lands at ~28/45/24/3 with competence decisive (COMPETENCE_WEIGHT
raised to 1.0). Options: bless the current split, re-band (e.g. 0.72/0.5/0.2),
or say DISASTER should stay rare. Which do you want?

## 2026-08-14 — Standing runaway band vs. starting spread (doc 4 / doc 2)
Doc 4's health band "no character > 3× median standing" starts at ratio 2.4 on
turn 0 with doc 2's STANDING_BY_RANK [60,40,25,12] — the band leaves almost no
room and single seeds brush 3.0-3.1 with a stable, gini-0.32 economy. Applied
doc 4 §7's ">80% of runs in band" rule (held at 90%) instead of per-seed
perfection, and measured at end-state per doc 4 §2. OK, or should the band be
widened / made rank-relative?

## 2026-08-14 — gdai-mcp plugin copy is incomplete
Copied `addons/gdai-mcp-plugin-godot` from cozy-space as requested, and wrote `.mcp.json` pointing at the standard layout. But the cozy-space copy itself is missing the plugin's binaries: its own `.gitignore` excludes `bin/`, `*.gdextension`, and `*.py` (the MCP server script), and none of those exist on disk there either. The plugin's loader refuses to start without `bin/` ("Binary files ... are missing"), so enabling it in the editor will error until the full plugin (v0.3.2, gdaimcp.com) is re-installed into this project — cozy-space's `.mcp.json` also pointed at an old install path (`/Users/gustafgroning/Desktop/...`), suggesting the working install lived elsewhere. Once the full install is in place, the checked-in `.mcp.json` here should work as-is; if the server command differs, tell me and I'll update it.
