---
title: REVIEW.md and the review loop
type: entity
created: 2026-10-31
updated: 2026-10-31
links: [diff-review, branch-state, upgrade-path]
---

# REVIEW.md and the review loop

## TLDR

v0.18.0, after Anthropic's "How the Claude Code team does code review". The code owner writes a
5–15 line `REVIEW.md`; every reviewer reads it, labels findings **Important / Nit / Pre-existing**,
reports one row per bug class, never repeats itself and opens with the count. The review → fix loop
stops after three rounds and asks the human to reconsider the approach; a PR carries Testing /
Risk / How to revert, drafted by the agent and confirmed by the person.

## Role

Before 0.18.0 the [[diff-review]] knew Important vs Nit and five nits, from Strata's own rules. It
did not know what *broken* means in a given repo, blamed the branch for old bugs it only touched,
reported one line of a pattern that sat in five places, and nothing stopped a fix → re-review loop
from running forever.

## Current solutions

- **The file** — `templates/core/REVIEW.md.tmpl`: broken here means · nit cap · skip · always a
  human · `file:line` evidence · Pre-existing apart · summary opens with the count ("Nothing to
  fix"). `adopt` Phase 2 step 5 and `init` Phase 2 step 11 draft it from the repo and show it;
  `upgrade` Step 7 offers it; `strata-upgrade-all` names repos without one. Never written unasked.
  Strata's own: `REVIEW.md` at the root.
- **Pre-existing is a script, not a judgement** — `scripts/lib/line_origin.sh <base> <file>:<line>`
  → `PRE-EXISTING | BRANCH | UNCOMMITTED | UNKNOWN`, from plain `git blame` and `merge-base
  --is-ancestor` against the merge-base (never the round's SINCE). No `-M/-C/-w`: a moved line
  counts as the branch's — a false "pre-existing" hides a bug, a false "branch" costs a look.
- **Three rounds** — `state_tools.py review-round <branch>` (cap `REVIEW_ROUNDS = 3`, one place)
  prints `ROUND n/3 SINCE <sha|base>` and writes nothing; `--done` records the round in the
  [[branch-state]] (`review: {rounds, head}`) after the report, so an interrupted review is retried
  with the same scope (Codex review, 0.18.0 pre-release). Round 2–3 read `git diff <SINCE>` only and
  mark PREVIOUS findings Fixed / Still open; a still-open Important keeps VERDICT off CLEAN. Past
  round 3 both calls exit 3 without counting; `--reset` after the human changes the approach. No
  state file → `--done` makes one with an empty goal, and an empty goal is not a plan (else the
  reviewer checked a trivial branch against "close branch X").
- **Council** — eng / CSO / design carry the same five rules and a `Label` column; the CEO
  reviewer judges scope, not lines, and kept its shape.
- **PR** — `light-finish` step 4: `## Testing` / `## Risk` / `## How to revert`, into the repo's own
  PR template when it has one.

## Related

[[diff-review]] · [[branch-state]] · [[upgrade-path]]

## Sources

`docs/superpowers/plans/2026-10-31-review-md-plan.md` · `reference/review-md.md` ·
`scripts/test_p7_review.sh`
