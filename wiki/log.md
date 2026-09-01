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

## 2026-09-01T14:29:02Z auto-mirror

- pending_ingest: docs/superpowers/specs/2026-09-01-episodic-state-layer.md (mirrored docs/ -> raw/, ingest still owed)

## 2026-09-01T14:48:23Z lint

- errors: 3, warnings: 24

  - ❌ wiki/index.md: references missing file: decisions/adr-<n>-<slug>.md
  - ❌ wiki/index.md: references missing file: entities/<slug>.md
  - ❌ wiki/index.md: references missing file: entities/analysis-<slug>.md
  - ⚠️  wiki/entities/ablate.md: not listed in wiki/index.md (rel: entities/ablate.md)
  - ⚠️  wiki/entities/agent-teams.md: not listed in wiki/index.md (rel: entities/agent-teams.md)
  - ⚠️  wiki/entities/branch-state.md: not listed in wiki/index.md (rel: entities/branch-state.md)
  - ⚠️  wiki/entities/career-ledger.md: not listed in wiki/index.md (rel: entities/career-ledger.md)
  - ⚠️  wiki/entities/commit-gate.md: not listed in wiki/index.md (rel: entities/commit-gate.md)
  - ⚠️  wiki/entities/enforcement-layer.md: not listed in wiki/index.md (rel: entities/enforcement-layer.md)
  - ⚠️  wiki/entities/executable-wiki.md: not listed in wiki/index.md (rel: entities/executable-wiki.md)
  - ⚠️  wiki/entities/gardener.md: not listed in wiki/index.md (rel: entities/gardener.md)
  - ⚠️  wiki/entities/hq-mode.md: not listed in wiki/index.md (rel: entities/hq-mode.md)
  - ⚠️  wiki/entities/native-invocation.md: not listed in wiki/index.md (rel: entities/native-invocation.md)
  - ⚠️  wiki/entities/pending-ingest-marker.md: not listed in wiki/index.md (rel: entities/pending-ingest-marker.md)
  - ⚠️  wiki/entities/raw-mirror-hook.md: not listed in wiki/index.md (rel: entities/raw-mirror-hook.md)
  - ⚠️  wiki/entities/session-reflector.md: not listed in wiki/index.md (rel: entities/session-reflector.md)
  - ⚠️  wiki/entities/session-start-injection.md: not listed in wiki/index.md (rel: entities/session-start-injection.md)
  - ⚠️  wiki/entities/stop-gate.md: not listed in wiki/index.md (rel: entities/stop-gate.md)
  - ⚠️  wiki/entities/upgrade-path.md: not listed in wiki/index.md (rel: entities/upgrade-path.md)
  - ⚠️  wiki/entities/wiki-emit.md: not listed in wiki/index.md (rel: entities/wiki-emit.md)
  - ⚠️  wiki/sources/adaptive-ceremony-design.md: not listed in wiki/index.md (rel: sources/adaptive-ceremony-design.md)
  - ⚠️  wiki/sources/adaptive-ceremony-plan.md: not listed in wiki/index.md (rel: sources/adaptive-ceremony-plan.md)
  - ⚠️  wiki/sources/ai-led-onboarding-design.md: not listed in wiki/index.md (rel: sources/ai-led-onboarding-design.md)
  - ⚠️  wiki/sources/ai-led-onboarding-plan.md: not listed in wiki/index.md (rel: sources/ai-led-onboarding-plan.md)
  - ⚠️  wiki/sources/episodic-state-layer.md: not listed in wiki/index.md (rel: sources/episodic-state-layer.md)
  - ⚠️  wiki/sources/p1-enforce-route-plan.md: not listed in wiki/index.md (rel: sources/p1-enforce-route-plan.md)
  - ⚠️  wiki/sources/vnext-brief.md: not listed in wiki/index.md (rel: sources/vnext-brief.md)

## 2026-09-01T14:49:51Z ingest — P2 shipped (v0.5.0)

