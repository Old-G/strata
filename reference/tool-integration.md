# Strata Tool Integration — the TOKEN-ECONOMY layer

Strata's fourth layer is **token economy**: keeping long sessions cheap and
context-dense. Strata does **not bundle** the tools that do this work. It
**declares** them, composes them, and degrades gracefully when they're absent.
Every tool below is **machine-global** — installed once on the developer's
machine (or their Claude Code config), not vendored into the repo and not a
Strata dependency. Strata detects what's present and adapts.

This separation is intentional: bundling someone else's globally-installed tool
into every repo would mean version skew, double-installs, and licensing drift.
Strata's posture is "rely on it if it's here, work without it if it isn't."

---

## claude-mem — episodic memory + smart-Read

**What it does.** Captures observations across sessions into a persistent,
searchable memory store, and offers "smart" structural reads (`smart_search`,
`smart_outline`, `smart_unfold`) so the agent can navigate code without slurping
whole files into context.

**How Strata relies on it.** Strata's KNOWLEDGE layer is `wiki/` — *durable,
curated, human-reviewed* facts (formulas, schemas, ADRs). claude-mem is
*episodic and automatic* — "what did we do last Tuesday," "have we hit this bug
before." The rule that keeps them from fighting:

> **Never double-store.** Curated, long-lived knowledge goes in `wiki/`.
> Session-by-session episodic recall belongs to claude-mem. If a fact graduates
> from "we learned this once" to "this is canonical," it moves *into* the wiki
> and stops being just an observation.

**The third memory — Claude Code auto memory.** Claude Code keeps its own notes per
project under `~/.claude/projects/<project>/memory/`: a `MEMORY.md` index (the first
200 lines / 25 KB load every session) plus one-fact files opened on demand. It is
*personal, per-machine and unversioned* — like claude-mem it is the wrong home for a
canonical fact. Same rule, third store: if something surfaces there twice, or a
teammate would need it, it moves into `wiki/`; if it is a lesson about how to work
here, it climbs the promotion ladder in `WIKI.md` instead.

When claude-mem is present, Strata prefers its smart-Read over full-file Reads
for exploration, and queries its memory before re-deriving something from
scratch. When it's absent, Strata falls back to plain Read/Grep/Glob and the
wiki alone — slower context-building, same correctness.

**Declared, not bundled.** Installed as a Claude Code plugin globally. Strata
checks for the `claude-mem` MCP search tools and uses them if available.

---

## RTK (Rust Token Killer) — command-output compaction

**What it does.** A **Bash PreToolUse hook** that transparently rewrites shell
commands to route through `rtk`, which compacts noisy command output (build
logs, test runs, git status) before it ever reaches the context window —
typically 60–90% savings on dev operations, at zero added tokens for the rewrite
itself.

**How Strata relies on it.** Strata assumes that if RTK is installed and hooked,
verbose Bash output is already being compacted, so its commands and skills don't
need to add their own `| head`/`| tail` truncation. Strata declares RTK in its
recommended setup but never invokes `rtk` directly in committed scripts.

**Gotcha — the path-form blind spot.** The hook rewrites *recognized command
prefixes* (e.g. `git`, `npm`, `pytest`, `uv run …`). It does **not** rewrite a
**path-form** invocation like `.venv/bin/pytest` — that runs raw and floods the
context. Mitigations Strata documents:

- Prefer `uv run pytest` (or `poetry run pytest`) over `.venv/bin/pytest`.
- Or add the path form to RTK's `transparent_prefixes` config so the hook
  catches it.

**Declared, not bundled.** RTK is a globally-installed binary plus a hook in the
user's Claude Code settings. Strata neither ships the binary nor edits the hook.

---

## Superpowers — the PROCESS skills Strata wraps

**What it does.** Provides the disciplined-workflow skills: `brainstorming`,
`writing-plans`, `executing-plans`, `test-driven-development`,
`systematic-debugging`, `requesting-code-review`, `verification-before-completion`,
and more.

