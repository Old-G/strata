---
title: Session reflector (ACE playbook)
type: entity
created: 2026-08-15
updated: 2026-08-15
links: [gardener, hq-mode]
---

# Session reflector (ACE playbook)

## TLDR

A post-session pipeline that distils what worked, what failed, and what surprised into **delta
bullets** appended to `wiki/playbook.md` and `wiki/closed-routes.md` — never a wholesale
rewrite.

## Role

Strata records *decisions* but not *lessons*. ACE (Agentic Context Engineering, Stanford /
SambaNova, arXiv 2510.04618) models context as an evolving playbook with three roles —
Generator (does the work), Reflector (distils lessons from successes and failures), Curator
(merges them as incremental deltas) — plus a grow-and-refine loop. It names the two failure
modes precisely: **brevity bias** (summaries drop the details that mattered) and **context
collapse** (iterative full rewrites erode knowledge), and reports +10.6% on agent benchmarks
from context alone. Strata has the Generator and the storage; the Reflector is the missing
piece.

## Current solutions

Planned as the flagship P3 item. `lean-plan` and `feature` read the playbook first;
[[gardener]] runs the nightly dedupe-and-prune half. `wiki/closed-routes.md` implements the
RH-campaign "ledger of failures" pattern — a prior session's only useful artifact was a list of
106 tried-and-deflated ideas handed to every sub-agent as a do-not-repeat list; `hq-sync`
aggregates these across projects into cross-project "don't repeat my mistakes" memory.

Kill criterion, stated up front: if after two weeks the playbook is not changing plans, drop it.

Boundary: claude-mem already covers episodic memory — prefer *declaring* it over rebuilding it,
per Strata's thin-glue rule. Ship the distiller only if the claude-mem → wiki handoff proves
too lossy.

Open: trigger on every session end (noisy) or only sessions that closed a feature or hit a
failure (signal) — OQ#8; and whether `hq-sync` lifts cross-project bullets upward — OQ#9.

## Related

[[gardener]] · [[hq-mode]] · [[executable-wiki]]

## Sources

[[vnext-brief]] §2 (A6), §8.6, §11.2, §12.1
