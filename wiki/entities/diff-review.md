---
title: Diff-vs-plan review (R1)
type: entity
created: 2026-09-01
updated: 2026-09-26
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

**v0.9.0 — lenses and "Decided, not asked"** ([[p5-provenance]], after devdotfast/whiteboard):

- **Lenses:** before any pass, every changed file is bucketed — non-implementation swept out first
  (tests · docs/wiki · generated/lockfiles · config/build · fixtures · renames · formatting), then
  the implementation split by the part of the design each file serves, in reading order. Passes
  run lens by lens; output gains a `LENSES:` block.
- **Decided, not asked:** choices neither the plan nor the user settled (a default, a threshold,
  a fallback, a format, error behaviour), sourced from branch-state `decisions`
  (`trust: session`), commit messages and the diff, each with where it is recorded or
  `unrecorded`. Unrecorded + behaviour-changing is Important. Header lines
  (`VERDICT`/`PLAN`/`DIFF`) keep their exact shape — `light-finish` parses them.
- **First run paid for itself:** over the P4 range it found a real Stop-gate false-interrupt bug
  and a stale diagram pin, both fixed in P5 T6.

**Since v0.14.0 — scenarios ([[behaviour-specs]]):** the plan is found by `state_tools.py plan
<branch>`; when it has a `## Behaviour delta` (already applied by light-finish 1b), Pass 1 runs
`requirements.py check` and `owed` and reports their lines as Important, then judges only what a
script cannot — does each pointed-at test assert the scenario's THEN, and did the diff change
specified behaviour with no delta. The output gains a `Scenarios honoured:` line.

**Since v0.15.0 — LLM-behaviour evidence ([[llm-eval-evidence]]):** a diff that changes a prompt,
skill, tool description, model id/effort or the harness feeding them must show an eval before/after
on a held-out split, or a `no-eval: <reason>`; neither = Important, and so is a prompt carrying a
failing case or the missed phrase verbatim. This one check also runs when there is no plan.

## Related

[[branch-state]] · [[session-reflector]] · [[enforcement-layer]] · [[pre-tool-guard]] · [[behaviour-specs]] · [[llm-eval-evidence]]

## Sources

[[sdlc-right-side]] D3 · [[p5-provenance]] D8
