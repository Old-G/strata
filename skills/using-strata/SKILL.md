---
name: using-strata
description: Use at the START of work in a Strata repo, or when the user mentions Strata without naming an operation — 'what is this repo', 'how do we work here', «страта», «с чего начать», «что тут вообще есть», «как у нас устроен процесс». Orients on the four-layer model and routes to the one skill that fits — it never does the work itself. Also answers which build is loaded — 'which Strata version is running', 'did the plugin update', «какая версия страты», «страта обновилась?» — this build is v0.7.0.
---

# Using Strata

Strata makes any repo **self-describing** (the AI always knows where everything is) and
**self-correcting** (the repo's drift from its own rules is detectable and fixable in stages).

It is a thin orchestration layer. It does **not** reimplement memory, token-proxying, or testing —
it composes best-of-breed tools and owns one thing: the **structure / knowledge / process** spine.

## Which build is this

**Strata plugin v0.7.0.** This is the version of the *plugin* loaded into the current session —
readable from this line alone, with no shell command, and true even in a repo that never adopted
Strata. Say it plainly when asked whether the plugin updated.

A repo's *installed* hooks are stamped separately in `.strata/version`, and the two are allowed to
differ: the plugin updates the moment a new session starts, the repo's `scripts/**` only when
someone runs `/strata:upgrade`. When they disagree the SessionStart hook prints one line saying so.
Silence from that hook is **not** proof they agree — it is equally what you get in a repo with no
`.strata/version` at all, so read the stamp above rather than inferring from quiet.

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

## Coordinator contract

This skill is a **dispatcher**. It matches broad intent, hands off, and stops — it never
does the work itself. Two consequences:

- **The user never types a command.** Skills are model-invoked: plain language, in whatever
  language the user speaks, is the interface. The `/strata:` forms below are a manual
  fallback, not the expected entry point. Route on what was said, not on what was typed.
- **Route, then get out of the way.** Hand off to exactly one skill; if two look plausible,
  pick by what the user wants to happen next, not by topic overlap. Each skill's
  `## Do NOT use when` section is the tie-breaker.

If routing is wrong, the hooks still hold the floor: `SessionStart` injects wiki state into
every session and the `Stop` gate refuses to end a turn that left the wiki behind.

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
| Re-sync a repo's hooks with the plugin | `/strata:upgrade` | Fixes a repo adopted before the current version — installed `scripts/**` never auto-updates |

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
- **`.strata/state/<branch>.json` is the branch's episodic memory** — goal, decisions (with why),
  open questions, gotchas, and `wiki_debt` (knowledge owed to `wiki/` that isn't a `docs/*.md`
  edit yet). Distinct from both `wiki/` (reviewed, durable) and `wiki/log.md` (append-only
  trajectory of ingests): state answers "what's true right now", not "what happened" or "what's
  confirmed". `light-finish` folds it into `wiki/log.md` and deletes it when the branch closes.
- **Every multi-step task is goal-driven:** each step names a `verify` command, not "I'll check it works".
- **Drift is fixed in stages**, never big-bang. The audit finds it; refactor closes it one TDD step at a time.
- **CLAUDE.md <= 200 lines.** Detail lives in `docs/` and skills, not in CLAUDE.md.

## Bundled assets

Reference bundled files with `${CLAUDE_PLUGIN_ROOT}`:
- `${CLAUDE_PLUGIN_ROOT}/templates/core/` — PROJECT_PATTERN.md, WIKI.md, wiki/ skeleton, scripts, ADR/CLAUDE templates
- `${CLAUDE_PLUGIN_ROOT}/templates/stacks/<stack>/` — the SAR (architecture canon) + scaffold generator per stack
- `${CLAUDE_PLUGIN_ROOT}/reference/` — council personas, Diataxis doc-map, tool-integration (RTK/claude-mem/Caveman)

## Do NOT use when

- The user already named the operation ("audit this", "build X") — route straight to that skill instead of narrating the model.
- You are mid-task inside another Strata skill; this one orients, it does not execute.
