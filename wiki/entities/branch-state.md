---
title: Episodic branch state (P2)
type: entity
created: 2026-09-01
updated: 2026-09-01
links: [stop-gate, session-start-injection, pending-ingest-marker, session-reflector]
---

# Episodic branch state (P2)

## TLDR

`.strata/state/<branch-slug>.json` — a small, schema-validated, **git-tracked** file per branch
holding what the wiki's append-only log cannot: the branch's current goal, decisions (with why),
open questions, gotchas, and `wiki_debt` — knowledge owed to the wiki that isn't a `docs/*.md`
edit yet.

## Role

`wiki/log.md` is a trajectory — it answers "what happened, in order". Nothing answered "what is
true *right now* about this branch" — the object SKILL.state (arXiv:2608.26263) calls execution
state and the field calls episodic memory. Without it, every session boundary and every `/clear`
made the model reconstruct context from scrollback, or — the actual symptom that motivated this —
never captured it at all, because the only automatic wiki trigger was an edit to `docs/*.md`.
`wiki_debt` closes that gap: it's the missing signal for knowledge that exists (a decision made in
conversation, a gotcha hit) but hasn't reached a doc yet.

## Current solutions

**Shipped in v0.5.0.** Schema owned by `scripts/lib/state_tools.py` (stdlib-only CLI: `init`,
`validate`, `debt`, `summary`, `path`):

```
goal (str, required) · status: active|blocked|done (required) · branch (required) ·
updated (ISO-8601, required) · verify (str) · decisions[{what, why, evidence, trust}] ·
open_questions[str] · gotchas[str] · wiki_debt[str] · files_touched[str]
```

`trust` on each decision defaults to `"session"`; `"reviewed"` is set only when a human or
`wiki-ingest` actually promotes it. Nothing promotes automatically — the quarantine minimum from
the user's own Prime Agent notes (P-1): persistence must not silently launder an unverified claim
into something later reused as fact.

Wired into the existing hooks rather than a new gate:

- [[stop-gate]] trigger (c) — blocks once (same one-block-per-session cap as triggers a/b) when
  the current branch's state has non-empty `wiki_debt`, or exists but fails validation. A
  *missing* file is not a trigger — the layer is adoptable incrementally.
- [[session-start-injection]] prints the state summary (goal, status, decision/open-question/debt
  counts) when a file exists for the current branch.
- `light-finish` folds `decisions`/`gotchas` into the branch's final `wiki/log.md` entry and
  deletes the state file on close — a merged branch doesn't keep scratch state around once its
  reviewed content moved to `wiki/`.
- `audit` flags a state file whose branch no longer exists (orphaned) and counts unreviewed
  (`trust: session`) decisions.

Committed on purpose (see [ADR #5](../decisions/adr-5-episodic-state-branch-scoped.md)) —
`.gitignore` carve-out is `.strata/*` + `!.strata/state/`, so session stamps and the version
stamp stay ignored while state is tracked.

**Not attempted:** SKILL.state's turn-by-turn `state_patch`/`action` loop and its 93–98% token
savings. Both come from a runtime that owns the model's inference loop and discards history after
every step; Strata doesn't own Claude Code's loop. What ported is the abstraction (explicit,
schema-validated, mutable state), not the mechanism.

**Distinct from [[session-reflector]]** (P3, not yet built): branch state is this-branch,
in-progress, per-file facts a human/AI wrote directly. The reflector, when built, distils
cross-session *lessons* (what worked, what failed) into `wiki/playbook.md` as delta bullets. Don't
duplicate a fact across the two once both exist.

## Related

[[stop-gate]] · [[session-start-injection]] · [[pending-ingest-marker]] · [[session-reflector]] ·
[[upgrade-path]]

## Sources

[[episodic-state-layer]] · [ADR #5](../decisions/adr-5-episodic-state-branch-scoped.md)
