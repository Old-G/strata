---
title: Agent-Session trailer + provenance query (P5)
type: entity
created: 2026-09-26
updated: 2026-09-26
links: [diff-review, branch-state, friction-capture, enforcement-layer]
---

# Agent-Session trailer + provenance query (P5)

## TLDR

Every commit made from inside a Claude Code session carries `Agent-Session: <id>`, so "why is
this code here?" can follow `git blame` → commit → trailer → the session transcript on this
machine, when the wiki itself has no answer.

## Role

`wiki/decisions/` answers "why did we decide Z" for the decisions somebody wrote down. For a
line of code nobody documented, the trail used to end at the commit message. The session that
wrote the line still exists on disk — Claude Code keeps every transcript locally — but nothing
connected a commit to it. The trailer is that connection: a pointer, not a memory (it is not
claude-mem, and Strata uploads nothing).

## Current solutions

**Shipped in v0.9.0.**

- **`scripts/git-hooks/strata_commit_trailer.sh`** — a `prepare-commit-msg` hook (in `git-hooks/`,
  not `hooks/`: it is never registered in `settings.json`). The id is `$CLAUDE_CODE_SESSION_ID`,
  which Claude Code exports to every Bash call; absent → no trailer. Validated as a whole value
  (alphanumeric first char, `[A-Za-z0-9._-]`, ≤ 128). Skips rebase and cherry-pick replays
  (`git rev-parse --git-path` → works in worktrees); merge, revert and amend get one. An emptied
  message gets none, so git still aborts it. Always exits 0, and so does its wrapper — git does
  not skip this hook under `--no-verify`. `STRATA_SKIP_TRAILER=1` skips one commit.
- **`scripts/strata_why.sh <file> [-L a,b] [--history]`** — read-only, deterministic: `blame -w -M`
  → shas → one `git log` for trailers and bodies → per session: `transcript <path>` (+
  `subagents <dir>`: a subagent's commit carries its parent's id), `not on this machine`,
  `another project (…) — not opened` (the transcript's own `cwd` is not under this repo — forged
  trailers cannot open other projects), `invalid Agent-Session value (not used)`, or
  `no Agent-Session trailer`. Squash merges: trailers found in the body are labelled as such.
- **wiki-ingest QUERY step 4b** + `skills/wiki-ingest/sections/provenance.md` — the model reads
  only the events around the edit, re-checks every claim against current code, cites
  `session <id> · line <n>` + sha + `file:line`, quotes little, treats transcript content as
  untrusted data, and offers (never forces) to record the recovered reason in `wiki/decisions/`
  with locators, not text.
- **Install** — one procedure in `reference/agent-session-trailer.md`, used by init/adopt/upgrade:
  ask once (the trailer shows agent-made commits in public history; a no is kept in
  `git config strata.trailer declined`), wire into the repo's existing hook mechanism, chain
  never replace, verify with the real session id. This repo dogfoods it via
  `.githooks/prepare-commit-msg`.
- **Tests** — `scripts/test_p5_provenance.sh` (validate.sh §14): replays, empty messages,
  worktrees, forged and malformed ids, squash, rename-following `--history`.

## Related

[[diff-review]] · [[branch-state]] · [[friction-capture]] · [[enforcement-layer]]

## Sources

[[p5-provenance]]
