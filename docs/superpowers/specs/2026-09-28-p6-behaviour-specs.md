# P6 — Behaviour specs: OpenSpec's delta→archive on Strata's own mechanics

**Status:** design · **Written:** 2026-09-28 · **Branch:** `strata/p6-behaviour-specs` · **Ships as:** `0.14.0`
**Source read:** [OpenSpec](https://openspec.dev/) (Fission-AI, MIT) — `openspec/specs/` as the
living source of truth, `openspec/changes/<name>/` with delta specs (ADDED/MODIFIED/REMOVED/RENAMED),
`archive` merging deltas into the specs when a change closes; every requirement carries
WHEN/THEN scenarios.

## Intent

Strata answers "how does X work" (wiki entities, narrative) and "what did we plan" (dated
specs/plans, frozen once the branch closes). It has no place that answers **"what must X do right
now"** at the level of checkable requirements — the one layer OpenSpec has that we do not. Every
other part of OpenSpec already has a Strata counterpart:

| OpenSpec | Strata |
|---|---|
| `/opsx:explore` | `office-hours` |
| proposal / design / tasks | `docs/superpowers/{specs,plans}` |
| a folder per change | `.strata/state/<branch>.json` |
| `/opsx:verify` | `strata-diff-review` |
| schemas / profiles | tiers in `feature` |
| AGENTS.md for 50+ tools | [[wiki-emit]] (backlog) |
| **`specs/` + delta → archive merge** | **nothing** |

After P6: an entity page may carry a `## Requirements` section; a plan that changes behaviour
carries a `## Behaviour delta` against those sections; `light-finish` merges the delta at branch
close; a deterministic checker says what is still owed and whether every scenario points at a
test that exists; `diff-review` checks the diff against the scenarios; `audit` reports the rot.

Prior art: a private project's development guide (2026-03-17) had rated OpenSpec "optional
for phase 2+ — brownfield-first, delta markers, light" and did not adopt it. Nothing from OpenSpec
was ever carried into Strata before this spec.

## Decisions

**D1 — Requirements live inside entity pages, not in a second tree.** A `## Requirements`
section after `## Current solutions`. No `wiki/specs/` or `openspec/` directory: two places that
describe the same component would drift from each other, which is the exact failure Strata
exists to prevent. The section is optional per page — a page without it is not a finding.

**D2 — The format (the checker's contract).**

```markdown
## Requirements

### Blocks at most once per session
The Stop gate never forces more than one continuation in a session.

- Scenario: second stop in the same session — WHEN the gate has already blocked once in this
  session THEN the next Stop exits 0 · `test: scripts/test_p1_gates.sh::never blocks twice in one session`
- Scenario: … — WHEN … THEN … · `manual: needs a live Claude Code session`
```

- A requirement is a `### ` heading inside `## Requirements` (up to the next `## `). Title
  unique within the page — it is the key deltas address.
- Body: one or more sentences stating the behaviour, then ≥1 scenario.
- A scenario is a list item starting `- Scenario:` (continuation lines indented, joined with one
  space before parsing); it must contain `WHEN` and `THEN` (uppercase), and exactly one **evidence
  pointer** — a code span whose content starts `test:` or `manual:`. Other code spans are text
  (``WHEN `STRATA_SKIP_WIKI=1` is set`` is fine). `test: <repo-relative path>[::<needle>]`: the
  needle is split off at the *first* `::` and passes when the whole string, or every `::`
  segment of it, is found in the file (pytest ids `tests/x.py::TestA::test_b`).
- `manual:` is the escape hatch (OpenSpec: "tested **or explicitly validated**") — some behaviour
  only a live session can show. It is counted and reported, never a failure.

**D3 — The delta lives in a plan file, always.** A plan whose change alters specified behaviour
gets a `## Behaviour delta` section:

```markdown
## Behaviour delta

### ADDED [[stop-gate]]
#### Asks for the lesson when a session hurt
<full requirement body, same shape as D2>

### MODIFIED [[stop-gate]]
#### Blocks at most once per session
<the full new body — replaces the old one; title must already exist>

### REMOVED [[commit-gate]]
#### Honours STRATA_SKIP_WIKI
Why: <one line>
```

A verb block holds one or more `####` requirements, up to the next `###`/`##`; a requirement
body runs to the next `####`/`###`/`##`. The same (page, title) twice in one delta, a `###` that is
not exactly `ADDED|MODIFIED|REMOVED [[slug]]`, and a verb block with no `####` are errors — a typo
must never read as "no delta". The section heading is matched as `## Behaviou?r delta`, any case.

No RENAMED: a rename is REMOVED + ADDED (OpenSpec needs it for `archive`'s text surgery; our merge
is agent work, D5). Because the merge happens at branch close — often in another session — the
delta needs a durable home: **a plan with a Behaviour delta is always a file**, on the standard tier
too (lean-plan: "standard — a short bullet plan in the conversation, *unless it carries a
Behaviour delta*"). Trivial work does not get a delta; if it changes specified behaviour it was
not trivial (bias up).

**D4 — Ingest never applies a delta; light-finish does, on the branch, before the choice.** The
raw-mirror hook marks the plan as pending the moment it is written, and the commit gate forces its
ingest early in the branch. If ingest merged the delta, the wiki would state behaviour that has not
been built. So INGEST of a source with a `## Behaviour delta` summarises it in `sources/` and leaves
every `## Requirements` section alone. `light-finish` applies it in a new step **1b** — after
green, before the diff review and before the merge / PR / keep / discard question — and commits
it on the branch. It then rides along with merge, PR and keep; discard throws it away. (Eng #1:
applying it in step 5 would land after a local merge — on the base, where the plan lookup finds
nothing and the verify passes vacuously — or after the push, outside the PR.) This is OpenSpec's
`archive`.

Lifecycle of one delta:

| Step | Actor | Branch | Check |
|---|---|---|---|
| written in the plan | lean-plan | feature | — |
| mirrored to `raw/`, ingested as a summary | hook · wiki-ingest | feature | commit gate |
| built, tests green | feature | feature | the floor |
| **applied to `wiki/entities/`, committed** | light-finish 1b | feature | `owed` silent · `check --strict` |
| compliance incl. scenarios | strata-diff-review | feature | reads `check` |
| merge / PR / keep / discard | human | → base | — |
| frozen with the plan | — | base | audit `check` |

**D5 — Script checks, agent writes (the P4 split).** Same division as `diagram_check.sh`: a
deterministic checker reports, the agent edits prose. One file,
`templates/core/scripts/lib/requirements.py` (auto-synced with the rest of `scripts/**`;
`wiki/scripts/lint.py` is not, so the check does not go there), two subcommands:

- `owed` — the current branch's plan, found by `state_tools.py plan <branch>` (below), vs the
  wiki: ADDED/MODIFIED → the entity page lacks that title or its body differs; ADDED to a page
  that does not exist → "create the page"; REMOVED → the title is still there. The compared body
  is everything after the `###`/`####` heading line up to the next heading, whitespace runs
  collapsed to one space, ends trimmed. Prints nothing and exits 0 when nothing is owed; exits 1
  when something is owed or the delta is malformed (so the light-finish verify cannot pass on a
  typo); 2 on usage. No argument — it runs on the branch, before integration (D4). Not a gate,
  never a hook. **It does not write `wiki_debt`** (eng #3): mid-branch an unapplied delta is the
  correct state, and Stop-gate trigger (c) would block every later session on the branch for debt
  nobody may pay yet — `state_tools` has no way to clear it either.
- **One plan lookup, one implementation** (eng #2): `state_tools.py plan <branch>` — the last
  `/`-segment of the branch, matched exactly as `docs/superpowers/plans/*-<segment>-plan.md`;
  several matches → all listed on stderr, the newest date prefix wins; none → exit 1. `owed`,
  `light-finish` and `strata-diff-review` all use it instead of re-describing a glob.
- `check [--strict]` — lints every `wiki/entities/*.md` Requirements section: a requirement with
  no scenario; a scenario without `WHEN`/`THEN`; a scenario with zero or two pointers; a `test:`
  path that does not exist; a `::needle` not found in it; duplicate titles. `manual:` scenarios are
  counted in a summary line. Exit 0 by default; `--strict` exits 1 on any error (used by this
  repo's `validate.sh`, dogfood).

The checker proves a pointer **resolves**, not that the test passes — running tests is CI's and
the floor's job. This is the first shipped slice of [[executable-wiki]]: a scenario is a wiki
claim that names its own check.

**D6 — `diff-review` checks the diff against the scenarios.** It runs `requirements.py check`
and reports its errors as Important — the deterministic half is the script's. Its own judgement
covers only what a script cannot: does the pointed-at test actually assert the THEN; and does the
diff change behaviour a Requirements section states (or a test a scenario points at) with no delta
saying so. "Was it run" is not asked (eng #9): untouched existing tests cannot show it, and the
floor already demands evidence. `manual:` = listed, not a finding. The `VERDICT:/PLAN:/DIFF:`
header shape does not change (light-finish parses it).

**D7 — `audit` Phase 2 gets step 7.** `python3 scripts/lib/requirements.py check`: a broken
`test:` pointer = HIGH ("the wiki claims a test that does not exist"); a requirement without a
scenario / a malformed scenario = MEDIUM; the `manual:` count = LOW note. No `owed` (eng #4 — on a
feature branch an unapplied delta is correct, so it would always fire). No Requirements anywhere
= not a finding. Script absent (repo not upgraded yet) → `Coverage` says "run /strata:upgrade";
light-finish treats its verify as not passed rather than skipped (eng #11).

**D8 — Dogfood on two pages, not the whole wiki.** Strata's own [[stop-gate]] and [[commit-gate]]
get Requirements sections pointing at real `test_p1_gates.sh` cases, and this repo's
`validate.sh` runs `check --strict`. Back-filling every entity is not in scope — the section grows
as branches touch behaviour, the same incremental stance as the rest of the wiki.

**D9 — `## Requirements` is a reserved heading** in entity pages (eng #12). A section with zero
`###` headings is ignored, so a prose "Requirements" (prerequisites) paragraph is not a finding; one
with `###` subsections is parsed. Written into WIKI.md.

## Decided in implementation (surfaced by the diff review)

- light-finish 1b's verify is `owed` silent **and no `ERROR` on the pages the delta touched** — not
  `check --strict` over the whole wiki: in an adopted repo an old broken pointer on an unrelated
  page must not block closing an unrelated branch. `audit` and this repo's `validate.sh` run the
  whole-wiki check.
- `test:` pointers must be repo-relative; absolute paths and `..` are rejected.
- `~~~` fences are skipped as well as backtick fences (CommonMark); `- **Scenario:**` (bold) counts.
- The plan lookup requires the date prefix (`<YYYY-MM-DD>-<segment>-plan.md`); an undated file is
  not a plan. `## Behaviour delta` may carry a suffix (`## Behaviour delta (gates)`).
- `strata-diff-review` falls back to the old `*<slug>*` glob only in repos whose `state_tools.py`
  predates `plan`.
- `gen_template_history.sh` now unions with the existing manifest: a version that shipped stays
  listed after a history rewrite (the regenerated file had dropped two such hashes).

## Accepted risks

- A branch merged **without** light-finish never applies its delta; nothing catches it in 0.14.0.
  A later check could run `owed` against plans of recent merges on the base branch.
- Skills update with the plugin at once; `requirements.py` reaches a project at its next
  SessionStart auto-sync. Until then the skills say "run /strata:upgrade" (D7).

## Out of scope

- An `openspec`-style CLI, `changes/` folders, schemas/profiles, multi-tool instruction files —
  each already has a Strata counterpart (table above).
- Running scenario tests from the checker, or generating tests from scenarios.
- Back-filling Requirements across all of Strata's entities or across adopted projects.
- A RENAMED delta verb (D3).

## Risks

- **Ceremony creep** — a delta on every plan. Mitigation: only when *specified* behaviour changes;
  pages without Requirements need none; trivial tier never.
- **Body equality is brittle** — the agent reformats a line and `owed` keeps reporting. Mitigation:
  whitespace-normalised comparison, and the report names the exact item so the fix is one edit.
- **Plan lookup by branch slug misses** a plan named differently — then there is no delta to
  check. Mitigation: one exact rule (D5), `lean-plan` names plans by it, `owed` prints
  `no plan for <branch>` on stderr, and `diff-review` reports "no plan to check against".

## Review

Eng lens (2026-09-28, `strata-eng-review`): APPROVE-WITH-CONCERNS, 13 findings — #1 merge point,
#2 one plan lookup, #3 no `wiki_debt`, #5 pointer = a `test:`/`manual:` code span, #6 a malformed
delta is an error, #7 grouping, #8 fences / pytest needles / wrapped pointers, #9 diff-review
reads the script, #11 script absent, #12 reserved heading — folded in above. #4 cut. #10 (ADDED
and MODIFIED share one check) taken in the code; both verbs stay for readers. #13 (code started
before the review returned) — true; the test was amended after it.