[2026-09-01T14:49:51Z] ingest raw/superpowers/specs/2026-09-01-episodic-state-layer.md → created: sources/episodic-state-layer.md; entities/{branch-state, upgrade-path}.md; decisions/adr-5-episodic-state-branch-scoped.md; updated: index.md, overview.md, entities/{stop-gate, session-start-injection, enforcement-layer, session-reflector}.md — retires the marker for docs/superpowers/specs/2026-09-01-episodic-state-layer.md
- Shipped: `scripts/lib/state_tools.py` (schema+validator+CLI) · Stop-gate trigger (c) · SessionStart branch-state summary + version nudge · `/strata:upgrade` (`skills/upgrade/`, `scripts/strata_upgrade_check.sh`) · `light-finish`/`audit` updated · `.gitignore` carve-out (`.strata/*` + `!.strata/state/`) · `bash scripts/test_p2_state.sh` (25/25 green) · version 0.4.0 → 0.5.0.
- Gotcha confirmed during this work: a blanket `.strata/` gitignore line blocks git from descending into the directory at all, so a later `!.strata/state/` negation would silently have no effect — must use `.strata/*` + `!.strata/state/` instead. Verified with `git check-ignore` on both sub-paths.
- Pre-existing defect found, NOT fixed (out of this scope): `wiki/scripts/lint.py`'s "linked from index.md" check flags every single entity/source page as unlisted, even ones plainly listed in `index.md` — reproduced against the pristine pre-P2 tree via `git archive HEAD`, so it predates this work. Worth its own audit finding.

## 2026-09-01T15:02:22Z fix — wiki/scripts/lint.py index-membership check

Corrects the previous entry's "NOT fixed (out of this scope)" note — user asked to fix before merge.
- Root cause: `_read_index_state()` only recognized markdown `[text](path)` links and backtick
  paths as "listed in index.md", never the `[[slug]]` wikilink syntax index.md's own convention
  note declares as canonical and `check_wikilinks`/`check_orphans` already treat as such —
  two inconsistent membership rules in the same file. Fixed by parsing `[[slug]]` in
  `_read_index_state` too, resolved against the real `entities/decisions/sources/sessions` file
  set (same `known_slugs`-style lookup already used elsewhere in the script).
- Second bug, same function: `_INDEX_BACKTICK_RE` matched documentation placeholders like
  a backtick-wrapped `entities/<slug>.md` (angle brackets, not real filenames) as if they were
  real references, producing 3 "references missing file" errors. Fixed by excluding `<`/`>`
  from the backtick-path character class.
- verify: `python3 wiki/scripts/lint.py --no-log` now reports 0 errors, 0 warnings (was 3
  errors + 21 warnings, reproduced identically against the pristine pre-P2 tree via
  `git archive HEAD`, so the bug predated P2 entirely). Mirrored to
  `templates/core/wiki/scripts/lint.py` (was byte-identical to the root copy; kept that way).

## 2026-09-01T15:13:55Z fix — CI failure + real-world multi-path marker bug

GitHub Actions caught what local runs missed. Two fixes:
- scripts/lib/pending_ingest.sh: the retirement regex only matched the FIRST raw/ path
  after the word "ingest" — an ingest line listing several paths at once
  ("ingest raw/A, raw/B -> created: ...") only ever retired the first. Found by testing
  /strata:upgrade against a real external project's 338KB wiki/log.md: 325 markers looked
  outstanding under the fixed-once bug from v0.4.0; the true number was near zero once this
  second retirement bug was also fixed. Regression test added to test_p1_gates.sh (29/29 now).
- scripts/test_p2_state.sh hardcoded the git branch name as "main" without pinning it —
  passed locally (this machine's `init.defaultBranch` happens to be main) and failed on
  GitHub's runner (defaults to master), because the Stop gate resolves the REAL current
  branch at runtime and a name mismatch is a silent miss, not an error. Fixed with an
  explicit `git checkout -b main` right after `git init` in the fixture, verified by
  reproducing the failure locally with `git config --global init.defaultBranch master`.
- verify: `bash scripts/validate.sh` green (29 P1 + 25 P2 assertions); CI run
  https://github.com/Old-G/strata/actions confirms green after push.

## 2026-09-01T15:27:37Z fix — /strata:upgrade must not blind-overwrite a STALE file

Real-world dry run against a real external project (325-marker false backlog investigation
also happened this session) almost overwrote its check_secrets.sh: STALE verdict, but the
diff was the template PLUS ~80 lines of a genuine PII guard + documented AWS-placeholder
exception, not drift behind. skills/upgrade/SKILL.md Step 3 now requires reading the diff:
template-only new lines -> copy; local-only lines present -> stop and surface to the human.
No code change (upgrade is instructions-driven, not a script for this part) — documented in
the skill itself and wiki/entities/upgrade-path.md.
