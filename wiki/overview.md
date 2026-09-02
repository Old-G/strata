---
title: Project Overview
type: entity
created: 2026-08-15
updated: 2026-09-01
links: [enforcement-layer, native-invocation, hq-mode, branch-state, upgrade-path]
---

# Overview — the big picture

## What we're building

**Strata** is a Claude Code plugin that packages a reusable way to run AI-assisted projects:
an AI-navigable wiki, architecture canon, a spec→plan→TDD feature flow, a parallel review
council, and drift detection with staged refactor. It is *thin glue* — it composes claude-mem
(memory), RTK (token proxy), and the project's own test suite rather than reimplementing any
of them. This repo dogfoods its own patterns.

## Current phase / status

**v0.6.0 shipped** — [[version-stamp]]: the running build names itself in every session's skill
listing, and the bump is what delivers it (the plugin cache is keyed by the version string, so a
merge without one reaches no session and reports success anyway).

**v0.5.0** — P1's [[enforcement-layer]] (A1–A4) + [[native-invocation]] (C1–C4), plus a
second pass: [[branch-state]] (the episodic layer the enforcement layer was missing — knowledge
captured in conversation that never became a `docs/*.md` edit) and [[upgrade-path]] (fixes repos
adopted before the enforcement layer existed, which had no way to receive it later).

**v0.7.0 — P3, the right side of the loop** ([[sdlc-right-side]]): [[routing-evals]] test the
probabilistic half for the first time (34 cases, 1.0), the [[pre-tool-guard]] refuses writes
under `raw/` and to test files mid-fix before they happen, and [[diff-review]] checks the diff
against the plan at branch close with the "mistake twice → `CLAUDE.md`" rule. Triggered by
Anthropic's AI-Native SDLC playbook, which turned out to be ADR #1 in other words.

**Still in planning**, driven by [[vnext-brief]]: [[hq-mode]], then [[ablate]],
[[session-reflector]], [[gardener]] (now carrying the playbook's `bands.yaml` σ-tier pattern as
its reference design), [[executable-wiki]], [[career-ledger]], [[agent-teams]], [[wiki-emit]].

The knowledge layer of this repo was bootstrapped on 2026-08-15 — Strata had shipped the wiki
pipeline as a template without running it on itself.

## Key decisions

- [ADR #1](decisions/adr-1-deterministic-enforcement.md) — deterministic enforcement over
  advisory prose; hooks ship as templates, never as global plugin hooks.
- [ADR #2](decisions/adr-2-native-invocation.md) — skill descriptions are the routing surface;
  EN+RU triggers inline.
- [ADR #3](decisions/adr-3-hq-nested-layout.md) — projects live inside HQ.
- [ADR #4](decisions/adr-4-stop-gate-session-scope.md) — the Stop gate blocks only on markers
  from the current session.
- [ADR #5](decisions/adr-5-episodic-state-branch-scoped.md) — branch state is git-tracked and
  branch-scoped, not session-scoped.

## Architectural layers

- **Knowledge** — `docs/` (human) → `raw/` (mirror) → `wiki/` (AI-owned, queried first).
- **Enforcement** — [[raw-mirror-hook]] on the write side; [[stop-gate]], [[commit-gate]],
  [[session-start-injection]] on the guarantee side.
- **Process** — skills: `init` / `adopt` / `onboard` (setup), `office-hours` / `lean-plan` /
  `feature` / `light-finish` (build), `audit` / `refactor` (correct), `wiki-ingest`
  (knowledge), `autoplan` (council), `using-strata` (router).
- **Review** — four council subagents in `agents/`: ceo, eng, design, cso; lens-selected by
  risk tier.

## Component map

- [[enforcement-layer]] — makes wiki freshness an invariant → reads [[pending-ingest-marker]]
  written by [[raw-mirror-hook]].
- [[native-invocation]] — routes plain language to skills → relies on
  [[session-start-injection]] for context and on the [[enforcement-layer]] as its floor.
- [[hq-mode]] — aggregates project wikis upward → strictly depends on the enforcement layer
  holding per project.
- [[branch-state]] — the episodic layer `wiki/log.md`'s trajectory couldn't provide → feeds the
  [[stop-gate]] a fourth trigger and [[session-start-injection]] a per-branch summary.
- [[upgrade-path]] — re-syncs `scripts/**` into repos adopted before the current version → the
  bootstrap fix for the [[enforcement-layer]] itself.

## Layout

- `.claude-plugin/` — `plugin.json` (manifest) + `marketplace.json` (this repo is its own
  marketplace).
- `skills/<name>/SKILL.md` — one skill per command, invoked as `/strata:<name>`.
- `agents/strata-*-review.md` — the parallel review council.
- `templates/core/` — portable assets: `PROJECT_PATTERN.md`, `WIKI.md`, `wiki/` skeleton,
  `scripts/`, CLAUDE/ADR templates.
- `templates/stacks/<stack>/` — per-stack architecture canon + scaffold generator.
- `reference/` — council personas, Diataxis doc-map, tool integration.
- `docs/superpowers/{specs,plans}/` — Strata's own design specs and plans, dated.
- `raw/`, `wiki/` — this repo's own knowledge layer (mirror + curated).
