---
title: Wiki as compile target (/strata:wiki-emit)
type: entity
created: 2026-08-15
updated: 2026-08-15
links: [enforcement-layer]
---

# Wiki as compile target (/strata:wiki-emit)

## TLDR

One command compiles `wiki/` into `llms.txt`, `llms-full.txt`, and `AGENTS.md` — so every
non-Claude agent reads the same knowledge spine Strata maintains.

## Role

Cheap to build (a renderer over an already-structured wiki), high differentiation:
*maintained by gates, readable by every agent*. Public repos also pick up the Lighthouse
signal for free.

## Current solutions

Planned for P2/P3. Context: llms.txt adoption is real — Google added it as a Lighthouse signal
in a new "Agentic Browsing" category (May 2026), and Cursor and others use it for docs lookup.
AGENTS.md is the cross-agent instruction standard read by Codex, Cursor, and Gemini CLI.
Microsoft's agent-skills ships a "Deep Wiki Plugin" that generates a wiki including llms.txt,
llms-full.txt, AGENTS.md, a CLAUDE.md pointer, and role-based onboarding guides — a direct
overlap with Strata's knowledge layer and worth watching as competition.

Notable convention: write llms.txt in the repo's working language, not default English.
Per-project language choice would live in `registry.yaml` (OQ#10).

## Related

[[enforcement-layer]] · [[hq-mode]]

## Sources

[[vnext-brief]] §11.3, §12.2
