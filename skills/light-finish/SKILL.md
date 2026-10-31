---
name: light-finish
description: Use when implemented work needs integrating and the branch wrapped up — 'wrap this up', 'merge it', 'we are done', «заканчиваем», «закончили фичу», «мержи», «вливай», «подытожь ветку». Confirms the build is green, runs the branch review by the repo's REVIEW.md (at most three rounds, then the human reconsiders the approach), offers merge / PR / keep / discard — a PR body with Testing / Risk / How to revert that the human confirms — runs drift-close into the wiki, and cleans up.
---

# light-finish — integrate the work, minimally

1. **Green?** Run the project's test/build command. If it fails, stop and report — never integrate broken work.
   **1b. Apply the behaviour delta — on the branch, before anything else.** If the branch's plan
   (`python3 scripts/lib/state_tools.py plan <branch>`) has a `## Behaviour delta`, apply it to
   `wiki/entities/`: ADDED → append the requirement verbatim under `## Requirements` (create the
   section, or the page, if missing); MODIFIED → replace that requirement's body; REMOVED → delete
   it. Commit on the branch, so merge, PR and keep all carry it and discard throws it away.
   `verify`: `python3 scripts/lib/requirements.py owed` prints nothing and `python3
   scripts/lib/requirements.py check` shows no `ERROR` on the pages the delta touched — both
   outputs go into this branch's `wiki/log.md` entry. `scripts/lib/requirements.py` absent → the repo predates it: say "run
   /strata:upgrade" and treat the verify as **not passed**. (OpenSpec's `archive`; format in
   "Requirements and behaviour deltas", `${CLAUDE_PLUGIN_ROOT}/templates/core/WIKI.md`.)
2. **Review — cannot be skipped, cannot block, at most three rounds.**
   1. `python3 scripts/lib/state_tools.py review-round <branch>` prints `ROUND <n>/3 SINCE
      <sha | base> AT <sha>` and writes nothing. **Exit 3 is the cap:** do not run a
      fourth round — ask the human once: "Three review rounds and Important findings remain:
      reconsider the approach (rethink the plan) · integrate with the findings recorded · keep the
      branch?" When they rethink and the approach changes, `review-round <branch> --reset` starts
      the new approach at round 1. No `review-round` (repo not upgraded) → count the rounds in this
      session yourself and say "run /strata:upgrade".
   2. Spawn the `strata-diff-review` subagent (read-only; it reads the repo's `REVIEW.md` and finds
      the plan itself — `state_tools.py plan <branch>`, else the branch state's `goal`/`verify`,
      else it returns `VERDICT: no plan to check against` and that is a legitimate result for a
      trivial-tier change). Brief it with `ROUND`, `SINCE` and `PREVIOUS` — the findings of earlier
      rounds (the branch state's `gotchas` plus the last table shown this session), so round 2
      and 3 review only the new diff and repeat nothing. Show the human its first line (the finding
      count) and its tables verbatim. Only now record the round, at the commit it was asked at:
      `python3 scripts/lib/state_tools.py review-round <branch> --done <AT>` — a review that failed
      or was interrupted is asked again with the same scope, and a commit that landed meanwhile is
      still in the next round's diff.
   3. Every **Important** finding is written into the branch state's `gotchas` (the P2 file — it is
      folded into `wiki/log.md` in step 5, so the finding survives even if the human waves it
      through). **Pre-existing** findings are not this branch's: name them to the human as
      candidates for their own fix (`/strata:refactor`) and keep the list for step 5's log line.
   4. If the human wants a finding fixed, that is a loop back to step 1: fix it, commit the fix,
      green again, then this step again — the next round. Not a merge.

   **Second-occurrence rule:** for each gotcha, `grep -F` a distinctive phrase of it in
   `wiki/log.md`. A hit means this mistake has been made before — propose one line for
   `CLAUDE.md`'s "Things Claude gets wrong" (or the equivalent section), and on approval add it
   in the same closing commit. Mistake twice → `CLAUDE.md`; that is the whole rule.
3. **Ask once:** merge to base locally · push + open a PR · keep the branch · discard.
4. **Do it.** Git safety holds: never a silent write to the default branch; keep commits reversible; if on the default branch, branch first.
   **A PR or MR gets three fields** — the agent drafts them from evidence, the human confirms or
   edits them before it is opened. A repo template (`.github/pull_request_template.md`,
   `.gitlab/merge_request_templates/`) keeps its shape; these go into it.

   ```
   ## Testing
   <the commands from step 1 and the plan's verify lines, each with its result — not "tests pass">
   ## Risk
   <what breaks if this is wrong and who would notice; REVIEW.md's always-human paths it touches; Important findings left open>
   ## How to revert
   <the concrete undo — git revert <sha>, the flag to turn off, the down-migration — and what it cannot undo: data written, messages sent>
   ```
5. **Drift-close — not optional.** Run `/strata:wiki-ingest` on every `docs/*.md` the branch touched. If only code changed, append a one-line summary to `wiki/log.md` and update the affected `wiki/entities/` pages. This is the moment the knowledge layer is supposed to catch up; the Stop and commit gates exist because it used to get skipped here.
   **Diagrams first** (P4 diagram layer): run `bash scripts/diagram_check.sh <base-branch>`. Every line it
   prints is a diagram in `wiki/diagrams/` whose pinned source files changed on this branch (or whose pins
   no longer resolve at `HEAD`); it has already been written into the branch state's `wiki_debt`. Refresh
   each one through the **archify** skill: edit only the changed area of `<name>.architecture.json`, set
   `meta.repository.revision` to the branch's latest commit, `validate --repo-root .` → `deliver` to
   `<name>.html` (delete the receipt files it writes beside it once summarised; a diagram older than
   Archify 3.0 also needs `meta.output` and no `meta.viewBox` — the diagram JSON contract in `${CLAUDE_PLUGIN_ROOT}/reference/tool-integration.md` (Archify section)), then `compare` the previous JSON (`git show <base>:wiki/diagrams/<name>.architecture.json`, as a
   temporary copy normalised to the contract when it predates Archify 3.0) against the new one: if `summary.semanticSha256` differs, `mkdir -p wiki/diagrams/history` and copy the new JSON to
   `wiki/diagrams/history/<YYYY-MM-DD>-<name>.architecture.json` and put the compare summary counts in this
   entry's `wiki/log.md` line; history HTML is never committed. Archify not installed → the debt item stays
   and the log line says so; do not hand-edit the HTML. A `pins NOT verified` or `quality check failed`
   line is the same repair, owed to the installed Archify rather than to this branch — the branch that
   closes next makes it (usually the contract's one-field edit), because its verify cannot pass until then.
   `verify`: `bash scripts/lib/pending_ingest.sh` prints nothing, and `bash scripts/diagram_check.sh <base-branch>`
   prints nothing.
   If `.strata/state/<branch-slug>.json` exists (`python3 scripts/lib/state_tools.py path <branch>`),
   fold its `decisions` and `gotchas` (including step 2's findings), the review rounds it took and
   step 2's pre-existing list into this same `wiki/log.md` entry, then delete the state file. A closed branch has no business leaving scratch state behind
   once its reviewed content has moved to `wiki/` — a stale file here just becomes a future
   `audit` "orphaned state" finding. Also `rm -f .strata/guard-tests` if a fix left it behind.
6. **Clean up** the branch after a merge or discard.

If the project's release rule requires a version bump or changelog entry (see `CONTRIBUTING.md`), do that as part of finishing; otherwise skip it.

## Do NOT use when

- Nothing is implemented yet, or the build is red — fix that first; never integrate broken work.
- The user wants a new change built — that is `feature`.
