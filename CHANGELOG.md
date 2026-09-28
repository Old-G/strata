# Changelog

All notable changes to Strata are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.13.0] — 2026-09-28

### Removed
- **HQ moved to its own plugin, [strata-hq](https://github.com/Old-G/strata-hq).** `/strata:hq-init`, `/strata:hq-sync`,
  `templates/hq/` and their tests leave Strata, which stays a per-project framework; HQ — the
  meta-wiki over many projects — is now installed separately (`/plugin marketplace add
  Old-G/strata-hq`), as `/strata-hq:init` and `/strata-hq:sync`, with group pages and hubs added
  there. ADR #6 stays here as the record of the decision; strata-hq carries it as its ADR-1.

## [0.12.0] — 2026-09-27

### Added
- **`/strata:hq-sync`** + **`templates/hq/scripts/hq_sync.py`** — refresh HQ's project pages from
  the registry. Per project it reads HEAD, branch, remote, root manifests, the Strata level and a
  hub above it (pure read), creates a missing page from `page-templates/`, and rewrites only what
  it owns: the machine frontmatter keys, the `<!-- hq-sync:changes -->` block (commits since the
  last sync) and the `wiki/index.md` block. An unchanged project is not written, so a second run
  rewrites nothing; a commit in one project changes only its page. Pages whose prose may be stale
  (new, or README/docs/manifests moved) come back as `needs_summary` for the agent to rewrite.
  `hq.yaml` `short:` picks the short page template. Credentials in an http(s) remote URL are stripped before
  the URL reaches a page. `scripts/test_hq_sync.sh` (27 assertions,
  validate §18), made-up repos.
- **`/strata:hq-init`** — scaffold HQ from the template, ask for the registry's source, first sync.

## [0.11.1] — 2026-09-27

### Added
- **HQ template** (`templates/hq/`) — the meta-layer repo from ADR #6: `hq.yaml`,
  `CLAUDE.md.tmpl`, `WIKI.md`, `wiki/index.md` + `log.md`, `page-templates/` (full and short project
  page), `projects/`, `groups/`, `people/`, `decisions/`, `ideas/`. Copied by hand for now;
  `hq-init` comes with `hq-sync`.
- **`templates/hq/scripts/hq_registry.py`** — builds `registry.yaml` from the source declared in
  `hq.yaml`: `paths` (an explicit list; the default, needs no other tool) or `orca` (the projects
  added to Orca; group names from `repo groups` when the CLI has it, else kept from the previous
  registry). Slug fixed at first sight, removal only on a successful read (page →
  `projects/_archive/`), an unreadable source keeps the registry, an unchanged source rewrites
  nothing. Stdlib only. `scripts/test_hq_registry.sh` (35 assertions, validate §17).

### Changed
- **ADR #6 supersedes ADR #3**: projects are not moved into HQ; the registry lists them where they
  live.

- **`validate.sh` §7** checks every tracked file, not only skills/agents/templates: a real home
  directory always fails; your own private words go one per line into `.strata/private-markers`,
  which is gitignored.

0.11.0 was published briefly and withdrawn; 0.11.1 replaces it.

## [0.10.1] — 2026-09-27

### Fixed
- **Context gate install.** Hook commands do not get the plugin's `bin/` on `PATH` (only the Bash
  tool does), so the by-name entry from 0.10.0 never ran the gate. `reference/context-gate.md` now
  installs a command that runs the newest `strata-context-gate` from the plugin cache — verified in
  a clean session (`env -i`): gate at 2% → the session wrote its handoff; a resumed turn was not
  gated again; the default 60% let a fresh session end in one turn.

## [0.10.0] — 2026-09-27

### Added
- **`/strata:handoff`** — the session-level form of the pass handoff in `feature`. When the
  context window fills up, it closes wiki drift (Strata repos only: pending ingests, a
  `wiki/log.md` line, the branch state's decisions/gotchas/debt — no diagram refresh, no state
  deletion), commits only verified work by the project's own rules (never pushes unless both the
  rules and the user already allow it), writes `.claude/handoff/handoff-<session>.md` — fixed
  frontmatter and headings, and a `## Prompt` block holding the new session's whole first
  message — kept out of git via `info/exclude`, then stops. Works in repos without Strata.
