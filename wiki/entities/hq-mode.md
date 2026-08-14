---
title: HQ mode (Feature B)
type: entity
created: 2026-08-15
updated: 2026-08-15
links: [gardener, career-ledger, enforcement-layer]
---

# HQ mode (Feature B)

## TLDR

`~/hq` — a Strata project whose wiki is a *meta-wiki*: the table of contents of every
project's table of contents, with the projects themselves nested physically underneath.

## Role

One entry point for cross-project work: a global index, cross-project queries, MCP
connectors (Slack, ClickUp, GitLab) wired once, and a place for scheduled automations to
run. Progressive disclosure downward — the global session never bulk-reads project wikis.

## Current solutions

Planned for P2. Layout ([ADR #3](../decisions/adr-3-hq-nested-layout.md)):

```
~/hq/                    # git repo; .gitignore: projects/
├── CLAUDE.md            # global rules + routing map (thin)
├── .mcp.json            # connectors wired once
├── registry.yaml        # auto-discovered from projects/*/wiki
├── docs/ → raw/ → wiki/ # HQ's own pipeline; wiki/ = meta-index
└── projects/<name>/     # each its own git repo and its own wiki/
```

Skills: `hq-init` (scaffold), `hq-sync` (pull each project's index head + log tail +
`git log --since`, refresh `wiki/projects/<name>.md`; **pure read**, never writes into member
projects), `hq-report` (windowed shipped / in-progress / blocked / next report to
`hq/reports/`, posted as a **draft** for human approval first).

Resolution path is three small hops: `hq/wiki/index.md` (one line per project) →
`hq/wiki/projects/<name>.md` (TLDR + last-sync digest) → the project's own `wiki/index.md` →
entity.

Hard dependency: **B is only as good as A.** If project wikis drift, the meta-wiki aggregates
garbage — so the [[enforcement-layer]] ships first.

Open and deferred: work-state layer (Beads `bd` vs markdown plans, OQ#4), report template
(OQ#3), playbook scope across projects (OQ#9).

## Related

[[gardener]] · [[career-ledger]] · [[enforcement-layer]] · [[session-reflector]]

## Sources

[[vnext-brief]] §3, §10 · [ADR #3](../decisions/adr-3-hq-nested-layout.md)
