---
name: light-finish
description: Use when implemented work needs integrating and the branch wrapped up — 'wrap this up', 'merge it', 'we are done', «заканчиваем», «закончили фичу», «мержи», «вливай», «подытожь ветку». Confirms the build is green, offers merge / PR / keep / discard, runs drift-close into the wiki, and cleans up.
---

# light-finish — integrate the work, minimally

1. **Green?** Run the project's test/build command. If it fails, stop and report — never integrate broken work.
2. **Plan compliance — cannot be skipped, cannot block.** Spawn the `strata-diff-review` subagent
   (read-only; it finds the plan itself — `docs/superpowers/plans/*<branch>*`, else the branch
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
   `verify`: `bash scripts/lib/pending_ingest.sh` prints nothing.
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
