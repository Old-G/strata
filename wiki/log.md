---
title: Operational Log
type: index
created: 2026-08-15
updated: 2026-08-15
---

# Log — operational journal

Append-only record of every wiki operation: `ingest`, `query`, and `lint`. Newest
entries at the bottom. This is how we trace what the AI knew and when, and where `lint`
findings go.

**Format** — one line per operation:

```
[YYYY-MM-DDTHH:MM:SSZ] <op> <target> → <result>
```

- `ingest raw/<file>.md → created/updated: <page list>`
- `query "<question>" → answered from: <pages>` (note any raw/ fallback = incomplete ingest)
- `lint → <N> findings: <one-line summary>` followed by an indented list of findings

Never auto-fix during `lint`; only record what was found. See `wiki/WIKI.md` for the
full protocol.

---

[2026-08-14T21:46:52Z] bootstrap → created wiki skeleton: index.md, overview.md, glossary.md, log.md (sources/, entities/, decisions/ empty, awaiting first ingest)

## 2026-08-14T21:41:44Z auto-mirror

- pending_ingest: docs/superpowers/specs/2026-06-25-ai-led-onboarding-design.md (mirrored docs/ -> raw/, ingest still owed)

## 2026-08-14T21:41:44Z auto-mirror

- pending_ingest: docs/superpowers/specs/2026-07-21-adaptive-ceremony-design.md (mirrored docs/ -> raw/, ingest still owed)

## 2026-08-14T21:41:44Z auto-mirror

- pending_ingest: docs/superpowers/specs/2026-08-14-vnext-brief.md (mirrored docs/ -> raw/, ingest still owed)

## 2026-08-14T21:41:44Z auto-mirror

- pending_ingest: docs/superpowers/plans/2026-06-25-ai-led-onboarding.md (mirrored docs/ -> raw/, ingest still owed)

## 2026-08-14T21:41:44Z auto-mirror

- pending_ingest: docs/superpowers/plans/2026-07-21-adaptive-ceremony.md (mirrored docs/ -> raw/, ingest still owed)

## 2026-08-14T21:46:52Z ingest

[2026-08-14T21:46:52Z] ingest raw/superpowers/specs/2026-08-14-vnext-brief.md → created: sources/vnext-brief.md; entities/{enforcement-layer, stop-gate, commit-gate, session-start-injection, pending-ingest-marker, raw-mirror-hook, native-invocation, hq-mode, gardener, executable-wiki, career-ledger, ablate, session-reflector, agent-teams, wiki-emit}.md; decisions/{adr-1-deterministic-enforcement, adr-2-native-invocation, adr-3-hq-nested-layout, adr-4-stop-gate-session-scope}.md; updated: index.md, overview.md, glossary.md — retires the marker for docs/superpowers/specs/2026-08-14-vnext-brief.md
- Bootstrap note: this repo shipped the wiki pipeline as a template without running it on itself; wiki/ + raw/ created here from templates/core on 2026-08-15.
- Open: 4 mirrored sources remain un-ingested (2 specs + 2 plans from 2026-06/07) — genuine backlog, not silently cleared.
- Resolved this session: OQ#1 (ADR #4), OQ#5 (ADR #2). OQ#2 was already answered by the brief itself (ADR #3).

## 2026-08-14T21:50:29Z auto-mirror

- pending_ingest: docs/superpowers/plans/2026-08-15-p1-enforce-route-plan.md (mirrored docs/ -> raw/, ingest still owed)

## 2026-08-14T22:16:37Z ingest — P1 shipped (v0.4.0)

[2026-08-14T22:16:37Z] ingest raw/superpowers/plans/2026-08-15-p1-enforce-route-plan.md → created: sources/p1-enforce-route-plan.md; updated: index.md, entities/{stop-gate, commit-gate, session-start-injection, native-invocation, enforcement-layer, pending-ingest-marker, raw-mirror-hook}.md (planned → shipped, with measured evidence)
[2026-08-14T22:16:37Z] ingest raw/superpowers/specs/2026-06-25-ai-led-onboarding-design.md → created: sources/ai-led-onboarding-design.md
[2026-08-14T22:16:37Z] ingest raw/superpowers/specs/2026-07-21-adaptive-ceremony-design.md → created: sources/adaptive-ceremony-design.md
[2026-08-14T22:16:37Z] ingest raw/superpowers/plans/2026-06-25-ai-led-onboarding.md → created: sources/ai-led-onboarding-plan.md
[2026-08-14T22:16:37Z] ingest raw/superpowers/plans/2026-07-21-adaptive-ceremony.md → created: sources/adaptive-ceremony-plan.md
- Backlog cleared: all 5 mirrored sources now have source pages; the un-ingested note in index.md is retired.
- Defect fixed during this work: sync_raw_mirror.sh had gone blind to every doc it had ever ingested once (marker written only if the string had never appeared). Found by dogfooding, covered by scripts/test_p1_gates.sh.
- Contradiction fixed in wiki: entities/pending-ingest-marker.md still described the old, broken idempotency rule.

## 2026-08-14T22:17:50Z gotcha

- `git restore --staged --worktree <path>` DELETES an untracked-but-staged file — there is no HEAD version to restore from. Hit while cleaning up a negative-control test; wiki/log.md was recovered from the dangling blob left by `git add`. Use `git reset -- <path>` (unstage only) or edit the file directly.
