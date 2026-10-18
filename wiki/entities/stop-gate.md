---
title: Stop gate (A1)
type: entity
created: 2026-08-15
updated: 2026-10-18
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

A second trigger covers code-only sessions: ~20+ changed lines (50 until v0.16.4 — a 40-line fix
left no trace) outside `wiki/ raw/ docs/` with
nothing written to `wiki/log.md` blocks once, satisfiable by a single log line (including an
explicit `no-wiki-impact:`). Tune with `STRATA_STOP_GATE_LINES`; `0` disables it. Since v0.9.0 it
counts only what *this* session touched: SessionStart snapshots the already-dirty files as
`(blob hash, path)` (`lib/tree_snapshot.sh`) and (b) skips any file whose pair is unchanged — a
session opened on top of someone's uncommitted work is no longer billed for it ([[p5-provenance]]
D10). Without a snapshot (older SessionStart) it falls back to the whole-tree count.

**Since v0.16.3 (b) also counts code committed this session.** Uncommitted lines alone missed the
field's common case: an agent writes 50+ lines, commits them, then stops — a clean tree, so the gate
saw 0 and stayed silent exactly when it mattered (the [[commit-gate]] only checks docs→raw markers).
SessionStart now writes `HEAD=<sha>` into the stamp (empty before the first commit); (b) adds the
numstat of `git log --no-merges <start>..HEAD` minus `wiki/ raw/ docs/`, keeping only commits whose
committer time is at or after the stamp's `EPOCH` — commits pulled in from others carry older dates
and are not billed. Fails open: no `HEAD=` (older stamp), an empty one, or a start commit that is
not an ancestor of HEAD (branch switch, rebase) → the committed part is skipped. The satisfaction
rule is unchanged: `wiki/log.md` grew since the session started, committed or not. Deliberate: a
commit made this session is this session's act, even if it carries uncommitted work that predates
the session. HEAD is read with shell builtins on the plain layout (loose ref or detached, incl.
linked worktrees and submodules) and from `git rev-parse` only for packed refs/reftable — a
`rev-parse` on every Stop cost ~8 ms of the 100 ms budget.

**Trigger (e), shipped in v0.16.4 — wiki left behind:** (b) is satisfied by a `wiki/log.md` line
*committed or not*, so a session could write the wiki, commit only its code and leave the wiki in its
own working tree, where nobody else ever reads it (seen in the field: a repo with a dozen wiki pages
uncommitted for a week). When `wiki/log.md` grew this session, the gate lists `wiki/` files that are
uncommitted *and* newer than the session stamp (mtime — older wiki dirt is not this session's), and
blocks once when the session's code is already committed (HEAD moved since the stamp) or no code is
left uncommitted at all. Code still dirty reads as work in progress and passes. The clean path pays
nothing: the check runs only after the log grew. Its push-time twin is the [[commit-gate]]'s push gate.

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

## Requirements

### Blocks at most once per session
The Stop gate never forces more than one continuation in a session, however much wiki work is owed.

- Scenario: a marker created this session — WHEN a pending-ingest marker was written in the current
  session THEN the first Stop is blocked · `test: scripts/test_p1_gates.sh::blocks on a marker created this session`
- Scenario: second stop — WHEN the gate already blocked once in this session THEN the next Stop
  exits 0 · `test: scripts/test_p1_gates.sh::never blocks twice in one session`

### Ignores work that predates the session
Markers and dirty files that existed before the session started are not this session's debt.

- Scenario: an old marker — WHEN the only pending marker is older than the session THEN Stop is not
  blocked · `test: scripts/test_p1_gates.sh::ignores markers older than the session (ADR #4)`
- Scenario: a commit pulled in — WHEN the only new commit on HEAD has a committer date before the
  session started THEN its lines are not billed · `test: scripts/test_p1_gates.sh::a commit dated before the session (pulled in) is not billed`

### Counts code committed this session
Trigger (b) bills a session for the code it committed as well as the code it left uncommitted, and
skips the committed part whenever it cannot tell what the session committed.

- Scenario: commit then stop — WHEN this session committed 20+ lines of code and `wiki/log.md` did not
  grow THEN the first Stop is blocked · `test: scripts/test_p1_gates.sh::code committed this session, tree clean, wiki silent → blocked`
- Scenario: commit with a log line — WHEN the commit also added a `wiki/log.md` line THEN Stop is not
  blocked · `test: scripts/test_p1_gates.sh::committed code + a committed wiki/log.md line → clear`
- Scenario: committed plus uncommitted — WHEN 30 committed and 30 uncommitted lines together pass the
  threshold THEN Stop is blocked · `test: scripts/test_p1_gates.sh::committed + uncommitted lines are summed`
- Scenario: branch switch — WHEN the session's starting commit is not an ancestor of HEAD THEN the
  committed part is skipped · `test: scripts/test_p1_gates.sh::start HEAD not an ancestor of HEAD (branch switch)`
- Scenario: older stamp — WHEN the session stamp has no `HEAD=` line THEN the committed part is
  skipped · `test: scripts/test_p1_gates.sh::stamp without HEAD= (older SessionStart)`

### Asks for a code change of 20+ lines
The default threshold of trigger (b) is 20 changed lines; `STRATA_STOP_GATE_LINES` overrides it.

- Scenario: 25 lines — WHEN this session changed 25 lines of code and wrote nothing to the wiki THEN
  Stop is blocked · `test: scripts/test_p1_gates.sh::25 changed lines → blocked (default threshold 20)`
- Scenario: 10 lines — WHEN it changed 10 lines THEN Stop is not blocked ·
  `test: scripts/test_p1_gates.sh::10 changed lines → clear (below the default)`

### Asks for the wiki to be committed with the code
A session that wrote the wiki may not stop with those wiki files uncommitted once its code is committed.

- Scenario: wiki left behind — WHEN this session committed code and left wiki files it wrote
  uncommitted THEN Stop is blocked · `test: scripts/test_p1_gates.sh::code committed, wiki written but uncommitted → blocked`
- Scenario: work in progress — WHEN both the wiki and the code are still uncommitted THEN Stop is not
  blocked · `test: scripts/test_p1_gates.sh::wiki and code both uncommitted (work in progress) → clear`
- Scenario: committed together — WHEN code and wiki went into the same commit THEN Stop is not
  blocked · `test: scripts/test_p1_gates.sh::code and wiki committed together → clear`
- Scenario: older wiki dirt — WHEN the only uncommitted wiki file predates the session THEN Stop is
  not blocked · `test: scripts/test_p1_gates.sh::wiki dirt older than the session is not its debt → clear`

## Related

[[enforcement-layer]] · [[pending-ingest-marker]] · [[commit-gate]] ·
[[session-start-injection]] · [[branch-state]] · [[friction-capture]]

## Sources

[[vnext-brief]] §2 (A1) · [ADR #1](../decisions/adr-1-deterministic-enforcement.md) ·
[ADR #4](../decisions/adr-4-stop-gate-session-scope.md) ·
[ADR #5](../decisions/adr-5-episodic-state-branch-scoped.md) · [[episodic-state-layer]]
