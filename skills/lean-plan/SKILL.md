---
name: lean-plan
description: Use when a change needs a written plan before implementation — 'write a plan', 'plan this out', 'how would we approach this', «напиши план», «распиши по шагам», «набросай план». Produces a complete-but-lean plan — intent, constraints, success criterion — pointing at high-fidelity references (a failing test, real code to mirror, a rubric) instead of pasting invented code.
---

# lean-plan — complete, but free of noise

Frontier models do best with the **complete** task specification up front, then left to run. So aim for complete, not minimal — while cutting anything that isn't signal.

## What a plan carries

- **Intent** — what should be true when this is done.
- **Constraints** — stack, ADRs, data, security, compatibility.
- **Success criterion** — how we'll know, in one line.
- **Steps** — what changes, in order.
- **Behaviour delta** — only when the change adds, alters or removes behaviour that a wiki entity
  states (or should state) under `## Requirements`: `### ADDED|MODIFIED|REMOVED [[entity]]` →
  `#### <title>` → the full requirement with its WHEN/THEN scenarios and `test:` pointers. Format:
  "Requirements and behaviour deltas" in `${CLAUDE_PLUGIN_ROOT}/templates/core/WIKI.md`. It is the plan's promise in checkable form —
  `light-finish` merges it into the wiki at branch close and `strata-diff-review` checks the diff
  against its scenarios. Point each `test:` at the test you are about to write, not one that
  exists by luck.

Do not dictate libraries or frameworks, and do not paste invented implementation code. The implementing model chooses how.

## Prefer high-fidelity references over prose

Where a real artifact can express the requirement, point at it instead of describing it: a failing test that defines the behavior, an existing file or function to mirror, an acceptance rubric. **Point at real artifacts; never invent fake ones.**

## By tier

- **trivial** — no written plan; hold the step list inline.
- **standard** — a short bullet plan in the conversation — unless it carries a Behaviour delta:
  then it is a file too, because the delta is merged at branch close, often in another session.
- **risky** — a dated file at `docs/superpowers/plans/<YYYY-MM-DD>-<slug>-plan.md`, same shape, short enough to hold in context.

`<slug>` is the branch's last `/`-segment (`strata/p6-specs` → `p6-specs`), matched exactly —
`state_tools.py plan <branch>` is how `light-finish`, `strata-diff-review` and `requirements.py
owed` find the plan.

Return the plan (or its path) to `/strata:feature`.

## Do NOT use when

- The task is trivial (a one-line fix, a typo) — plan inline, do not write a file.
- The user wants the whole flow executed, not just a plan — that is `feature`.
