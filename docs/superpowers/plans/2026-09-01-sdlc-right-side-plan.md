# P3 — Closing the right side of the loop (plan)

**Status:** plan, approved for a new session **Date:** 2026-09-01 **Tier:** risky
**Source:** [spec](../specs/2026-09-01-sdlc-right-side.md) · [[sdlc-right-side]]

---

## Intent

When this is done, Strata's probabilistic half (which skill fires) is tested the way its
deterministic half already is; a write under `raw/` or to a test file mid-fix is refused before
it happens; and no branch closes through `light-finish` without a read-only check of the diff
against the plan. All three ship as templates and reach adopted repos through `/strata:upgrade`.

## Constraints

Carried from the spec, in one line each: mechanisms not roles · new hooks copy the Stop gate's
shape (bash, grep/sed, fail open, env escape, <100 ms) · new reviewer copies the council's
frontmatter · `validate.sh` stays offline and free, the eval *run* is a separate script + CI
job · every gate escapable · `CLAUDE.md` ≤ 200 · version `0.6.1 → 0.7.0` in both manifests ·
the shipping branch dogfoods every piece of this.

Decisions D1–D4 in the spec are settled. Do not reopen them; if one turns out to be wrong in
practice, record why in the branch state and in `wiki/log.md`, then proceed with the smallest
correction.

## Success criterion

As in the spec, verbatim: `validate.sh` green with two new structural checks; the routing eval
suite at 1.0 with the ablation arm confirming the plugin fired; fixture-verified guard behaviour
for both rules and both escapes; `light-finish` on the shipping branch itself produces a
plan-compliance findings table and folds it into `wiki/log.md`.

---

## Tasks

Work the tasks in order; 1–2 and 3–5 are independent of each other and may run in parallel
worktrees if two sessions are available. 6 depends on 5; 7–8 depend on everything.

### Task 1 — Routing eval suite (E1)

Run `claude plugin eval init --bare probe` once at the plugin root and read what it emits — that
scaffold is the case contract; mirror it, delete the probe. Then, for each `skills/*/SKILL.md`:
two positive cases (one EN phrase, one RU phrase, copied **verbatim** from that skill's
`description`), grader `tool_used: Skill` expecting that skill. Add negative cases for the four
confusable pairs named in D1, grading that the neighbour did **not** fire. Name cases
`routing-<skill>-{en,ru,neg-<neighbour>}` so `--case 'routing-*'` selects the whole suite.
Reference for trigger phrases: `scripts/validate.sh` §8 already extracts each description —
reuse that regex rather than re-parsing frontmatter by hand.
**verify:** `claude plugin eval . --case 'routing-*' --runs 3 --threshold 1.0 --max-cost-usd 5
--json` exits 0; the JSON shows every case at 1.0 and the ablation delta non-zero (baseline arm
did not fire the skill).

### Task 2 — Eval runner, CI job, structural check

`scripts/test_routing_evals.sh`: wraps the command above, fails loudly if `ANTHROPIC_API_KEY`
is absent (it must never silently pass), prints the per-case table. New
`.github/workflows/routing-evals.yml` on `pull_request` with `paths: [skills/**, agents/**,
CLAUDE.md, evals/**]` plus a weekly `schedule`, mirroring the playbook's `agent-evals.yml`
shape; secret `ANTHROPIC_API_KEY`; `--max-cost-usd` set. `validate.sh` gets **§11 — every
skill has at least one routing case** (a `for d in skills/*/` glob against `evals/`), so the
suite cannot rot when a skill is added without a case. Note in `CONTRIBUTING.md`: adding a skill
= adding its two cases.
**verify:** `bash scripts/validate.sh` green with §11 listed; remove one case temporarily and
confirm §11 goes red, then restore; the workflow YAML parses (`python3 -c "import yaml"` is
not guaranteed — use `ruby -ryaml -e 'YAML.load_file(ARGV[0])'` as `ci.yml` was verified, or
let the first push be the check).

### Task 3 — PreToolUse guard script (A5)

`templates/core/scripts/hooks/strata_pre_tool_guard.sh` per D2. Shape to copy:
`templates/core/scripts/hooks/strata_stop_gate.sh` — header comment that states loop-safety /
fail-open order first, `set -uo pipefail`, payload via `cat` when stdin is not a tty,
`file_path` extracted with `sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'`,
`REPO_ROOT` via `git rev-parse`, paths normalised relative to it. Rule (a) raw/ + escape
`STRATA_ALLOW_RAW_EDIT=1`; rule (b) test patterns + `.strata/guard-tests` toggle. Exit 2 with
a one-line reason on stderr that names the escape. Anything unparseable → exit 0. Add the
`PreToolUse` block to `templates/core/claude-settings-hook.json` (matcher
`Edit|Write|MultiEdit`) and to this repo's own `.claude/settings.json`; mirror the script to
`scripts/hooks/`.
**verify:** `bash -n` clean; manual: `echo '{"tool_name":"Edit","tool_input":{"file_path":"raw/x.md"}}'
| bash scripts/hooks/strata_pre_tool_guard.sh; echo $?` → `2` with reason; same with
`STRATA_ALLOW_RAW_EDIT=1` → `0`; `docs/x.md` → `0`; `tests/test_a.py` → `0` without the toggle,
`2` with it; `echo 'garbage' | …` → `0`.

