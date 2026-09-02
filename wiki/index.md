---
title: Wiki Index
type: index
created: 2026-08-15
updated: 2026-08-15
---

# Wiki Index — start here

This is the catalog and **first stop** for any question about the project. The AI reads
this page before grepping the repo: scan the one-line TLDRs, follow the link to the
relevant page, and answer from `wiki/`. Add a row here for every page you create during
`ingest` (see `WIKI.md` for the protocol).

> Convention: internal links use `[[entity-slug]]` (→ `entities/<slug>.md`). Links to
> raw sources use plain markdown `[file](../raw/<file>.md)`.

---

## Big picture

| Page | What it is |
|---|---|
| [[overview]] | Strata's narrative — what it is, v0.3.1 shipped, v-next P1 in progress, layers, component map. |
| [glossary](glossary.md) | Term → definition table; also the drift-protection source-of-truth for at-risk facts. |
| [log](log.md) | Operational journal of every ingest / query / lint, timestamped. |

---

## Sources

One page per file in `raw/`, holding a 3–7 paragraph summary (never a copy).

| Page | What it is |
|---|---|
| [[vnext-brief]] | The v-next research brief (2026-08-14): diagnosis of wiki drift, features A/B/C, research digest, approved innovations, nightly architecture, 14 open questions. |
| [[p1-enforce-route-plan]] | The P1 execution plan (2026-08-15) — the four shared decisions (marker rule, session boundary, one routing map, block channel) and the order they shipped in. |
| [[adaptive-ceremony-design]] | v0.3 design: tiers, the always-on floor, effort as the cost lever, lens-selected council — and why frontier-model guidance means removing machinery. |
| [[adaptive-ceremony-plan]] | The nine tasks that shipped v0.3.0, including the grep that asserts an absence of self-verification scaffolding. |
| [[ai-led-onboarding-design]] | v0.2 design: one line to install and conduct setup, and the reload seam that cannot be automated away. |
| [[ai-led-onboarding-plan]] | The six tasks that shipped v0.2.0, and the release rule they taught (bump both manifests or the marketplace serves the old build). |
| [[episodic-state-layer]] | P2 (2026-09-01): the episodic branch-state layer + the `/strata:upgrade` re-sync path, and the four decisions that shaped them. |
| [[sdlc-right-side]] | P3 spec + plan (2026-09-01): the AI-Native SDLC playbook read against v0.6.1 — routing evals, PreToolUse guards, diff-vs-plan review; decisions D1–D4 settled. |

_All files in `raw/` are ingested as of 2026-09-01._

---

## Entities

Components, technologies, roles, and patterns — each with TLDR / Role / Current
solutions / Related / Sources.

| Page | What it is |
|---|---|
| [[enforcement-layer]] | The deterministic half of the knowledge pipeline: hooks + guards that make wiki freshness an invariant. |
| [[stop-gate]] | A1 — `Stop` hook that refuses to end the turn once while this session owes wiki work. |
| [[commit-gate]] | A2 — pre-commit guard failing the commit while `pending_ingest` markers exist. |
| [[session-start-injection]] | A3 — `SessionStart` hook injecting branch, pending list, and wiki index head into every session. |
| [[pending-ingest-marker]] | The `pending_ingest:` line in `wiki/log.md` — the single token every gate reads. |
| [[raw-mirror-hook]] | `sync_raw_mirror.sh` — PostToolUse hook mirroring `docs/*.md → raw/` and emitting the marker. |
| [[native-invocation]] | Feature C — zero slash commands; skill descriptions as the whole routing surface, EN+RU. |
| [[hq-mode]] | Feature B — `~/hq` meta-wiki over nested projects; sync, report, connectors wired once. |
| [[gardener]] | Two-tier nightly curator with anacron-style scheduling; never pushes to main. |
| [[executable-wiki]] | Facts carrying `verify:` commands — the wiki reports its own lies. |
| [[career-ledger]] | Append-only ledger of shipped/decided events, compiled into review and raise-case docs. |
| [[ablate]] | `audit` for instructions: empirically test which rules the model still needs, delete the rest. |
| [[session-reflector]] | ACE-style playbook growth: delta bullets of what worked and what failed, never rewrites. |
| [[agent-teams]] | Native multi-agent primitive and the council v2 it unlocks (reviewers who argue before synthesis). |
| [[wiki-emit]] | Compile `wiki/` → `llms.txt` / `llms-full.txt` / `AGENTS.md` for non-Claude agents. |
| [[branch-state]] | P2 — `.strata/state/<branch>.json`: git-tracked episodic state (goal, decisions, wiki_debt) the append-only log couldn't hold. |
| [[upgrade-path]] | P2 — `/strata:upgrade` re-syncs `scripts/**` into repos adopted before the current plugin version. |
| [[version-stamp]] | Which plugin build a session loaded — stamped in `using-strata`'s description, held true by `validate.sh` §2c. |
| [[pre-tool-guard]] | A5 — `PreToolUse` hook refusing writes under `raw/` and to test files mid-fix; exit 2 with reason, fails open. |
| [[diff-review]] | R1 — fifth read-only agent at branch close: diff vs plan, bugs, security-lite; second occurrence → `CLAUDE.md`. |

---

## Decisions (ADRs)

One page per architectural decision: `decisions/adr-<n>-<slug>.md`.

| Page | What it is |
|---|---|
| [ADR #1](decisions/adr-1-deterministic-enforcement.md) | Deterministic enforcement over advisory prose; hooks ship as templates, never global. |
| [ADR #2](decisions/adr-2-native-invocation.md) | Skill descriptions are the routing surface; EN+RU triggers inline (resolves OQ#5). |
| [ADR #3](decisions/adr-3-hq-nested-layout.md) | Projects live inside HQ; registry auto-discovered (resolves OQ#2). |
| [ADR #4](decisions/adr-4-stop-gate-session-scope.md) | The Stop gate blocks only on current-session markers (resolves OQ#1). |
| [ADR #5](decisions/adr-5-episodic-state-branch-scoped.md) | Branch state is git-tracked and branch-scoped, not session-scoped like the gate stamps it sits next to. |

---

## Analyses

Saved answers to recurring questions (`entities/analysis-<slug>.md`, `type: analysis`).

_Add pages here when you save a query answer — `[[analysis-<slug>]]` — one line each._
