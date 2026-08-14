---
title: Enforcement layer
type: entity
created: 2026-08-15
updated: 2026-08-15
links: [stop-gate, commit-gate, session-start-injection, pending-ingest-marker]
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

## Related

[[stop-gate]] · [[commit-gate]] · [[session-start-injection]] · [[pending-ingest-marker]] ·
[[raw-mirror-hook]] · [[native-invocation]] · [[ablate]]

## Sources

[[vnext-brief]] §1, §2, §7.2 · [ADR #1](../decisions/adr-1-deterministic-enforcement.md)
