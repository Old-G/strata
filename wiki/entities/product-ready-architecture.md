---
title: Product-ready architecture
type: entity
created: 2026-10-18
updated: 2026-10-18
links: [stop-gate]
---

# Product-ready architecture

## TLDR

The architecture canon `strata-eng-review` applies to every plan (item 7), shipped in v0.16.6 as
`reference/product-ready-architecture.md`.

- **Two levels.** Level 1 always — cheap rules that make a project usable by someone else (no
  owner-specific constants in code, one module per vendor, one storage layer, domain modules,
  one-command run, no early generalisation). Level 2 only for a project marked a product candidate
  — tenant scope on every record, per-scope secrets, a user in the model, tool-enforced boundaries,
  per-scope export/delete.
- **The marker** is `.strata/profile` containing `product`; absent → level 1 only. Chosen over a
  CLAUDE.md line because a file is greppable by the reviewer and by `audit` without parsing prose.
- **Why two levels, not one.** Applying tenancy to every internal tool is accidental complexity;
  the reviewer flags level-2 machinery in an unmarked project instead of praising it.
- **Not covered on purpose:** billing, sign-up, multi-region, SSO — they come with the first real
  customer.

Related: [[stop-gate]] (process enforcement), `reference/council-personas.md`.
