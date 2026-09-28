---
title: "P6 — Behaviour specs: OpenSpec's delta→archive on Strata's own mechanics (spec + plan)"
type: source
source: raw/superpowers/specs/2026-09-28-p6-behaviour-specs.md
created: 2026-09-28
updated: 2026-09-28
links: [behaviour-specs, executable-wiki, diff-review, branch-state, stop-gate, commit-gate]
---

# P6 — Behaviour specs

Sources: [spec](../../raw/superpowers/specs/2026-09-28-p6-behaviour-specs.md) ·
[plan](../../raw/superpowers/plans/2026-09-28-p6-behaviour-specs-plan.md) · status: eng-reviewed
(approve-with-concerns, 13 findings folded in) and implemented 2026-09-28 on
`strata/p6-behaviour-specs`, shipping as v0.14.0.

## Summary

[OpenSpec](https://openspec.dev/) (Fission-AI, MIT) read against v0.13.1. Every part of it but one
already had a Strata counterpart — explore ↔ `office-hours`, proposal/design/tasks ↔
`docs/superpowers`, a folder per change ↔ [[branch-state]], verify ↔ [[diff-review]], schemas ↔
the tiers in `feature`, AGENTS.md ↔ [[wiki-emit]]. The missing one was `openspec/specs/`: a living
statement of what the system **must do now**, changed only by deltas that are merged when a change
closes. Strata's plans are frozen once a branch closes and its wiki describes components in prose,
so nothing answered "what must X do" at the level of a checkable requirement. Prior art: a private
project's development guide (2026-03-17) had rated OpenSpec "optional for phase 2+" and not
adopted it; nothing from OpenSpec had been carried into Strata before.

The design (D1–D9) puts the living spec inside the wiki instead of beside it: an optional
`## Requirements` section on entity pages (D1, D9 reserved heading), each requirement a `###`
title + statement + `- Scenario:` items with `WHEN`/`THEN` and exactly one evidence pointer — a
code span starting `test:` or `manual:` (D2). A plan that changes specified behaviour carries a
`## Behaviour delta` of `ADDED|MODIFIED|REMOVED [[entity]]` blocks and is therefore always a file
(D3). The timing rule is the heart of it (D4): the plan is ingested early — the commit gate forces
that — so **ingest never applies a delta**; `light-finish` step 1b applies it on the branch, after
green and before the diff review and the merge/PR/keep/discard question.

The deterministic half is `scripts/lib/requirements.py` (D5, the P4 split: script reports, agent
writes): `check` lints every Requirements section and proves each `test:` pointer resolves;
`owed` compares the branch plan's delta with the pages and exits 1 while anything is owed or the
delta is malformed. The plan lookup became one implementation, `state_tools.py plan <branch>`.
[[diff-review]] reads the script's output and judges only what it cannot — does the test assert
the THEN, did behaviour change without a delta (D6); `audit` runs `check` (D7). Strata dogfoods it
on [[stop-gate]] and [[commit-gate]] (D8) — the plan's own delta is what light-finish merged.

The eng review changed the design more than it approved it: the merge point moved from step 5
(after the merge — where the plan lookup on the base branch finds nothing and the verify passed
vacuously — or after the push, outside the PR) to step 1b; `owed` stopped writing `wiki_debt`
(mid-branch an unapplied delta is correct, and the Stop gate would have blocked every later
session for debt nobody may pay yet); a malformed delta became an error instead of silence;
pointers became only `test:`/`manual:` code spans after the dogfood delta's own
`` `STRATA_SKIP_WIKI=1` `` would have broken the naive reading. Accepted risk: a branch merged
without light-finish never applies its delta.

The diff review at branch close (the new scenarios pass, first run) caught what the session had
not: a private project name in the spec — `validate.sh` §7 had passed only because it scans
*tracked* files and the spec was not yet added, so the recorded "validate PASSED" was false;
the branch was squash-merged so the name never reached the public history. It also caught
`gen_template_history.sh` silently dropping two shipped hashes lost in an earlier history rewrite
(now a union), a scenario whose test asserted only half its THEN (split in two), and six
implementation choices nobody had been shown (now listed in the spec).

## Entities touched

[[behaviour-specs]] (new) · [[executable-wiki]] (first shipped slice) · [[diff-review]] ·
[[branch-state]] (`plan`) · [[stop-gate]] · [[commit-gate]] (Requirements).