### Task 4 — Guard tests (`scripts/test_p3_guards.sh`) + validate §12

Same harness as `scripts/test_p2_state.sh` (mktemp repo, real shipped script, `git checkout -q
-b main` pinned — do not repeat the CI branch-name flake). Assertions: the six cases from Task 3's
verify, plus a best-of-7 latency check under 100 ms (copy the loop from `test_p1_gates.sh`),
plus "toggle left behind → SessionStart prints a warning line" once Task 5 lands. Wire as
`validate.sh` **§12**, same block shape as §9/§10.
**verify:** `bash scripts/test_p3_guards.sh` green; `bash scripts/validate.sh` lists §12 green.

### Task 5 — Toggle lifecycle in `feature`, `refactor`, `SessionStart`

In `skills/feature/SKILL.md` and `skills/refactor/SKILL.md`, at the TDD step "make the failing
test pass without touching the test": `touch .strata/guard-tests` before, `rm -f
.strata/guard-tests` once green — one line each, next to the existing verify. In
`templates/core/scripts/hooks/strata_session_start.sh` (and its root mirror): if
`.strata/guard-tests` exists, print one line: `Stale test-file guard: .strata/guard-tests is set
— a previous fix session did not clear it; remove it or tests stay read-only.` Keep the block
inside the ≤50-line budget (the `test_p1_gates.sh` budget assertion must stay green).
**verify:** `grep -n guard-tests skills/feature/SKILL.md skills/refactor/SKILL.md` shows the
touch/rm pair in both; `test_p3_guards.sh` asserts the warning line; `test_p1_gates.sh` still
28+/28+ with the budget check green.

### Task 6 — `agents/strata-diff-review.md` (R1)

Copy the frontmatter shape of `agents/strata-eng-review.md` (name / description / `tools: Read,
Grep, Glob, Bash`). Description must say it runs at **branch close** on the **diff**, so it never
competes with the plan-stage council in routing. Body per D3: locate the plan (glob
`docs/superpowers/plans/*<branch-slug>*` → else branch state via `python3
scripts/lib/state_tools.py path <branch>` → else "no plan to check against", stop); obtain the
diff (`git diff <base>...HEAD`, base = the branch's merge-base with the default branch); three
tagged passes; Important vs Nit; ≤5 nits; every finding `file:line` or `plan §`. Read-only —
state it three times like the council files do.
**verify:** `validate.sh` §4 green (frontmatter); dry-run the agent on this branch's own diff
against this plan and confirm a findings table with citations comes back.

### Task 7 — `light-finish` wiring + second-occurrence rule

Insert **step 2 — Plan compliance** between "Green?" and "Ask once": invoke
`strata-diff-review`; write its Important findings into the branch state `gotchas` (P2 CLI);
if the human wants a finding fixed, that is a loop back to step 1, not a merge. Then the
second-occurrence rule: for each gotcha, `grep -F` a distinctive phrase in `wiki/log.md`; on a
hit, propose one line for `CLAUDE.md` "Things Claude gets wrong" and, on approval, add it in
the same closing commit. Existing steps renumber; the drift-close step keeps folding state into
`wiki/log.md`.
**verify:** the skill text contains the new step and the rule; Task 8's dogfood run exercises
it end-to-end.

### Task 8 — Install path, docs, version, dogfood

`skills/adopt` + `skills/init`: add the guard script to the copy list (the settings block is
already merged wholesale). `README.md` hooks table: new row for `PreToolUse`; commands table
unchanged (no new skill). `CLAUDE.md`: phase-table row "Right side of the loop (E1 evals · A5
PreToolUse guard · R1 diff review)"; commands block gets `test_p3_guards.sh` and
`test_routing_evals.sh`. `CHANGELOG.md` `[0.7.0]`. Both manifests `0.7.0`. Then the dogfood
gate: close **this** branch through `light-finish` — the diff review must run against this plan,
its findings must land in `wiki/log.md`, and the routing evals must pass on the edited skill
descriptions. Ingest spec + plan into `wiki/` (source pages, index rows, log line retiring both
markers) before the closing commit — the commit gate will refuse otherwise, which is the point.
**verify:** `bash scripts/validate.sh` fully green (§1–§12); `bash scripts/test_routing_evals.sh`
1.0; `bash scripts/lib/pending_ingest.sh` prints nothing; `git log -1` on `main` shows the
closing commit with the diff-review findings referenced in `wiki/log.md`.
