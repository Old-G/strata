---
title: Enforcement layer
type: entity
created: 2026-08-15
updated: 2026-09-01
links: [stop-gate, commit-gate, session-start-injection, pending-ingest-marker, branch-state]
---

# Enforcement layer

## TLDR

The deterministic half of Strata's knowledge pipeline: hooks and pre-commit guards that
make wiki freshness an invariant instead of something the model is asked to remember.

## Role

Everything that keeps the wiki fresh today is advisory prose inside skills — probabilistic
by construction. The enforcement layer converts the load-bearing rules into lifecycle
hooks so the guarantee survives a forgetful late-session model, a manual commit, or a
different tool entirely. Its governing rule: *if you're writing "the agent must always…",
that's a hook, not a paragraph.*

It is also the **floor under [[native-invocation]]** — when description-matching fails to
route a request to the right skill, the invariant still holds.

## Current solutions

Three components, **shipped in v0.4.0** as templates and installed per target project (the plugin
ships **no global hooks**):

- [[stop-gate]] — refuses to end the turn while this session owes wiki work.
- [[commit-gate]] — fails the commit while [[pending-ingest-marker]] entries exist.
- [[session-start-injection]] — opens every session with branch, pending list, and wiki
  index head in context.

Scripts live in `templates/core/scripts/hooks/` and `templates/core/scripts/pre-commit/`;
`init` / `adopt` wire them into the target project's `.claude/settings.json` and
`.pre-commit-config.yaml`, exactly as [[raw-mirror-hook]] is installed today.

Per the Boris Cherny ablation principle (see [[ablate]]), this layer is **exempt from the
purge**: it encodes invariants, not model-capability scaffolding.

**v0.7.0 adds the write-time layer:** [[pre-tool-guard]] (A5) refuses a write under `raw/` or
to a test file mid-fix *before* it happens — the first `PreToolUse` hook, the deterministic form
of two rules that were prose. [[diff-review]] (R1) checks the diff against the plan at branch
close. The routing half stays deliberately untested by machinery: descriptions are the surface,
other plugins compete on it, and a phrase is checked by saying it in a fresh session.

**v0.5.0 extends the invariant beyond `docs/*.md`:** [[branch-state]] gives the [[stop-gate]] a
fourth signal — non-empty `wiki_debt` in the branch's own state file — so knowledge captured in
conversation (a decision, a gotcha) that never became a doc edit is no longer invisible to the
gates. [[upgrade-path]] (`/strata:upgrade`) is the companion fix for the layer's own bootstrap
problem: a repo adopted before these hooks existed had no way to receive them later.

## Related

[[stop-gate]] · [[commit-gate]] · [[session-start-injection]] · [[pending-ingest-marker]] ·
[[raw-mirror-hook]] · [[native-invocation]] · [[ablate]] · [[branch-state]] · [[upgrade-path]]

## Sources

[[vnext-brief]] §1, §2, §7.2 · [ADR #1](../decisions/adr-1-deterministic-enforcement.md)
