# P2 — Episodic State Layer + Upgrade Path

**Status:** plan, approved by user directive ("реши сам, делай") **Date:** 2026-09-01 **Tier:** risky
**Source:** session research — SKILL.state (arXiv:2608.26263), Prime Agent (arXiv:2608.23552),
user's own Prime Agent notes (P-1…P-4) · [[skill-state]] [[prime-agent-notes]]

---

## Intent

Two independent problems surfaced from the same research session, and both trace back to a
missing layer, not a broken one:

1. **Some adopted repos run with zero enforcement.** `init`/`adopt` COPY
   `templates/core/scripts/**` once, at adoption time. There is no re-sync command. A repo
   adopted before v0.4.0 (confirmed on a real external project of the user's) has `wiki/` but no
   gates at all, and stays that way forever regardless of how many times the plugin is upgraded.
2. **The wiki only ever hears about `docs/*.md`.** Every other kind of knowledge a session
   produces — a decision, a rejected hypothesis, a gotcha, a "still owes an ingest" fact that
   isn't yet a doc — has no capture path and no persistence. Nothing forces it to survive a
   `/clear`, a compaction, or tomorrow's session. `wiki/log.md` cannot substitute for this: it
   is an append-only *trajectory* of ingest operations, not the project's current *state*.

When this ships: every Strata project has a re-sync command that makes "update the plugin" mean
something for repos adopted in the past, and every git branch worked on through Strata carries an
explicit, small, git-tracked state file that survives context loss — the thing SKILL.state calls
an execution state and the field calls episodic memory. `wiki/log.md` keeps doing what it already
does well (the trajectory); the new file does what nothing currently does (the current state).

## Constraints

- **Reuse existing enforcement, don't invent a second kind.** The Stop gate already has the one
  correct shape for "block once, self-limiting, escapable" (A1). The new "state is stale / owes
  wiki work" trigger is trigger (c) on the *same* script, not a new hook event. One more
  PostToolUse gate that blocks on every edit would violate "gates must be escapable and
  self-limiting" the first time it fires twice in a session.
- **No turn-by-turn state_patch loop.** SKILL.state's 93–98% token win comes from a rantime that
  owns the model's inference loop and discards history after every step. Strata does not own
  Claude Code's runtime loop, so that mechanism is not portable and is not attempted. What *is*
  portable is the abstraction: a small, schema-validated, mutable state object, updated
  deliberately at hook boundaries (SessionStart / PostToolUse / Stop), instead of asking the
  model to reconstruct "what have we decided so far" from scrollback every time.
- **`python3` only, no new dependencies** — same rule P1 shipped under.
- **Bash-only hooks stay bash-only for the fast path.** The Stop gate's clean-state path is
  measured under 100 ms; the new trigger reuses the same `grep`/`sed` discipline for the
  existence/emptiness check and shells out to `python3` only when a `.strata/state/*.json` file
  actually exists to validate.
- **`CLAUDE.md` ≤ 200 lines** here and in every template (hard rule, unchanged).
- Release rule: this changes shipped behaviour → bump both `.claude-plugin/plugin.json` and
  `.claude-plugin/marketplace.json` (0.4.0 → 0.5.0), per [[strata-release-bump-versions]].

## Decisions on the four open questions (from the research artifact)

**OQ1 — Who validates state, and how does the paper's #1 failure mode get designed out?**
Decision: a single python validator (`scripts/lib/state_tools.py validate`) owns the schema —
same "one marker rule, one implementation" discipline as `pending_ingest.sh`. The paper's
open-weight-model failure analysis found 68% of errors were *premature overwrite/deletion of a
state key*. Strata's state format designs that class out structurally: there is no implicit
null-means-delete merge semantics (SKILL.state's own convention) applied to a live turn loop we
don't control. Instead the file is fully rewritten and re-validated on every edit; the validator
rejects an edit that silently drops a required top-level key (`goal`, `status`) without that
being the obvious intent of the edit (going from populated → absent on a required key is a hard
schema error, not a warning) — see `REQUIRED_KEYS` in the validator.

**OQ2 — Session-scoped or branch-scoped, and does it get committed?**
Decision: **branch-scoped, one file per branch, tracked in git.** Session stamps
(`.strata/sessions/<id>.start`) stay exactly what they are today — ephemeral, gitignored,
gate-cadence bookkeeping. State (`.strata/state/<branch-slug>.json`) is a different object: it
must survive a machine change, a `/clear`, and a different person picking up the same branch —
none of which a gitignored file can do. It is small structured JSON, not secrets, so committing
it costs nothing and buys durability across exactly the boundary that currently loses knowledge.
Lifecycle: created on first substantive work on a branch, updated through the branch's life,
folded into `wiki/log.md` and deleted by `light-finish` when the branch closes (a completed
branch has no business leaving a permanent per-branch scratch file behind — its *reviewed*
content already moved to `wiki/`). `audit` flags any state file whose branch no longer exists
(abandoned) as a MEDIUM finding, so orphans don't silently accumulate.

**OQ3 — Quarantine now or later?**
Decision: **schema field now, promotion machinery later.** Every entry in `decisions[]` carries
`trust: "session" | "reviewed"`, defaulting to `"session"`. Nothing auto-promotes a `"session"`
entry into `wiki/` — that stays a human/skill-driven ingest, same as today. This is the P-1
minimum from the user's own Prime Agent notes (their Factorio lesson: persistence must not
silently launder an unverified claim into something that gets reused as fact). Building the
promotion/audit workflow now, before any project has accumulated real state files to observe,
would be speculative; the field costs nothing to add today and is expensive to retrofit onto
already-shipped files later.

**OQ4 — Whose UX owns quarantine visibility?**
Decision: **`audit`**, not a "gardener" skill — because no gardener skill exists in this repo yet
(`wiki/entities/gardener.md` is a design note, not a shipped skill; `skills/` has no `gardener/`).
`audit` already owns "read-only ranked drift report" as its entire job, so a new Phase-2 sub-check
— stale/orphaned state files and a count of `trust: "session"` entries older than the file's own
`updated` timestamp by some visible margin — is additive to a skill that already exists, instead
of standing up new surface area to answer a question nobody has asked yet. Revisit when/if a
gardener skill actually ships.

## Success criterion

`bash scripts/validate.sh` and `bash scripts/test_p1_gates.sh` stay green unmodified in behaviour;
a new `bash scripts/test_p2_state.sh` is green and asserts, behaviourally, against the real
shipped scripts (no mocks): the validator accepts a well-formed state file and rejects (a) invalid
JSON, (b) a missing required key, (c) an unknown top-level key, (d) a `trust` value outside the
enum; the Stop gate blocks once when the current branch's state file has a non-empty `wiki_debt`
and stays clear once it's emptied, without weakening any existing trigger's test; SessionStart
injects a state summary when a state file exists for the current branch and stays within the
existing ≤50-line budget; the upgrade-check script correctly reports drift between a fixture
"installed" tree and a fixture "template" tree and reports clean when they match.

---

## Tasks

### Task 1 — State schema + validator
Write `templates/core/scripts/lib/state_tools.py`: a stdlib-only CLI (`init`, `validate`, `debt`,
`summary`, `path`) over the schema below. Fields: `goal` (str), `status` (enum: `active` |
`blocked` | `done`), `verify` (str, the one command that proves the goal is met — mirrors the
user's own "goal-driven execution" convention), `decisions` (array of `{what, why, evidence,
trust}`), `open_questions` (array of str), `gotchas` (array of str), `wiki_debt` (array of str —
the missing signal: "this needs to reach wiki/ and hasn't yet", independent of `docs/*.md`),
`files_touched` (array of str), `branch` (str), `updated` (ISO-8601 str). `REQUIRED_KEYS = {goal,
status, branch, updated}`. Reject unknown top-level keys (typo protection — same spirit as the
marker-format strictness in `pending_ingest.sh`).
`verify`: `python3 -c "..."` round-trips a valid fixture through `init` → `validate` (exit 0), and
each of the four rejection cases from the Success criterion exits non-zero with a message naming
the offending key.

### Task 2 — Wire trigger (c) into the Stop gate
Extend `templates/core/scripts/hooks/strata_stop_gate.sh`: after triggers (a) and (b), if
`.strata/state/<current-branch-slug>.json` exists, is valid JSON, and its `wiki_debt` array is
non-empty, block once with a reason naming the file and its entries. If the file exists but fails
`state_tools.py validate`, block once with the validator's error (surfacing a schema break beats
silently ignoring a corrupt state file). Absence of the file is not itself a trigger — the layer
must stay adoptable incrementally, exactly like A1/A2 today.
`verify`: extend `scripts/test_p2_state.sh` — a session with a state file carrying non-empty
`wiki_debt` blocks once and clears once `wiki_debt` is emptied and re-saved; a session with no
state file at all is unaffected (existing `test_p1_gates.sh` assertions must still pass
unmodified).

### Task 3 — SessionStart: inject last state + version nudge
Extend `templates/core/scripts/hooks/strata_session_start.sh`: if a state file exists for the
current branch, print `state_tools.py summary` (goal, status, open_questions count, wiki_debt
count — a few lines, not the whole file). Separately: if `.strata/version` exists and
`$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json`'s version differs from it, print one line
suggesting `/strata:upgrade`. Both additions stay inside the existing ≤50-line budget — trim the
wiki-index-head cap if needed rather than blow the budget.
`verify`: `test_p2_state.sh` asserts the printed block includes the state summary when a state
file is present, stays silent about it when absent, and the whole block is still ≤50 lines
(reusing the existing `test_p1_gates.sh` line-budget assertion style).

### Task 4 — `/strata:upgrade` skill
New `skills/upgrade/SKILL.md` + `templates/core/scripts/strata_upgrade_check.sh` (a pure diff
reporter: compares the target repo's installed `scripts/**` against
`${CLAUDE_PLUGIN_ROOT}/templates/core/scripts/**`, reports missing/differing/matching files, exit
0 when nothing to do). The skill runs the check, and on drift: shows the diff, copies over
missing/differing files (`chmod +x`), merges any new hook entries from
`templates/core/claude-settings-hook.json` into `.claude/settings.json` the same way `adopt`/`init`
already do (append, never overwrite), and writes `.claude/../.strata/version` = the running
plugin's version. Idempotent — a clean re-run reports nothing to do and touches nothing.
`verify`: `test_p2_state.sh` builds a fixture repo with a stale installed script (one line
different from the template) plus one missing file, runs `strata_upgrade_check.sh`, and asserts
it names both; running it again after a fixture "fix" (copy the fresh files in) reports clean.

### Task 5 — Retire state on branch close
Edit `skills/light-finish/SKILL.md` step 4: after drift-close, if a `.strata/state/<branch>.json`
exists, fold its `decisions`/`gotchas` into the `wiki/log.md` entry already being written there,
then delete the state file — a merged branch has no business leaving scratch state behind once
its reviewed content has moved to `wiki/`.

### Task 6 — Audit surfaces quarantine + orphans
Edit `skills/audit/SKILL.md` Phase 2 (knowledge drift): add a state-file check — list
`.strata/state/*.json` whose branch no longer exists (`git branch --list <slug>` empty) as MEDIUM
"orphaned state file"; count `decisions[]` entries with `trust: "session"` and surface as a LOW
note ("N unreviewed decisions in state — nothing auto-promotes these").

### Task 7 — `.gitignore` carve-out
Change the `.strata/` blanket ignore (root `.gitignore` and `templates/core/gitignore.tmpl`) to
`.strata/*` + `!.strata/state/` so `.strata/sessions/` and `.strata/version` stay ignored while
`.strata/state/**.json` is tracked. `verify`: `git check-ignore .strata/sessions/x.start` exits 0
(ignored); `git check-ignore .strata/state/main.json` exits 1 (tracked).

### Task 8 — Docs, routing, version
- `using-strata` SKILL.md: add `/strata:upgrade` to the skills table; one line in "Operating
  rules" naming `.strata/state/` as the branch's episodic memory, distinct from `wiki/`.
- `CLAUDE.md` phase table: new row for the state layer + upgrade path.
- `README.md`: one line in the Commands table for `/strata:upgrade`; one line in the Hooks table
  extending the Stop-gate row's description to mention trigger (c).
- `CHANGELOG.md`: `[Unreleased]` → `[0.5.0]` entry.
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`: `0.4.0` → `0.5.0`.

### Task 9 — Mirror templates → root, run the whole suite, ingest this doc
Copy every changed `templates/core/scripts/**` file to its root `scripts/**` counterpart (this
repo dogfoods its own templates — same convention as every prior file in that tree). Run
`bash scripts/validate.sh`, `bash scripts/test_p1_gates.sh`, `bash scripts/test_p2_state.sh` —
all green. Then run `/strata:wiki-ingest` on this spec (dogfooding the very layer it describes —
leaving it un-ingested would be exactly the failure mode this document exists to fix).

---
