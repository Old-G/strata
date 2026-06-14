---
title: Wiki Index
type: index
created: {{DATE}}
updated: {{DATE}}
---

# Wiki Index — start here

This is the catalog and **first stop** for any question about the project. The AI reads
this page before grepping the repo: scan the one-line TLDRs, follow the link to the
relevant page, and answer from `wiki/`. Add a row here for every page you create during
`ingest` (see `wiki/WIKI.md` for the protocol).

> Convention: internal links use `[[entity-slug]]` (→ `entities/<slug>.md`). Links to
> raw sources use plain markdown `[file](../raw/<file>.md)`.

---

## Big picture

| Page | What it is |
|---|---|
| [[overview]] | The project narrative — what we're building, current phase, layers, component map. |
| [glossary](glossary.md) | Term → definition table; also the drift-protection source-of-truth for at-risk facts. |
| [log](log.md) | Operational journal of every ingest / query / lint, timestamped. |

---

## Sources

One page per file in `raw/`, holding a 3–7 paragraph summary (never a copy).

_Add pages here as you ingest — `[[<source-slug>]]` — one line each._

<!-- e.g. | [[source-architecture]] | Summary of raw/architecture.md — system layers + boundaries. | -->

---

## Entities

Components, technologies, roles, and patterns — each with TLDR / Role / Current
solutions / Related / Sources.

_Add pages here as you ingest — `[[<entity-slug>]]` — one line each._

<!-- e.g. | [[wiki]] | The curated knowledge layer; queried before the repo. | -->

---

## Decisions (ADRs)

One page per architectural decision: `decisions/adr-<n>-<slug>.md`.

_Add pages here as decisions are anchored — `[ADR #N](decisions/adr-N-slug.md)` — one line each._

<!-- e.g. | [ADR #1](decisions/adr-1-three-layer-wiki.md) | Adopt the docs→raw→wiki three-layer split. | -->

---

## Analyses

Saved answers to recurring questions (`entities/analysis-<slug>.md`, `type: analysis`).

_Add pages here when you save a query answer — `[[analysis-<slug>]]` — one line each._
