# Strata

> Make any repo **self-describing** and **self-correcting**.

Strata is a [Claude Code](https://docs.claude.com/claude-code) plugin that packages a battle-tested way
of running AI-assisted projects. Install it into any repository — new or existing — and the project
gains an AI-navigable **wiki**, an architecture **canon**, a **spec → plan → TDD** feature flow, a
parallel review **council**, and **drift detection** with staged refactor. Every project becomes
structured, token-efficient, and easy for an AI agent to navigate across fresh sessions.

Strata is **thin glue**. It composes best-of-breed tools (Superpowers, claude-mem, RTK) and adapts
ideas from [gstack](https://github.com/garrytan/gstack). It does **not** reimplement memory,
token-proxying, or testing — it owns one thing well: the **structure / knowledge / process** spine.

---

## Table of contents

- [Why Strata](#why-strata)
- [Instant setup (AI-led)](#-instant-setup-ai-led)
- [The four layers](#the-four-layers)
- [Installation](#installation)
- [Prerequisites](#prerequisites)
- [Quickstart](#quickstart)
- [Commands](#commands)
- [The review council](#the-review-council)
- [How knowledge works](#how-knowledge-works-the-wiki)
- [Typical lifecycle](#typical-lifecycle)
- [Repo layout](#repo-layout)
- [Design philosophy](#design-philosophy--what-strata-is-not)
- [Troubleshooting](#troubleshooting)
- [Credits & license](#credits--license)

---

## Why Strata

AI agents are powerful but forgetful and undisciplined by default. Three problems recur on every
real project:

1. **The agent doesn't know where things are.** Each new session re-reads the codebase from scratch,
   burning tokens and rediscovering the same facts.
2. **Features get added, the pattern gets forgotten.** Structure drifts — raw SQL creeps into
   handlers, docs go stale, dead code piles up — and nobody notices until it hurts.
3. **Work enters the repo without a process.** "Just build it" skips the cheap, high-leverage steps:
   pressure-testing the idea, reviewing the plan, writing the test first.

Strata fixes all three with one installable layer: a **wiki** the agent queries first, an **audit**
that detects drift, and a **feature flow** that runs ideation → review → TDD every time.

---

## The four layers

Strata's whole job is to keep the right tool in the right lane:

| Layer | Owns | Backed by |
|---|---|---|
| **Structure** | What a correct repo looks like — folders, layers, naming, anti-patterns | `PROJECT_PATTERN.md` + a per-stack `SCALABLE_ARCHITECTURE_REFERENCE.md` (the architecture canon) |
| **Knowledge** | What *is* true about the project — curated, git-versioned, queried first | `wiki/` (managed by `/strata:wiki-ingest`) — complementary to claude-mem's episodic memory |
| **Process** | How work enters the repo and how it's verified | `/strata:feature` → office-hours → plan → **council** → TDD |
| **Token economy** | Fewer tokens per session | RTK (command output), claude-mem (smart-Read), Caveman (prose, optional) |

**Knowledge, the key distinction:** `wiki/` is the *reviewed, project-scoped, in-git* truth that
humans read and the agent queries first. **claude-mem** is the *automatic, machine-local, episodic*
working memory ("what did we do last week"). They are complementary — never store the same fact in
both.

---

## ⚡ Instant setup (AI-led)

Don't want to learn the commands? Drop **one line** into a fresh Claude Code session in your repo
and let the AI install Strata and walk you through the whole setup — it detects new-vs-existing,
checks prerequisites, runs `init` or `adopt`, and produces your first audit, asking questions as it
goes.

**In a Claude Code chat (recommended):**

> Install and run Strata in this repo: fetch and follow
> https://raw.githubusercontent.com/Old-G/strata/main/BOOTSTRAP.md

**Or in your terminal:**

```bash
curl -fsSL https://raw.githubusercontent.com/Old-G/strata/main/install.sh | sh
```

Either way you do exactly **one** manual action: when prompted, run `/reload-plugins` (or restart
Claude Code), then send `/strata:onboard`. That single restart is a Claude Code limitation — newly
installed plugin commands only activate after a reload. From there the AI leads the rest.

Prefer to do everything by hand? See [Manual install](#installation) below.

---

## Installation

Strata is a single Claude Code plugin. This repo is also its own plugin **marketplace**.

### Option A — install from the marketplace (recommended)

```bash
# inside any Claude Code session
/plugin marketplace add Old-G/strata
/plugin install strata@strata
```

Then restart the session (or run `/reload-plugins`). The skills become available as `/strata:<name>`.

### Option B — local development

Point Claude Code at a local clone — useful while iterating on the plugin itself:

```bash
git clone https://github.com/Old-G/strata.git
claude --plugin-dir /path/to/strata
/reload-plugins        # after editing any skill or agent
```

### Verify it loaded

```
/strata:using-strata
```

…should load the entry skill and list the available commands.

---

## Prerequisites

Strata works on its own, but is **better** with these. They are **machine-global** (install once),
so Strata declares and checks them rather than bundling them.

| Tool | Role in Strata | Required? |
|---|---|---|
| [Superpowers](https://github.com/obra/superpowers) | The brainstorming / TDD / code-review skills that `/strata:feature` wraps | Recommended (the PROCESS layer leans on it) |
| [claude-mem](https://github.com/thedotmack/claude-mem) | Cross-session episodic memory + smart-Read truncation | Recommended |
| RTK | Bash hook that compacts command output (60–90% fewer tokens on dev ops) | Optional |
| Caveman | Compresses prose output (~4–10% overall session savings) | Optional, low priority |

See [`reference/tool-integration.md`](reference/tool-integration.md) for exactly how each is composed.

---

## Quickstart

### A brand-new project

```bash
cd ~/projects/my-new-thing
claude --plugin-dir /path/to/strata     # or install from marketplace
/strata:init
```

`init` walks the bootstrap checklist: `git init`, `docs/` + `ADR-Lean.md`, a `CLAUDE.md` from
template, `.gitignore`, `.env.example`, pre-commit guards, a passing smoke test, CI skeleton, and —
if an AI agent will read the repo — `raw/` + `wiki/` + the docs→raw mirror hook.

### An existing project

```bash
cd ~/projects/legacy-app
claude --plugin-dir /path/to/strata
/strata:adopt        # incremental + reversible; emits an adoption report for approval
/strata:audit        # read-only drift report — see what to fix
```

`adopt` infers your stack, writes a tailored `CLAUDE.md`, stands up a `wiki/` (ingesting your existing
docs), installs the mirror hook, and produces an adoption report. It **does not** refactor code — it
sets up structure and knowledge, then hands off to `audit` and `refactor`.

---

## Commands

All skills are invoked as `/strata:<name>` and are also auto-suggested by Claude when relevant.

| Command | Purpose | Produces |
|---|---|---|
| `/strata:using-strata` | Entry/router — explains the model and points to the right command | — |
| `/strata:init` | Bootstrap a brand-new project from templates (skip-list aware) | A structured repo |
| `/strata:adopt` | Incrementally bring Strata to an existing repo | Adoption report + wiki + hooks |
| `/strata:audit` | **Read-only** ranked drift report: structure vs canon · wiki-lint · doc freshness · dead code | `docs/superpowers/specs/<date>-strata-audit.md` |
| `/strata:refactor` | Close audit findings safely — per finding → dated spec+plan → TDD | Green, behavior-preserving changes |
| `/strata:office-hours` | YC-partner interrogation of a feature idea (6 forcing questions) | A design doc |
| `/strata:feature` | Full feature flow: office-hours → plan → council → TDD → review → finish | A shipped, reviewed feature |
| `/strata:autoplan` | Run the review council automatically; surface only taste calls & disagreements | A build-ready plan |
| `/strata:wiki-ingest` | The karpathy `ingest` / `query` / `lint` protocol over docs → raw → wiki | Updated `wiki/` |

### Examples

```text
/strata:office-hours add a CSV export to the reports page
    → asks the 6 forcing questions one at a time, then writes
      docs/superpowers/specs/2026-06-16-csv-export-design.md

/strata:audit
    → scans the repo, writes a ranked CRITICAL/HIGH/MEDIUM/LOW findings table,
      changes nothing, ends with "Run /strata:refactor to address these"

/strata:wiki-ingest query where is auth handled?
    → reads wiki/index.md first and answers from the wiki, not by grepping the repo
```

---

## The review council

The council is Strata's process value-add: **four reviewer subagents** that pressure-test a plan or
design doc. They run **in parallel** (via the Agent tool), each with its own context, and they **may
disagree** — with each other and with you. A synthesis step **surfaces conflicts to you** rather than
smoothing them over.

| Reviewer | Persona | Checks |
|---|---|---|
| `strata-ceo-review` | CEO / Founder | Scope, the 10x version, "right problem?", failure modes, observability, 6-month check |
| `strata-eng-review` | Eng-Manager / Staff Eng | Architecture, edge cases, **complexity smell** (8+ files / 2+ new classes → STOP), tests, reversibility |
| `strata-design-review` | Senior Designer | UX, 0–10 ratings, empty/error states, "AI slop is the enemy" (frontend stacks only) |
| `strata-cso-review` | CSO | OWASP Top-10 + STRIDE, secrets, PII, with a confidence bar to avoid false-positive noise |

`/strata:autoplan` runs them and classifies every surfaced decision:

- **Mechanical** — auto-applied silently.
- **Taste** — auto-applied, but listed at the final gate for your awareness.
- **User-challenge** — reviewers disagree with your stated intent → **never** auto-decided; you decide.

See [`reference/council-personas.md`](reference/council-personas.md) for the full personas.

---

## How knowledge works (the wiki)

Strata uses the [karpathy-wiki](https://github.com/karpathy) "pull-forward knowledge base" pattern
over a three-layer split:

```
docs/   ── humans write (source of truth: plans, specs, ADRs, runbooks)
  │  (a script mirrors docs → raw on every edit)
  ▼
raw/    ── AI reads only (a stable mirror of docs/; never hand-edited)
  │  (the AI ingests raw → wiki)
  ▼
wiki/   ── AI writes & queries (index, sources, entities, decisions, glossary, log)
```

- **The agent answers project questions from `wiki/index.md` first** — not by grepping the whole repo.
- A `PostToolUse` hook (installed per-project by `init`/`adopt`, never shipped globally) mirrors
  `docs/*.md → raw/` and flags a `pending_ingest` so the wiki can't silently fall behind.
- `/strata:wiki-ingest lint` reports contradictions, orphans, and drift — it **never** auto-fixes.

The full protocol lives in the bundled [`templates/core/WIKI.md`](templates/core/WIKI.md).

---

## Typical lifecycle

```
new repo  ──/strata:init──▶  structured project  ──┐
existing  ──/strata:adopt─▶  + wiki + hooks  ──────┤
                                                    ▼
            ┌──────────  /strata:audit  ◀── (drift accrues over time)
            │                 │ ranked findings
            │                 ▼
            │          /strata:refactor  ── staged TDD ──▶ green
            │
   feature work:  /strata:feature ─▶ office-hours ─▶ plan ─▶ council ─▶ TDD ─▶ review ─▶ merge
                                                                                  │
                                                              mini-audit + wiki-ingest (no silent drift)
```

---

## Repo layout

```
strata/
├── .claude-plugin/
│   ├── plugin.json          # plugin manifest
│   └── marketplace.json     # this repo is also its own marketplace
├── skills/                  # 9 skills (one dir each, SKILL.md)
│   ├── using-strata/        # entry router
│   ├── init/  adopt/        # bootstrap new / adopt existing
│   ├── audit/  refactor/    # drift detection / staged remediation
│   ├── feature/  office-hours/  autoplan/   # the process layer
│   └── wiki-ingest/         # knowledge protocol
├── agents/                  # the council reviewer subagents (read-only)
│   └── strata-{ceo,eng,design,cso}-review.md
├── templates/
│   ├── core/                # PROJECT_PATTERN.md, WIKI.md, wiki/ skeleton,
│   │                        #   CLAUDE/ADR templates, scripts, pre-commit guards
│   └── stacks/python-fastapi/   # SCALABLE_ARCHITECTURE_REFERENCE.md + scaffold generator
├── reference/               # council personas, tool-integration, Diataxis doc-map
├── CLAUDE.md                # Strata dogfoods its own pattern
└── README.md
```

---

## Design philosophy / what Strata is NOT

- **Thin glue, not a monolith.** Strata composes Superpowers, claude-mem, and RTK — it does not
  re-implement memory, token-proxying, or testing.
- **No global side effects.** The plugin ships **no** global hooks; the docs→raw mirror is installed
  *per target project*, so Strata stays inert in unrelated repos.
- **Stages over big-bang.** Drift is found by `audit` and closed by `refactor` one verifiable TDD
  step at a time — never a sweeping rewrite.
- **Evidence before assertion.** Every multi-step task names a `verify`; a step isn't "done" until the
  verify command passes.
- **Stack-neutral core + stack packs.** The core templates are language-agnostic; the architecture
  canon ships per-stack (`templates/stacks/<stack>/`). `python-fastapi` ships first.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `/strata:*` commands don't appear | Run `/reload-plugins`, or confirm the plugin is enabled with `/plugin`. With `--plugin-dir`, check the path points at the repo root. |
| Skills load but templates aren't found | Skills reference bundled files via `${CLAUDE_PLUGIN_ROOT}` — that env var is set only when running as a plugin. Use a proper install or `--plugin-dir`, not a manual copy. |
| docs→raw mirror not firing | The hook is installed into the *project's* `.claude/settings.json` by `init`/`adopt`. Re-run `/strata:adopt`, or merge `templates/core/claude-settings-hook.json` manually. |
| RTK not compacting `pytest` output | Path-form `.venv/bin/pytest` isn't rewritten — use `uv run pytest` or add the prefix to RTK's `transparent_prefixes`. |
| Audit seems to miss files | For large repos the audit fans out; it logs a "Skipped (NOT audited)" section. Re-run scoped to a subtree if needed. |

---

## Credits & license

MIT. The review-council personas and sprint phases are adapted from
[gstack](https://github.com/garrytan/gstack) (MIT, © Garry Tan) — Strata reimplements the patterns in
its own skills and vendors no gstack source. The wiki pattern is inspired by Andrej Karpathy's
pull-forward knowledge-base approach. The process layer wraps
[Superpowers](https://github.com/obra/superpowers).