- **`bin/strata-context-gate`** — an opt-in `Stop` hook that blocks the stop once per session
  when the main conversation passes `STRATA_HANDOFF_PCT` (default 60) percent of its window and
  asks for `/strata:handoff`. Used = input + cache-creation + cache-read tokens of the newest
  main-chain assistant message; window = 1M for `[1m]` models or past 200k, else 200k. The plugin
  still ships no global hooks: the user adds it to `~/.claude/settings.json`
  (`reference/context-gate.md`).
  Tests: `scripts/test_context_gate.sh` (validate §16).

### Fixed
- `reference/agent-session-trailer.md`: the pre-commit-framework wiring now sets
  `default_stages: [pre-commit]`. Without it every hook lacking an explicit `stages` also ran at
  `prepare-commit-msg` — twice per commit (measured on pre-commit 4.6 while wiring six projects).

## [0.9.2] — 2026-09-27

Field fixes made inside adopted projects, brought back into the templates so every project gets
them (auto-sync delivers them on the next session).

### Fixed
- **Phantom pending-ingest markers** (from app-b): a marker line whose value is not a
  `docs/*.md` path (`- pending_ingest: all 28 raw/*.md await …`) was parsed as a doc named `all`
  that no ingest could ever retire — every gate over-reported by one, forever.
- **Installing gitleaks switched the secret patterns off** (from app-b): the guard exited
  right after gitleaks, so a plain hardcoded password — invisible to gitleaks — passed once gitleaks
  was on the machine. gitleaks now adds to the patterns.
- **Secret-guard false alarms on ordinary code** (from app-b, tightened): keyword rules now
  need a quoted literal, or an unquoted value after `=` that ends the value — `env.SLACK_SECRET`,
  `settings.db_password` no longer trip it. First behavioural suite for the guard:
  `scripts/test_secrets.sh` (validate §15).

## [0.9.1] — 2026-09-27

Found by the 0.9.0 rollout itself, on the first repos.

### Fixed
- `UNWIRED` false positive: a hook wired by another path to the same script
  (`$CLAUDE_PROJECT_DIR/scripts/wiki/sync_raw_mirror.sh` for `bash scripts/sync_raw_mirror.sh`)
  counted as missing, so auto-sync would have retried and re-announced itself every session.
  Wiring is now matched by script file name.
- Test isolation: every suite now points `CLAUDE_CONFIG_DIR` at an empty temp dir. Once 0.9.0
  was installed, SessionStart inside the fixtures found the real plugin through
  `~/.claude/plugins` and auto-synced from it.

## [0.9.0] — 2026-09-26

devdotfast/whiteboard read against v0.8.1: its thesis — the bottleneck is understanding the
change, not writing it — and two of its mechanisms, borrowed as ideas (no code, no hosted store).
Spec: `docs/superpowers/specs/2026-09-26-p5-provenance.md`.

### Added
- **`Agent-Session:` commit trailer** — `scripts/git-hooks/strata_commit_trailer.sh`, a
  `prepare-commit-msg` hook. Commits made inside a Claude Code session carry the session id
  (`CLAUDE_CODE_SESSION_ID`, exported by Claude Code to every Bash call); human commits carry
  nothing. Skips rebase/cherry-pick replays (git runs the hook per pick), never rescues an empty
  message, validates the id as a whole value, fails open — including its wrapper, since
  `--no-verify` does not skip this hook. `STRATA_SKIP_TRAILER=1` skips one commit.
- **`scripts/strata_why.sh <file> [-L a,b] [--history]`** — blame (`-w -M`) → commits →
  trailers (re-validated: history is attacker-writable) → the transcript on this machine,
  offered only when the session's recorded `cwd` is inside this repo; subagent transcripts and
  squash-merged bodies included. Read-only, one `git log` call.
