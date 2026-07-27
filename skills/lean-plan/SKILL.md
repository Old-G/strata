---
name: lean-plan
description: Use when /strata:feature needs a plan for a standard or risky task, or when the user asks for a lean implementation plan. Produces a complete-but-lean plan — intent, constraints, success criterion — that points at high-fidelity references (a failing test, real code to mirror, a rubric) instead of pasting invented implementation code.
---

# lean-plan — complete, but free of noise

Frontier models do best with the **complete** task specification up front, then left to run. So aim for complete, not minimal — while cutting anything that isn't signal.

## What a plan carries

- **Intent** — what should be true when this is done.
- **Constraints** — stack, ADRs, data, security, compatibility.
- **Success criterion** — how we'll know, in one line.
- **Steps** — what changes, in order.

Do not dictate libraries or frameworks, and do not paste invented implementation code. The implementing model chooses how.

## Prefer high-fidelity references over prose

Where a real artifact can express the requirement, point at it instead of describing it: a failing test that defines the behavior, an existing file or function to mirror, an acceptance rubric. **Point at real artifacts; never invent fake ones.**

## By tier

- **trivial** — no written plan; hold the step list inline.
- **standard** — a short bullet plan in the conversation.
- **risky** — a dated file at `docs/superpowers/plans/<YYYY-MM-DD>-<slug>-plan.md`, same shape, short enough to hold in context.

Return the plan (or its path) to `/strata:feature`.
