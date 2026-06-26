---
name: feature
description: Use when someone wants to build a feature end-to-end with the full Strata process, says "build feature X", "let's ship X properly", "run the full flow", or has an idea/design doc and wants it taken all the way to a merged, documented change. Orchestrates Think → Plan → Council → TDD → Review → Finish → wiki+audit.
---

# Feature — end-to-end feature flow orchestrator

This is Strata's PROCESS spine. It WRAPS the Superpowers skills and adds the two things bare Superpowers lacks: a **structured ideation front-end** (office-hours) and a **review council** that pressure-tests the plan from multiple perspectives before any code is written. Steps 3 (council) is where Strata earns its keep — do not skip it.

Orchestrate the phases below in order. Each phase delegates to a named skill and has a `verify` that MUST pass before advancing. If a verify cannot pass, STOP and report why — never claim a phase done on faith.

## Prerequisite: Superpowers (and what to do without it)

Phases 2, 4, 5, 6 delegate to **Superpowers** skills. If they're installed, use them — they carry the discipline. If `superpowers:*` is **not available**, do NOT abort: run the phase yourself to the same standard, tell the human the rigor is weaker, and recommend installing it (`/plugin install superpowers@claude-plugins-official`). Strata's own phases — 1 (office-hours), 3 (council), 7 (wiki+audit) — never depend on Superpowers.

| Phase | With Superpowers | Without — fallback (do this yourself) |
|---|---|---|
| 2 Plan | `superpowers:writing-plans` | Write the dated plan in the same shape at `docs/superpowers/plans/<date>-<slug>-plan.md`; every step names a concrete `verify`. |
| 4 Build | `superpowers:test-driven-development` | Stay test-first per step: write the failing test → make it pass → refactor; honor each step's verify, don't batch. |
| 5 Code review | `superpowers:requesting-code-review` | Run the **review council** (Strata's own subagents) against the diff, or a structured self-review; resolve every finding with evidence. |
| 6 Finish | `superpowers:finishing-a-development-branch` | Confirm tests green, then merge / open PR / keep / discard per the human's choice; clean up the branch. |

## Phase 1 — Think (delegate: /strata:office-hours)

If no design doc exists yet, invoke **`/strata:office-hours`**. It runs the YC-partner interrogation interactively and produces `docs/superpowers/specs/<date>-<slug>-design.md` with a chosen approach.

If the human already has a design doc, read it and confirm it has a Recommended Approach and Success Criteria. If it's thin, route back through office-hours.

**verify:** A design doc exists at `docs/superpowers/specs/` AND the human has confirmed the Recommended Approach. Do not proceed on a `Status: DRAFT` the human hasn't endorsed.

## Phase 2 — Plan (delegate: superpowers:writing-plans)

Invoke **`superpowers:writing-plans`** with the design doc as input. Produce a dated plan at `docs/superpowers/plans/<YYYY-MM-DD>-<slug>-plan.md`. Each step MUST carry a concrete `verify` (a command or observable), per goal-driven execution.

**verify:** The plan file exists and every step names a verify.

## Phase 3 — Review the plan: THE COUNCIL (Strata's value-add)

Pressure-test the plan with the review council **before** writing code. Two equivalent paths:

- **Simplest:** invoke **`/strata:autoplan`** with the plan path — it runs the council, classifies decisions, applies safe edits, and gates the rest to the human. Prefer this.
- **Manual:** spawn the reviewer subagents IN PARALLEL via the Agent tool (one message, multiple `Agent` calls), following `superpowers:dispatching-parallel-agents`:
  - `strata-ceo-review` — demand, wedge, business sense (always)
  - `strata-eng-review` — feasibility, complexity, failure modes (always)
  - `strata-cso-review` — security, data, access, risk (always)
  - `strata-design-review` — UX/IA — **only if the stack has a frontend** (detect: web UI, components, public-facing surface)

Collect the verdicts. **Surface DISAGREEMENTS to the human — do not smooth them over or average them away.** Where reviewers conflict with each other or with the human's stated intent, present the conflict and let the human decide. Then revise the plan and record the changes in an audit-trail section.

**verify:** Council verdicts are collected from every required reviewer; disagreements were shown to the human; the plan reflects the resolutions.

## Phase 4 — Build (delegate: superpowers:test-driven-development)

For each plan step, invoke **`superpowers:test-driven-development`**: write the failing test, make it pass, refactor. Honor the plan's per-step verify. Do not batch steps past their verifies.

**verify:** Tests are green and each step's stated verify passed.

## Phase 5 — Review the code (delegate: superpowers:requesting-code-review)

Invoke **`superpowers:requesting-code-review`** on the completed work. Address findings (use `superpowers:receiving-code-review` rigor — verify suggestions, don't blindly apply).

**verify:** Code review returns clean, or all findings are resolved with evidence.

## Phase 6 — Finish (delegate: superpowers:finishing-a-development-branch)

Invoke **`superpowers:finishing-a-development-branch`** to merge / PR / clean up per the human's choice.

**verify:** The branch is integrated (merged or PR opened) per the human's selection.

## Phase 7 — Post-merge: close the loop (Strata's drift guard)

The whole point of Strata is that a new feature can't silently rot the docs. After integration:

1. Invoke **`/strata:wiki-ingest`** for any docs/specs/ADRs the feature changed or added, so the knowledge layer reflects reality.
2. Run a **mini `/strata:audit`** scoped to the feature's area — confirm code, wiki, and CLAUDE.md still agree.

**verify:** wiki-ingest ran on the changed docs AND the mini-audit reports no fresh drift in the feature's area. If audit finds drift, fix it now — the loop isn't closed until it's clean.

## Summary

Think → Plan → **Council** → TDD → Code review → Finish → **wiki+audit**. Bare Superpowers gives you Plan→TDD→Review→Finish. Strata adds the front (office-hours) and the guards (council in Phase 3, drift-close in Phase 7). Keep both.
