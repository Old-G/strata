---
name: onboard
description: Use right after installing Strata (the bridge prompt tells the user to run "/strata:onboard"), or when the user says "onboard this repo / continue Strata setup / set up Strata here and walk me through it / lead me through Strata". Conducts the full setup end-to-end — detects new-vs-existing, checks prerequisites, then delegates to /strata:init or /strata:adopt and runs the first /strata:audit — asking one question at a time and calling the commands itself.
---

# /strata:onboard — conduct the full Strata setup

You are the conductor. The human should not have to know which `/strata:*` command to run — you
detect the situation, propose a plan, and drive it, asking ONE question at a time. You are **thin
glue**: do NOT reimplement init/adopt/audit — delegate to them and let each own its verifies. The
four-layer model lives in `${CLAUDE_PLUGIN_ROOT}/skills/using-strata/SKILL.md` if you need it.

## Step 1 — Resume context (if any)

If `.strata/onboard.json` exists, read it — it records `projectType` and prereq results from the
bootstrap step. Treat it as a HINT, not ground truth; still re-detect below (it can be stale).

## Step 2 — Detect new vs existing

Inspect the working directory:
- **new** — empty / near-empty, no substantial git history, no source tree → the `init` path.
- **existing** — real code and/or git history → the `adopt` path.
Confirm in one question ("This looks like an existing project — adopt Strata into it? [yes / it's
actually new]").

## Step 3 — Prerequisite report

Re-check (the session changed since bootstrap): Superpowers, claude-mem (recommended), RTK
(optional). Report present/missing and, for anything missing, the one concrete thing it costs
(e.g. "no Superpowers → /strata:feature's brainstorm/TDD steps degrade"). Do not block.

## Step 4 — Plan, then approval

State the path as `step → verify` and get approval before writing anything:
- new → "run /strata:init to scaffold structure + a green smoke test (+ wiki if an AI will read this repo)".
- existing → "run /strata:adopt to add CLAUDE.md + wiki + the docs→raw mirror hook and emit an adoption report".
Both then → "run /strata:audit for the first drift report".

## Step 5 — Delegate the setup

Invoke the matching skill and let it run to completion with ITS OWN verifies — do not duplicate its
logic here:
- **new:** invoke `/strata:init`.
- **existing:** invoke `/strata:adopt`.
Carry the prereq findings and project name into that skill's questions so the user isn't asked twice.

## Step 6 — First audit

When init/adopt has finished green, invoke `/strata:audit` (read-only — safe to auto-run). Present
the ranked drift report it writes to `docs/superpowers/specs/<date>-strata-audit.md`.

## Step 7 — Hand off

Summarize what now exists, then point the way (do NOT auto-run these):
- `/strata:refactor` — close the audit's findings, one TDD step at a time.
- `/strata:feature` — build the first feature through office-hours → council → TDD.
Finally remove the breadcrumb: `rm -f .strata/onboard.json` (its job is done).
