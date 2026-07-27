---
name: using-strata
description: Use when starting work in a Strata-managed project, when the user mentions Strata, or when the user wants to bootstrap/adopt/audit/refactor a project's structure - establishes the four-layer model and routes to the right Strata skill.
---

# Using Strata

Strata makes any repo **self-describing** (the AI always knows where everything is) and
**self-correcting** (the repo's drift from its own rules is detectable and fixable in stages).

It is a thin orchestration layer. It does **not** reimplement memory, token-proxying, or testing —
it composes best-of-breed tools and owns one thing: the **structure / knowledge / process** spine.

## The four-layer model (each tool stays in its lane)

| Layer | Owns | Backed by |
|---|---|---|
| **STRUCTURE** | "What a correct repo looks like" — folders, layers, naming, anti-patterns | `templates/core/PROJECT_PATTERN.md` + `templates/stacks/<stack>/SCALABLE_ARCHITECTURE_REFERENCE.md` |
| **KNOWLEDGE** | "What IS true about this project" (durable, git-versioned, curated) | `wiki/` (managed by `wiki-ingest`) — distinct from claude-mem (automatic, machine-local, episodic) |
| **PROCESS** | "How work enters the repo and how we verify it's done" | `feature` — native adaptive flow: ceremony scaled to the task (trivial/standard/risky), with a risk-matched `council`; Superpowers optional |
| **TOKEN ECONOMY** | "Spend fewer tokens per session" | RTK (command output), claude-mem (smart-Read), Caveman (prose, optional) — declared, not bundled |

**Knowledge layer, critical distinction:** `wiki/` is the *reviewed, project-scoped, in-git* truth
that humans read and the AI queries first. **claude-mem** is the *automatic, machine-local, episodic*
working memory ("what did we do recently"). They are complementary — never store the same fact in both.
When answering "where does X live / what's the architecture", read `wiki/`. When recalling "how did we
solve Y last week", that's claude-mem.

## Skills — what to invoke when

| You want to... | Invoke | What it does |
|---|---|---|
| Get set up end-to-end (let the AI lead it) | `/strata:onboard` | Detects new/existing, checks prereqs, then delegates to `init`/`adopt` and runs the first `audit` |
| Start a brand-new project | `/strata:init` | Scaffolds the full layout from templates (skip-list aware) |
| Bring Strata to an existing repo | `/strata:adopt` | Incremental, reversible: infers stack, writes CLAUDE.md + PROJECT_PATTERN, stands up wiki, installs hooks, emits an adoption report |
| Check the repo against its own rules | `/strata:audit` | Read-only ranked drift report: structure vs canon, wiki-lint, doc freshness, dead code |
| Fix the debt the audit found, safely | `/strata:refactor` | Per finding -> dated spec+plan -> test-first, one verifiable step at a time |
| Explore / pressure-test a new feature idea | `/strata:office-hours` | YC-partner interrogation (6 forcing questions) -> design-doc; then the council |
| Run the full feature flow | `/strata:feature` | Adaptive-ceremony feature flow — classifies the task (trivial/standard/risky) and runs only the ceremony that fits, behind a safety floor |
| Write a plan without the ceremony | `/strata:lean-plan` | Complete-but-lean plan: intent, constraints, success criterion; points at real references instead of pasting code |
| Close out a finished branch | `/strata:light-finish` | Wrap up a branch: confirm green, then merge / PR / keep / discard, and clean up |
| Auto-run the review council | `/strata:autoplan` | Runs the 4 reviewer subagents, auto-decides mechanical calls, surfaces only taste/disagreement |
| Update / query the knowledge wiki | `/strata:wiki-ingest` | The karpathy ingest / query / lint protocol over docs->raw->wiki |

## The review council (PROCESS layer)

The council is **risk-triggered and lens-selected** — it is not a standing panel on every plan. It
runs only on work triaged as **risky**, and then only the **1-2 reviewers whose lens matches the
actual risk**. The full panel runs only when several risks coincide. Its job is an independent
adversarial read of a risky surface, not a second pass over ordinary work.

| Risk in the work | Lens to run | Checks |
|---|---|---|
| Security, auth, secrets, PII | `strata-cso-review` | OWASP Top-10 + STRIDE |
| Frontend / user-facing UX | `strata-design-review` | UX (only when the stack has a frontend) |
| Architecture, data flow, complexity | `strata-eng-review` | Edge cases, **complexity smell** (8+ files / 2+ new classes -> STOP), tests |
| Scope, "is this the right problem?" | `strata-ceo-review` | Scope, the 10x version, failure modes |

Defined as **parallel subagents** in `agents/`: whichever lenses are selected run in parallel via the
Agent tool. They may disagree — with each other and with the human — and a synthesis step surfaces
conflicts rather than smoothing them over.

`/strata:office-hours` runs **interactively in the main session** (a dialogue can't be parallelized).

## Operating rules in a Strata project

- **Query the wiki first.** Start from `wiki/index.md`, not by grepping the whole repo.
- **docs/ is human source-of-truth; raw/ is its mirror; wiki/ is AI-owned.** Never hand-edit `raw/`.
- **Every multi-step task is goal-driven:** each step names a `verify` command, not "I'll check it works".
- **Drift is fixed in stages**, never big-bang. The audit finds it; refactor closes it one TDD step at a time.
- **CLAUDE.md <= 200 lines.** Detail lives in `docs/` and skills, not in CLAUDE.md.

## Bundled assets

Reference bundled files with `${CLAUDE_PLUGIN_ROOT}`:
- `${CLAUDE_PLUGIN_ROOT}/templates/core/` — PROJECT_PATTERN.md, WIKI.md, wiki/ skeleton, scripts, ADR/CLAUDE templates
- `${CLAUDE_PLUGIN_ROOT}/templates/stacks/<stack>/` — the SAR (architecture canon) + scaffold generator per stack
- `${CLAUDE_PLUGIN_ROOT}/reference/` — council personas, Diataxis doc-map, tool-integration (RTK/claude-mem/Caveman)