**How Strata relies on it.** Strata's PROCESS layer **wraps** these rather than
reimplementing them. `/strata:feature` and `/strata:autoplan` lean on
Superpowers' brainstorming and plan-writing to produce the plan/design doc that
the **review council** then pressure-tests; TDD and code-review skills carry the
implementation. Strata adds the council and the structure/knowledge layers
*around* Superpowers — it does not replace it.

**Declared, not bundled.** Superpowers is installed globally as its own plugin.
Strata expects its skills to be invocable and composes with them; if absent,
Strata's commands degrade to running the council against whatever plan exists.

---

## Caveman — optional prose compression (low priority)

**What it does.** Compresses prose/instructions into a terser form to shave
tokens. Realistic effect is modest: roughly **4–10% overall session savings**.

**How Strata relies on it.** It mostly doesn't. Caveman is **opt-in and low
priority** — listed for completeness in the token-economy layer. The bigger wins
(claude-mem smart-Read, RTK output compaction) come first; Caveman is a
marginal extra for users who want every percent.

**Declared, not bundled.** Globally installed, opt-in. Strata never assumes it's
present and never depends on its output format.

---

## Archify — the DIAGRAM layer's renderer

**What it does.** An agent skill plus a dependency-free Node CLI (`node
~/.claude/skills/archify/bin/archify.mjs`, Node ≥ 18, MIT). The agent authors a typed
JSON IR (components, connections, boundaries, ≤ 12 primary nodes); `validate` runs nine
fail-closed artifact checks and `deliver` compiles one self-contained HTML (≈0.8 MB, fonts
embedded, works offline) with search, focus, relationship tracing and PNG/SVG/WebM export
in the viewer. With `meta.repository {url, revision}` and `components[].sources[]`,
`--repo-root` verifies every pin against the blob at that commit and fails with a stable
rule code (`repository-evidence/file-missing`, `line-out-of-range`,
`revision-unavailable`). `compare base.json head.json` yields per-kind change counts and
a `semanticSha256` that ignores presentation.

**How Strata relies on it.** `wiki/diagrams/<name>.architecture.json` is canonical and
tracked; `<name>.html` is the current render, tracked; dated JSON snapshots land in
`history/` only when the semantics changed; history HTML is never committed.
`scripts/diagram_check.sh` (installed by `init`/`adopt`, re-synced by `upgrade`) runs in
`light-finish` step 5 and `audit` Phase 2: pinned paths ∩ the branch diff, plus — when
archify is present — a re-pin-to-`HEAD` validate. Findings become `wiki_debt`, which the
Stop gate already enforces; the refresh itself is the agent's work through the archify
skill. A diagram is a human artifact and never a gate: a stale one is a debt item and an
`audit` finding, not a refused commit. Never call archify from a hook; set
`ARCHIFY_UPDATE_CHECK_DISABLED=1` wherever Strata invokes it so no script touches the
network. `meta.repository.url` comes from `git remote get-url origin`; GitHub and Gitee
get `link_mode: web`, any other forge `local-only` (SRC markers without hyperlinks).

