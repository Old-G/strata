# Changelog

All notable changes to Strata are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.7.0] — 2026-09-02

The right side of the loop. Anthropic's AI-Native SDLC playbook (2026-08-21) turned out to be
ADR #1 in other words, and every gap it exposed sat to the right of Build — places where Strata
still relied on prose for something its own rules say must be deterministic. Spec:
`docs/superpowers/specs/2026-09-01-sdlc-right-side.md`.

### Added
- **Routing evals (E1)** — the first test of Strata's probabilistic half. `evals/routing_cases.py`
  generates `evals/routing-cases.json` from the skill descriptions: one EN and one RU trigger
  phrase per skill, **verbatim**, plus eight borderline prompts for the confusable pairs
  (`feature`/`refactor`, `office-hours`/`lean-plan`, `wiki-ingest`/`using-strata`,
  `upgrade`/`adopt`). `scripts/test_routing_evals.sh` runs each case headless (`claude -p
  --plugin-dir . --allowedTools Skill --max-turns 1` from an empty temp dir) and requires the
  first `Skill` call to be the expected one; threshold 1.0, RUNS=3. First run: 34/34.
  `validate.sh` §11 asserts (offline, free) that the case list is current and covers every
  skill; the eval **run** stays a local command (`RUNS=3 bash scripts/test_routing_evals.sh`)
  because it costs API calls. `claude plugin eval` is in early access on this CLI, so the JSON
  is shaped to convert to native cases unchanged later.
- **PreToolUse guard (A5)** — `templates/core/scripts/hooks/strata_pre_tool_guard.sh`, the first
  hook that refuses a write *before* it happens. Rule (a): any write under `raw/` (a mirror of
  `docs/`), escape `STRATA_ALLOW_RAW_EDIT=1`. Rule (b): any write to a test file while
  `.strata/guard-tests` exists — `feature`/`refactor` set the toggle at "make the failing test
  pass" and clear it once green; SessionStart warns about a stale one. Exit 2 with the reason on
  stderr, bash-only, fails open, 27 ms. `scripts/test_p3_guards.sh` (24 assertions) as
  `validate.sh` §12. Reaches adopted repos through `/strata:upgrade`. The branch's own
  `strata-diff-review` run caught the first cut narrowing the spec's `*_test.*` to `.py`/`.go`
  (Dart/Deno test files slipped through) — widened back before release.
- **Diff-vs-plan review (R1)** — `agents/strata-diff-review.md`, a fifth read-only agent that runs
  at branch close on the diff (the council runs on the plan). Finds the plan itself
  (`docs/superpowers/plans/*<branch>*`, else the branch state, else "no plan to check against");
  three tagged passes — compliance, bugs, security-lite; Important vs Nit, ≤5 nits. Wired as
  `light-finish` step 2: advisory (cannot block), unskippable, Important findings written to the
  branch state's `gotchas`. **Second-occurrence rule:** a gotcha already in `wiki/log.md`
  proposes one `CLAUDE.md` line in the same closing commit.

### Changed
- `adopt`/`init` copy lists include the guard and `lib/state_tools.py`; `claude-settings-hook.json`
  carries the `PreToolUse` block; `CLAUDE.md` hard rules gain "changing a skill description
  changes the routing surface — regenerate the cases".

## [0.6.1] — 2026-09-01

### Fixed

