---
name: feature
description: Use when someone wants to build a feature or change end-to-end and wants the process to fit the task — says "build X", "ship X properly", "run the flow", or has a design doc to carry to a merged change. Classifies the task (trivial/standard/risky) and runs only the ceremony that fits, behind a floor of evidence, risk escalation, drift-close and git safety.
---

# Feature — adaptive-ceremony feature flow

Strata's PROCESS spine: trivial work goes fast, risky work gets real guardrails, and the framework decides — not the human. Built for frontier models, so it deliberately carries **less** scaffolding than classic pipelines: state intent, then let the model work.

## Phase 0 — Triage (always, cheap)

Classify the request with `${CLAUDE_PLUGIN_ROOT}/skills/feature/sections/triage.md`. Emit **tier + one-line why + what you'll skip + the effort level**, then proceed — no confirmation gate. The user may say "go higher / lower" at any time; re-scale immediately. Bias **up** on doubt.

## The floor — always, every tier

1. **Evidence** — show that the change works: run the real test or command and report its output. Ask for proof, not reassurance.
2. **Risk escalation** — a risk surface (see the rubric) makes the task `risky`, however small it looks.
3. **Drift-close** — if docs or a documented fact changed, run `/strata:wiki-ingest` on them; otherwise nothing to do.
4. **Git safety** — work on a branch, keep commits reversible, never write silently to the default branch.

## Effort per tier

`trivial` → low · `standard` → medium · `risky` → high (xhigh for demanding agentic or multi-file work). Effort is the main cost lever; prefer thinking on at low effort over turning thinking off.

## Tier → phases

| Phase | trivial | standard | risky |
|---|---|---|---|
| Think | restate the ask in one line | light grill via `/strata:office-hours` (intent + success criterion) | `/strata:office-hours` — grill to convergence, design doc |
| Plan | none | `lean-plan`, short | `lean-plan`, complete-but-lean |
| Council | none | none by default | 1–2 risk-matched lenses (below) |
| Build | implement, then evidence | implement, evidence on the core | implement, evidence per meaningful step |
| Finish | `light-finish` | `light-finish` | `light-finish` + an explicit gate |
| Drift-close | floor #3 | `/strata:wiki-ingest` + scoped mini-`/strata:audit` | `/strata:wiki-ingest` + mini-audit |

## The council — risk-triggered, lens-selected

Only on `risky`, and only the lenses the risk actually calls for: security or PII → `strata-cso-review` · frontend or UX → `strata-design-review` · architecture or complexity → `strata-eng-review` · scope or "is this the right problem" → `strata-ceo-review`. Use the full panel only when several of those risks genuinely coincide; `/strata:autoplan` can drive it. Its job is an **independent adversarial read of a risky surface** — not routine double-checking of ordinary work. Surface reviewer disagreements to the user rather than averaging them away.

## Delegation

Think → `/strata:office-hours` · Plan → `lean-plan` · Council → `/strata:autoplan` or the `strata-*-review` agents in parallel · Finish → `light-finish` · Knowledge → `/strata:wiki-ingest`, `/strata:audit`.

**Superpowers is optional.** If `superpowers:*` skills are installed you may use them as accelerators on `risky` work. Absent — the native path above is complete; nothing degrades.

## Never

Skip the floor. Treat a risk-surface task as trivial. Run the council on trivial or standard work by default. Claim something works without showing its evidence.
