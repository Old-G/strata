---
title: Session handoff (/strata:handoff)
type: entity
created: 2026-09-27
updated: 2026-09-27
links: [branch-state, stop-gate, native-invocation]
---

# Session handoff (/strata:handoff)

## TLDR

`skills/handoff/SKILL.md` — when the context window fills up, save the session into a file the
next session starts from, then stop. The session-level form of the pass handoff `feature` already
asks for ("Hand off, don't hope").

## Role

Answer quality decays as context fills, and auto-compact keeps a lossy summary inside the same
tired session. The handoff replaces both with a fresh session that reads one file. It works in any
repo; in a Strata repo it also closes wiki drift first, so the knowledge layer does not fall behind
at exactly the moment the session is cut.

## Current solutions

**Shipped in v0.10.0.**

- **Drift-close, knowledge half only:** pending ingests, one `wiki/log.md` line, the
  [[branch-state]] file's decisions/gotchas/`wiki_debt` updated — never deleted (the branch is not
  closed), no diagram refresh (that stays as debt). Out of budget → the doc becomes debt.
- **Commits only verified work**, by the project's own conventions; red/unverified work stays in
  the working tree and is listed. Push only when the project's rules and the user both allow it.
- **The file:** `<root>/.claude/handoff/handoff-${CLAUDE_SESSION_ID}.md`, kept out of git via
  `$(git rev-parse --git-path info/exclude)` (no tracked file changes), newest 10 kept. Fixed
  frontmatter (`type: strata-handoff`, session, created, workspace, branch, head, pushed) and fixed
  `##` headings; `## Prompt` holds exactly one fenced block — the new session's whole first
  message. Tools (e.g. Orca) parse these, so they are a contract.
- **Trigger:** plain language (EN+RU), or the context gate `bin/strata-context-gate` — a `Stop`
  hook that blocks once per session past `STRATA_HANDOFF_PCT` (default 60%) of the window and asks
  for the skill. Not registered by the plugin ([ADR #1](../decisions/adr-1-deterministic-enforcement.md):
  no global hooks): the user adds it to `~/.claude/settings.json`
  ([reference/context-gate.md](../../reference/context-gate.md)). Hooks do NOT see the plugin's
  `bin/` on `PATH` (0.10.0 assumed they did and its by-name entry never ran), so the entry runs the
  newest copy in the plugin cache and follows updates with no settings change. Window: 1M for `[1m]` models or past 200k, else 200k
  (the hook input names no model). SDK chats report `CLAUDE_CODE_SESSION_ATTENDED=0` like
  `claude -p`, so "unattended" sessions are gated too.
- **Not a delegation:** handing work to another agent/worktree is a different skill (routing
  checked: «передай эту задачу другому агенту в соседнем worktree» → `orca-cli`).

## Related

- [[branch-state]] — where the handoff leaves decisions for the next session's SessionStart summary.
- [[stop-gate]] — the other Stop-time mechanism; a context gate would block once, like it.

## Sources

- `skills/handoff/SKILL.md`, `bin/strata-context-gate`, `reference/context-gate.md`; CHANGELOG `[0.10.0]`.
