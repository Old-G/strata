---
title: Native invocation (Feature C)
type: entity
created: 2026-08-15
updated: 2026-08-15
links: [session-start-injection, enforcement-layer]
---

# Native invocation (Feature C)

## TLDR

Strata used entirely through natural language — mostly Russian — with no `/strata:*` typed
ever; skill `description` fields carry the whole routing decision.

## Role

The requirement is a usability one (never type a command), but the mechanism already exists:
`SKILL.md` files are model-invoked — Claude scans names and descriptions and auto-loads a
skill when the request matches. The slash form is only an optional manual entry point. So the
work is not "add a mechanism", it is **make routing reliable**.

## Current solutions

**Shipped in v0.4.0**, four parts, with C1–C3 enforced by `scripts/validate.sh` §8:

- **C1 — descriptions as trigger specs.** Every skill's `description` is rewritten from
  role-oriented prose ("Use when ingesting a docs/raw file…") to *use when the user says X*,
  with concrete phrase examples **in both English and Russian**, since matching happens
  against the user's actual words. Each gains a `## Do NOT use when` guard — over-broad
  descriptions are the classic false-trigger failure. `wiki-ingest` already does this once
  ("проингестим X"); the pattern generalizes to all 12 skills.
  Bilingual triggers live inline, not in a separate locale block
  ([ADR #2](../decisions/adr-2-native-invocation.md)).
- **C2 — routing map in `CLAUDE.md.tmpl`.** A 6–8 line intent table (build request → feature
  flow; project question → wiki query; "done / merge" → light-finish; "messy / drift" →
  audit; risky idea → office-hours). A table, not prose rules, and nothing else grows.
- **C3 — `using-strata` as coordinator.** Its description is modelled on a dispatcher: broad
  intent match, loads early, routes, never does the work itself.
- **C4 — hooks as the floor.** [[stop-gate]] and [[session-start-injection]] hold the wiki
  invariant even when description-matching misses. Native happy path, deterministic floor.

## Related

[[enforcement-layer]] · [[session-start-injection]] · [[ablate]]

## Sources

[[vnext-brief]] §6, §9 · [ADR #2](../decisions/adr-2-native-invocation.md)
