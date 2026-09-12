---
title: Friction capture (Stop-gate trigger d)
type: entity
created: 2026-09-12
updated: 2026-09-13
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

**Shipped in v0.8.0** inside `templates/core/scripts/hooks/strata_stop_gate.sh` as trigger (d) —
see [[stop-gate]] for the mechanics as built. `scripts/test_p4_friction.sh`, 24 assertions, is
`validate.sh` §12. Shape:

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
- Runs last, after the cheap checks: one fixed-string `grep` pass under `LC_ALL=C` selects the
  candidate lines (interrupts and `is_error` results — a denial *is* an `is_error` result), the
  counts run over that small set. Measured +≈90 ms on a 5 MB transcript (best of 7); the spec's
  ≤ 50 ms aspiration was not met with BSD grep and is recorded as such. Fails open on a
  missing or unreadable transcript. No new hook event — Claude Code exposes no Esc or
  permission-denied event, the transcript is the only deterministic channel.
- Not adopted: TeamAI's "correction within 60 s" keyword heuristic — language-dependent and
  noisy in a bilingual repo.

Delivered to adopted repos by [[upgrade-path]] since it lives inside the existing Stop-gate script.
Two fixture lessons from building it (also in [[stop-gate]]): bash 3.2 mis-parses a quote inside
`"${var:-default}"`; BSD `seq 1 0` counts down and emits two lines.

## Related

[[stop-gate]] · [[branch-state]] · [[session-reflector]] · [[diff-review]] · [[enforcement-layer]]

## Sources

[[p4-field-patterns]] D1 · TeamAI-CLI usage guide (friction hook) · this repo's transcripts, 2026-09-12
