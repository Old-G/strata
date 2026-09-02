---
name: feature
description: Use when the user wants something BUILT or CHANGED end-to-end — 'build X', 'add X', 'ship this properly', 'run the flow', «добавь», «сделай фичу», «надо чтобы», «запили», «поменяй поведение», «реализуй». Classifies the task (trivial/standard/risky) and runs only the ceremony that fits, behind a floor of evidence, risk escalation, drift-close and git safety.
---

# Feature — adaptive-ceremony feature flow

Strata's PROCESS spine: trivial work goes fast, risky work gets real guardrails, and the framework decides — not the human. Built for frontier models, so it deliberately carries **less** scaffolding than classic pipelines: state intent, then let the model work.

## Phase 0 — Triage (always, cheap)

Classify the request with `${CLAUDE_PLUGIN_ROOT}/skills/feature/sections/triage.md`. Emit **tier + one-line why + what you'll skip + the effort level**, then proceed — no confirmation gate. The user may say "go higher / lower" at any time; re-scale immediately. Bias **up** on doubt.

## The floor — always, every tier

1. **Evidence** — show that the change works: run the real test or command and report its output. Ask for proof, not reassurance. When the evidence is a failing test you are about to make pass: `touch .strata/guard-tests` before the first code edit, `rm -f .strata/guard-tests` once green — the PreToolUse guard keeps test files read-only in between, so the proof cannot be weakened by the fix. Fix the code, not the test.
2. **Risk escalation** — a risk surface (see the rubric) makes the task `risky`, however small it looks.
3. **Drift-close** — if docs or a documented fact changed, run `/strata:wiki-ingest` on them; otherwise nothing to do.
4. **Git safety** — work on a branch, keep commits reversible, never write silently to the default branch.

## Effort per tier

`trivial` → low · `standard` → medium · `risky` → high (xhigh for demanding agentic or multi-file work). Effort is the main cost lever; prefer thinking on at low effort over turning thinking off.

## Tier → phases

| Phase | trivial | standard | risky |
|---|---|---|---|
| Think | restate the ask in one line | light grill via `/strata:office-hours` (intent + success criterion) | `/strata:office-hours` — grill to convergence, design doc |
| Plan | none | `/strata:lean-plan`, short | `/strata:lean-plan`, complete-but-lean |
| Council | none | none by default | 1–2 risk-matched lenses (below) |
| Build | implement, then evidence | implement, evidence on the core | implement, evidence per meaningful step |
| Finish | `/strata:light-finish` | `/strata:light-finish` | `/strata:light-finish` + an explicit gate |
| Drift-close | floor #3 | `/strata:wiki-ingest` + scoped mini-`/strata:audit` | `/strata:wiki-ingest` + mini-audit |

## The council — risk-triggered, lens-selected

Only on `risky`, and only the lenses the risk actually calls for: security or PII → `strata-cso-review` · frontend or UX → `strata-design-review` · architecture or complexity → `strata-eng-review` · scope or "is this the right problem" → `strata-ceo-review`. Use the full panel only when several of those risks genuinely coincide; `/strata:autoplan` can drive it. Its job is an **independent adversarial read of a risky surface** — not a routine second pass over ordinary work. Surface reviewer disagreements to the user rather than averaging them away.

## Context discipline

Answer quality decays as a session fills up, so long work is split rather than pushed through one conversation:

- **Split long work into short passes.** One meaningful unit per pass, one commit per unit.
- **Run each unit in a fresh agent.** Give it exactly the context it needs; don't let it inherit the whole conversation. A tired context reviews its own work with a tired eye.
- **Hand off, don't hope.** When work crosses a session, an agent, or a pass, write a compact handoff: the goal, what's done (with commit refs), what's next, the constraints and decisions already made, and how to verify. Keep it short enough to paste. It replaces re-reading the transcript.

## Delegation

Think → `/strata:office-hours` · Plan → `/strata:lean-plan` · Council → `/strata:autoplan` or the `strata-*-review` agents in parallel · Finish → `/strata:light-finish` · Knowledge → `/strata:wiki-ingest`, `/strata:audit`.

**Superpowers is optional.** If `superpowers:*` skills are installed you may use them as accelerators on `risky` work. Absent — the native path above is complete; nothing degrades.

## Never

Skip the floor. Treat a risk-surface task as trivial. Run the council on trivial or standard work by default. Claim something works without showing its evidence.

## Do NOT use when

- The user is asking a question about the project rather than requesting a change — that is a wiki query.
- The change is already implemented and just needs integrating — that is `light-finish`.
- The idea has not been pressure-tested and the user is unsure it should exist — that is `office-hours`.
