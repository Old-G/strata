---
name: handoff
description: Use when the context window is filling up and the work must continue in a FRESH session of the SAME workspace — 'context is running out', 'save progress for a new session', 'write a handoff and stop', «контекст заканчивается», «сделай handoff», «сохрани прогресс для новой сессии», «передай в новую сессию». Also what the context-gate Stop hook asks for. Closes wiki drift (Strata repos only), commits verified work by the project's rules, writes .claude/handoff/handoff-<session>.md with a ready first prompt, then stops. Works in repos without Strata.
---

# handoff — save the session, then stop

Answer quality decays as context fills. This skill turns the rest of the session into a file the
next session can start from, instead of pushing on or relying on auto-compact. It is the
session-level form of the pass handoff in `feature` ("Hand off, don't hope"). Keep every step
cheap: the context left is the budget.

1. **Orient.** Workspace root = `git rev-parse --show-toplevel`, else the current directory (a
   plain folder is fine). It is a **Strata repo** when `scripts/lib/pending_ingest.sh` exists.
   Note the branch, `git rev-parse --short HEAD`, and `git status --short`.
2. **Drift-close — Strata repos only.** The knowledge half of `light-finish` step 5, nothing else:
   - `bash scripts/lib/pending_ingest.sh`; run `/strata:wiki-ingest` on each doc it prints.
   - Append one line for this session to `wiki/log.md`.
   - If the branch state exists (`python3 scripts/lib/state_tools.py path <branch>`), write this
     session's decisions, gotchas and remaining `wiki_debt` into it — the next session's
     SessionStart summary reads it. Do **not** delete it; the branch is not closed.
   - Do not refresh diagrams here; `diagram_check.sh` debt stays in `wiki_debt`.
   - Out of budget before an ingest finishes → that doc becomes `wiki_debt` and a line under Left.
3. **Commit what is verified — by the project's rules.** Read its commit conventions (CLAUDE.md /
   AGENTS.md / CONTRIBUTING.md) and follow them: message style, trailers, branch policy, checks.
   - Commit only work whose check passed this session. Red or unverified work stays uncommitted
     and is listed under Where we stopped — the working tree survives into the next session.
   - Never write silently to the default branch; if the project forbids it, leave the work
     uncommitted and say so.
   - Push only when the project's rules make pushing part of an ordinary commit **and** the user
     already allowed pushes in this session. Otherwise write "not pushed" in the handoff.
4. **Write the handoff** to `<root>/.claude/handoff/handoff-${CLAUDE_SESSION_ID}.md` (if the id
   was not substituted, use `handoff-<YYYYMMDD-HHMMSS>.md`). In a git repo, keep it out of git
   without touching tracked files: add `/.claude/handoff/` to `$(git rev-parse --git-path info/exclude)`
   once. Keep the 10 newest files in that folder, delete older ones. Content in the user's
   language; the frontmatter keys and `##` headings stay exactly as below (tools parse them):

   ````markdown
   ---
   type: strata-handoff
   session: <session id>
   created: <ISO 8601 with offset>
   workspace: <absolute root>
   branch: <branch | none>
   head: <short sha | none>
   pushed: <yes | no | n/a>
   ---
   ## Goal
   ## Done            — each item with its commit ref and the evidence that proved it
   ## Left            — ordered; unfinished wiki work included
   ## Where we stopped — the exact point: file/function, last command and its result, uncommitted files
   ## Decisions and constraints — made this session, with why; rules the next session must keep
   ## How to verify   — the commands that prove the goal is met
   ## First step      — one concrete action
   ## Prompt
   ```text
   <the whole first message for the new session: "Continue from <absolute handoff path>: read it
   first, then …" plus the first step; self-contained, pasteable>
   ```
   ````
5. **Stop.** Reply with the handoff path and the Prompt block, and tell the user to open a new
   session (or let the host app, e.g. Orca, start it). Make no further tool calls and do not start the first step.

**verify:** the file exists; its frontmatter has `type: strata-handoff`; `## Prompt` holds exactly
one fenced block; `git status --short` does not list it; in a Strata repo
`bash scripts/lib/pending_ingest.sh` prints nothing or every doc it prints is in Left.

## Do NOT use when

- Handing work to another agent, worktree or terminal — that is a delegation (e.g. Orca's `orca-cli`), not a session handoff.
- The work is finished and the branch should be wrapped up — that is `light-finish`.
- The user wants to keep going in this session — just continue.
