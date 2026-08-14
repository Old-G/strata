---
title: Ablation (/strata:ablate)
type: entity
created: 2026-08-15
updated: 2026-08-15
links: [enforcement-layer, native-invocation]
---

# Ablation (/strata:ablate)

## TLDR

`audit` for *instructions* instead of code: empirically test which CLAUDE.md rules, skill
paragraphs, and hooks the current model still needs — and delete the rest.

## Role

Boris Cherny (Claude Code creator, YC Startup School, July 2026): *"Every 6 months, delete your
CLAUDE.md file, delete your skills, and delete your hooks. Then see what the model does."* His
team cut 80%+ of Claude Code's own system prompt for Opus 5. Anthropic's best-practices doc
says the same per line: would removing this cause mistakes? If not, cut it — or convert it to a
hook. Every source describes a **manual** practice; no shipped tool runs the pruning test
empirically, which makes this an open niche and a possible headline feature.

## Current solutions

Planned for P3. Protocol: snapshot current CLAUDE.md / skills / hooks → generate an ablation
matrix (rule → what breaks without it?) → run the project's verify suite plus a scripted
feature dry-run **with and without** each candidate rule → classify each as *still needed* /
*dead scaffolding* / *convert to hook* / *move to wiki*.

Two standing rules it must respect:

- The [[enforcement-layer]] is **exempt** — safety and invariant hooks are not model-capability
  scaffolding. Everything advisory is a deletion candidate.
- Facts belong in `wiki/` (queried on demand), not in CLAUDE.md (paid every session). The tool
  should detect "this paragraph is actually knowledge" and move it.

Design pressure it applies to Strata now: each SKILL.md should trend toward task + guardrails +
exit criteria + verify, cutting step-by-step hand-holding written for 2025-era models. Shorter,
sharper descriptions also route better — see [[native-invocation]].

Open: cadence — fixed 6 months, or triggered on a model-version change detected at SessionStart
(OQ#6).

## Related

[[enforcement-layer]] · [[native-invocation]] · [[gardener]]

## Sources

[[vnext-brief]] §7, §11.4, §12.3
