---
title: Commit gate (A2)
type: entity
created: 2026-08-15
updated: 2026-08-15
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

## Related

[[enforcement-layer]] · [[pending-ingest-marker]] · [[stop-gate]] · [[raw-mirror-hook]]

## Sources

[[vnext-brief]] §2 (A2) · [ADR #1](../decisions/adr-1-deterministic-enforcement.md)
