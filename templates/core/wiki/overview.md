---
title: Project Overview
type: entity
created: {{DATE}}
updated: {{DATE}}
links:
---

# Overview — the big picture

> The single-page narrative of the project. It evolves with every `ingest`: when a
> source changes the structure, phase, or component map, update the relevant section
> here. Keep it to ~1–2 pages — depth lives in `entities/` and `sources/`. Replace each
> `{{PLACEHOLDER}}` with real content.

## What we're building

{{ONE_PARAGRAPH_WHAT_AND_WHY}}

<!-- What is this project? Who is it for? What problem does it solve? -->

## Current phase / status

{{CURRENT_PHASE}}

<!-- e.g. "Phase 0 — bootstrapping the knowledge layer." What is done, what's next. -->

## Key decisions

{{KEY_DECISIONS}}

<!-- The handful of decisions that shape everything else. Link each ADR:
     - [ADR #N](decisions/adr-N-slug.md) — <one line> -->

## Architectural layers

{{LAYERS}}

<!-- The conceptual stack, top to bottom. e.g.
     - **Knowledge** — wiki/ (curated, queried first)
     - **Application** — ...
     - **Data** — ... -->

## Component map

{{COMPONENT_MAP}}

<!-- The main moving parts and how they connect. Link entities with [[slug]]:
     - [[component-a]] — <role> → talks to [[component-b]]
     - [[component-b]] — <role> -->

## Layout

{{REPO_LAYOUT}}

<!-- Top-level directories and what lives in each. Mirror the repo's real structure;
     re-ingest affected sources whenever it changes. -->
