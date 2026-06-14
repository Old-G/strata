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

## Summary

| Tool | Layer role | Savings | Strata's stance | Bundled? |
|------|-----------|---------|-----------------|----------|
| claude-mem | episodic memory + smart-Read | large (context navigation) | rely-if-present; never double-store with wiki | no — global |
| RTK | Bash output compaction | 60–90% on dev ops | assume hook handles verbosity; watch path-form | no — global |
| Superpowers | PROCESS skills | n/a (workflow) | wrap, don't replace | no — global |
| Caveman | prose compression | ~4–10% | optional, low priority | no — global |

All four are **install-once, machine-global**. Strata composes them; it does not
ship them.
