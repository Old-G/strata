---
title: Commit gate (A2)
type: entity
created: 2026-08-15
updated: 2026-09-28
links: [enforcement-layer, pending-ingest-marker, stop-gate]
---

# Commit gate (A2)

## TLDR

`scripts/pre-commit/check_wiki_fresh.sh` — fails the commit while any
[[pending-ingest-marker]] is outstanding, printing the exact ingest commands to run.

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

## Related

[[enforcement-layer]] · [[pending-ingest-marker]] · [[stop-gate]] · [[raw-mirror-hook]]

## Sources

[[vnext-brief]] §2 (A2) · [ADR #1](../decisions/adr-1-deterministic-enforcement.md)
