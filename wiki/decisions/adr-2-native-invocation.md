---
title: "ADR #2 — Skill descriptions are the routing surface; triggers are bilingual and inline"
type: decision
created: 2026-08-15
updated: 2026-08-15
status: accepted
---

# ADR #2 — Skill descriptions are the routing surface; triggers are bilingual and inline

## Context

The requirement is that no `/strata:*` command is ever typed — input is plain natural
language, mostly Russian, and the agent decides what to load. Claude Code already works this
way: `SKILL.md` files are model-invoked, matched on name + `description`. Current Strata
descriptions are role-oriented ("Use when ingesting a docs/raw file…"), which describes the
skill rather than the user's words, so matching against real Russian prose is unreliable.

Open question #5 from the brief: bilingual EN+RU triggers in every description, or a separate
locale block?

## Decision

Descriptions are treated as the entire routing surface and rewritten as trigger specs — *use
when the user says X* — with concrete phrase examples **in both English and Russian, inline in
the `description` field of each of the 12 skills**. No separate locale block, no per-language
files.

Each skill also gains a `## Do NOT use when` guard against false triggers.

## Consequences

- Matching happens against the user's actual words in the language they used, with no
  indirection the dispatcher would have to resolve at match time.
- Descriptions get longer, which is the direct cost; it is bounded by keeping the rest of each
  SKILL.md shorter (the [[ablate]] design pressure — task + guardrails + exit criteria).
- One surface to maintain per skill, not two, so EN and RU triggers cannot drift apart.
- Adding a third language later means editing 12 descriptions; accepted — no third language is
  planned.
- Routing stays probabilistic by nature, which is why [[enforcement-layer]] hooks are the
  required floor under it (C4).

## Sources

[[vnext-brief]] §6, §9 (OQ#5) · resolved 2026-08-15 · see [[native-invocation]]
