# P5 — Provenance (plan)

**Spec:** [2026-09-26-p5-provenance.md](../specs/2026-09-26-p5-provenance.md) — decisions D1–D9
are settled there; this plan orders the work and names the verify for each step.
**Branch:** `strata/p5-provenance` · **Ships as:** `0.9.0` · **Written:** 2026-09-26

---

## T1 — Agent-Session trailer

Files: `templates/core/scripts/git-hooks/strata_commit_trailer.sh` (new, + mirror to `scripts/git-hooks/`
— moved out of `hooks/` per eng #9, spec D2),
`.githooks/prepare-commit-msg` (new — Strata dogfoods it), `scripts/test_p5_provenance.sh` (new).

1. **Tests first** — throwaway repo, real script wired as `prepare-commit-msg` via
   `core.hooksPath`, pinned `main`. Cases: commit with `CLAUDE_CODE_SESSION_ID` set → exactly one
   `Agent-Session: <id>` trailer; no variable → no trailer; `STRATA_SKIP_TRAILER=1` → none;
   amend in the same session → still one; amend from a second session → both ids; an existing
   `Co-Authored-By:` block → joined, not split; id with `;`/space/newline → no trailer, commit
   still succeeds; id of 129 chars → none; rebase of two session-A commits from session B →
   commits carry A only; cherry-pick from session B → carries A only; merge from session B →
   B trailer; unwritable message path → exit 0.
   `verify`: `bash scripts/test_p5_provenance.sh` — red before the script exists.
2. **Script** — `$1` message file; guard order: skip env → id present and valid (D3) → not a
   replay (D4) → `git interpret-trailers --in-place --if-exists addIfDifferent`. Exit 0 always.
   `verify`: the T1 cases green.
3. **Dogfood** — `.githooks/prepare-commit-msg` → the fail-open wrapper (`[ -f "$s" ] && bash "$s" "$@" || true;
   exit 0` — not `exec`: cso #2, a missing script must not block commits `--no-verify` cannot bypass).
   `verify`: the next commit on this branch shows the trailer in `git log -1 --format=%B`.

## T2 — `strata_why.sh` + the provenance QUERY fallback

Files: `templates/core/scripts/strata_why.sh` (new, + mirror), `skills/wiki-ingest/sections/
provenance.md` (new), `skills/wiki-ingest/SKILL.md` (QUERY step pointing at it), same test file.

1. **Tests first** (appended to `test_p5_provenance.sh`): a file whose lines come from two
   commits, one with a trailer whose fake transcript exists under a temp `CLAUDE_CONFIG_DIR`, one
   human commit → output names both shas, `session <id>` + transcript path for the first,
   `no Agent-Session` for the second; a trailer whose transcript does not exist → `not on this
   machine`; an uncommitted line → `not committed yet`; `--history` lists older commits that
   touched the file; a missing file → exit 2 with usage on stderr.
2. **Script** — `strata_why.sh <file> [-L a,b] [--history]`; `git blame -w -M --porcelain` (eng #7: the
   commit that *moved* code is not the reason) for the
   lines, `%(trailers:key=Agent-Session,valueonly)` in one `git log` for all shas (eng #6), `--history`
   capped at 20 commits and whole-file (eng #7), transcript lookup
   `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/*/<id>.jsonl`. Read-only.
3. **Skill** — QUERY gains step 4b: the wiki has no reason for this code → run the helper → read
   the few transcript events around the file/symbol → re-check against current code → answer
   with locators, under the D6 evidence rules (full text in `sections/provenance.md`). The skill
   description gains 'why is this code here' / «откуда этот код», «почему код такой».
   `verify`: `validate.sh` §8 still green; a fresh `claude --plugin-dir . -p` asked «почему в
   scripts/hooks/strata_stop_gate.sh трюк с isSidechain?» names `wiki-ingest` as the skill to use.

## T3 — `strata-diff-review`: lenses + "Decided, not asked"

Files: `agents/strata-diff-review.md`.

1. Step 1 gains lens bucketing (non-implementation buckets first, then implementation by design
   part in reading order; nothing left uncategorised); passes run in lens order.
2. Step 2 gains the autonomous-decisions check: branch-state `decisions` with `trust: session`,
   commit messages, and design choices visible in the diff that neither the plan nor the user's
   request covers → table `Decision | Location | Recorded in`; unrecorded + behaviour-changing =
   Important.
3. Output: header lines untouched (light-finish parses them); `LENSES:` block and the decision
   table appended after the findings table.
   `verify`: run the edited prompt as a subagent over the P4 range (`48ba7ea~3..395edc0`
   against `docs/superpowers/plans/2026-09-12-p4-field-patterns-plan.md`) — output has the
   unchanged `VERDICT:`/`PLAN:`/`DIFF:` lines, a `LENSES:` block covering every changed file,
   and a decisions table.

## T4 — Install paths, upgrade, release

Files: `skills/adopt/SKILL.md`, `skills/init/SKILL.md`, `skills/upgrade/SKILL.md`,
`reference/agent-session-trailer.md` (one install procedure the three skills point at),
~~`templates/core/claude-settings-hook.json` note~~ (dropped: the trailer is a *git* hook — a note in the
Claude Code settings template is exactly the confusion eng #9 moved the script to avoid), `scripts/validate.sh` §14, `reference/
tool-integration.md`, manifests + stamps → `0.9.0`, `CLAUDE.md` status row.

1. adopt/init: copy the two scripts; wire `strata_commit_trailer.sh` as `prepare-commit-msg` into
   the repo's existing mechanism (hooksPath dir / pre-commit `stages: [prepare-commit-msg]` +
   `pre-commit install --hook-type prepare-commit-msg` / husky / `.git/hooks`); verify with a
   real commit under a set `CLAUDE_CODE_SESSION_ID`.
2. upgrade: the scripts arrive through the existing MISSING path; add the one wiring question
   when `strata_commit_trailer.sh` exists but no `prepare-commit-msg` calls it.
   `verify`: `test_p2_state.sh` upgrade-check cases still green; `strata_upgrade_check.sh`
   against a pre-P5 fixture reports both new files MISSING.
3. `bash scripts/validate.sh` — all sections green, §14 runs P5.

## T5 — Drift-close

`wiki/entities/agent-session-trailer.md` (new), `wiki/entities/diff-review.md`, glossary
(Agent-Session trailer, provenance, lens, autonomous decision), index, overview, log;
`diagram_check.sh main` → update `wiki/diagrams/system` if it owes one.
`verify`: `uv run --python 3.12 --with pyyaml python wiki/scripts/lint.py` green; commit gate passes.

## T6 — Found by T3's own verify run (added 2026-09-26)

Running the new `strata-diff-review` over the P4 range surfaced a real P4 bug: Stop-gate
trigger (d) counted `[Request interrupted by user` anywhere in a `"type":"user"` line, so a
session that merely *read or grepped* the gate's code (a tool_result) had a false interrupt —
this session's own transcript showed 1 false, 0 real, at threshold 1. Fix: anchor on the
unescaped JSON value start (`"text":"[…` / `"content":"[…`); quoted text inside a tool result
is always escaped. Files: `templates/core/scripts/hooks/strata_stop_gate.sh` (+ mirror),
`scripts/test_p4_friction.sh` (cases 11b/11c).
`verify`: `bash scripts/test_p4_friction.sh` red on 11b before the fix, 27/27 after; the real
transcript counts 0. Accepted residual: a tool result whose content *starts* with the marker (a
`grep -o` of it, a file beginning with it) still counts — far narrower than before, and the gate
blocks at most once per session.

The same run also found `wiki/diagrams/system` pinned at `2d41399` while `395edc0`/`5781576`
changed pinned files — folded into T5 (re-pin while drawing P5 in).
