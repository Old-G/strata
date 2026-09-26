---
title: "P5 — Provenance: Agent-Session trailers, 'why is this code here', a diff review that reads like a reader (spec + plan)"
type: source
source: raw/superpowers/specs/2026-09-26-p5-provenance.md
created: 2026-09-26
updated: 2026-09-26
links: [agent-session-trailer, diff-review, stop-gate, friction-capture, diagram-layer, branch-state]
---

# P5 — Provenance

Sources: [spec](../../raw/superpowers/specs/2026-09-26-p5-provenance.md) ·
[plan](../../raw/superpowers/plans/2026-09-26-p5-provenance-plan.md) · status: council-approved
(cso + eng, approve-with-concerns, folded in) and implemented 2026-09-26 on
`strata/p5-provenance`, shipping as v0.9.0.

## Summary

[devdotfast/whiteboard](https://github.com/devdotfast/whiteboard) (v0.1.3, MIT) read against
v0.8.1. It is a desktop app — a vendored Code-OSS fork, a Rust AST diff, a hosted trace store —
and none of that belongs in Strata. Its thesis does: **the bottleneck is no longer writing the
change but understanding it** — what the agent built, why, and which choices it made alone. Two
of its mechanisms landed on plumbing Strata already had; the app, its trace store and its
semantic diff were explicitly left out (`reference/tool-integration.md` names it as an optional
viewer that Strata never calls).

**The measurement that shaped the design:** Claude Code exports `CLAUDE_CODE_SESSION_ID` to every
Bash tool call, git hooks inherit it, and the transcript is `~/.claude/projects/<dir>/<id>.jsonl`.
So attribution needs no "active sessions" bookkeeping (Whiteboard needs it for five agents): a
commit from inside a session carries its id, a human commit carries nothing. Also measured: git
runs `prepare-commit-msg` for every rebase and cherry-pick pick, so the hook must skip replays or
it stamps the wrong session.

**What shipped:** [[agent-session-trailer]] — the `prepare-commit-msg` hook, `strata_why.sh`
(blame → commit → trailer → transcript), and wiki-ingest QUERY step 4b with evidence rules; and
[[diff-review]] gained file lenses and a "Decided, not asked" table. Decisions D1–D9: on where
wired but asked once (visible in public history), never blocks and never rescues an empty
message, id validated on write *and* read, replays skipped, transcripts local-only and offered
only when the session's recorded `cwd` is inside this repo, the helper mechanical and the reading
the model's, the change-brief deferred.

**Council:** cso found the read side trusted history (forged trailers → glob / prompt-injection
channel / another project's transcript) and that a failing wrapper blocks commits `--no-verify`
cannot bypass; eng found the empty-message rescue, subagent commits carrying the parent id,
squash-merged trailers in the body, worktree paths, and argued to defer lenses. All folded in
except the lenses deferral — kept at the owner's request, recorded as D8.

**T6, found by the feature's own verify run:** running the new diff review over the P4 range
surfaced a real P4 bug in [[stop-gate]] trigger (d) — see [[friction-capture]] — and a stale
pin on the [[diagram-layer]]'s own system picture; both fixed on this branch.

## Open

The change brief (D9: an RFC-shaped write-up at `light-finish`, one rule-picked diagram) is the
next candidate. Unverified: whether `--resume` keeps the session id — harmless either way, since
the exported id and the transcript filename agree.
