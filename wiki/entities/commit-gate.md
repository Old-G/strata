---
title: Commit gate (A2) and push gate (A2b)
type: entity
created: 2026-08-15
updated: 2026-10-18
links: [enforcement-layer, pending-ingest-marker, stop-gate]
---

# Commit gate (A2) and push gate (A2b)

## TLDR

`scripts/pre-commit/check_wiki_fresh.sh` — fails the commit while any
[[pending-ingest-marker]] is outstanding, printing the exact ingest commands to run. Since v0.16.4 its push-time twin,
`scripts/pre-commit/check_wiki_push.sh`, refuses a push whose new commits change code but never
touch `wiki/log.md`.

## Role

The backstop that does not depend on Claude being in the loop at all. It catches everything
the [[stop-gate]] misses: manual commits, commits from another editor or tool, and markers
left over from earlier sessions (which the Stop gate deliberately ignores, per
[ADR #4](../decisions/adr-4-stop-gate-session-scope.md)).

## Current solutions

**Shipped in v0.4.0** as `scripts/pre-commit/check_wiki_fresh.sh`, joining the guards Strata
already installs —
`check_secrets.sh` and `check_raw_mirror.sh` — in `templates/core/scripts/pre-commit/`.

- Fail with a non-zero exit and a list of `pending_ingest` files.
- Print a runnable remediation line per file.
- Escape hatch for genuine WIP commits: `STRATA_SKIP_WIKI=1 git commit …`.

It judges the **staged** `wiki/log.md`, not the working tree: the question is what this commit
contains, so ingesting without staging `wiki/` is caught too.

## Push gate (A2b, v0.16.4)

The commit gate only fires on docs→raw markers, and the [[stop-gate]] only sees sessions run
through Claude Code — code committed by another agent, an editor or by hand reached the remote with
no knowledge trace. The push is the point every path crosses. Per pushed branch, over the commits
the remote does not have (`<remote sha>..<local sha>`; `<local> --not --remotes=<remote>` for a new
branch or an unfetched remote sha), it sums changed lines outside `wiki/ raw/ docs/` and Strata's own installed scripts (since v0.16.5 — a
hook re-sync is the plugin's change, not the project's) (no merges)
and refuses the push at `STRATA_PUSH_GATE_LINES` (default 20; `0` disables) when none of those
commits touches `wiki/log.md`. Tags, branch deletions and repos without `wiki/log.md` pass.
`STRATA_SKIP_WIKI=1` (or `--no-verify`) bypasses it. Reads git's pre-push stdin, or the pre-commit
framework's `PRE_COMMIT_FROM_REF`/`PRE_COMMIT_TO_REF` at its `pre-push` stage. A git hook is wired
per clone, so `strata_upgrade_check.sh` reports `UNWIRED  git pre-push` without failing, and
`/strata:upgrade` wires it.

## Requirements

### Refuses a commit while the wiki is behind
A commit fails while any pending-ingest marker is outstanding, and names the file to ingest.

- Scenario: outstanding marker — WHEN a doc was edited and not ingested THEN the commit exits 1 ·
  `test: scripts/test_p1_gates.sh::fails the commit while a marker is outstanding`
- Scenario: names the fix — WHEN the commit is refused THEN the message names
  `wiki-ingest raw/<file>` · `test: scripts/test_p1_gates.sh::names the file to ingest`
- Scenario: ingested and staged — WHEN the ingest is recorded and `wiki/` is staged THEN the commit
  passes · `test: scripts/test_p1_gates.sh::ingesting AND staging passes`

### Can be skipped on purpose
`STRATA_SKIP_WIKI=1` lets a commit through with markers outstanding.

- Scenario: escape hatch — WHEN `STRATA_SKIP_WIKI=1` is set THEN the commit passes ·
  `test: scripts/test_p1_gates.sh::STRATA_SKIP_WIKI=1 is an escape hatch`

### Refuses a push of code without a wiki line
A push whose new commits change 20+ lines of code and never touch `wiki/log.md` is refused.

- Scenario: code only — WHEN the pushed commits carry 30 lines of code and no log line THEN the push
  is refused · `test: scripts/test_p1_gates.sh::30 lines of code, no wiki/log.md in the pushed commits → refused`
- Scenario: with a log line — WHEN one pushed commit touches `wiki/log.md` THEN the push goes through ·
  `test: scripts/test_p1_gates.sh::a pushed commit touching wiki/log.md satisfies it → pushed`
- Scenario: new branch — WHEN the branch does not exist on the remote yet THEN its commits are judged
  too · `test: scripts/test_p1_gates.sh::a new branch (remote sha all zeros) is judged too → refused`
- Scenario: escape hatch — WHEN `STRATA_SKIP_WIKI=1` is set THEN the push goes through ·
  `test: scripts/test_p1_gates.sh::STRATA_SKIP_WIKI=1 bypasses it`

## Related

[[enforcement-layer]] · [[pending-ingest-marker]] · [[stop-gate]] · [[raw-mirror-hook]]

## Sources

[[vnext-brief]] §2 (A2) · [ADR #1](../decisions/adr-1-deterministic-enforcement.md)
