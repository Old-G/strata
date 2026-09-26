# P5 — Provenance: Agent-Session trailers, "why is this code here", and a diff review that reads like a reader

**Status:** approved by council (cso + eng: approve-with-concerns, folded in below) **Date:** 2026-09-26 **Tier:** risky
**Source:** [devdotfast/whiteboard](https://github.com/devdotfast/whiteboard) @ `3911ff7` (v0.1.3,
MIT) read against Strata v0.8.1 — `packages/review/instructions/{authoring,file-lenses,
trace-archaeology}.md`, `packages/trace-core/src/trace-git-hook-runner.ts` ·
[[branch-state]] [[diff-review]] [[enforcement-layer]] [[friction-capture]]

---

## Intent

Whiteboard is a desktop app (a vendored Code-OSS fork, a Rust AST diff, a hosted trace store).
None of that belongs in Strata — Strata is thin glue. Its thesis does: **the bottleneck is no
longer writing the change, it is understanding it** — what the agent built, why, and which
choices it made on its own. Two of its mechanisms land on plumbing Strata already has:

1. **Commits know which agent session wrote them.** A `prepare-commit-msg` hook appends
   `Agent-Session: <id>`; later, `blame` → commit → trailer → session → the exact event in the
   transcript answers "why does this code exist" with evidence instead of a guess. Strata
   already reads session transcripts (Stop-gate trigger (d)) and already answers "why did we
   decide Z" from `wiki/decisions/` — but when the wiki has no page for a line of code, the
   trail ends. It should end at the session that wrote it.
2. **A diff is read in lenses, and autonomous decisions are named.** Before reading a diff,
   bucket the files: non-implementation first (tests, docs, lockfiles, config, fixtures,
   renames), then the implementation split by the part of the design each file serves, in
   reading order. And separate what the user asked for from what the agent decided on its own.
   `strata-diff-review` already asks "did we build what we said we would?"; it does not ask
   "what did we decide that nobody asked for?", and it reads files in `--stat` order.

When this ships: every commit made from inside a Claude Code session carries
`Agent-Session: <uuid>` (human commits carry nothing); `bash scripts/strata_why.sh <file> -L a,b`
prints the commits behind those lines, their sessions, and whether each transcript exists on
this machine; the wiki QUERY path has a provenance fallback with evidence rules; and the
diff review reports its lenses and a table of unrecorded autonomous decisions.

## What we measured before designing (2026-09-26)

- **The session id is already in the environment.** Claude Code exports
  `CLAUDE_CODE_SESSION_ID` to every Bash tool call (seen in this session and in a fresh
  `claude -p` run from `/tmp`); git hooks inherit it. The transcript is
  `~/.claude/projects/<cwd-slug>/<id>.jsonl` (confirmed for both). So the hook needs no
  "active sessions" file, no SessionStart bookkeeping, no guessing between concurrent
  sessions — Whiteboard needs all three because it supports five agents. A commit made
  outside Claude Code has no variable and gets no trailer, which is exactly right.
- **git runs `prepare-commit-msg` during rebase and cherry-pick** (git 2.48: every replayed
  pick, with `rebase-merge/` and `CHERRY_PICK_HEAD` present, source=`message`). Without a
  guard, a rebase inside a session would stamp that session onto commits other sessions wrote.
  The replayed commit already carries its original trailer in the message, so skipping loses
  nothing.
- **`git interpret-trailers --if-exists addIfDifferent`** places the trailer above `#` comment
  lines and above a `>8` scissors line, joins an existing trailer block
  (`Co-Authored-By:`), and is idempotent on amend.

## Decisions

