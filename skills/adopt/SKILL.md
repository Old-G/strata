---
name: adopt
description: Use when onboarding Strata into an EXISTING repo with real code/history, when the user says "adopt Strata here / add Strata to this project / make this repo self-describing / onboard our codebase". Incrementally and reversibly sets up structure + knowledge (CLAUDE.md, wiki, docs→raw mirror) and emits an adoption report for approval — it does NOT refactor code.
---

# /strata:adopt — onboard an existing repository

Goal: make an existing repo self-describing without a big-bang rewrite. Everything is incremental, reversible (small git commits), and gated on human approval before any structural move. Adopt sets up the structure + knowledge spine; it does NOT change application code. Drift findings are handed to `/strata:audit`; code fixes are handed to `/strata:refactor`.

Bundled assets live under `${CLAUDE_PLUGIN_ROOT}/templates/`.

## Phase 1 — Scan and infer (read-only)

Make NO writes in this phase. Build an accurate picture:

1. Stack & tooling: detect manifests (`pyproject.toml`, `package.json`, `go.mod`, …), pinned vs floating versions, lint/format/type tools, lockfiles.
2. Topology: monorepo vs multiple `services/`/`packages/` vs single app. Note repo strategy (PROJECT_PATTERN §5): monorepo / nested independent / submodule.
3. Existing docs: `README*`, `docs/`, `ARCHITECTURE*`, ADRs (single-file or `adr/NNNN-*`), runbooks.
4. Tests & CI: test runner, how tests are invoked, coverage signal, existing CI config and whether it's green.
5. Secrets hygiene: is `.env` gitignored? Any secrets already in history? (flag, don't fix.)
6. Existing `CLAUDE.md` / `.claude/settings.json` — preserve and merge, never clobber.
7. Decide the §9 skip-list shape (skip `raw/`+`wiki/` for a tiny human-only repo; skip Phase-status table for no-roadmap projects).

Summarize findings to the user before proceeding.

## Phase 2 — Draft structure + tailored CLAUDE.md (write to a branch)

Create a working branch (e.g. `strata/adopt`) so everything is reversible.

1. Render `${CLAUDE_PLUGIN_ROOT}/templates/core/CLAUDE.md.tmpl` into a tailored `CLAUDE.md` that reflects what ACTUALLY exists: real commands (the project's real test/run/build invocations), real layout, honest phase status (use the real current state — "live in prod", "WIP", etc., not a fake Phase 0). If a `CLAUDE.md` exists, propose a merged version and show the diff.
2. Map the current layout onto PROJECT_PATTERN as a *proposal* (a table: current path → proposed path → rationale). Do not move anything yet.
3. If `docs/ADR-Lean.md` is absent, render `${CLAUDE_PLUGIN_ROOT}/templates/core/ADR-Lean.md.tmpl` (with ADR #01 secrets policy). If single-file-incompatible ADRs exist, propose consolidating them (deferred, not forced).
4. Ensure `.gitignore` covers `.env` etc. by merging `${CLAUDE_PLUGIN_ROOT}/templates/core/gitignore.tmpl` (merge, never overwrite). Add `.env.example` from the template if missing.

## Phase 3 — Knowledge spine: wiki + docs→raw mirror

Skip if Phase 1 chose the §9 skip-list (no AI reader). Otherwise:

1. Copy `${CLAUDE_PLUGIN_ROOT}/templates/core/WIKI.md` → project `WIKI.md` (merge if present).
2. Create `raw/` and mirror existing `docs/`: `cp -p docs/*.md raw/` (recurse subdirs). Create the `wiki/` skeleton from `${CLAUDE_PLUGIN_ROOT}/templates/core/wiki/` (copy `wiki/scripts/lint.py` + empty `sources/ entities/ decisions/`) and seed `wiki/index.md`, `wiki/overview.md`, `wiki/glossary.md`, `wiki/log.md`.
3. Ingest the existing docs by DELEGATING to `/strata:wiki-ingest` for each `raw/*.md` (README, architecture, ADRs, runbooks). Do not hand-author entity pages here — wiki-ingest owns the cascade.
4. Install the docs→raw hook: copy `${CLAUDE_PLUGIN_ROOT}/templates/core/scripts/sync_raw_mirror.sh` → project `scripts/sync_raw_mirror.sh` (`chmod +x`), then MERGE the `hooks` block from `${CLAUDE_PLUGIN_ROOT}/templates/core/claude-settings-hook.json` into the project's `.claude/settings.json` (append to an existing `PostToolUse` array; drop the `_strata_note` key). Confirm you did not overwrite existing hooks.

## Phase 4 — Adoption report (REQUIRED gate)

Write `docs/superpowers/specs/<YYYY-MM-DD>-strata-adoption-report.md` with three explicit sections:

- **Conforms** — what already matches PROJECT_PATTERN (e.g. tests present, `.env` gitignored, ADRs exist).
- **Does not conform** — gaps vs the pattern (floating tool versions, no pre-commit, code outside the proposed layout, secrets-in-history flag). Each gap → who fixes it: `/strata:refactor` (code), human (history purge), or follow-up adopt step.
- **Deferred** — structural moves NOT done now and why (e.g. renaming dirs touches imports → needs `/strata:refactor`).

Also state, plainly: "adopt did not modify any application code." Then STOP and require explicit human approval before performing any structural move (file/dir relocation). Approval is per-move where moves are risky.

## Phase 5 — VERIFY (evidence before assertion)

1. Tests still pass — `verify`: run the project's real test command, confirm exit 0 (adopt must not break the build).
2. Hook installed — `verify`: edit a `docs/*.md` file and confirm `raw/` updated + a `pending_ingest` line landed in `wiki/log.md` (or run `bash scripts/sync_raw_mirror.sh docs/<file>.md` directly).
3. **Knowledge verification (the real acceptance test):** in a fresh mindset, answer "where does X live?" and "what is the architecture?" using `wiki/` ONLY (not `raw/`, not source). If the wiki can't answer, the ingest is incomplete — loop back to `/strata:wiki-ingest`. Say so honestly rather than claiming success.
4. Confirm small, reversible commits on the branch (no squashed mega-commit); the report is committed.

## Phase 6 — Hand off

- Present the branch + adoption report for review/merge.
- Recommend the path forward: `/strata:audit` to surface drift findings against the now-documented canon, then `/strata:refactor` to fix conformance gaps in stages. Do NOT auto-run them.