- **`strata_upgrade_check.sh` can now be satisfied.** A repo that deliberately extends a shipped
  script was reported `STALE` on every run, so the check exited 1 forever — a guard nobody can
  satisfy is a guard nobody reads. Measured on a real repo: `check_secrets.sh` there is the
  template plus 59 lines (a guest-phone PII guard, an AWS-placeholder exception). A fourth verdict
  `AHEAD` decides the *direction* of the difference in the script instead of asking a human to
  diff every file: no template line absent from the installed file ⇒ the installed file is the
  template plus local lines, nothing to copy, reported but not a failure. Genuine template
  evolution always leaves a line the installed file lacks, so a real `STALE` cannot be misread;
  a reordered file reported `STALE` is the safe way to be wrong. `/strata:upgrade` updated to
  match. 4 mutations, 4 killed — including one proving the `pipefail` workaround is load-bearing
  (`diff` exits 1 on any difference and would poison a `diff | grep` pipeline's status).

## [0.6.0] — 2026-09-01

A build nobody can name is a build nobody can verify. `.strata/version` answers for the *repo's*
copied `scripts/**`, not for the plugin the session actually loaded, so "did the update land" was
only answerable by comparing cached release directories on disk. The entry skill now carries the
stamp, which puts it in every session's skill listing — no shell, no invocation, no adopted repo
required.

The version number itself is load-bearing, and this release is the proof. The plugin cache is keyed
by the version string (`cache/<marketplace>/<plugin>/<version>/`), so a merge into `main` that does
not bump it is copied nowhere: the marketplace clone advances, `installed_plugins.json` keeps the
old `gitCommitSha`, and both commands report success. Measured on 2026-09-01 — the stamp feature
shipped to `main` as `9fe528a` and stayed invisible to every session, because the cache still held
`3c6d90d` under the same `0.5.0` directory. Shipping the stamp therefore *requires* the bump that
makes it reachable.

### Added

- **Version stamp readable from inside a session.** `skills/using-strata/SKILL.md` now carries the
  running plugin's version in its description (so it lands in every session's skill listing without
  a shell, an invocation, or an adopted repo) and in its body. Answers "did the plugin update, and
  is this chat using it" — a question `.strata/version` could not answer, because that stamp is the
  *repo's* copied `scripts/**`, and the SessionStart nudge speaks only on mismatch (its silence
  equally means "agree", "no `.strata/version`", or "no `CLAUDE_PLUGIN_ROOT`").
- **`validate.sh` §2c — one version, stamped everywhere it is claimed.** `plugin.json` is the single
  source; `marketplace.json`, the `using-strata` description, the `using-strata` body, and
  `CLAUDE.md`'s status line are checked against it. Compares every `vX.Y.Z` token in those files
  (a half-updated file fails) and fails on a *missing* stamp, not only a stale one. 5 mutations,
  5 killed.

## [0.5.0] — 2026-09-01

The knowledge layer gets a second half. `wiki/log.md` was always a trajectory (what happened,
in order); nothing answered "what do we currently know about this branch" — and separately, a
repo adopted before v0.4.0 had no way back to the enforcement layer at all. Both trace to the
same research session (SKILL.state, arXiv:2608.26263; Prime Agent, arXiv:2608.23552) — see
`docs/superpowers/specs/2026-09-01-episodic-state-layer.md`.

### Added
- **Episodic state layer** (`scripts/lib/state_tools.py`). A small, schema-validated, git-tracked
  `.strata/state/<branch-slug>.json` per branch: goal, decisions (`what`/`why`/`evidence`/`trust:
  session|reviewed`), open questions, gotchas, and `wiki_debt` — knowledge owed to the wiki that
  isn't a `docs/*.md` edit yet. `trust` defaults to `"session"`; nothing auto-promotes an
  unreviewed decision into `wiki/` (P-1 quarantine minimum). Committed on purpose — it survives a
  machine change or a `/clear`, unlike the gitignored session stamps it sits next to.
- **Stop-gate trigger (c).** Extends the existing A1 Stop gate: blocks once (same loop-safety cap
  as triggers a/b) when the current branch's state file has a non-empty `wiki_debt`, or exists but
  fails schema validation. A missing state file is not a trigger — the layer stays adoptable
  incrementally.
- **SessionStart state summary + version nudge.** Prints the current branch's state summary (goal,
  status, decision/open-question/debt counts) when a state file exists, and one line suggesting
  `/strata:upgrade` when `.strata/version` disagrees with the running plugin's version. Stays
  inside the existing ≤50-line budget.
- **`/strata:upgrade`** (`skills/upgrade/`, `scripts/strata_upgrade_check.sh`). Re-syncs a repo's
  installed `scripts/**` and `.claude/settings.json` hook block with the plugin currently running.
  Fixes the confirmed case: a repo adopted before v0.4.0 with `wiki/` fully populated and zero
  hooks installed — `init`/`adopt` only ever copy templates once, and there was no path back.
  Idempotent; never touches `wiki/`, `CLAUDE.md`, or application code.
- `light-finish` now folds a branch's state file into its `wiki/log.md` drift-close entry and
  deletes it on close; `audit` now flags orphaned state files (branch gone) and counts unreviewed
  (`trust: session`) decisions.
