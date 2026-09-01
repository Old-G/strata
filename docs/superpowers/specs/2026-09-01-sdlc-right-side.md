# P3 — Closing the right side of the loop

**Status:** spec, approved for a new session **Date:** 2026-09-01 **Tier:** risky
**Source:** "The AI-Native SDLC playbook" (claude.com/blog, L. Claxton, 2026-08-21) read against
Strata v0.6.1 · [[episodic-state-layer]] [[enforcement-layer]] [[native-invocation]]

---

## Intent

The playbook is independent confirmation of Strata's central bet. Its governing sentence —
*"a skill is a control, though an advisory one… a policy that must always hold needs something
deterministic behind the skill… the skill makes violations rare and the hook makes them close to
impossible"* — is ADR #1 in someone else's words. Strata already implements the playbook's left
half (Plan → Design → Build): committed artifacts as the hand-off chain, plan-first, a ≤1-page
`CLAUDE.md`, skills as institutional knowledge, hooks behind them.

The gaps are all **to the right of Build**, and each is a place where Strata today relies on
prose for something the playbook (and Strata's own hard rules) say must be deterministic:

1. **Routing is probabilistic and untested.** `README.md` says so verbatim ("Routing is still
   probabilistic — which is exactly why the hooks below are not"). `validate.sh` §8 checks that
   every skill description *contains* Russian trigger phrases and a `## Do NOT use when` guard.
   Nothing checks that «страта отстала» actually fires `upgrade`, or that «есть идея» does not
   leak into `feature`. The deterministic half has 53 behavioural assertions; the half that
   decides *which skill runs at all* has zero. `claude plugin eval` exists in the installed CLI
   (with an ablation arm and a `tool_used: Skill` grader) — the tool is there, the suite is not.
2. **No PreToolUse gates.** "Skills never hand-edit a target project's `raw/`" is a hard rule in
   `CLAUDE.md`, enforced by prose plus a pre-commit check *after* the damage. The playbook's
   deterministic form is a `PreToolUse` hook that refuses the write. Same for the feedback loop:
   an agent fixing code must not be able to weaken the test on that code — a hook that blocks
   test-file edits during a fix task. Strata ships `PostToolUse`, `SessionStart`, `Stop`, and
   pre-commit; `grep -r PreToolUse templates/ skills/` returns nothing.
3. **Nobody reviews the diff against the plan.** The council pressure-tests the *plan* before
   code. After code, `light-finish` asks "green?" and merges. The playbook's REVIEW.md
   *compliance* pass — does the change match `spec.md`/`plan.md` — has no counterpart, and
   neither does its most concrete rule: a mistake flagged for the second time goes into
   `CLAUDE.md` in the same commit.

When this ships: a change to any skill description is gated by evals that prove the routing
still holds; a write under `raw/` (or to a test file mid-fix) is refused with a reason before it
happens; and a branch cannot close through `light-finish` without a read-only pass that checked
the diff against the plan it was supposed to implement.

## Constraints

- **Take mechanisms, not org structure.** The playbook is written for enterprises: product
  owners, release managers, change management, an `intent.md` home for non-technical authors.
  Strata's adaptive ceremony (trivial / standard / risky) exists precisely to *not* impose fixed
  heavy stages on one person. No new stage, no new role, no `intent.md` before `spec.md` —
  `office-hours` already produces both in one dialogue.
- **Reuse the existing enforcement shapes.** New hooks follow the Stop gate's contract: bash
  only, `grep`/`sed` payload parsing, fail open on anything unparseable, escapable with an env
  var, measured fast path. New review is a read-only `agents/strata-*` subagent with the same
  frontmatter and tool set as the four council members.
- **No new runtime dependencies.** Evals use the CLI's native `claude plugin eval` — nothing
  installed. `validate.sh` stays free and offline: the eval *run* lives in a separate script and
  CI job (it costs money and needs a key); `validate.sh` only asserts, structurally, that every
  skill has a case, so the suite cannot rot silently.
- **Gates stay escapable and self-limiting** (hard rule). Both PreToolUse rules have an env
  escape; the test-file guard is a toggle file that cannot outlive the session unnoticed.
- `CLAUDE.md` ≤ 200 lines. Release rule: shipped behaviour changes → `0.6.1 → 0.7.0` in both
  manifests (`validate.sh` §2c already enforces one version everywhere).
- **Dogfood on itself.** The branch that ships this work must be closed through the new
  `light-finish` diff-review step, and its own skill edits must pass the new routing evals.

## Decisions (made here so the implementing session does not re-litigate)

**D1 — Routing evals: one case per skill, plus the confusable pairs, native format.**
Cases live at `evals/` in the plugin root, in whatever shape `claude plugin eval init --bare`
emits (that scaffold is the contract — copy it, do not invent a schema). Each of the 13 skills
gets two positive prompts, one EN and one RU, taken **verbatim** from that skill's own
`description` triggers — the eval must test the routing surface as written, not a paraphrase.
The four pairs that share vocabulary get negative cases too, graded "expected skill fired AND
the neighbour did not": `feature`/`refactor`, `office-hours`/`lean-plan`, `wiki-ingest`
question/`using-strata`, `upgrade`/`adopt`. Target 25–35 cases (the playbook's 20–50).
Grader: `tool_used: Skill` with the expected skill name; runs = 3; ablation `with-without` on
(it also proves the plugin is what fires the skill). Threshold 1.0 per case — a routing test
that passes two times out of three is a routing bug, not flakiness.

**D2 — One PreToolUse script, two rules, shipped as a template.**
`templates/core/scripts/hooks/strata_pre_tool_guard.sh`, matcher `Edit|Write|MultiEdit`,
exit 2 with the reason on stderr (the Claude Code contract — the message reaches the model).
Rule (a): path under `raw/` → refuse, "raw/ mirrors docs/ — edit docs/ instead"; escape
`STRATA_ALLOW_RAW_EDIT=1`. Rule (b): path matches the project's test-file patterns
(`tests/`, `test_*.py`, `*_test.*`, `*.spec.*`, `*.test.*`) **while `.strata/guard-tests`
exists** → refuse, "fix the code, not the test"; escape: delete the toggle. The toggle is
created by `feature`/`refactor` at the "make the failing test pass" step and removed once green;
`SessionStart` prints one warning line if it finds the toggle at session start, so a stale
guard cannot silently block the next session. Fail open on any payload it cannot parse.
Delivered to every adopted repo by the existing `/strata:upgrade` path — this is the first
payoff of P2's re-sync work.

**D3 — Diff-vs-plan review is a fifth read-only agent, invoked by `light-finish`.**
`agents/strata-diff-review.md`, same frontmatter and `tools: Read, Grep, Glob, Bash` as the
council. Input: the branch's plan (`docs/superpowers/plans/*<slug>*` if one exists, else the
branch state's `goal`/`verify`) and `git diff <base>...HEAD`. Three passes, each finding
tagged: **compliance** (files that change, order of work, proof — against the plan), **bugs**,
**security-lite** (hand off to `strata-cso-review` if anything real surfaces). Important vs Nit
defined in the agent; at most five nits, the rest a count. **Advisory:** it cannot block a
merge — the human decides — but `light-finish` cannot skip running it, and its findings land
in the branch state's `gotchas` before the state is folded into `wiki/log.md`. When there is no
plan (trivial tier), it records "no plan to check against" and stops; that is a legitimate
outcome, not a failure. **Second-occurrence rule:** `light-finish` greps `wiki/log.md` for each
gotcha; a repeat proposes one line for `CLAUDE.md`'s "Things Claude gets wrong" (the human
approves the line, the skill writes it in the same closing commit). This is the concrete,
zero-infrastructure predecessor of [[session-reflector]] — if it changes plans, the reflector
has a reason to exist; if it does not, it never needed to.

**D4 — Explicitly not now.** Closing-the-loop (deterministic detector → σ-tiers → `intent.md`)
stays with [[gardener]]; the playbook's `bands.yaml` pattern is recorded there as the reference
design. `claude -p` in CI, Claude Tag on-call, Claude Security scans: enterprise-scale plays
for later. `REVIEW.md` as a file for GitHub's review service: not applicable, the diff review
here runs inside `light-finish`, not on a PR bot.

## Success criterion

`bash scripts/validate.sh` green including two new structural checks (every skill has a
routing case; PreToolUse guard tests pass); `bash scripts/test_routing_evals.sh` scores 1.0 on
every case with the ablation arm confirming the plugin fired the skill; in a fixture repo an
Edit to `raw/x.md` is refused with a reason and `STRATA_ALLOW_RAW_EDIT=1` lets it through, and
a test-file edit is refused only while `.strata/guard-tests` exists; `light-finish` on the very
branch that ships this produces a plan-compliance findings table with `file:line` citations and
folds it into the branch's `wiki/log.md` entry.

Plan: [2026-09-01-sdlc-right-side-plan.md](../plans/2026-09-01-sdlc-right-side-plan.md)
