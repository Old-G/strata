# Strata

> Make any repo **self-describing** and **self-correcting**.

Strata is a [Claude Code](https://docs.claude.com/claude-code) plugin that packages a battle-tested way
of running AI-assisted projects. Install it into any repository — new or existing — and the project
gains an AI-navigable **wiki**, an architecture **canon**, a **spec → plan → TDD** feature flow, a
parallel review **council**, and **drift detection** with staged refactor. Every project becomes
structured, token-efficient, and easy for an AI agent to navigate across fresh sessions.

Strata is **thin glue**. It composes best-of-breed tools (claude-mem, RTK, optionally Superpowers) and adapts
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
- [No commands needed (auto-invocation)](#no-commands-needed-auto-invocation)
- [The review council](#the-review-council)
- [How knowledge works](#how-knowledge-works-the-wiki)
- [Hooks — the enforcement layer](#hooks--the-enforcement-layer)
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

## ⚡ Instant setup (AI-led)

**The fastest way in — one line, and the AI does the rest.** You don't need to learn any commands or
read any docs first. Paste a single line into a fresh Claude Code session (or run one command in your
terminal); the AI gets Strata installed and then **runs the entire setup as a conversation** — it works out
whether your repo is new or existing, checks which tools you have, scaffolds or adopts the structure,
and hands you a first drift report. You just answer a few questions as they come.

**Option 1 — paste into a Claude Code chat (recommended):**

> Install and run Strata in this repo: fetch and follow https://raw.githubusercontent.com/Old-G/strata/main/BOOTSTRAP.md

**Option 2 — run in your terminal:**

```bash
curl -fsSL https://raw.githubusercontent.com/Old-G/strata/main/install.sh | sh
```

### What happens next

1. **The AI checks your setup and hands you the install command.** Enabling a plugin is your call in
   Claude Code — it guards that on purpose — so the AI doesn't do it silently; it tells you exactly
   what to run: `/plugin install strata@strata` (plus `/plugin marketplace add Old-G/strata` first,
   only if the marketplace isn't registered yet). Prefer the terminal? The `curl … | sh` above writes
   the same config without any slash commands.
2. **You reload, then launch the conductor.** In **terminal Claude Code**, run `/reload-plugins` (or
   restart the session). In **Cursor / VS Code / other IDE extensions**, fully restart the app (quit
   and reopen, or "Developer: Reload Window") — the extension often won't pick up a newly enabled
   plugin from `/reload-plugins` alone. Then send `/strata:onboard`.
3. **`/strata:onboard` takes over and leads the setup.** It detects whether the repo is **new**
   (→ runs `/strata:init`) or **existing** (→ runs `/strata:adopt`), reports which optional tools you
   have (Superpowers, claude-mem, RTK), proposes a plan, runs it to a green state, then produces your
   **first `/strata:audit`** — asking one question at a time the whole way.
4. **You're set up.** It then points you at `/strata:refactor` (to fix what the audit found) and
   `/strata:feature` (to build your first feature through the full flow).

That's the whole entry: **one line → one reload → answer a few questions → a structured, audited repo.**
If `/strata:onboard` isn't found after the reload, run `/plugin marketplace add Old-G/strata` and
`/plugin install strata@strata` first — the AI tells you this too.

Already know the commands, or prefer to install by hand? See [Manual install](#installation).

---

## The four layers

Strata's whole job is to keep the right tool in the right lane:

| Layer | Owns | Backed by |
|---|---|---|
| **Structure** | What a correct repo looks like — folders, layers, naming, anti-patterns | `PROJECT_PATTERN.md` + a per-stack `SCALABLE_ARCHITECTURE_REFERENCE.md` (the architecture canon) |
| **Knowledge** | What *is* true about the project — curated, git-versioned, queried first | `wiki/` (managed by `/strata:wiki-ingest`) — complementary to claude-mem's episodic memory |
| **Process** | How work enters the repo and how it's verified | `/strata:feature` — ceremony scaled to the task (trivial / standard / risky) |
| **Token economy** | Fewer tokens per session | RTK (command output), claude-mem (smart-Read), Caveman (prose, optional) |

**Knowledge, the key distinction:** `wiki/` is the *reviewed, project-scoped, in-git* truth that
humans read and the agent queries first. **claude-mem** is the *automatic, machine-local, episodic*
working memory ("what did we do last week"). They are complementary — never store the same fact in
both.

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
| [Superpowers](https://github.com/obra/superpowers) | Optional heavier discipline on risky work — Strata's flow is native and complete without it | Optional |
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
| `/strata:feature` | Adaptive feature flow: triage → (grill) → lean plan → risk-matched council → build with evidence → finish → wiki+audit | A shipped feature, with ceremony matched to its risk |
| `/strata:lean-plan` | Write a complete-but-lean plan: intent, constraints, success criterion; references real code instead of pasting it | An inline plan, or `docs/superpowers/plans/<date>-<slug>-plan.md` when risky |
| `/strata:light-finish` | Wrap up a branch: confirm green, then merge / PR / keep / discard, and clean up | An integrated (or cleanly parked) branch |
| `/strata:autoplan` | Run the review council automatically; surface only taste calls & disagreements | A build-ready plan |
| `/strata:wiki-ingest` | The karpathy `ingest` / `query` / `lint` protocol over docs → raw → wiki | Updated `wiki/` |
| `/strata:upgrade` | Re-sync a repo's installed hooks with the plugin currently running — fixes a repo adopted before this version shipped | Current `scripts/**` + merged `.claude/settings.json` |

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

## No commands needed (auto-invocation)

The `/strata:*` forms above are a manual fallback. Skills in Claude Code are **model-invoked**:
Claude matches what you actually said against each skill's `description`, so the normal way to
use Strata is to say what you want, in whatever language you speak.

```
"добавь ретраи в вебхуки"        → feature flow (triaged first)
"как у нас работает авторизация"  → wiki query (index.md first, never grep-first)
"заканчиваем, мержи"              → light-finish (which drift-closes the wiki)
"что-то тут грязно, проверь"      → audit
"есть идея, стоит ли делать"      → office-hours
```

Every skill description carries concrete trigger phrases in **English and Russian**, plus a
`## Do NOT use when` guard so neighbouring skills do not steal each other's requests. The
routing table also lives in your project's `CLAUDE.md`, which is in context every session.

Routing is still probabilistic — which is exactly why the hooks below are not. It is also shared:
every other plugin you have enabled competes for the same words, so a phrase like "build X" can
land in another plugin's skill instead. If routing goes to the wrong place, the fix is the
descriptions (or disabling the competing plugin), not more machinery.

## The review council

The council is Strata's process value-add: reviewer subagents that give an **independent adversarial
read of a risky surface** — not a second pass over ordinary work. It is **risk-triggered and
lens-selected**: it runs only on work triaged as **risky**, and only the **1–2 reviewers whose lens
matches the actual risk** (security / PII → `cso`, frontend / UX → `design`, architecture /
complexity → `eng`, scope → `ceo`). The full panel runs only when several of those risks coincide.
Whichever reviewers are selected run **in parallel** (via the Agent tool), each with its own context,
and they **may disagree** — with each other and with you. A synthesis step **surfaces conflicts to
you** rather than smoothing them over.

| Reviewer | Persona | Checks |
|---|---|---|
| `strata-ceo-review` | CEO / Founder | Scope, the 10x version, "right problem?", failure modes, observability, 6-month check |
| `strata-eng-review` | Eng-Manager / Staff Eng | Architecture, edge cases, **complexity smell** (8+ files / 2+ new classes → STOP), tests, reversibility |
| `strata-design-review` | Senior Designer | UX, 0–10 ratings, empty/error states, "AI slop is the enemy" (frontend stacks only) |
| `strata-cso-review` | CSO | OWASP Top-10 + STRIDE, secrets, PII, with a confidence bar to avoid false-positive noise |

A fifth read-only reviewer runs **after** the code exists, not before: `strata-diff-review` is invoked
by `/strata:light-finish` at branch close to check the diff against the plan it was meant to implement
(done as planned / done differently / planned-not-done / done-not-planned), then bugs and light
security. It cannot block a merge — you decide — but it cannot be skipped, its Important findings land
in the branch state and `wiki/log.md`, and a mistake it flags for the **second time** proposes a line
for `CLAUDE.md` in the same closing commit.

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
  `docs/*.md → raw/` and records a `pending_ingest` marker.
- Those markers are **enforced**, not advisory — see the hooks below.
- `/strata:wiki-ingest lint` reports contradictions, orphans, and drift — it **never** auto-fixes.

The full protocol lives in the bundled [`templates/core/WIKI.md`](templates/core/WIKI.md).

**`wiki/log.md` is a trajectory, not a state.** It answers "what happened, in order" — useful for
an audit trail, useless for "what do we currently know about this branch". That's what
`.strata/state/<branch>.json` is for: a small, schema-validated, git-tracked file (see
`scripts/lib/state_tools.py`) holding the branch's goal, decisions (each with a `why` and a
`trust: session|reviewed` flag — nothing auto-promotes an unreviewed decision into `wiki/`),
open questions, gotchas, and `wiki_debt` — knowledge that owes the wiki but isn't a `docs/*.md`
edit yet. SessionStart injects its summary; the Stop gate blocks once while `wiki_debt` is
non-empty; `light-finish` folds it into `wiki/log.md` and deletes it when the branch closes.

---

## Hooks — the enforcement layer

Skill text is probabilistic; hooks are deterministic. Anything phrased "the agent must always…"
is a hook in Strata, not a paragraph. Three of them keep the wiki honest:

| Hook | Event | What it does |
|---|---|---|
| `scripts/sync_raw_mirror.sh` | `PostToolUse` | Mirrors an edited `docs/*.md` into `raw/` and records a `pending_ingest` marker in `wiki/log.md`. |
| `scripts/hooks/strata_session_start.sh` | `SessionStart` | Injects ≤50 lines of state — branch, pending ingests, the head of `wiki/index.md` — into every session, and stamps where the session began. |
| `scripts/hooks/strata_stop_gate.sh` | `Stop` | Refuses to end the turn **once** if this session left the wiki behind — including a non-empty `wiki_debt` in the current branch's `.strata/state/*.json`, the episodic state layer. |
| `scripts/hooks/strata_pre_tool_guard.sh` | `PreToolUse` | Refuses a write **before it happens**: always under `raw/` (a mirror — edit `docs/`; escape `STRATA_ALLOW_RAW_EDIT=1`), and to test files while `.strata/guard-tests` exists (a fix is in progress — fix the code, not the test). Exit 2 with the reason; fails open on anything it cannot parse. |
| `scripts/pre-commit/check_wiki_fresh.sh` | pre-commit | Fails the commit while any doc is mirrored but un-ingested. |

**Nothing is installed globally.** The plugin ships these as templates; `init`/`adopt` copy them
into the *target* project and merge the events into that project's `.claude/settings.json`. Strata
stays inert in repos that never adopted it.

**The Stop gate cannot trap you.** In order: it exits immediately when `stop_hook_active` is set;
it fails open when it cannot tell where the session began; and it blocks **at most once per
session** — a gate that fires forever is worse than no gate. It only considers markers created in
the current session; older ones are the commit gate's problem, not an interruption you did not
earn. The clean-state path is measured under 100 ms.

It also blocks a session that changed a lot of code and wrote nothing to the wiki at all — because
code-only changes were the drift nobody caught. That block is always satisfiable with one line in
`wiki/log.md`, including an explicit `no-wiki-impact: <reason>`.

```bash
STRATA_STOP_GATE_LINES=0     # disable the code-only trigger (default: 50 changed lines)
STRATA_SKIP_WIKI=1 git commit -m "wip"   # escape hatch for a genuine WIP commit
```

Verify the whole layer end-to-end: `bash scripts/test_p1_gates.sh`.

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
   feature work:  /strata:feature ─▶ triage:  trivial │ standard │ risky
                          │
                          │   tier decides which phases run:  office-hours · lean plan
                          │                                   · risk-matched council
                          ▼
                 build with evidence ─▶ finish (merge / PR) ─▶ wiki-ingest + mini-audit
                                                                      (no silent drift)
```

---

## Repo layout

```
strata/
├── .claude-plugin/
│   ├── plugin.json          # plugin manifest
│   └── marketplace.json     # this repo is also its own marketplace
├── skills/                  # 12 skills (one dir each, SKILL.md)
│   ├── using-strata/        # entry router
│   ├── onboard/             # AI-led end-to-end setup
│   ├── init/  adopt/        # bootstrap new / adopt existing
│   ├── audit/  refactor/    # drift detection / staged remediation
│   ├── feature/  office-hours/  autoplan/   # the process layer
│   ├── lean-plan/  light-finish/            #   …lean plan + branch wrap-up
│   └── wiki-ingest/         # knowledge protocol
├── agents/                  # the council reviewer subagents (read-only)
│   └── strata-{ceo,eng,design,cso}-review.md
├── templates/
│   ├── core/                # PROJECT_PATTERN.md, WIKI.md, wiki/ skeleton,
│   │   │                    #   CLAUDE/ADR templates
│   │   └── scripts/         # installed per-project by init/adopt:
│   │       ├── sync_raw_mirror.sh        # PostToolUse: docs → raw + marker
│   │       ├── lib/pending_ingest.sh     # the one marker-retirement rule
│   │       ├── hooks/                    # SessionStart injection · Stop gate
│   │       └── pre-commit/               # secrets · raw mirror · wiki freshness
│   └── stacks/python-fastapi/   # SCALABLE_ARCHITECTURE_REFERENCE.md + scaffold generator
├── reference/               # council personas, tool-integration, Diataxis doc-map
├── scripts/                 # validate.sh + behavioural tests (installer, P1 gates)
├── .githooks/pre-commit     # Strata's own guards (git config core.hooksPath .githooks)
├── raw/  wiki/              # Strata's own knowledge layer — it dogfoods the wiki
├── CLAUDE.md                # Strata dogfoods its own pattern
└── README.md
```

---

## Design philosophy / what Strata is NOT

- **Thin glue, not a monolith.** Strata composes claude-mem and RTK — and Superpowers too, if you
  have it installed — rather than re-implementing memory, token-proxying, or testing. The process
  flow itself is native: Superpowers is an optional power-up, never a prerequisite.
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
