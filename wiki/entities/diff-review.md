---
title: Diff-vs-plan review (R1)
type: entity
created: 2026-09-01
updated: 2026-09-01
links: [branch-state, session-reflector, enforcement-layer]
---

# Diff-vs-plan review (R1)

## TLDR

`agents/strata-diff-review.md` — a fifth read-only reviewer that runs at **branch close**, on the
**diff**, invoked by `light-finish` before the merge/PR/keep/discard question. Its first pass is
the one nobody else ran: did we build what the plan said?

## Role

The council (`ceo/eng/design/cso`) pressure-tests the *plan* before code exists. After code,
`light-finish` used to ask "green?" and merge. The playbook's REVIEW.md *compliance* pass — the
change matches `spec.md`/`plan.md` — had no counterpart. Now it does, and with it the
playbook's most concrete rule: a mistake flagged for the second time goes into `CLAUDE.md` in
the same commit.

## Current solutions

**Shipped in v0.7.0.** Same frontmatter and `tools: Read, Grep, Glob, Bash` as the council.

- **Finds the plan itself:** `docs/superpowers/plans/*<branch-slug>*`, else the [[branch-state]]
  file's `goal`/`verify`, else it returns `VERDICT: no plan to check against` and stops — a
  legitimate outcome for a trivial-tier change, not a failure.
- **Three passes**, every finding tagged and cited (`plan §` ↔ `file:line`): **compliance**
  (done as planned / done differently / planned-not-done / done-not-planned / verify lines
  honoured), **bugs** in the changed lines only, **security-lite** (hands off to
  `strata-cso-review` if anything real surfaces). Important vs Nit; at most five nits.
- **Advisory, unskippable:** it cannot block a merge — the human decides — but `light-finish`
  step 2 cannot skip running it, and every Important finding is written into the branch state's
  `gotchas`, which step 5 folds into `wiki/log.md`. A waved-through finding still leaves a trace.
- **Second-occurrence rule:** `light-finish` greps `wiki/log.md` for each gotcha; a hit proposes
  one line for `CLAUDE.md`'s "Things Claude gets wrong", added in the closing commit on approval.
  This is the zero-infrastructure predecessor of [[session-reflector]]: if it changes plans, the
  reflector has a reason to exist.

## Related

[[branch-state]] · [[session-reflector]] · [[enforcement-layer]] · [[routing-evals]]

## Sources

[[sdlc-right-side]] D3
