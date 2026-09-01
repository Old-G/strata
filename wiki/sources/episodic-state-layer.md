---
title: "P2 — Episodic state layer + upgrade path (source)"
type: source
created: 2026-09-01
updated: 2026-09-01
links: [branch-state, upgrade-path, stop-gate, session-start-injection]
---

# P2 — Episodic state layer + upgrade path

Source: [docs/superpowers/specs/2026-09-01-episodic-state-layer.md](../../raw/superpowers/specs/2026-09-01-episodic-state-layer.md)

## Summary

Two problems traced back to one research session (SKILL.state, arXiv:2608.26263; Prime Agent,
arXiv:2608.23552, plus the user's own Prime Agent notes). First: repos adopted before v0.4.0 run
with zero enforcement, because `init`/`adopt` copy `templates/core/scripts/**` once and there was
no re-sync path — confirmed on a real external project (`wiki/` present, all three hooks absent).
Second: the wiki only ever hears about `docs/*.md` edits, and `wiki/log.md` is an append-only
*trajectory*, not a *state* — nothing answers "what do we currently know about this branch" after
a `/clear` or a session boundary.

The spec ports SKILL.state's abstraction — explicit, schema-validated, mutable state — rather
than its mechanism. SKILL.state's 93–98% token savings come from a runtime that owns the model's
inference loop and discards history after every step; Strata doesn't own Claude Code's loop, so
that mechanism doesn't port. What does port: a small state object updated deliberately at hook
boundaries instead of asking the model to reconstruct "what have we decided" from scrollback.

## Four decisions (resolving the source artifact's open questions)

1. **Validator ownership.** One script (`scripts/lib/state_tools.py`) owns the schema — same
   discipline as `pending_ingest.sh` owns the marker rule. Designs out the paper's #1 open-weight
   failure mode (68% of errors were premature overwrite/deletion of a state key) structurally:
   the file is fully rewritten and re-validated on every edit, and dropping a required key is a
   hard schema error, not silently accepted.
2. **Branch-scoped, git-tracked.** One file per branch (`.strata/state/<slug>.json`), committed —
   unlike the gitignored session stamps it sits next to. It must survive a machine change or a
   `/clear`, which a gitignored file cannot do. See [ADR #5](../decisions/adr-5-episodic-state-branch-scoped.md).
3. **Quarantine field now, promotion machinery later.** Every `decisions[]` entry carries
   `trust: "session" | "reviewed"`, defaulting to `"session"`. Nothing auto-promotes — the P-1
   minimum from the user's own Prime Agent notes (their Factorio lesson: persistence must not
   silently launder an unverified claim into reused fact).
4. **`audit` owns quarantine visibility**, not a "gardener" skill — because [[gardener]] is a
   design note, not a shipped skill. Additive to a skill that already exists.

## What shipped

`scripts/lib/state_tools.py` (schema + validator + CLI) · Stop-gate trigger (c) (non-empty
`wiki_debt`, or invalid state, blocks once — same loop-safety cap as triggers a/b) ·
SessionStart branch-state summary + `.strata/version` mismatch nudge · `/strata:upgrade`
(`skills/upgrade/`, `scripts/strata_upgrade_check.sh`) · `light-finish` retires state on branch
close · `audit` flags orphaned/unreviewed state · `bash scripts/test_p2_state.sh` (25 behavioural
assertions, green) · version bump 0.4.0 → 0.5.0.

## Related

[[branch-state]] · [[upgrade-path]] · [[stop-gate]] · [[session-start-injection]] ·
[[pending-ingest-marker]] · [[session-reflector]]