- `bash scripts/test_p2_state.sh` — behavioural tests for the validator, trigger (c), the
  SessionStart additions, and the upgrade-check diff reporter.

### Fixed
- `wiki/scripts/lint.py`'s index-membership check never recognized the `[[slug]]` wikilink
  syntax `index.md` itself declares canonical — flagged nearly every entity/source page as
  "not listed", and 3 documentation placeholders (`` `entities/<slug>.md` ``) as broken
  references. Predated this release; 0 errors/0 warnings after the fix (was 3 + 21).
- `scripts/lib/pending_ingest.sh`'s retirement regex only matched the first `raw/` path after
  the word "ingest" — an ingest line listing several paths at once
  (`ingest raw/A, raw/B → created: …`) only ever retired the first, leaving every later path a
  permanent phantom marker. Found testing `/strata:upgrade` against a real 338KB `wiki/log.md`:
  325 markers looked outstanding; the true backlog was near zero once fixed.
- `scripts/test_p2_state.sh` hardcoded the git branch name without pinning it, passing locally
  and failing on CI (different `init.defaultBranch` default). Pinned with an explicit
  `git checkout -b main` in the fixture.

## [0.4.0] — 2026-08-15

Wiki freshness stops being advice. P1 of the v-next brief: the enforcement layer (A1–A4) and
native invocation (C1–C4).

