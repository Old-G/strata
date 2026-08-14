---
title: Career ledger
type: entity
created: 2026-08-15
updated: 2026-08-15
links: [hq-mode]
---

# Career ledger

## TLDR

Append-only `hq/ledger/ledger.jsonl` — one event per shipped or decided thing, compiled on
demand into a performance review, a raise case, or a portfolio.

## Role

The work already produces the evidence (merges, wiki log lines, closed tasks); it is simply
never collected, so review season becomes an archaeology exercise. The ledger captures each
win at the moment it happens, with provenance.

## Current solutions

Approved, planned for P2. Event shape carries `ts`, `project`, `type`, `what`, `evidence`
links, and an optional `metric` with from/to values.

Writers: `light-finish` appends on merge, `hq-report` appends weekly rollups, and a manual
`ledger add` covers non-code wins. Compilers run **on demand, never scheduled**:
`ledger compile review | case | portfolio`.

Privacy rule: work evidence links resolve only inside work context — the ledger stores
references, never confidential payloads.

Open: is the taxonomy shipped / decided / learned / prevented sufficient (OQ#12).

## Related

[[hq-mode]]

## Sources

[[vnext-brief]] §13.2
