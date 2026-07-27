---
name: autoplan
description: Use when a plan or design doc needs the Strata review council run over it automatically, someone says "autoplan", "run the council", "review this plan", "is this plan ready to build", or wants a plan pressure-tested and made build-ready with an audit trail. Spawns reviewer subagents in parallel and gates decisions to the human.
---

# Autoplan — run the review council, produce a build-ready plan

Takes a plan (or design doc), runs the Strata review council over it in parallel, applies the safe edits itself, and gates the judgment calls to the human. Output: a plan marked **ready for build** with an audit trail of every change and why.

**Core rule:** you NEVER silently override the human on something they explicitly intended. Mechanical and taste edits you may apply; a disagreement with the human's stated intent is always escalated, never auto-decided.

## Step 1 — Resolve the input

Input is a path to a plan or design doc. If none is given, use the most recent file in `docs/superpowers/plans/` (fallback: `docs/superpowers/specs/`). Read it fully. Note whether the stack has a frontend (web UI / components / public surface) — this decides whether design review runs.

**verify:** You have the doc's path and content, and a yes/no on frontend.

## Pick the lenses the risk calls for

Do not run a fixed panel by default. Choose the reviewers whose lens matches the plan's actual risk: security, secrets, or PII → `strata-cso-review` · frontend or UX surface → `strata-design-review` · architecture, complexity, or reversibility → `strata-eng-review` · scope or "is this the right problem" → `strata-ceo-review`. One or two is the norm; use the full panel only when several of those risks genuinely coincide. Skip the council entirely for trivial or routine changes — it exists for an independent adversarial read of a risky surface, not for a second pass over ordinary work.

When you brief a reviewer, ask it to **report everything it finds and let the synthesis step filter**. Telling a reviewer to "only report high-severity issues" or "be conservative" makes it report less.

## Step 2 — Spawn the council IN PARALLEL

Following `superpowers:dispatching-parallel-agents`, spawn the selected reviewer subagents in a SINGLE message with multiple `Agent` calls (no shared state, fully parallel):

- `strata-ceo-review` — demand reality, wedge, business value
- `strata-eng-review` — feasibility, complexity, failure modes, missing steps
- `strata-cso-review` — security, data handling, access, blast radius
- `strata-design-review` — UX/IA, accessibility — **only if frontend**

Give each the doc path and ask for: a verdict, a list of concrete proposed changes, and any point where they disagree with the human's stated intent. Wait for all to return.

**verify:** Every selected reviewer returned a verdict + change list.

## Step 3 — Classify every surfaced decision

Sort each proposed change into exactly one bucket:

- **MECHANICAL** — objectively right, no taste involved (typo, wrong path, missing verify, broken ordering, factual error). Auto-apply silently.
- **TASTE** — a defensible judgment call with a clear better option (naming, structure, library choice, test granularity). Auto-apply BUT list it at the final gate so the human can veto.
- **USER-CHALLENGE** — a reviewer disagrees with something the human explicitly decided or intended (scope, approach, a premise from the design doc). **NEVER auto-decide.** Hold it for the human.

When reviewers disagree *with each other*, treat it as USER-CHALLENGE unless one is plainly mechanical-correct.

**verify:** Every proposed change is in exactly one bucket; nothing dropped.

## Step 4 — Apply safe edits + build the audit trail

Apply MECHANICAL and TASTE edits directly to the plan. Append an **## Audit Trail** section recording, per change: source reviewer, bucket, what changed, one-line rationale. This is the record of what the council did to the plan.

**verify:** Plan reflects mechanical+taste edits; audit trail lists each with rationale.

## Step 5 — FINAL GATE (human sign-off)

Present to the human, in one consolidated message:

1. **Taste decisions applied** — so they can veto any.
2. **User-challenges** — each disagreement with their intent, with the reviewer's argument and the human's original position, asked as an explicit choice (AskUserQuestion).
3. **Unresolved reviewer disagreements** — conflicts the council couldn't settle.

Do not proceed past this gate until the human has ruled on every user-challenge and unresolved conflict. Apply their rulings and update the audit trail.

**verify:** The human has explicitly resolved every user-challenge and unresolved disagreement; none were auto-decided.

## Step 6 — Mark ready & hand off

Set the plan's status to **ready for build**. Hand off:

- **`superpowers:test-driven-development`** — to build it step by step, or
- **`/strata:feature` step 4** — if running inside the full feature flow.

Point at the exact plan path.

**verify:** Plan status is "ready for build" and the handoff target + path are stated.
