---
name: light-finish
description: Use when a /strata:feature change is implemented and needs integrating, or when the user asks to wrap up a branch. Confirms the build is green, offers merge / PR / keep / discard, does the chosen one, and cleans up.
---

# light-finish — integrate the work, minimally

1. **Green?** Run the project's test/build command. If it fails, stop and report — never integrate broken work.
2. **Ask once:** merge to base locally · push + open a PR · keep the branch · discard.
3. **Do it.** Git safety holds: never a silent write to the default branch; keep commits reversible; if on the default branch, branch first.
4. **Clean up** the branch after a merge or discard.

If the project's release rule requires a version bump or changelog entry (see `CONTRIBUTING.md`), do that as part of finishing; otherwise skip it.
