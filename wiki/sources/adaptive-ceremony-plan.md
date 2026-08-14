---
title: "Adaptive ceremony — implementation plan"
type: source
source: raw/superpowers/plans/2026-07-21-adaptive-ceremony.md
created: 2026-08-15
updated: 2026-08-15
---

# Source — Adaptive ceremony (implementation plan, 2026-07-21)

The execution plan for [[adaptive-ceremony-design]]; shipped as v0.3.0. Summarised at the level of
task structure and outcomes — the reasoning lives in the design page, the literal text in `raw/`.

Nine tasks. **Task 1** wrote the triage rubric into `skills/feature/sections/triage.md`
(progressive disclosure — the rubric loads only when triage runs): tiers, the non-negotiable risk
surfaces that force `risky`, the cheap signals to read, how to handle ambiguity, and the required
one-line output. **Tasks 2–3** added the two new skills, `lean-plan` (complete but noise-free;
high-fidelity references instead of invented code) and `light-finish` (green → choose → do →
clean up; P1 later inserted drift-close into it). **Task 4** rewrote `feature` around the whole
model: Phase 0 triage, the always-on floor, effort per tier, the tier→phase table, delegation, and
an explicit `## Never` section.

**Tasks 5–7** spread the model outward: grill-style questioning folded into `office-hours` rather
than shipped as a duplicate skill, lens selection in `autoplan` so the council picks the reviewers
the risk calls for, and Superpowers demoted from prerequisite to optional accelerator in both
`BOOTSTRAP.md` and `onboard`. **Task 8** handled docs, attribution (ideas adapted from
Superpowers / gstack / grill-me, no vendored code), the changelog and the dual manifest bump.
**Task 9** was acceptance: an automated sweep plus a manual dogfood run.

The acceptance sweep included a check worth noting as a precedent — a grep proving the skills
contain **no** "double-check / re-verify / add a verification step" scaffolding. It is a test that
asserts an absence, which is the same shape as P1's rule that the [[enforcement-layer]] is exempt
from ablation while advisory prose is not.
