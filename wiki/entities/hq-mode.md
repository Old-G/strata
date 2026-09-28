---
title: HQ mode (Feature B)
type: entity
created: 2026-08-15
updated: 2026-09-27
links: [gardener, career-ledger, enforcement-layer]
---

# HQ mode (Feature B)

## TLDR

HQ — a separate Strata repo whose wiki is a *meta-wiki*: the table of contents of every
project's table of contents. The projects stay where they already live; the registry lists them
from one declared source.

## Role

One entry point for cross-project work: a global index, cross-project queries, MCP
connectors (Slack, ClickUp, GitLab) wired once, and a place for scheduled automations to
run. Progressive disclosure downward — the global session never bulk-reads project wikis.

## Current solutions

Moved out of Strata on 2026-09-28 (0.13.0): HQ is the separate plugin
[strata-hq](https://github.com/Old-G/strata-hq) (`/strata-hq:init`, `/strata-hq:sync`, group pages
and hubs). The design it was built from, recorded here ([ADR #6](../decisions/adr-6-hq-registry-by-path.md),
which superseded the nested layout of [ADR #3](../decisions/adr-3-hq-nested-layout.md)):

```
HQ/                      # own git repo, meta-layer only
├── CLAUDE.md            # global rules + routing map (thin)
├── .mcp.json            # connectors wired once
├── hq.yaml              # the registry's source: paths (default) | orca
├── registry.yaml        # generated from that source; keyed by the source's id
├── docs/ → raw/ → wiki/ # HQ's own pipeline; wiki/ = meta-index
└── projects/<slug>.md   # one page per registered project; _archive/ for removed ones
```

Member projects stay at their own paths. Only the sync writes the registry and the pages; other
tools may only ask for a sync. A project leaves the registry only on a successful read of the
source without it. A group is a working set, not a hub: a hub (an optional Strata project owning a
set of project pages) is matched by path.

Skills: `hq-init` (scaffold), `hq-sync` (pull each project's index head + log tail +
`git log --since`, refresh `wiki/projects/<name>.md`; **pure read**, never writes into member
projects), `hq-report` (windowed shipped / in-progress / blocked / next report to
`reports/`, posted as a **draft** for human approval first).

Resolution path is three small hops: HQ `wiki/index.md` (one line per project) →
`projects/<slug>.md` (TLDR + last-sync digest) → the project's own `wiki/index.md` →
entity.

Hard dependency: **B is only as good as A.** If project wikis drift, the meta-wiki aggregates
garbage — so the [[enforcement-layer]] ships first.

Open and deferred: work-state layer (Beads `bd` vs markdown plans, OQ#4), report template
(OQ#3), playbook scope across projects (OQ#9). Sessions inside a project no longer inherit HQ's
`CLAUDE.md` by directory walk — the route is the user-scope pointer in `~/.claude/CLAUDE.md`.

## Related

[[gardener]] · [[career-ledger]] · [[enforcement-layer]] · [[session-reflector]]

## Sources

[[vnext-brief]] §3, §10 · [ADR #6](../decisions/adr-6-hq-registry-by-path.md) ·
[ADR #3](../decisions/adr-3-hq-nested-layout.md) (superseded)
