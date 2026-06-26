# Changelog

All notable changes to Strata are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.1] — 2026-06-26

### Changed
- **Onboarding now checks prerequisites and hands you the exact install command.** `BOOTSTRAP.md`
  Step 1 and `/strata:onboard` Step 3 no longer merely *report* missing companions — for each one
  they show how to install it and what it buys:
  - **Superpowers** (strongly recommended) → `/plugin install superpowers@claude-plugins-official`,
    offered in the same batch as enabling Strata. It's the engine of `/strata:feature`.
  - **claude-mem** (optional) → install command + the payoff: cross-session memory + smart-Read to
    navigate code by structure instead of re-reading whole files each session.
  - **RTK** (optional) → its setup + the payoff: typically **60–90% fewer tokens** on dev operations.
  Strata's native spine still works without any of them — the check is non-blocking.

## [0.2.0] — 2026-06-25

### Added
- **One-line, AI-led onboarding.** Drop a single line into a fresh Claude Code session
  (`Install and run Strata in this repo: fetch and follow …/BOOTSTRAP.md`) or run
  `curl -fsSL …/install.sh | sh`, and the AI installs Strata, then conducts the whole setup as a
  conversation — no need to learn the commands first.
  - **`install.sh`** — idempotent, non-destructive, no-op-safe merge of the marketplace +
    `enabledPlugins["strata@strata"]` keys into `~/.claude/settings.json` (aborts *before* writing if
    the existing file is invalid JSON; skips backup/rewrite when already registered). Covered by
    `scripts/test_install.sh` (5 behavioral tests, wired into CI).
  - **`BOOTSTRAP.md`** — the chat-path session-1 conductor (addressed to the AI): idempotency check,
    prerequisite scan, config write, a resume breadcrumb, and the restart **bridge** that always
    carries a `/plugin marketplace add` + `/plugin install` fallback.
  - **`/strata:onboard`** — the session-2 conductor: detects new-vs-existing, checks prerequisites,
    delegates to `/strata:init` or `/strata:adopt`, then runs the first `/strata:audit` — a thin glue
    skill that never reimplements those flows.
- **CI/validation** — `scripts/validate.sh` now syntax-checks the root `install.sh`; the GitHub
  Actions workflow runs the installer behavioral tests.
- **README** — a prominent "⚡ Instant setup (AI-led)" walkthrough explaining the one-line flow.

## [0.1.2] — 2026-06-16

### Fixed
- **Plugin install still failed with "agents: Invalid input".** The manifest schema only accepts
  `.md` FILE paths for `agents` (not a directory), and the standard `skills/` and `agents/`
  directories are **auto-discovered** — so the manifest needs no component-path fields at all.
  Removed both `skills` and `agents` from `plugin.json`, matching every official plugin (superpowers,
  claude-mem, pr-review-toolkit, … all ship metadata-only manifests). `validate.sh` now enforces the
  real schema.

## [0.1.1] — 2026-06-16

### Fixed
- **Plugin install failed** — `plugin.json` declared `"agents": ["./agents/"]` (an array containing a
  folder), which the Claude Code manifest validator rejects. A folder reference must be a **string**
  (`"agents": "./agents/"`), matching `skills`. `validate.sh` now catches this format regression.

## [0.1.0] — 2026-06-16

Initial release. Strata packaged as a Claude Code plugin.

### Added
- **Plugin manifests** — `.claude-plugin/plugin.json` + `marketplace.json` (the repo is its own marketplace).
- **9 skills** (`/strata:<name>`): `using-strata` (entry router), `init`, `adopt`, `audit`,
  `refactor`, `feature`, `office-hours`, `autoplan`, `wiki-ingest`.
- **4 review-council subagents** (read-only, parallel, may disagree): `strata-ceo-review`,
  `strata-eng-review`, `strata-design-review`, `strata-cso-review`.
- **templates/core** — `PROJECT_PATTERN.md`, `WIKI.md`, the `wiki/` skeleton, `CLAUDE.md`/`ADR-Lean`
  templates, the docs→raw mirror script, and pre-commit guards.
- **templates/stacks/python-fastapi** — `SCALABLE_ARCHITECTURE_REFERENCE.md` (the architecture canon).
- **reference/** — council personas, tool-integration (RTK / claude-mem / Caveman), Diataxis doc-map.
- **CI** — `scripts/validate.sh` + a GitHub Actions workflow validating manifests, skill/agent
  frontmatter, and script syntax.

### Security
- Genericized all templates for public release: removed an internal service inventory from `WIKI.md`,
  emptied the hardcoded drift-check manifest and an employee name reference in `lint.py`, and quoted a
  glob-expansion in `sync_raw_mirror.sh` (findings from a dogfooded `strata-cso-review` pass).
- Removed an incomplete MCP-scaffold script that referenced a non-bundled template directory.

### Notes
- Methodology adapts [gstack](https://github.com/garrytan/gstack) (MIT) and wraps
  [Superpowers](https://github.com/obra/superpowers); composes claude-mem and RTK as declared
  prerequisites (not bundled).
- All shipped templates and docs are in English.
