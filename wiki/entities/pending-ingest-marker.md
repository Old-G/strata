---
title: pending_ingest marker
type: entity
created: 2026-08-15
updated: 2026-08-15
links: [raw-mirror-hook, stop-gate, commit-gate]
---

# pending_ingest marker

## TLDR

A line in `wiki/log.md` of the form `pending_ingest: docs/<file>.md`, written when a doc is
mirrored into `raw/` and cleared only by a completed ingest. It is the single token the
whole [[enforcement-layer]] reads.

## Role

The marker turns "the wiki owes work" from a judgement call into a grep. Any component can
answer "is the knowledge layer behind?" with one pass over `wiki/log.md` — no model, no
heuristics, no state machine.

## Current solutions

Written by [[raw-mirror-hook]] (`sync_raw_mirror.sh`) as a dated `## <ts> auto-mirror`
block containing `- pending_ingest: <src> (mirrored docs/ -> raw/, ingest still owed)`. The
script is idempotent per file — it skips writing when that file *already owes* an ingest,
which is not the same as "this string has appeared before" (see [[raw-mirror-hook]] for the
defect that distinction fixed).

Until v0.4.0, **nothing consumed these markers** — they were write-only, which is the root
cause of wiki drift. Feature A gives them two consumers:

- [[stop-gate]] blocks turn end on markers created in the current session
  ([ADR #4](../decisions/adr-4-stop-gate-session-scope.md)).
- [[commit-gate]] blocks the commit on *any* outstanding marker.

Clearing convention: an `ingest raw/<file>.md → created/updated: …` line for that file,
appended after the marker, retires it. Pairing is by line order, so an edit → ingest → edit-again
cycle correctly reopens the marker. The rule lives in exactly one place —
`scripts/lib/pending_ingest.sh` — sourced by all three gates and by the mirror hook.

## Related

[[raw-mirror-hook]] · [[stop-gate]] · [[commit-gate]] · [[enforcement-layer]]

## Sources

[[vnext-brief]] §1, §2 (A1–A2)
