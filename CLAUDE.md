# Strata

Claude Code plugin that packages a reusable way to run AI-assisted projects: AI-navigable wiki,
architecture canon, spec→plan→TDD feature flow, a parallel review council, and drift detection with
staged refactor. **State:** v0.2.0 — AI-led onboarding shipped. This repo dogfoods its own patterns.

## Phase / status

| Checkpoint | Status |
|---|---|
| Plugin installs (`plugin.json` + `marketplace.json` valid) | 🔄 building |
| Entry skill `using-strata` routes to all commands | ✅ |
| Skills: init / adopt / audit / refactor / feature / office-hours / autoplan / wiki-ingest / onboard | 🔄 building |
| One-line AI-led onboarding (BOOTSTRAP.md + install.sh + /strata:onboard) | ✅ verified end-to-end on v0.2.0 |
| Council subagents (ceo / eng / design / cso) | 🔄 building |
| Templates: core + python-fastapi stack pack | ✅ seeded from a production project, genericized |
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
- `docs/superpowers/{specs,plans}/` — Strata's own design specs & plans (dated).

## Commands (dev)

```bash
# develop locally against any test project
claude --plugin-dir /Users/glebzavalov/Desktop/Projects/strata
/reload-plugins                          # after editing skills/agents

# validate manifests
python3 -c "import json,sys; json.load(open('.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json')); print('manifests OK')"

# reference bundled assets from inside a skill at runtime
#   ${CLAUDE_PLUGIN_ROOT}/templates/core/...
```

## Workflow

- Plan mode → approval → execute. No silent changes.
- Skill files are the product: keep each `SKILL.md` focused; push long detail into a `sections/` subfile or `reference/`.
- Bundled template paths are referenced via `${CLAUDE_PLUGIN_ROOT}` — never hardcode absolute paths in skills.
- Dogfood: run `/strata:audit` on this repo before tagging a release.

## Hard rules

- **Strata is thin glue.** Do not reimplement memory (claude-mem), token-proxying (RTK), or testing. Compose them.
- **Skills never hand-edit a target project's `raw/`** — it is a mirror of `docs/`.
- **No global PostToolUse hooks shipped by the plugin** — the docs→raw mirror is installed *per target project* by `init`/`adopt` (into that project's `.claude/settings.json`), so the plugin stays inert in unrelated repos.
- **Skill/command names are namespaced** `/strata:<name>` — do not prefix skill dirs with `strata-` (the namespace already adds it). Subagents in `agents/` DO keep the `strata-` prefix to avoid collisions in target projects.
- **CLAUDE.md ≤ 200 lines** here and in every template.
