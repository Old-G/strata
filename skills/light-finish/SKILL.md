---
name: light-finish
description: Use when implemented work needs integrating and the branch wrapped up — 'wrap this up', 'merge it', 'we are done', «заканчиваем», «закончили фичу», «мержи», «вливай», «подытожь ветку». Confirms the build is green, offers merge / PR / keep / discard, runs drift-close into the wiki, and cleans up.
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
2. **Plan compliance — cannot be skipped, cannot block.** Spawn the `strata-diff-review` subagent
   (read-only; it finds the plan itself — `state_tools.py plan <branch>`, else the branch
   state's `goal`/`verify`, else it returns `VERDICT: no plan to check against` and that is a
   legitimate result for a trivial-tier change). Show its findings table to the human verbatim.
   Every **Important** finding is written into the branch state's `gotchas` (the P2 file — it is
   folded into `wiki/log.md` in step 5, so the finding survives even if the human waves it
   through). If the human wants a finding fixed, that is a loop back to step 1, not a merge.
   **Second-occurrence rule:** for each gotcha, `grep -F` a distinctive phrase of it in
   `wiki/log.md`. A hit means this mistake has been made before — propose one line for
   `CLAUDE.md`'s "Things Claude gets wrong" (or the equivalent section), and on approval add it
   in the same closing commit. Mistake twice → `CLAUDE.md`; that is the whole rule.
3. **Ask once:** merge to base locally · push + open a PR · keep the branch · discard.
4. **Do it.** Git safety holds: never a silent write to the default branch; keep commits reversible; if on the default branch, branch first.
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
   fold its `decisions` and `gotchas` (including step 2's findings) into this same `wiki/log.md`
   entry, then delete the state file. A closed branch has no business leaving scratch state behind
   once its reviewed content has moved to `wiki/` — a stale file here just becomes a future
   `audit` "orphaned state" finding. Also `rm -f .strata/guard-tests` if a fix left it behind.
6. **Clean up** the branch after a merge or discard.

If the project's release rule requires a version bump or changelog entry (see `CONTRIBUTING.md`), do that as part of finishing; otherwise skip it.

## Do NOT use when

- Nothing is implemented yet, or the build is red — fix that first; never integrate broken work.
- The user wants a new change built — that is `feature`.