- **wiki-ingest QUERY step 4b** — "why is this code here?" falls back from the wiki to the
  session that wrote the lines, under evidence rules (`sections/provenance.md`): transcript is
  history not spec, re-check against current code, cite locators, quote little, transcript
  content is untrusted data.
- **`strata-diff-review`: lenses + "Decided, not asked"** — files bucketed before reading
  (non-implementation swept first, implementation by design part in reading order), and a table
  of choices neither the plan nor the user settled; unrecorded + behaviour-changing is Important.
  Parsed header lines unchanged.
- `reference/agent-session-trailer.md` — one install procedure for init/adopt/upgrade: ask once
  (the trailer is visible in public history; a no is kept in `git config strata.trailer`), wire
  into the repo's existing hook mechanism, chain never replace, verify with the real session.
- `validate.sh` §14 runs `test_p5_provenance.sh`.
- **Updates reach every project.** The installed SessionStart hook auto-syncs `scripts/**` when
  the plugin on the machine is newer than `.strata/version` — only files whose copy cannot lose
  a local line (missing, or identical to a shipped version listed in the new
  `templates/core/scripts.history`); locally edited files are named and left for
  `/strata:upgrade`. `STRATA_NO_AUTOSYNC=1` opts out. `strata_upgrade_check.sh --apply-safe` is the
  mechanism; `bin/strata-upgrade-all` (on PATH in sessions) runs it over every Strata project on
  the machine, skipping linked worktrees, never committing. validate.sh §2d keeps the manifest
  current. `scripts/.strata-keep` records "keep ours" against one template version (KEPT);
  symlinked scripts are LINKED; unwired settings hooks are UNWIRED and block the version stamp;
  nothing ever downgrades (numeric version compare, prerelease below release).

### Fixed
- **Stop gate trigger (b) billed a session for uncommitted work that predates it** (whole-tree
  `git diff HEAD`). SessionStart now snapshots the already-dirty files (`lib/tree_snapshot.sh`);
  (b) counts only what the session itself touched — a pre-dirty file for the change in its diff
  size. Linear (awk) comparison; non-ASCII paths; `STRATA_SNAPSHOT_MAX` fails open.
