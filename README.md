# Strata

> Make any repo **self-describing** and **self-correcting**.

Strata is a [Claude Code](https://docs.claude.com/claude-code) plugin that packages a battle-tested
way of running AI-assisted projects: an AI-navigable **wiki**, an architecture **canon**, a
**spec → plan → TDD** feature flow, a parallel review **council**, and **drift detection** with
staged refactor. Bootstrap a new project or adopt an existing one — every project becomes structured,
token-efficient, and easy for an AI agent to navigate across fresh sessions.

It is **thin glue**: it composes best-of-breed tools (Superpowers, claude-mem, RTK) and adapts ideas
from [gstack](https://github.com/garrytan/gstack). It does not reimplement memory, token-proxying, or
testing — it owns the **structure / knowledge / process** spine.

## The four layers

| Layer | Owns |
|---|---|
| **Structure** | What a correct repo looks like — folders, layers, naming, anti-patterns (`PROJECT_PATTERN.md` + a per-stack `SCALABLE_ARCHITECTURE_REFERENCE.md`) |
| **Knowledge** | What *is* true about the project — a curated, git-versioned `wiki/` the AI queries first (complementary to claude-mem's episodic memory) |
| **Process** | How work enters the repo and how it's verified — `office-hours` → plan → review **council** → TDD |
| **Token economy** | Fewer tokens per session — RTK (command output), claude-mem (smart-Read), Caveman (prose, optional) |

## Install

```bash
# add this repo as a marketplace, then install the plugin
/plugin marketplace add <owner>/strata
/plugin install strata@strata

# or develop locally
claude --plugin-dir /path/to/strata
```

## Commands

| Command | Purpose |
|---|---|
| `/strata:init` | Bootstrap a brand-new project from templates (skip-list aware) |
| `/strata:adopt` | Incrementally bring Strata to an existing repo; emits an adoption report |
| `/strata:audit` | Read-only ranked **drift report**: structure vs canon · wiki-lint · doc freshness · dead code |
| `/strata:refactor` | Close audit findings safely — per finding → dated spec+plan → TDD |
| `/strata:office-hours` | YC-partner interrogation of a feature idea → a design doc |
| `/strata:feature` | Full feature flow: office-hours → plan → council → TDD → review → finish |
| `/strata:autoplan` | Run the review council automatically; surface only taste calls & disagreements |
| `/strata:wiki-ingest` | The karpathy `ingest` / `query` / `lint` protocol over docs → raw → wiki |

## The review council

Four **parallel reviewer subagents** (they may disagree; conflicts are surfaced, not smoothed):

- **CEO** — scope, the 10x version, failure modes
- **Eng-Manager** — architecture, edge cases, complexity smell, tests
- **Designer** — UX (frontend stacks only)
- **CSO** — OWASP Top-10 + STRIDE

## How it works (typical lifecycle)

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

## Layout

```
strata/
├── .claude-plugin/
│   ├── plugin.json          # plugin manifest
│   └── marketplace.json     # this repo is also its own marketplace
├── skills/                  # init, adopt, audit, refactor, feature, office-hours, autoplan, wiki-ingest, using-strata
├── agents/                  # the council reviewer subagents
├── templates/
│   ├── core/                # PROJECT_PATTERN.md, WIKI.md, wiki/ skeleton, scripts, CLAUDE/ADR templates
│   └── stacks/python-fastapi/  # SCALABLE_ARCHITECTURE_REFERENCE.md + scaffold generator
└── reference/               # council personas, Diataxis doc-map, tool-integration notes
```

## Prerequisites (declared, not bundled)

Strata works without these, but is better with them (machine-global, install once):

- **[claude-mem](https://github.com/thedotmack/claude-mem)** — cross-session episodic memory + smart-Read.
- **RTK** — token-compacting Bash proxy hook.
- **[Superpowers](https://github.com/obra/superpowers)** — the brainstorming / TDD / code-review skills Strata's `feature` flow wraps.
- **Caveman** *(optional)* — prose-output compression; low overall savings, opt-in.

## License

MIT. Methodology adapted from gstack (MIT); no gstack source is vendored.
