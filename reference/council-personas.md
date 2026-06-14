# The Strata Review Council

The council is Strata's PROCESS-layer value-add. Where Superpowers gives you
disciplined brainstorming, TDD, and code-review *skills*, the council adds a
distinct thing: **parallel reviewer subagents that pressure-test a PLAN or a
DESIGN doc before (or while) you write code.** They review intent, not just
diffs. They are allowed to disagree — with each other and with you — and the
orchestrator surfaces those disagreements instead of averaging them away.

The methodology is adapted from **gstack** (MIT-licensed). Strata reimplements
the personas in its own files and vendors no gstack source.

## The four reviewers

| Persona | File | Owns | Can return |
|---------|------|------|------------|
| **CEO / Founder** | `agents/strata-ceo-review.md` | Scope, premises, the "right problem", the wedge-vs-10x tension, silent-failure visibility, observability-as-deliverable, the 6-months-from-now check. | APPROVE / APPROVE-WITH-CONCERNS / BLOCK |
| **Engineering Manager / Staff Eng** | `agents/strata-eng-review.md` | Architecture, data flow, the **complexity smell** hard stop (8+ files or 2+ new classes/services → demand leaner), edge cases, tests, performance, footguns. | APPROVE / APPROVE-WITH-CONCERNS / BLOCK |
| **Senior Product Designer** | `agents/strata-design-review.md` | User-facing surfaces only: information hierarchy, empty/loading/error states, affordance/clarity, design-system consistency, the AI-slop check. | APPROVE / APPROVE-WITH-CONCERNS / BLOCK / **N/A** |
| **Chief Security Officer** | `agents/strata-cso-review.md` | OWASP Top-10 + STRIDE threat model: authz, injection, secrets, PII, SSRF/deserialization, dependency risk, with a confidence bar to suppress noise. | APPROVE / APPROVE-WITH-CONCERNS / BLOCK |

Each reviewer is **read-only** (tools: Read, Grep, Glob, Bash). They analyze;
they never edit. Their final message *is* their report — every one ends with a
structured findings table and a one-line VERDICT.

## How they run — in parallel

`/strata:feature` and `/strata:autoplan` spawn the reviewers via the **Agent
tool**, concurrently, each handed the same plan or design doc plus the target
repo. They do not see each other's output while reviewing — this is deliberate.
Independent reviews keep blind spots independent; a sequential chain would let
the first reviewer anchor the rest.

The designer self-gates: on a backend-only change it returns `VERDICT: N/A`
immediately and costs almost nothing.

## How disagreements are surfaced — not smoothed

The orchestrator does **not** merge the four reports into one mushy consensus.
It collects the verdicts and the explicit "Disagreements with the plan / open
decisions for the human" list each reviewer emits, then presents conflicts
*as conflicts* to you:

- If any reviewer returns **BLOCK**, the plan does not silently proceed — the
  block and its remediation are put in front of the human.
- When two reviewers **disagree** (e.g. CEO wants the 10x version, Engineering
  trips the complexity smell on exactly that ambition), the orchestrator shows
  both positions side by side and asks *you* to make the call. It does not pick
  a winner.
- "APPROVE-WITH-CONCERNS" concerns are listed, not buried. The human decides
  which to absorb into the plan and which to defer.

The council's job is to make tensions visible early, while changing the plan is
cheap, rather than discovering them in review of finished code.

## How /strata:autoplan classifies the outputs

`/strata:autoplan` reads the council reports and sorts every finding into one
of three buckets, which drives what happens next:

- **MECHANICAL** — objective, fixable-without-judgment items (a missing error
  state, an unparameterized query, no rollback flag, a missing test on a risky
  path). Autoplan folds these directly into the plan as concrete tasks.
- **TASTE** — defensible-either-way calls (naming, an abstraction boundary, a
  layout choice, boring-vs-novel). Autoplan records them as decisions with the
  reviewer's recommendation, but leaves the final call to the human.
- **USER-CHALLENGE** — findings that contradict the user's stated intent or
  scope (CEO says "wrong problem"; CSO BLOCKs the requested shortcut). These are
  escalated explicitly: autoplan stops and asks the human to confirm, revise, or
  override before generating the plan.

This classification is why the council can be opinionated without being
obstructive: mechanical fixes flow through automatically, taste calls are
logged, and only genuine challenges to your intent interrupt you.

## Why a council and not one big reviewer

Four narrow experts with conflicting incentives catch more than one generalist
trying to hold every lens at once. The CEO pushes for ambition; the Engineer
pushes for the lean change; the Designer guards the user's experience; the CSO
guards the blast radius. The friction between them is the feature.
