---
title: "ADR #4 — The Stop gate blocks only on markers from the current session"
type: decision
created: 2026-08-15
updated: 2026-08-15
status: accepted
---

# ADR #4 — The Stop gate blocks only on markers from the current session

## Context

Open question #1 from the brief: should the [[stop-gate]] block on *any* outstanding
[[pending-ingest-marker]], or only on markers the session itself created?

Blocking on any marker is the stronger invariant, but it means a repo carrying an old backlog
would refuse to end *every* turn for work the user never touched — including turns that
changed nothing. A gate that fires forever is worse than no gate.

## Decision

The Stop gate considers only markers created during the current session. Older markers are the
[[commit-gate]]'s job: they cannot reach `main` regardless, since the commit fails while any
marker is outstanding.

## Consequences

- The gate is proportionate: you are asked to clean up what you just made dirty, not to pay off
  someone else's debt before you can finish a sentence.
- Adopting Strata into a repo with existing docs does not immediately produce an unusable
  session — a real risk for `/strata:adopt`, which bulk-mirrors docs on first run.
- Coverage is not lost, only deferred to commit time; the two gates compose.
- The Stop gate needs a session-start reference point (timestamp or marker file) to tell "this
  session" from "before" — extra state, and the same file that enforces the one-block-per-session
  cap.
- Combined with reading `stop_hook_active` first and exiting 0, the maximum interruption per
  session is exactly one forced continuation.

## Sources

[[vnext-brief]] §2 (A1), §5 (OQ#1) · resolved 2026-08-15