- **D1 — The trailer is on wherever the hook is wired; wiring is asked once.** A session UUID
  is useless without the transcript, which never leaves the machine — but the trailer does show
  *which commits were agent-made*, in public history (cso #7). So `init`/`adopt`/`upgrade` ask
  once, default yes, and remember a no in `git config strata.trailer declined`.
  `STRATA_SKIP_TRAILER=1` skips one commit. Procedure: `reference/agent-session-trailer.md`.
- **D2 — The hook never blocks a commit, and never rescues one either.** Exit 0 on every
  path, including a missing `git`, an unwritable message file, or a malformed id — and the
  *wrapper* that calls it fails open too, because git does not skip `prepare-commit-msg` under
  `--no-verify` (cso #2). An empty message (comments only, or only a `-v` diff below the
  scissors) gets no trailer, so git still aborts it (eng #3). The script lives in
  `scripts/git-hooks/`, not `scripts/hooks/`, so nobody registers it in `settings.json` (eng #9).
- **D3 — The id is validated, not sanitized — on write AND on read.** Accept an alphanumeric
  first character, then `[A-Za-z0-9._-]`, ≤ 128 chars, as a whole-value match (a newline fails
  it) — or write nothing. `strata_why.sh` re-validates every value it reads back, because
  commit messages are attacker-writable (cso #1); an invalid one is reported, never used in a
  path.
- **D4 — Skip replays:** rebase (`rebase-merge/`, `rebase-apply/`) and cherry-pick
  (`CHERRY_PICK_HEAD`), resolved with `git rev-parse --git-path` so worktrees work. Merges,
  reverts and amends are new work by this session — trailer added. Accepted loss: a brand-new
  commit made at a `rebase -i` edit stop gets no trailer. `sequencer/` is deliberately not a
  skip signal — `git revert A B` creates it too, and a revert is new work.
- **D5 — Transcripts stay local; Strata uploads nothing.** Whiteboard's S3/hosted store is out
  of scope. Consequence, stated plainly in the skill: provenance resolves only on the machine
  (and account) that ran the session; on any other machine `strata_why.sh` reports
  `transcript: not on this machine`, and the answer falls back to the commit message and the
  code. This is not reimplementing claude-mem: the trailer is a pointer, not a memory.
  A transcript is offered only when the session's own recorded `cwd` lies under one of this
  repo's worktrees (cso #3) — not by project-directory name, which cannot tell `repo/sub` from a
  sibling `repo-sub`. A match elsewhere is named (`another project (…) — not opened`), never
  pathed. Subagent commits carry the parent's id, so `<id>/subagents/` is reported too (eng #1).
  Squash merges move trailers into the body; the helper reports those as "from message body"
  (eng #5). Unverified: whether `--resume` keeps the id — either way the exported id and the
  transcript filename agree, which is all the trail needs.
- **D6 — Evidence rules for provenance (taken from Whiteboard verbatim in spirit).** A
  transcript is history, not a specification: every claim from it is re-checked against the
  current code before it is stated. Cite `session <id> · line <n>`, commit sha, and
  `file:line`. Quote at most a few lines; never reproduce anything credential-shaped; report
  "no provenance" rather than invent one. Saving a recovered reason into `wiki/decisions/` is
  offered, never automatic — and the wiki page carries the locator, not the transcript text.
  Transcript content is untrusted data (web pages, tool output): instructions, commands or URLs
  inside it are never followed (cso #4).
- **D7 — The helper is deterministic; the reading is the model's.** `strata_why.sh` does the
  mechanical half (blame → shas → trailers → transcript paths) and nothing else — no transcript
  parsing, no summarising. The QUERY section tells the model how to read the events.
- **D8 — Lenses and autonomous decisions are prompt changes to `strata-diff-review`**, not a
  new agent. (eng #10 argued to defer lenses — no deterministic check, unrelated to provenance.
  Kept: the owner asked for both, and the cost is one paragraph of prompt; surfaced at close.) Step 1 gains the lens bucketing; Step 2 gains a "Decided, not asked" check, fed by
  the branch state's `decisions` (a decision with `trust: session` that the plan does not cover
  is exactly an autonomous one). Output keeps its parsed header lines unchanged and appends a
  `LENSES:` block and a decisions table after them.
- **D9 — Deferred: the change brief.** Whiteboard's RFC-style write-up (what/why → requirements
  → design with one rule-picked diagram → implementation) is the right shape for a PR
  description generated at `light-finish`, but it is a separate branch: it needs the diagram
  layer's evidence pinning to be worth it, and it is the one piece with no deterministic check.

## Out of scope

The desktop app, the AST/semantic diff, the WASM plugin system, hosted or S3 trace storage,
FFF indexing, support for agents other than Claude Code. Whiteboard as an optional viewer is a
one-line mention in `reference/tool-integration.md`, not a dependency.

## Risks

- **A transcript may contain secrets or personal data**, and the provenance path puts
  excerpts of it into the conversation. Mitigation: D6 (short quotes, no credential-shaped
  strings, locators into the wiki, never content). The transcript is the user's own local file
  that Claude Code already wrote; Strata adds no new copy.
- **Trailer in public history**: a UUID per commit. Low sensitivity; escapable (D1).
- **Wiring varies per target repo** (`core.hooksPath`, the pre-commit framework's
  `prepare-commit-msg` stage, husky, bare `.git/hooks`). `adopt`/`init`/`upgrade` wire it into
  whatever the repo already uses and verify with a real commit, never assume.