### Added
- **Stop gate** (`templates/core/scripts/hooks/strata_stop_gate.sh`). A `Stop` hook that refuses
  to end the turn once when the session left the wiki behind. Loop safety is the design: it exits
  immediately on `stop_hook_active`, fails open when it cannot tell where the session began, and
  blocks **at most once per session**. Only markers created in the current session count — older
  ones belong to the commit gate (ADR #4). Clean-state path measured under 100 ms, which is why
  the hook payload is parsed with `grep`/`sed` rather than `python3`.
- **Second Stop trigger for code-only sessions.** A session that changed ~50+ lines outside
  `wiki/ raw/ docs/` and wrote nothing to `wiki/log.md` is blocked once — the drift nobody used
  to catch. Always satisfiable with a single log line, including an explicit `no-wiki-impact:`.
  Tune or disable with `STRATA_STOP_GATE_LINES` (`0` = off).
- **Commit gate** (`templates/core/scripts/pre-commit/check_wiki_fresh.sh`). Fails the commit
  while any doc is mirrored but un-ingested, printing the exact ingest commands. Judges the
  **staged** `wiki/log.md`, so ingesting without staging `wiki/` is caught too. Escape hatch:
  `STRATA_SKIP_WIKI=1`.
- **SessionStart injection** (`templates/core/scripts/hooks/strata_session_start.sh`). Puts ≤50
  lines of real state into every session — branch, pending ingests, the head of `wiki/index.md`,
  the wiki-first rule — and stamps where the session began (the Stop gate depends on it).
- **`scripts/lib/pending_ingest.sh`** — one implementation of the marker-retirement rule, shared
  by all three gates and the mirror hook, so they cannot disagree about what "pending" means.
- **`## Do NOT use when` guards** on all 12 skills, to stop neighbouring skills stealing each
  other's requests.
- **`scripts/test_p1_gates.sh`** — 28 behavioural assertions driving the real scripts through
  their real interfaces (loop safety, session scoping, thresholds, latency, and a real
  blocked-then-allowed `git commit`). Wired into `scripts/validate.sh`.
- **`.githooks/pre-commit`** — Strata now runs its own guards (`git config core.hooksPath .githooks`).
- **Strata's own `wiki/` and `raw/`.** The repo shipped the knowledge pipeline as a template
  without ever running it on itself; it now dogfoods it.

### Changed
- **Every skill `description` is now a bilingual trigger spec** — concrete EN and RU phrases
  inline, matched against the words a user actually types. Strata is meant to be driven in plain
  language; `/strata:*` is the manual fallback (ADR #2).
- **`using-strata` is a coordinator**, with an explicit contract: match broad intent, hand off to
  exactly one skill, never do the work itself.
- **`light-finish` gained a drift-close step** between "Do it" and "Clean up" — ingest the docs the
  branch touched, or record why the code change had no knowledge impact. Not optional.
- **`CLAUDE.md.tmpl` carries a routing map** (5 lines, one source of truth; the SessionStart hook
  deliberately does not duplicate it).
- **`init` / `adopt` install the enforcement layer** alongside the mirror hook, and `adopt` now
  bulk-ingests the existing doc backlog *before* the gates go in, so adoption never starts blocked.
- `validate.sh` gained two sections: bilingual-description enforcement and the behavioural gate run.

### Fixed
- **The mirror hook went blind after the first ingest.** `sync_raw_mirror.sh` skipped writing a
  marker whenever that exact string had *ever* appeared in `wiki/log.md`, so editing a doc a second
  time produced no signal at all — permanently, for every doc ever ingested. It now reopens the
  marker using the shared retirement rule. Found by dogfooding the pipeline on this repo.
- `check_raw_mirror.sh` printed a remediation path (`scripts/wiki/sync_raw_mirror.sh`) that does
  not exist.

## [0.3.1] — 2026-07-21

### Added
- **Context discipline in `/strata:feature`.** Long work is split into short passes (one unit, one
  commit), each run by a **fresh agent** rather than pushed through one long conversation, and work
  that crosses a session/agent/pass carries a compact **handoff** (goal · done + commit refs · next ·
  constraints and decisions · how to verify) instead of relying on re-reading the transcript.
  Answer quality decays as context fills; this addresses it directly. Handoff idea adapted from
  [mattpocock/skills](https://github.com/mattpocock/skills).

## [0.3.0] — 2026-07-21

### Changed
- **`/strata:feature` is now adaptive-ceremony.** A cheap Phase-0 triage classifies each task
  (trivial / standard / risky) and runs only the ceremony that fits, behind a floor of evidence,
  risk auto-escalation, drift-close and git safety. Adds a per-tier **effort** policy (low/medium/high)
  as the main token lever.
- **The council is risk-triggered and lens-selected.** Instead of a fixed four-agent panel on every
  plan, 1–2 reviewers are chosen to match the actual risk, and only on `risky` work — an independent
  adversarial read of a risky surface, not a second pass over ordinary work.
- **Removed verification scaffolding.** Per Anthropic's Opus 5 guidance (frontier models verify their
  own work; explicit verification instructions cause over-verification), the flow asks for *evidence*
  — run the test, show the output — instead of instructing re-checks.
- **Strata owns a lean process spine:** new `lean-plan` (complete-but-lean, reference-first) and
  `light-finish` (lean branch integration). **Superpowers is now an optional power-up, not a
  prerequisite** — the native flow is complete without it.
- **`office-hours` grills better:** every question comes with a recommended answer (except the two
  that ask for the user's own evidence), and depth scales with the task.

## [0.2.2] — 2026-06-26

### Changed
- **`/strata:feature` now degrades gracefully without Superpowers.** The phases that wrap Superpowers
  (plan, TDD, code-review, finish) carry an explicit fallback: run the phase to the same standard
  yourself — flagging that the rigor is weaker — and recommend installing Superpowers, instead of
  hard-delegating to a skill that may be absent. Strata's native phases (office-hours, council,
  wiki+audit) were already standalone.

### Docs
- `CONTRIBUTING.md`: added a **"Releasing — bump the version"** section (and a step in "Adding a
  skill") so shipped skill/agent/template changes actually reach marketplace consumers.

## [0.2.1] — 2026-06-26

### Changed
- **Onboarding now checks prerequisites and hands you the exact install command.** `BOOTSTRAP.md`
  Step 1 and `/strata:onboard` Step 3 no longer merely *report* missing companions — for each one
  they show how to install it and what it buys:
  - **Superpowers** (strongly recommended) → `/plugin install superpowers@claude-plugins-official`,
    offered in the same batch as enabling Strata. It's the engine of `/strata:feature`.
  - **claude-mem** (optional) → install command + the payoff: cross-session memory + smart-Read to
    navigate code by structure instead of re-reading whole files each session.
  - **RTK** (optional) → its setup + the payoff: typically **60–90% fewer tokens** on dev operations.
  Strata's native spine still works without any of them — the check is non-blocking.

## [0.2.0] — 2026-06-25

### Added
- **One-line, AI-led onboarding.** Drop a single line into a fresh Claude Code session
  (`Install and run Strata in this repo: fetch and follow …/BOOTSTRAP.md`) or run
  `curl -fsSL …/install.sh | sh`, and the AI installs Strata, then conducts the whole setup as a
  conversation — no need to learn the commands first.
  - **`install.sh`** — idempotent, non-destructive, no-op-safe merge of the marketplace +
    `enabledPlugins["strata@strata"]` keys into `~/.claude/settings.json` (aborts *before* writing if
    the existing file is invalid JSON; skips backup/rewrite when already registered). Covered by
    `scripts/test_install.sh` (5 behavioral tests, wired into CI).
  - **`BOOTSTRAP.md`** — the chat-path session-1 conductor (addressed to the AI): idempotency check,
    prerequisite scan, config write, a resume breadcrumb, and the restart **bridge** that always
    carries a `/plugin marketplace add` + `/plugin install` fallback.
  - **`/strata:onboard`** — the session-2 conductor: detects new-vs-existing, checks prerequisites,
    delegates to `/strata:init` or `/strata:adopt`, then runs the first `/strata:audit` — a thin glue
    skill that never reimplements those flows.
- **CI/validation** — `scripts/validate.sh` now syntax-checks the root `install.sh`; the GitHub
  Actions workflow runs the installer behavioral tests.
- **README** — a prominent "⚡ Instant setup (AI-led)" walkthrough explaining the one-line flow.

## [0.1.2] — 2026-06-16

### Fixed
- **Plugin install still failed with "agents: Invalid input".** The manifest schema only accepts
  `.md` FILE paths for `agents` (not a directory), and the standard `skills/` and `agents/`
  directories are **auto-discovered** — so the manifest needs no component-path fields at all.
  Removed both `skills` and `agents` from `plugin.json`, matching every official plugin (superpowers,
  claude-mem, pr-review-toolkit, … all ship metadata-only manifests). `validate.sh` now enforces the
  real schema.

## [0.1.1] — 2026-06-16

### Fixed
- **Plugin install failed** — `plugin.json` declared `"agents": ["./agents/"]` (an array containing a
  folder), which the Claude Code manifest validator rejects. A folder reference must be a **string**
  (`"agents": "./agents/"`), matching `skills`. `validate.sh` now catches this format regression.

## [0.1.0] — 2026-06-16

Initial release. Strata packaged as a Claude Code plugin.

### Added
- **Plugin manifests** — `.claude-plugin/plugin.json` + `marketplace.json` (the repo is its own marketplace).
- **9 skills** (`/strata:<name>`): `using-strata` (entry router), `init`, `adopt`, `audit`,
  `refactor`, `feature`, `office-hours`, `autoplan`, `wiki-ingest`.
- **4 review-council subagents** (read-only, parallel, may disagree): `strata-ceo-review`,
  `strata-eng-review`, `strata-design-review`, `strata-cso-review`.
- **templates/core** — `PROJECT_PATTERN.md`, `WIKI.md`, the `wiki/` skeleton, `CLAUDE.md`/`ADR-Lean`
  templates, the docs→raw mirror script, and pre-commit guards.
- **templates/stacks/python-fastapi** — `SCALABLE_ARCHITECTURE_REFERENCE.md` (the architecture canon).
- **reference/** — council personas, tool-integration (RTK / claude-mem / Caveman), Diataxis doc-map.
- **CI** — `scripts/validate.sh` + a GitHub Actions workflow validating manifests, skill/agent
  frontmatter, and script syntax.

### Security
- Genericized all templates for public release: removed an internal service inventory from `WIKI.md`,
  emptied the hardcoded drift-check manifest and an employee name reference in `lint.py`, and quoted a
  glob-expansion in `sync_raw_mirror.sh` (findings from a dogfooded `strata-cso-review` pass).
- Removed an incomplete MCP-scaffold script that referenced a non-bundled template directory.

### Notes
- Methodology adapts [gstack](https://github.com/garrytan/gstack) (MIT) and wraps
  [Superpowers](https://github.com/obra/superpowers); composes claude-mem and RTK as declared
  prerequisites (not bundled).
- All shipped templates and docs are in English.
