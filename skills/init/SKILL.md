---
name: init
description: Use when starting a brand-new project from an empty or near-empty directory, when the user says "set up a new repo / bootstrap a project / scaffold a new service with Strata". Bootstraps the full PROJECT_PATTERN structure (docs, CLAUDE.md, ADR-Lean, pre-commit, tests, CI, optional raw/wiki) with a green-on-first-commit baseline.
---

# /strata:init — bootstrap a brand-new project

Goal: produce a self-describing, self-correcting repo skeleton where the smoke test is green, the architecture canon exists, and (optionally) an AI agent can already answer "where does X live" from `wiki/`. This runs the PROJECT_PATTERN §10 bootstrap checklist programmatically. Do NOT scaffold application features — that is `/strata:feature`.

All bundled assets are under `${CLAUDE_PLUGIN_ROOT}/templates/`. Render every `{{PLACEHOLDER}}` before writing.

## Phase 1 — Confirm scope and stack

1. Confirm the target directory (default: cwd). If it already has a git history or substantial code, STOP and redirect to `/strata:adopt` (init is for new projects only).
2. Ask the user for: project name, one-line purpose, and primary stack.
3. Pick a stack pack: list `${CLAUDE_PLUGIN_ROOT}/templates/stacks/`. If one matches (e.g. `python-fastapi`), use it. If none matches, use `templates/core/` only and tell the user explicitly: "No stack pack for <stack>; bootstrapping core structure only — stack-specific tooling is left to you."
4. Derive: `{{SERVICE_SLUG}}` (kebab/snake of name), `{{SERVICE_PREFIX}}` (UPPER_SNAKE, used for env vars), `{{TODAY}}`.
5. Apply the §9 skip-list decision now (see Phase 5). Ask: "Will an AI agent read this repo regularly?" — drives whether `raw/`+`wiki/` are created.
6. State the plan as `step → verify` and get approval before writing anything.

## Phase 2 — Core bootstrap (always)

Run the PROJECT_PATTERN §10 checklist. Use `git mv`/plain writes; keep it one reviewable commit.

1. `git init` if not already a repo.
2. `.gitignore` ← render `${CLAUDE_PLUGIN_ROOT}/templates/core/gitignore.tmpl` (merge if one exists; never clobber).
3. `docs/Architecture.md` — a real one-pager: purpose, the chosen stack, a component sketch in prose, and the data-flow. Not a stub.
4. `docs/ADR-Lean.md` ← render `${CLAUDE_PLUGIN_ROOT}/templates/core/ADR-Lean.md.tmpl` (ships with ADR #01 = secrets policy).
5. `CLAUDE.md` ← render `${CLAUDE_PLUGIN_ROOT}/templates/core/CLAUDE.md.tmpl`. Phase status MUST be honest: `🔄 Phase 0: planning` with no prod checkmarks. Keep ≤200 lines.
6. `.env.example` ← render `${CLAUDE_PLUGIN_ROOT}/templates/core/env.example.tmpl` with the `{{SERVICE_PREFIX}}_` prefix.
7. Stack manifest with pinned tooling versions: from the stack pack if present, else `pyproject.toml`/`package.json` minimal + pinned lint/format/test tools.
8. Pre-commit config `.pre-commit-config.yaml`: linter + formatter for the stack + a local `check-secrets` hook running `${CLAUDE_PLUGIN_ROOT}/templates/core/scripts/pre-commit/check_secrets.sh` — copy that script to the project's `scripts/pre-commit/check_secrets.sh` and `chmod +x` it (hooks run project-relative paths, not plugin paths).
9. `tests/` with ONE passing smoke test (`test_smoke` that imports the package / hits a health route). It must actually pass.
10. CI skeleton (`.github/workflows/ci.yml` or `.gitlab-ci.yml` per stack): install → lint → type-check → test. It MUST be green on the first commit — only wire steps that pass now.

## Phase 3 — AI-mirror + wiki (only if Phase 1 said "yes")

Skip this entire phase for human-only repos (§9 skip-list). When enabled:

1. Copy `${CLAUDE_PLUGIN_ROOT}/templates/core/WIKI.md` → project root `WIKI.md`.
2. Create `raw/` and mirror current `docs/` into it: `cp -p docs/*.md raw/`.
3. Create the `wiki/` skeleton from `${CLAUDE_PLUGIN_ROOT}/templates/core/wiki/` (copy `wiki/scripts/lint.py` and the empty `decisions/ entities/ sources/` dirs), then write the top-level pages that the skeleton omits:
   - `wiki/index.md` — catalog with a one-line TLDR row per `raw/` file (Architecture, ADR-Lean).
   - `wiki/overview.md` — big picture + current phase, derived from `docs/Architecture.md`.
   - `wiki/glossary.md` — seed with the project's domain terms.
   - `wiki/log.md` — a bootstrap entry: `[<ts>] init: created wiki skeleton`.
4. Install the docs→raw hook: copy `${CLAUDE_PLUGIN_ROOT}/templates/core/scripts/sync_raw_mirror.sh` → project `scripts/sync_raw_mirror.sh` (`chmod +x`), then MERGE `${CLAUDE_PLUGIN_ROOT}/templates/core/claude-settings-hook.json`'s `hooks` block into the project's `.claude/settings.json` (create the file if absent; if a `PostToolUse` array exists, append the matcher, do not overwrite). Drop the `_strata_note` key when merging.
5. Hand the wiki population to `/strata:wiki-ingest` for `raw/Architecture.md` and `raw/ADR-Lean.md` (do not hand-write deep entity pages here).

## Phase 4 — Skip-list trimming (§9)

For a tiny project (single file of logic, throwaway prototype, <2 weeks expected life), explicitly drop: `raw/`+`wiki/` (Phase 3), the Phase status table in CLAUDE.md, and the full service skeleton — leave `src/<slug>/main.<ext>` + `tests/`. Record what was skipped and why in the final report so it's a conscious choice, not an omission.

## Phase 5 — VERIFY (do not skip; evidence before assertion)

Run these and paste the observed output:

1. Smoke test green — `verify`: run the stack test command (e.g. `pytest -q` / `npm test`), confirm exit 0.
2. Pre-commit guard works — `verify`: `git add -A && sh scripts/pre-commit/check_secrets.sh` exits 0 on clean tree.
3. Manifests parse — `verify`: `python -c "import tomllib,sys; tomllib.load(open('pyproject.toml','rb'))"` (or `node -e "require('./package.json')"`).
4. If Phase 3 ran: `wiki/index.md` exists and a fresh-session question "what's the architecture / where does X live" is answerable from `wiki/` alone — spot-check it.
5. Make the first commit. If any verify fails, FIX before committing; never claim success on red. If a verify is impossible here (e.g. CI can only run on push), say so explicitly.

## Phase 6 — Hand off

- Commit with a clear message; show the tree.
- Suggest next steps: `/strata:audit` to confirm zero drift on a fresh repo, then `/strata:feature` to build the first feature through the full flow.
- If a stack pack was missing, remind the user that stack-specific tooling/CI is theirs to complete.
