---
title: "P1 — Enforce + Route (implementation plan)"
type: source
source: raw/superpowers/plans/2026-08-15-p1-enforce-route-plan.md
created: 2026-08-15
updated: 2026-08-15
---

# Source — P1 Enforce + Route (plan, 2026-08-15)

The approved execution plan for phase P1 of [[vnext-brief]] — Feature A (A1–A4) and Feature C
(C1–C4). Shipped as v0.4.0.

Its intent: a Strata project cannot let its wiki silently drift, and Strata can be driven
end-to-end in Russian without typing a single `/strata:` command. Constraints carried from the
brief and from Strata's own hard rules — no global plugin hooks (scripts ship as templates,
`init`/`adopt` install them per target project), bash only with no new dependencies, and loop
safety treated as spec rather than polish.

## Four decisions the plan settled before any code

**D1 — the marker retirement rule.** A `pending_ingest` line is outstanding unless a *later* line
mentions `ingest raw/<mirror>`; pairing is by line order, so edit → ingest → edit-again correctly
reopens it. Implemented once in `scripts/lib/pending_ingest.sh` and shared by every gate. This was
forced by dogfooding: a naive count also matches prose that merely mentions the token.

**D2 — the session boundary.** [[session-start-injection]] records where the session began;
[[stop-gate]] reads it and **fails open** when it is missing. A gate that cannot know the boundary
must not guess.

**D3 — one routing map.** It lives in `CLAUDE.md`, which is already in context every session; A3
does not duplicate it. Single source of truth, and the injection budget stays spent on state the
model cannot otherwise see.

**D4 — the block channel.** `{"decision":"block","reason":…}` on stdout rather than exit-code-2
stderr semantics.

## Order and outcome

Execution order was A3 → A2 → A1 → A4 → C2 → C1 → C3 → finish: A3 first because A1 depends on its
stamp, and A2 before A1 because the commit gate is the safe, non-interactive half of the same
logic. Two open questions were resolved during execution — the code-only Stop trigger shipped
**on** by default at 50 changed lines (always satisfiable by one log line, including an explicit
`no-wiki-impact:`), and this repo dogfoods the commit gate through a tracked `.githooks/pre-commit`
rather than an untracked shim or a new pre-commit-framework dependency.

Deliberately out of scope, and still open: A5 `FileChanged` migration, A6 session distiller, all of
Feature B ([[hq-mode]]), [[ablate]], and the council upgrades.