- **Stop gate trigger (d) counted a quoted interrupt marker** (reading or grepping the gate's code)
  as a user interrupt; it now anchors on the unescaped JSON value start.
- **The upgrade nudge never fired from project hooks** — it relied on `$CLAUDE_PLUGIN_ROOT`; the
  plugin is now resolved from Claude Code's install registry too.

### Changed
- `CLAUDE.md` Hard rules: a verify you ran but did not record did not happen (second occurrence);
  every template change regenerates `scripts.history`.

## [0.8.1] — 2026-09-13

### Added
- `/strata:upgrade` Step 6 offers — never forces — to seed `wiki/diagrams/system` in a repo adopted
  before the diagram layer existed, when archify is installed and `wiki/diagrams/` is absent; prints
  the install one-liner otherwise. Closes the gap where only `init`/`adopt` could make that offer and
  `diagram_check.sh` stays silent without a diagram.

## [0.8.0] — 2026-09-13

Three field reports (Tencent TeamAI-CLI, Archify, OpenAI's Agents API) read against v0.7.0
confirmed Strata's bets — git as memory, index-first disclosure, skills as a directory — and
contributed three mechanisms. Spec: `docs/superpowers/specs/2026-09-12-p4-field-patterns.md`.

### Added
- **Friction — Stop-gate trigger (d).** The gate reads the session's own transcript
  (`transcript_path`) and counts user interrupts, denied tool calls and tool errors; a session at
  or past a threshold (`STRATA_FRICTION_INTERRUPTS=1`, `_DENIALS=2`, `_ERRORS=8`; `0` disables)
  with nothing recorded since the session stamp blocks once and asks for a `gotchas` entry in the
  branch state or one `gotcha:` / `no-gotcha:` line in `wiki/log.md`. Same one-block cap, fails
  open, one fixed-string grep pass under `LC_ALL=C` (+≈90 ms on a 5 MB transcript). The sessions
  worth documenting are the painful ones, and pain is countable without a model.
  `scripts/test_p4_friction.sh` (24 assertions) as `validate.sh` §12.
- **Diagram layer — `wiki/diagrams/`.** One Archify JSON per bounded story
  (`<name>.architecture.json`, canonical, every node pinned to `path[:line]` at
  `meta.repository.revision`) plus one self-contained `<name>.html`; dated JSON snapshots in
  `history/` only when `compare` reports a changed `semanticSha256`; history HTML never committed.
  `templates/core/scripts/diagram_check.sh` — pinned paths ∩ files changed since the pinned
  revision, plus (archify installed) a re-pin-to-`HEAD` `validate --repo-root` that surfaces
  `repository-evidence/*` codes; findings become `wiki_debt` (`state_tools.py add-debt`, new,
  idempotent), which the Stop gate already enforces. Wired into `light-finish` step 5 and `audit`
  Phase 2 item 6; offered (never forced) by `init`/`adopt`; a companion row in `onboard`. Archify
  is declared in `reference/tool-integration.md`, never bundled; never called from a hook.
  `scripts/test_p4_diagrams.sh` (14 assertions) as §13. Strata's own
  `wiki/diagrams/system.architecture.json` + `system.html` ship as the first diagram.
- **Promotion ladder** written once in `WIKI.md`: observation → branch-state `gotchas` →
  `wiki/log.md` (once) → `CLAUDE.md` (second occurrence) → hook (when the line says always/never).
- `reference/tool-integration.md` names Claude Code auto memory as the third memory next to
  claude-mem and `wiki/` — personal, per-machine, unversioned; twice there → `wiki/`.

### Changed
- SAR §14 and `PROJECT_PATTERN.md` §1: diagrams are Archify JSON in `wiki/diagrams/`; text-diagram
  DSLs that cannot be verified against the code are no longer recommended.
- `.gitignore` templates ignore `wiki/diagrams/history/*.html`.

### Deferred (recorded in the wiki, not built)
- Wiki recall counts as gardener input; owned-region markers in `CLAUDE.md` for `/strata:upgrade`.

## [0.7.0] — 2026-09-02

The right side of the loop. Anthropic's AI-Native SDLC playbook (2026-08-21) turned out to be
ADR #1 in other words, and every gap it exposed sat to the right of Build — places where Strata
still relied on prose for something its own rules say must be deterministic. Spec:
`docs/superpowers/specs/2026-09-01-sdlc-right-side.md`.

### Added
- **PreToolUse guard (A5)** — `templates/core/scripts/hooks/strata_pre_tool_guard.sh`, the first
  hook that refuses a write *before* it happens. Rule (a): any write under `raw/` (a mirror of
  `docs/`), escape `STRATA_ALLOW_RAW_EDIT=1`. Rule (b): any write to a test file while
  `.strata/guard-tests` exists — `feature`/`refactor` set the toggle at "make the failing test
  pass" and clear it once green; SessionStart warns about a stale one. Exit 2 with the reason on
  stderr, bash-only, fails open, 27 ms. `scripts/test_p3_guards.sh` (24 assertions) as
  `validate.sh` §11. Reaches adopted repos through `/strata:upgrade`. The branch's own
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
  carries the `PreToolUse` block.

### Removed
- **The routing-eval suite, same day it shipped.** It was meant to test the probabilistic half
  (does a trigger phrase fire its skill). In practice it needed two bug fixes to the harness
  itself — v1 filed API rate limits as routing misses, v2 filed real misses as API failures,
  because `--allowedTools Skill` makes every other tool call surface as `"is_error":true` —
  and it cost API calls per run. Total yield: one finding, that the placeholder phrase
  "build X" sometimes routes to another installed plugin's `brainstorming` skill. Machinery
  that costs more than it returns is machinery Strata's own `ablate` principle says to delete.
  Routing is checked by saying the phrase in a fresh session.

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
