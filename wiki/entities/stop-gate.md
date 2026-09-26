---
title: Stop gate (A1)
type: entity
created: 2026-08-15
updated: 2026-09-26
links: [enforcement-layer, pending-ingest-marker, commit-gate, branch-state, friction-capture]
---

# Stop gate (A1)

## TLDR

`scripts/hooks/strata_stop_gate.sh` — a `Stop`-event hook that refuses to end the turn once,
with a reason, while this session still owes wiki work.

## Role

Catches ad-hoc work done outside the `/strata:feature` flow — the exact case where advisory
prose fails, because the model is late in a long session and has forgotten step 3 of a skill
it read an hour ago. The Stop event is the only place Claude Code lets a hook hand control
back to the model with an instruction (exit code 2, or JSON `{"decision":"block","reason":…}`).

## Current solutions

**Shipped in v0.4.0** as `scripts/hooks/strata_stop_gate.sh`. Behaviour:

- Read `stop_hook_active` from the hook input **first**; if true → `exit 0`. Non-negotiable.
- Scan `wiki/log.md` for [[pending-ingest-marker]] lines created in the **current session**
  only ([ADR #4](../decisions/adr-4-stop-gate-session-scope.md)); older markers belong to
  the [[commit-gate]].
- Block **once**, with a reason naming the exact files and the ingest command.

Loop safety is the design constraint, not a footnote: at most **one** forced continuation
per session, enforced by a marker file, because a gate that fires forever is worse than no
gate. Fast path when the state is clean: `exit 0` in under 100 ms.

Shipped in `templates/core/scripts/hooks/`, installed into the target project's
`.claude/settings.json` by `init` / `adopt` — never as a global plugin hook.

A second trigger covers code-only sessions: ~50+ changed lines outside `wiki/ raw/ docs/` with
nothing written to `wiki/log.md` blocks once, satisfiable by a single log line (including an
explicit `no-wiki-impact:`). Tune with `STRATA_STOP_GATE_LINES`; `0` disables it.

The hook payload is parsed with `grep`/`sed`, not `python3` — interpreter startup measured ~36 ms,
unaffordable against the sub-100 ms budget. Verified clean-state path: 69 ms.

**Trigger (c), shipped in v0.5.0:** if [[branch-state]]'s `.strata/state/<branch>.json` exists for
the current branch, blocks once when its `wiki_debt` array is non-empty, or when the file exists
but fails schema validation (`scripts/lib/state_tools.py validate`). A *missing* state file is not
a trigger — same incremental-adoption stance as triggers (a)/(b). `python3` only runs when a state
file actually exists, so the clean/no-layer path pays nothing extra.

**Trigger (d), shipped in v0.8.0 — [[friction-capture]]:** the gate reads the session's own transcript
(`transcript_path` in the Stop payload) and counts three signals: user interrupts
(`[Request interrupted by user` as the *start of a JSON string value* — `"text":"[…` or
`"content":"[…` — on `"type":"user"` lines; since v0.9.0, because the same words quoted inside a
tool result, e.g. from reading this gate's code, are escaped and used to count as a false interrupt), denied tool calls (an `is_error`
tool_result matching `STRATA_FRICTION_DENY_RE`, default `doesn't want to proceed`) and other tool errors
(`"is_error":true`). Subagent sidechains are dropped. Thresholds `STRATA_FRICTION_INTERRUPTS=1`,
`_DENIALS=2`, `_ERRORS=8`; `0` disables a signal, all three `0` the trigger. It fires only when (a)–(c)
did not, some signal met its threshold, there is somewhere to record (`wiki/log.md` or a branch state
exists) and nothing was recorded since the session stamp (log line count unchanged, state file not
`-newer` than the stamp). Satisfied by a `gotchas` entry in `.strata/state/<branch>.json` or one line
`gotcha: …` / `no-gotcha: …` in `wiki/log.md`; when another trigger fires anyway, the counts are appended to
its reason. One fixed-string `grep` pass under `LC_ALL=C` selects candidate lines, the counts run over
that small set; skipped when the payload has no `transcript_path`, fails open on an unreadable file.
Measured: a 5 MB transcript adds ≈90 ms to the gate (`test_p4_friction.sh`, best of 7). Two fixture
lessons: bash 3.2 (macOS `/bin/bash`) mis-parses a quote inside `"${var:-default}"` — keep defaults in
their own assignment; BSD `seq 1 0` counts *down* and emits two lines — generate fixtures with
arithmetic loops.

## Related

[[enforcement-layer]] · [[pending-ingest-marker]] · [[commit-gate]] ·
[[session-start-injection]] · [[branch-state]] · [[friction-capture]]

## Sources

[[vnext-brief]] §2 (A1) · [ADR #1](../decisions/adr-1-deterministic-enforcement.md) ·
[ADR #4](../decisions/adr-4-stop-gate-session-scope.md) ·
[ADR #5](../decisions/adr-5-episodic-state-branch-scoped.md) · [[episodic-state-layer]]
