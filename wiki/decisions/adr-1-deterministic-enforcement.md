---
title: "ADR #1 — Deterministic enforcement over advisory prose"
type: decision
created: 2026-08-15
updated: 2026-08-15
status: accepted
---

# ADR #1 — Deterministic enforcement over advisory prose

## Context

Strata's knowledge pipeline is write-only: [[raw-mirror-hook]] emits
[[pending-ingest-marker]] entries that nothing ever consumes. The rules meant to consume
them live as prose inside skills — `feature` step 3 says "run wiki-ingest", `light-finish`
does not mention the wiki at all. Skill text is probabilistic: the model reads it early in a
session and forgets it late, which is exactly the observed drift. Code-only changes emit no
wiki signal at all.

## Decision

Convert the load-bearing wiki-freshness rules into hooks and pre-commit guards — the
[[enforcement-layer]]: [[stop-gate]] (A1), [[commit-gate]] (A2), [[session-start-injection]]
(A3), plus an explicit drift-close step in `light-finish` (A4).

Constraints that are part of the decision, not implementation detail:

- **No global hooks from the plugin.** Scripts ship in `templates/core/scripts/hooks/` and
  `templates/core/scripts/pre-commit/`; `init` / `adopt` install them into the *target*
  project's `.claude/settings.json`, the same way `sync_raw_mirror.sh` is installed today. The
  plugin stays inert in unrelated repos. The Strata repo dogfoods them on itself.
- **Bash only**, no new dependencies.
- **Loop safety is non-negotiable** for the Stop gate — see
  [ADR #4](adr-4-stop-gate-session-scope.md).

## Consequences

- Wiki freshness stops depending on the model's memory, and holds even for work done outside
  the `/strata:feature` flow or by other tools entirely.
- It is also the floor under [[native-invocation]]: when description-based routing misses, the
  invariant still holds.
- This layer is **exempt from ablation** ([[ablate]]) — it encodes invariants, not
  model-capability scaffolding.
- Cost: three more scripts to maintain, and a real risk of user-hostile behaviour if a gate
  misfires. Hence the escape hatch (`STRATA_SKIP_WIKI=1`), the one-block-per-session cap, and
  the sub-100 ms fast path.
- Unblocks [[hq-mode]]: aggregating drifted project wikis would aggregate garbage, so P1 ships
  before P2.

## Sources

[[vnext-brief]] §1, §2, §5
