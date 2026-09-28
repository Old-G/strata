# Strata

Claude Code plugin that packages a reusable way to run AI-assisted projects: AI-navigable wiki,
architecture canon, spec→plan→TDD feature flow, a parallel review council, and drift detection with
staged refactor. **State:** v0.13.1 — deterministic wiki freshness (hook + commit gates), native
command-free invocation, an episodic branch-state layer with a hook-driven upgrade path, a
PreToolUse guard (raw/ mirror · tests read-only mid-fix), a diff-vs-plan review at branch close,
a Stop gate that asks for the lesson when a session hurt, a diagram layer (`wiki/diagrams/`,
Archify JSON with commit-pinned sources), and provenance (`Agent-Session:` commit trailers →
`strata_why.sh` → the session that wrote the code). This repo dogfoods its own patterns, including its own
`wiki/` and gates.

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
| Right side of the loop — A5 PreToolUse guard · R1 diff-vs-plan review | ✅ `test_p3_guards.sh` green · `strata-diff-review` wired into light-finish |
| Friction — Stop-gate trigger (d) asks for the gotcha when a session hurt | ✅ `test_p4_friction.sh` green |
| Diagram layer — `wiki/diagrams/` (Archify JSON, commit-pinned sources) + `diagram_check.sh` | ✅ `test_p4_diagrams.sh` green · Strata's own `system` diagram |
| Provenance — `Agent-Session:` trailer (prepare-commit-msg) + `strata_why.sh` + diff-review lenses / "decided, not asked" | ✅ `test_p5_provenance.sh` green · dogfooded via `.githooks/prepare-commit-msg` |
| Verified by adopting a real external project | ⬜ pending (user will test elsewhere) |

## Stack

Claude Code plugin · Markdown skills + subagents · bundled shell/python templates · no runtime deps · MIT

## Layout

- `.claude-plugin/` — `plugin.json` (manifest) + `marketplace.json` (this repo is its own marketplace).
- `skills/<name>/SKILL.md` — one skill per command; invoked as `/strata:<name>`. `using-strata` is the entry/router.
- `agents/strata-*-review.md` — the parallel review council subagents (plan stage) + `strata-diff-review` (branch close, diff vs plan).
- `templates/core/` — portable assets: `PROJECT_PATTERN.md`, `WIKI.md`, `wiki/` skeleton, `scripts/`, CLAUDE/ADR templates.
- `templates/stacks/<stack>/` — per-stack architecture canon (`SCALABLE_ARCHITECTURE_REFERENCE.md`) + scaffold generator.
- `reference/` — council personas, Diataxis doc-map, tool-integration (RTK / claude-mem / Caveman).
- `templates/core/scripts/` — installed per target project: `sync_raw_mirror.sh`, `lib/pending_ingest.sh` (the one marker rule), `lib/state_tools.py` (the episodic-state schema/validator), `hooks/` (SessionStart + Stop + PreToolUse guard), `pre-commit/` guards, `strata_upgrade_check.sh` (re-sync diff reporter, backs `/strata:upgrade`), `diagram_check.sh` (P4 — pinned-source drift check for `wiki/diagrams/`; run by light-finish/audit, never a hook), `git-hooks/strata_commit_trailer.sh` + `strata_why.sh` (P5 provenance — a *git* hook, never registered in settings.json; install: `reference/agent-session-trailer.md`).
- `wiki/diagrams/` — this repo's own diagram layer: `system.architecture.json` (canonical, Archify JSON, sources pinned to a commit) + `system.html` (open it to see the whole plugin); `history/*.json` only when the semantics changed.
- `bin/strata-upgrade-all` — on PATH in every Claude session (plugin `bin/`); `bin/strata-context-gate` — opt-in `Stop` hook the user adds to `~/.claude/settings.json` (asks for `/strata:handoff` past 60% context; hooks don't see plugin `bin/` on PATH, so the entry runs the newest cached copy — `reference/context-gate.md`); `templates/core/scripts.history` — hash of every shipped template version (what auto-sync may safely replace).
- `docs/superpowers/{specs,plans}/` — Strata's own design specs & plans (dated).
- `raw/`, `wiki/` — this repo's own knowledge layer; `.githooks/` — its own pre-commit guards.

## Commands (dev)

```bash
# develop locally against any test project
claude --plugin-dir /path/to/strata
/reload-plugins                          # after editing skills/agents

# validate everything (manifests, skills, gates behaviour)
bash scripts/validate.sh
bash scripts/test_p1_gates.sh            # 28 behavioural assertions on A1/A2/A3
bash scripts/test_p2_state.sh            # state schema/validator, Stop-gate trigger (c), upgrade check
bash scripts/test_p3_guards.sh           # PreToolUse guard: raw/ mirror, tests read-only mid-fix, stale-toggle warning
bash scripts/test_p4_friction.sh         # Stop-gate trigger (d): friction counted from the session transcript
bash scripts/test_p4_diagrams.sh         # diagram layer: state_tools add-debt, diagram_check.sh (archify half runs where installed)
bash scripts/test_p5_provenance.sh       # Agent-Session trailer hook (replays, empty msg, worktrees) + strata_why.sh
bash scripts/test_context_gate.sh        # context gate: once per session, 1M/200k window, sidechain-proof
bash scripts/strata_why.sh <file> -L a,b # which commits/sessions wrote these lines (transcripts stay local)
bash scripts/gen_template_history.sh     # after ANY templates/core/scripts change (auto-sync safety manifest)
bin/strata-upgrade-all [--dry-run]       # sync every Strata project on this machine to this plugin (on PATH in sessions)
bash scripts/diagram_check.sh main       # does a wiki/diagrams/ picture owe an update on this branch?

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
- **The plugin ships NO global hooks.** Every hook (PostToolUse mirror, SessionStart injection, Stop gate, PreToolUse guard) and every pre-commit guard is a *template* installed into the target project by `init`/`adopt`, so the plugin stays inert in unrelated repos. Updates still reach every project: the installed SessionStart hook auto-syncs `scripts/**` from a newer plugin (`--apply-safe`: never a locally edited file), and `bin/strata-upgrade-all` does all projects at once.
- **Changing a skill description changes the routing surface.** Descriptions are the whole routing signal, and other installed plugins compete for the same words — check the change by saying the trigger phrase in a fresh session, not by reading the file.
- **One marker rule, one implementation.** Anything asking "does the wiki owe an ingest?" sources `scripts/lib/pending_ingest.sh`. Gates that disagree about what pending means are worse than no gates.
- **Gates must be escapable and self-limiting.** The Stop gate blocks at most once per session and fails open when unsure; the commit gate honours `STRATA_SKIP_WIKI=1`.
- **Skill/command names are namespaced** `/strata:<name>` — do not prefix skill dirs with `strata-` (the namespace already adds it). Subagents in `agents/` DO keep the `strata-` prefix to avoid collisions in target projects.
- **A verify you ran but did not record did not happen.** Put its result in `wiki/log.md` or the commit message — the branch review reads git, not the session. (Second occurrence: P4 red run, P5 routing check.)
- **Every template change regenerates `templates/core/scripts.history`** (`bash scripts/gen_template_history.sh`; validate.sh §2d fails otherwise) — auto-sync trusts only versions listed there.
- **CLAUDE.md ≤ 200 lines** here and in every template.
