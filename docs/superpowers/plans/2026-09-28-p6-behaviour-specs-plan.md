# P6 — Behaviour specs (plan)

**Spec:** [2026-09-28-p6-behaviour-specs.md](../specs/2026-09-28-p6-behaviour-specs.md) — decisions
D1–D8 are settled there; this plan orders the work and names the verify for each step.
**Branch:** `strata/p6-behaviour-specs` · **Ships as:** `0.14.0` · **Written:** 2026-09-28

---

## T1 — `lib/requirements.py` (the checker)

Files: `templates/core/scripts/lib/requirements.py` (new), `templates/core/scripts/lib/state_tools.py`
(`plan <branch>` — the one plan lookup, spec D5), both mirrored to `scripts/lib/`;
`scripts/test_p6_requirements.sh` (new).

1. **Tests first** — throwaway repo, the real script, no mocks (same harness as `test_p4_diagrams.sh`).
   `check`: a clean page → silent, exit 0; requirement with no scenario → reported; scenario without
   `WHEN`/`THEN` → reported; zero and two pointers → reported; `test:` path missing → reported;
   `::needle` absent → reported; needle present → clean; duplicate titles → reported; `manual:` →
   counted, not an error; `--strict` exits 1 on an error and 0 on a manual-only page; a page with no
   Requirements → nothing; a non-pointer code span in a scenario → not a pointer; a pointer wrapped
   across lines → resolves; a pytest-style `a::b` needle → resolves; a nested 4-backtick fence →
   skipped; a Requirements section with no `###` → ignored.
   `plan`: exact `*-<segment>-plan.md` (not `*-<segment>-v2-plan.md`); two dates → newest + stderr
   note; none → exit 1. `owed`: no plan → `no plan for` on stderr, exit 0; plan with no delta →
   silent; ADDED not in the page → owed, exit 1; ADDED to a missing page → "create"; ADDED present
   with equal body (different whitespace) → silent, exit 0; MODIFIED with a different body → owed;
   REMOVED still present → owed; two `####` under one verb → both checked; `## Behavior delta` →
   parsed; `### Added [[x]]`, `### ADDED x`, a verb block with no `####`, a duplicate (page, title)
   → error, exit 1; never touches `wiki_debt`; any argument → exit 2.
   `verify`: `bash scripts/test_p6_requirements.sh` — red before the script exists.
2. **Script** — python3 stdlib only; `owed` (no argument) and `check [--strict]` per spec D5. Code
   blocks (```` ``` ````) are skipped when parsing, so a spec that *shows* the format is not parsed as
   one.
   `verify`: T1 cases green.

## T2 — The flow: plan → ingest → close → review → audit

Files: `skills/lean-plan/SKILL.md`, `skills/wiki-ingest/SKILL.md`, `skills/light-finish/SKILL.md`,
`agents/strata-diff-review.md`, `skills/audit/SKILL.md`, `templates/core/WIKI.md` + `WIKI.md`
(identical copies). **No skill description changes** — the routing surface stays as it is.

1. lean-plan: "What a plan carries" gains **Behaviour delta** (when specified behaviour changes —
   format by pointer to `WIKI.md`); the standard tier writes a file when it carries one (D3).
2. wiki-ingest INGEST: a source with `## Behaviour delta` is summarised, never applied (D4); step 3's
   section list gains the optional `Requirements`.
3. light-finish step **1b** (spec D4): on the branch, after green and before the diff review,
   apply the plan's delta, commit it; `verify`: `owed` prints nothing, `check --strict` exits 0.
   Script absent → "run /strata:upgrade", not passed.
4. diff-review: the plan lookup calls `state_tools.py plan`; Pass 1 gains the Scenarios line —
   reads `requirements.py check`, judges only "does the test assert the THEN" and unrecorded
   behaviour changes (D6); header shape untouched.
5. audit Phase 2 step 7 — `check` only (D7).
6. WIKI.md: a "Requirements and behaviour deltas" section — the D2/D3 format once, the D4 timing
   rule, the checker command. Every skill points here instead of repeating the format.
   `verify`: `bash scripts/validate.sh` green (skill structure, §8 routing phrases unchanged).

## T3 — Dogfood + validate

Files: `scripts/validate.sh` (§17 — §15 was taken: `test_p6_requirements.sh` + `requirements.py check --strict` on
this repo's wiki), this plan's own Behaviour delta (below).

1. §17 as the sibling sections run the other behavioural tests.
2. The delta below is merged by light-finish at this branch's close — the first real run of the
   whole loop. Before the merge: `owed` lists 4 items. After: `owed` prints nothing and
   `check --strict` is green with every `test:` pointer resolving.
   `verify`: both outputs recorded in the closing `wiki/log.md` entry.

## T4 — Release

Files: `bash scripts/gen_template_history.sh`; `.claude-plugin/plugin.json` +
`marketplace.json` + the `using-strata` stamp → `0.14.0`; `CLAUDE.md` (status row, the new test
command); wiki — ingest the spec + plan, new entity `behaviour-specs`, update [[executable-wiki]]
(first shipped slice), index + overview + glossary; `diagram_check.sh main`.
`verify`: `bash scripts/validate.sh` green; `diagram_check.sh main` prints nothing (or the
diagram is refreshed through archify).

---

## Behaviour delta

### ADDED [[stop-gate]]
#### Blocks at most once per session
The Stop gate never forces more than one continuation in a session, however much wiki work is owed.

- Scenario: a marker created this session — WHEN a pending-ingest marker was written in the current
  session THEN the first Stop is blocked · `test: scripts/test_p1_gates.sh::blocks on a marker created this session`
- Scenario: second stop — WHEN the gate already blocked once in this session THEN the next Stop
  exits 0 · `test: scripts/test_p1_gates.sh::never blocks twice in one session`

#### Ignores work that predates the session
Markers and dirty files that existed before the session started are not this session's debt.

- Scenario: an old marker — WHEN the only pending marker is older than the session THEN Stop is not
  blocked · `test: scripts/test_p1_gates.sh::ignores markers older than the session (ADR #4)`

### ADDED [[commit-gate]]
#### Refuses a commit while the wiki is behind
A commit fails while any pending-ingest marker is outstanding, and names the file to ingest.

- Scenario: outstanding marker — WHEN a doc was edited and not ingested THEN the commit exits 1 ·
  `test: scripts/test_p1_gates.sh::fails the commit while a marker is outstanding`
- Scenario: names the fix — WHEN the commit is refused THEN the message names
  `wiki-ingest raw/<file>` · `test: scripts/test_p1_gates.sh::names the file to ingest`
- Scenario: ingested and staged — WHEN the ingest is recorded and `wiki/` is staged THEN the commit
  passes · `test: scripts/test_p1_gates.sh::ingesting AND staging passes`

#### Can be skipped on purpose
`STRATA_SKIP_WIKI=1` lets a commit through with markers outstanding.

- Scenario: escape hatch — WHEN `STRATA_SKIP_WIKI=1` is set THEN the commit passes ·
  `test: scripts/test_p1_gates.sh::STRATA_SKIP_WIKI=1 is an escape hatch`
