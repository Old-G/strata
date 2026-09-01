---
name: light-finish
description: Use when implemented work needs integrating and the branch wrapped up — 'wrap this up', 'merge it', 'we are done', «заканчиваем», «закончили фичу», «мержи», «вливай», «подытожь ветку». Confirms the build is green, offers merge / PR / keep / discard, runs drift-close into the wiki, and cleans up.
---

# light-finish — integrate the work, minimally

1. **Green?** Run the project's test/build command. If it fails, stop and report — never integrate broken work.
2. **Ask once:** merge to base locally · push + open a PR · keep the branch · discard.
3. **Do it.** Git safety holds: never a silent write to the default branch; keep commits reversible; if on the default branch, branch first.
4. **Drift-close — not optional.** Run `/strata:wiki-ingest` on every `docs/*.md` the branch touched. If only code changed, append a one-line summary to `wiki/log.md` and update the affected `wiki/entities/` pages. This is the moment the knowledge layer is supposed to catch up; the Stop and commit gates exist because it used to get skipped here.
   `verify`: `bash scripts/lib/pending_ingest.sh` prints nothing.
   If `.strata/state/<branch-slug>.json` exists (`python3 scripts/lib/state_tools.py path <branch>`),
   fold its `decisions` and `gotchas` into this same `wiki/log.md` entry, then delete the state
   file. A closed branch has no business leaving scratch state behind once its reviewed content
   has moved to `wiki/` — a stale file here just becomes a future `audit` "orphaned state" finding.
5. **Clean up** the branch after a merge or discard.

If the project's release rule requires a version bump or changelog entry (see `CONTRIBUTING.md`), do that as part of finishing; otherwise skip it.

## Do NOT use when

- Nothing is implemented yet, or the build is red — fix that first; never integrate broken work.
- The user wants a new change built — that is `feature`.
