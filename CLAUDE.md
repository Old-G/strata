# Strata

Claude Code plugin that packages a reusable way to run AI-assisted projects: AI-navigable wiki,
architecture canon, spec→plan→TDD feature flow, a parallel review council, and drift detection with
staged refactor. **State:** v0.6.0 — deterministic wiki freshness (hook + commit gates), native
command-free invocation, and an episodic branch-state layer with a hook-driven upgrade path so
gates re-sync into repos adopted before they existed. This repo dogfoods its own patterns,
including its own `wiki/` and gates.

## Phase / status

| Checkpoint | Status |
|---|---|
| Plugin installs (`plugin.json` + `marketplace.json` valid) | 🔄 building |
| Entry skill `using-strata` routes to all commands | ✅ |
| Skills: init / adopt / audit / refactor / feature / office-hours / autoplan / wiki-ingest / onboard / lean-plan / light-finish / upgrade | 🔄 building |
| One-line AI-led onboarding (BOOTSTRAP.md + install.sh + /strata:onboard) | ✅ verified end-to-end |
| Adaptive ceremony in /strata:feature (triage + tiers + effort + lens-selected council) | 🔄 building |
| Council subagents (ceo / eng / design / cso) | 🔄 building |
| Enforcement layer (A1 Stop gate · A2 commit gate · A3 SessionStart inject · A4 drift-close) | ✅ 28/28 behavioural tests green |
| Native invocation — EN+RU trigger specs on all 13 skills, routing map, coordinator | ✅ enforced by validate.sh |
| This repo runs its own wiki pipeline (`wiki/` + `raw/` + gates) | ✅ bootstrapped 2026-08-15 |
| Templates: core + python-fastapi stack pack | ✅ seeded from a production project, genericized |
| Episodic state layer (`.strata/state/`) + Stop-gate trigger (c) + SessionStart summary | ✅ `test_p2_state.sh` green |
| `/strata:upgrade` — re-syncs `scripts/**` into repos adopted before this version | ✅ fixes the confirmed no-gates-installed case |
| Verified by adopting a real external project | ⬜ pending (user will test elsewhere) |

## Stack

Claude Code plugin · Markdown skills + subagents · bundled shell/python templates · no runtime deps · MIT

## Layout

- `.claude-plugin/` — `plugin.json` (manifest) + `marketplace.json` (this repo is its own marketplace).
- `skills/<name>/SKILL.md` — one skill per command; invoked as `/strata:<name>`. `using-strata` is the entry/router.
- `agents/strata-*-review.md` — the parallel review council subagents.
- `templates/core/` — portable assets: `PROJECT_PATTERN.md`, `WIKI.md`, `wiki/` skeleton, `scripts/`, CLAUDE/ADR templates.
- `templates/stacks/<stack>/` — per-stack architecture canon (`SCALABLE_ARCHITECTURE_REFERENCE.md`) + scaffold generator.
- `reference/` — council personas, Diataxis doc-map, tool-integration (RTK / claude-mem / Caveman).
- `templates/core/scripts/` — installed per target project: `sync_raw_mirror.sh`, `lib/pending_ingest.sh` (the one marker rule), `lib/state_tools.py` (the episodic-state schema/validator), `hooks/` (SessionStart + Stop), `pre-commit/` guards, `strata_upgrade_check.sh` (re-sync diff reporter, backs `/strata:upgrade`).
- `docs/superpowers/{specs,plans}/` — Strata's own design specs & plans (dated).
- `raw/`, `wiki/` — this repo's own knowledge layer; `.githooks/` — its own pre-commit guards.

## Commands (dev)

```bash
# develop locally against any test project
claude --plugin-dir /Users/glebzavalov/Desktop/Projects/strata
/reload-plugins                          # after editing skills/agents

# validate everything (manifests, skills, gates behaviour)
bash scripts/validate.sh
bash scripts/test_p1_gates.sh            # 28 behavioural assertions on A1/A2/A3
bash scripts/test_p2_state.sh            # state schema/validator, Stop-gate trigger (c), upgrade check

# enable this repo's own guards once per clone
git config core.hooksPath .githooks

# reference bundled assets from inside a skill at runtime
#   ${CLAUDE_PLUGIN_ROOT}/templates/core/...
```

## Workflow

Routing — say what you want in plain language (RU or EN); no commands to memorize:

```
build / change request        → feature flow (triage first)
question about the project    → wiki query (wiki/index.md first, never grep-first)
"done / wrap up / merge"      → light-finish (includes drift-close)
"messy / check it / drift"    → audit
raw or risky idea             → office-hours grill
```

- Plan mode → approval → execute. No silent changes.
- Skill files are the product: keep each `SKILL.md` focused; push long detail into a `sections/` subfile or `reference/`.
- Bundled template paths are referenced via `${CLAUDE_PLUGIN_ROOT}` — never hardcode absolute paths in skills.
- Dogfood: run `/strata:audit` on this repo before tagging a release.

## Hard rules

- **Strata is thin glue.** Do not reimplement memory (claude-mem), token-proxying (RTK), or testing. Compose them.
- **Skills never hand-edit a target project's `raw/`** — it is a mirror of `docs/`.
- **The plugin ships NO global hooks.** Every hook (PostToolUse mirror, SessionStart injection, Stop gate) and every pre-commit guard is a *template* installed into the target project by `init`/`adopt`, so the plugin stays inert in unrelated repos.
- **One marker rule, one implementation.** Anything asking "does the wiki owe an ingest?" sources `scripts/lib/pending_ingest.sh`. Gates that disagree about what pending means are worse than no gates.
- **Gates must be escapable and self-limiting.** The Stop gate blocks at most once per session and fails open when unsure; the commit gate honours `STRATA_SKIP_WIKI=1`.
- **Skill/command names are namespaced** `/strata:<name>` — do not prefix skill dirs with `strata-` (the namespace already adds it). Subagents in `agents/` DO keep the `strata-` prefix to avoid collisions in target projects.
- **CLAUDE.md ≤ 200 lines** here and in every template.