**Diagram JSON contract (Archify 3.x; also valid on 2.x).** Every Strata diagram carries
`meta.output: "wiki/diagrams/<name>.html"` (required since 3.0 — `validate` fails the schema without
it) and **no `meta.viewBox`**: an explicitly declared canvas is held to 3.0's desktop-readability
floor (8 px labels must stay ≥ 6 px at 1440×900, i.e. ≤ 1240 px wide), while an omitted one is sized
by the renderer and passes. For `local-only` forges `meta.repository.url` is the origin **exactly** as `git remote get-url
origin` prints it — Archify compares it verbatim and resolves no SSH host aliases (GitHub and Gitee
normalise `.git` and HTTPS/SSH). `meta.views` is accepted but ignored since 3.0 (guided views were removed). Strata renders
with `deliver` (works on 2.x and 3.x); 3.x `finalize` adds a browser check and is optional. Both
write receipts beside the HTML (`<name>.delivery.json`, transient `*.delivery-pending.json` /
`*-lock.json`, and with `finalize` also `*.finalize*.json`, `*.browser-check.json`): put their summary in the `wiki/log.md` line, then
delete them — they are run evidence, never committed (the gitignore template lists them).
`diagram_check.sh` prints `pins NOT verified` when Archify fails before checking pins (a schema
error, an unreadable result) and `pins hold, but archify's quality check failed` when only a later
gate failed (3.0's desktop-readability) — either way the diagram owes a repair for the installed
Archify, made by the next branch close. Checked against 3.0.1 on 2026-10-01.

**Declared, not bundled.** Install once per machine: `npx skills add tt-a1i/archify -g -a
claude-code -s archify -y` (the skills CLI writes to `~/.claude/skills/archify`;
`ARCHIFY_BIN` overrides the path). Absent, `diagram_check.sh` still runs its git half and
prints one skip line; the render waits for a machine that has it.

---

## claude-api evals — the EVIDENCE for LLM-behaviour changes

Claude Code's bundled `claude-api` skill ships `/claude-api build-eval` (cases from production
data, graders, a train/test split, a runner scaffold) and `/claude-api hillclimb` (one structural
change per round; revert on regression or on train-up/test-flat). Results live in the target repo
under `.claude/hillclimb/<flow>/` (`summary.json`, `trajectory/scores.tsv`, `_state.json`).
Verified present in Claude Code 2.1.283 (the skill's subcommand list also has `prompt-audit` and
`cost-optimize`). Strata's stance: **delegate, never rebuild** — Strata's own routing-eval
harness (v0.7.0) was removed the day it shipped. `feature`'s evidence floor and
`strata-diff-review` point here via `reference/llm-evals.md`; for apps on another provider the
project's own harness is the default, since the skill steers away from non-Claude code when it
triggers on its own.

## Whiteboard (dev.fast) — optional viewer, not a dependency

**What it is.** [devdotfast/whiteboard](https://github.com/devdotfast/whiteboard) — an MIT
desktop app (a Code-OSS fork) where an agent draws an RFC-style review of a branch on a canvas:
prose, sequence/flow diagrams, call-stack diffs, code peeks, every node linked to the code at a
pinned revision; plus a semantic AST diff and a trace store for agent sessions.

**What Strata took, and what it did not.** P5 borrowed two of its ideas and none of its code:
the `Agent-Session:` commit trailer that ties a commit to the session that made it
(`reference/agent-session-trailer.md`, local transcripts only — Strata uploads nothing), and
file lenses + "decided, not asked" in `strata-diff-review`. Its hosted/S3 trace store and the
app itself stay out: Strata is glue. If a developer has Whiteboard installed, its MCP tools are
simply another way to *look* at a branch that Strata already reviewed — nothing in Strata calls
it, detects it, or depends on it.

---

## Summary

| Tool | Layer role | Savings | Strata's stance | Bundled? |
|------|-----------|---------|-----------------|----------|
| claude-mem | episodic memory + smart-Read | large (context navigation) | rely-if-present; never double-store with wiki | no — global |
| RTK | Bash output compaction | 60–90% on dev ops | assume hook handles verbosity; watch path-form | no — global |
| Superpowers | PROCESS skills | n/a (workflow) | wrap, don't replace | no — global |
| Caveman | prose compression | ~4–10% | optional, low priority | no — global |
| Archify | diagram layer renderer + pin verifier | n/a (human artifact) | rely-if-present; never a gate, never from a hook | no — global skill |
| claude-api evals | build-eval + hillclimb for LLM-behaviour evidence | n/a (evidence) | delegate; paid runs are the owner's call, never CI by default | no — bundled with Claude Code |
| Whiteboard | branch-review canvas (optional viewer) | n/a (human artifact) | ideas borrowed (P5); never called or detected | no — desktop app |

The global tools above are **install-once, machine-global** (the `claude-api` evals ship inside Claude Code itself). Strata composes them; it does not
ship them.
