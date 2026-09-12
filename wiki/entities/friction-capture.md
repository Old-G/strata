---
title: Friction capture (Stop-gate trigger d)
type: entity
created: 2026-09-12
updated: 2026-09-12
links: [stop-gate, branch-state, session-reflector, diff-review]
---

# Friction capture (Stop-gate trigger d)

## TLDR

The [[stop-gate]] learns to tell a painful session from a routine one: at `Stop` it counts
interrupts, denied tool calls and tool errors in the session's own transcript, and a session
that crossed a threshold cannot end without a recorded `gotcha` — or an explicit `no-gotcha:`.

## Role

Strata records decisions and wiki debt but not *lessons*, and the reflector's open question
OQ#8 was when to ask for one. TeamAI-CLI's answer, adopted here: only when the session hurt,
and hurt is measurable without an LLM. This is the zero-infrastructure feed for the
second-occurrence rule in [[diff-review]] — a gotcha recorded at the moment it happened is what
`light-finish` later greps `wiki/log.md` for.

## Current solutions

Spec'd in P4 ([[p4-field-patterns]] D1), not yet built. Shape:

- **Signals**, each a `grep -c` over `transcript_path` with `"isSidechain":true` lines dropped:
  `interrupts` = "Request interrupted by user"; `denials` = the user declined a tool call
  ("doesn't want to proceed" and the CLI's equivalents, one pattern variable); `tool_errors` =
  `"is_error":true`. Baseline on this repo's four transcripts: 5 / 10 / 21 in total.
- **Thresholds** `STRATA_FRICTION_INTERRUPTS=1`, `STRATA_FRICTION_DENIALS=2`,
  `STRATA_FRICTION_ERRORS=8`; zero disables a signal, all zero disables the trigger.
- **Fires** only when triggers (a)–(c) did not, at least one signal meets its threshold, and
  nothing was recorded this session (`wiki/log.md` and the branch state unchanged since the
  session stamp). Same one-block-per-session cap as every other trigger.
- **Satisfied** by a `gotchas` entry in `.strata/state/<branch>.json`, or one line
  `gotcha: <what>` / `no-gotcha: <why>` in `wiki/log.md`. When another trigger fires anyway,
  the counts ride along in its reason.
- Runs last, after the cheap checks; budget ≤ 50 ms on a 5 MB transcript; fails open on a
  missing or unreadable transcript. No new hook event — Claude Code exposes no Esc or
  permission-denied event, the transcript is the only deterministic channel.
- Not adopted: TeamAI's "correction within 60 s" keyword heuristic — language-dependent and
  noisy in a bilingual repo.

Tests land as `validate.sh` §12 with synthetic transcripts; delivered to adopted repos by
[[upgrade-path]] since it lives inside the existing Stop-gate script.

## Related

[[stop-gate]] · [[branch-state]] · [[session-reflector]] · [[diff-review]] · [[enforcement-layer]]

## Sources

[[p4-field-patterns]] D1 · TeamAI-CLI usage guide (friction hook) · this repo's transcripts, 2026-09-12
