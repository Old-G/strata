---
title: SessionStart injection (A3)
type: entity
created: 2026-08-15
updated: 2026-09-01
links: [enforcement-layer, native-invocation, pending-ingest-marker, branch-state, upgrade-path]
---

# SessionStart injection (A3)

## TLDR

`scripts/hooks/strata_session_start.sh` — a `SessionStart` hook whose stdout becomes model
context, so every session opens knowing the branch, the pending ingest list, and the head of
the wiki index.

## Role

Solves "every session starts with the right context" deterministically, instead of hoping the
model reads `CLAUDE.md` carefully. It is also the delivery vehicle for the routing map that
makes [[native-invocation]] reliable — the model sees how to route before it sees the request.

## Current solutions

**Shipped in v0.4.0** as `scripts/hooks/strata_session_start.sh` (measured output: 34 lines).
Fixed token budget of roughly 30–50 lines — this text is paid for on every
single session, so it stays small by design:

```
## Strata context
Branch: <branch> · Last wiki log: <last 3 lines of wiki/log.md>
Pending ingest: <list or "none">
Wiki index head: <first ~20 TLDR lines of wiki/index.md>
Rule: answer project questions from wiki/ first.
```

Bash only, no dependencies. Shipped in `templates/core/scripts/hooks/` and installed into the
target project's `.claude/settings.json` by `init` / `adopt`.

Boundary rule carried over from the brief's research digest: Claude Code's own per-repo Auto
Memory (`MEMORY.md`) is the model's private scratch preferences; `wiki/` is reviewed project
truth. Never duplicate a fact across the two.

**v0.7.0:** one more conditional line — if `.strata/guard-tests` survives into a new session
(a fix left the [[pre-tool-guard]]'s test-file toggle behind), say so up front, or every test
file is read-only for reasons nobody remembers.

**Two additions, shipped in v0.5.0:** if the current branch has a [[branch-state]] file, prints
its summary (goal, status, decision/open-question/`wiki_debt` counts) — the "here's what we
already knew" half of the episodic layer, complementing the Stop gate's "don't let it go stale"
half. Separately, if `.strata/version` disagrees with the plugin actually running
(`$CLAUDE_PLUGIN_ROOT`'s own `plugin.json`), prints one line pointing at [[upgrade-path]]. Both
additions stay inside the existing budget (`MAX_INDEX_ROWS` trimmed 20→15 to make room).

## Related

[[enforcement-layer]] · [[native-invocation]] · [[pending-ingest-marker]] · [[stop-gate]] ·
[[branch-state]] · [[upgrade-path]]

## Sources

[[vnext-brief]] §2 (A3), §4 · [ADR #1](../decisions/adr-1-deterministic-enforcement.md) ·
[[episodic-state-layer]]
