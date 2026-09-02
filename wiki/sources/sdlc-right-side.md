---
title: "P3 — Closing the right side of the loop (spec + plan)"
type: source
created: 2026-09-01
updated: 2026-09-01
links: [enforcement-layer, native-invocation, stop-gate, branch-state, session-reflector, gardener]
---

# P3 — Closing the right side of the loop

Sources: [spec](../../raw/superpowers/specs/2026-09-01-sdlc-right-side.md) ·
[plan](../../raw/superpowers/plans/2026-09-01-sdlc-right-side-plan.md)

## Summary

Anthropic's "AI-Native SDLC playbook" (2026-08-21) read against Strata v0.6.1. Verdict: it is
independent confirmation of ADR #1 — its governing line ("the skill makes violations rare and
the hook makes them close to impossible") is Strata's own hard rule in other words. Strata
already implements the playbook's left half (Plan → Design → Build). Every gap sits to the right
of Build, and each is a spot where Strata still relies on prose for something both the playbook
and its own rules say must be deterministic.

## The three gaps

1. **Routing is probabilistic and untested.** `validate.sh` §8 checks that skill descriptions
   *contain* EN+RU triggers; nothing checks that a phrase actually fires the right skill. The
   deterministic half has 53 behavioural assertions, the half that picks the skill has zero.
   `claude plugin eval` (ablation arm, `tool_used: Skill` grader) is already in the CLI.
2. **No PreToolUse gates.** "Never hand-edit `raw/`" is enforced by prose plus a pre-commit
   check after the fact; the deterministic form is a hook that refuses the write. Same for
   guarding the feedback loop — no test-file edits while fixing. `grep PreToolUse templates/`
   returns nothing today.
3. **Nobody reviews the diff against the plan.** The council reviews plans before code;
   `light-finish` then asks "green?" and merges. The playbook's compliance pass (diff vs
   `plan.md`) and its "second occurrence → `CLAUDE.md`" rule have no counterpart.

## Decisions (settled in the spec — the implementing session does not reopen them)

- **D1 evals:** `evals/` in the plugin root, native `claude plugin eval init --bare` scaffold as
  the schema; 2 positive cases per skill (EN + RU, verbatim from the description) + negative
  cases for four confusable pairs; grader `tool_used: Skill`, runs 3, threshold 1.0, ablation on.
  The run lives in `scripts/test_routing_evals.sh` + a CI job (costs money); `validate.sh` only
  asserts every skill has a case.
- **D2 guard:** one `PreToolUse` template script, two rules — refuse writes under `raw/`
  (escape `STRATA_ALLOW_RAW_EDIT=1`); refuse test-file edits while `.strata/guard-tests` exists
  (set by `feature`/`refactor` at "make the failing test pass", cleared when green, warned about
  by SessionStart if left behind). Exit 2 + stderr reason; bash-only; fail open. Reaches adopted
  repos via [[upgrade-path]] — P2's first payoff.
- **D3 review:** fifth read-only agent `strata-diff-review` (council frontmatter), invoked by
  `light-finish` between "green?" and "ask once"; passes compliance / bugs / security-lite;
  Important vs Nit, ≤5 nits; advisory (cannot block a merge) but cannot be skipped; findings go
  into [[branch-state]] `gotchas` and then `wiki/log.md`. Second-occurrence rule: a gotcha that
  already appears in `wiki/log.md` proposes one `CLAUDE.md` line in the same closing commit —
  the zero-infrastructure predecessor of [[session-reflector]].
- **D4 not now:** closing-the-loop stays with [[gardener]] (the playbook's `bands.yaml` σ-tier
  pattern recorded as its reference design); `claude -p` in CI, Claude Tag, Claude Security,
  `REVIEW.md` for a PR bot — enterprise-scale, later.
- **Explicitly rejected:** the playbook's org structure (six roles, product-owner sign-offs, an
  `intent.md` stage before `spec.md`). Strata's adaptive ceremony exists to not impose that on
  one person; `office-hours` already yields intent and spec in one dialogue.

## What shipped (v0.7.0, same day)

[[routing-evals]] — 34 generated cases, 34/34 at 1.0 on the first run, gated offline by
`validate.sh` §11 and run locally on demand; D1 amended to headless `claude -p` because
`claude plugin eval` is in early access. [[pre-tool-guard]] — one script, both rules, 24 assertions as `validate.sh` §12, wired in
`claude-settings-hook.json` and this repo. [[diff-review]] — `agents/strata-diff-review.md`,
`light-finish` step 2 + the second-occurrence rule. Toggle lifecycle in `feature`/`refactor`/
SessionStart; `adopt`/`init` copy lists updated; version 0.6.1 → 0.7.0.

## Plan shape

Eight tasks: E1 eval suite → runner + CI + `validate.sh` §11 → A5 guard script → guard tests +
§12 → toggle lifecycle in `feature`/`refactor`/SessionStart → R1 agent → `light-finish` wiring
+ second-occurrence rule → install path, docs, `0.7.0`, and the dogfood gate: the shipping
branch itself closes through the new diff review. Tasks 1–2 and 3–5 are independent and may run
in parallel worktrees.

## Related

[[enforcement-layer]] · [[native-invocation]] · [[stop-gate]] · [[branch-state]] ·
[[upgrade-path]] · [[session-reflector]] · [[gardener]] · [[episodic-state-layer]]
