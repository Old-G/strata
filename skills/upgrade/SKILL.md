---
name: upgrade
description: Use when this repo's installed Strata hooks might be behind the plugin currently running — 'update strata', 'sync the hooks', 'upgrade strata here', 'my hooks are stale', «обнови страту», «синхронизируй хуки», «страта отстала», «подтяни обновления страты», «почему гейты не срабатывают». Re-syncs templates/core/scripts/** and the settings.json hook block into a repo that was adopted before this plugin version shipped. Idempotent — a clean repo reports nothing to do.
---

# /strata:upgrade — re-sync installed hooks with the running plugin

`/strata:init` and `/strata:adopt` COPY `templates/core/scripts/**` into a project once, at
adoption time. There is no other path back — updating the Strata plugin itself never reaches a
repo adopted in the past. Confirmed case: a project with `wiki/` fully populated and zero hooks
installed, because it was adopted before the enforcement layer (v0.4.0) existed. If "the wiki
never updates itself" and the project genuinely has `wiki/`, checking here first is often faster
than debugging the flow — see `docs/superpowers/specs/2026-09-01-episodic-state-layer.md`.

This skill NEVER touches `wiki/`, `CLAUDE.md`, or application code. It only re-syncs the
mechanical layer: `scripts/**` and the hook block in `.claude/settings.json`.

## Step 1 — Diagnose (read-only)

Run the diff reporter, pointing it at the plugin's own templates:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/templates/core/scripts/strata_upgrade_check.sh" \
  "${CLAUDE_PLUGIN_ROOT}/templates/core/scripts"
```

It prints one `OK|STALE|MISSING <path>` line per template file and exits 0 when everything
matches. If this project has no `scripts/` at all, that itself is the finding — Strata's
enforcement layer was never installed here (offer `/strata:adopt` or `/strata:init` instead;
this skill only *re-syncs*, it doesn't do first-time install).

**Verify:** you can state, in one sentence, whether the repo is clean or which files are
MISSING/STALE — before touching anything.

## Step 2 — If clean, say so and stop

Exit 0 with no MISSING/STALE lines means the scripts are current. Report that plainly — don't
manufacture work — then still do Step 4 (stamp `.strata/version`): scripts can be byte-identical
while the version stamp itself is stale or missing, and that stamp is the only thing that lets
SessionStart notice drift on its own next time.

## Step 3 — If drifted, show the diff and re-sync

1. Show the user the MISSING/STALE list from Step 1 in plain language (which files, why it
   matters — e.g. "the Stop gate script is 40 lines behind the plugin's, missing the branch-state
   trigger").
2. For every MISSING or STALE file: copy it from `${CLAUDE_PLUGIN_ROOT}/templates/core/scripts/<path>`
   to `scripts/<path>` (preserving the subpath) and `chmod +x` it. Do not touch files the check
   reported `OK`, and do not touch any script under `scripts/` that has no counterpart in the
   templates tree at all — that's the project's own, not Strata's.
3. Merge the `hooks` block from `${CLAUDE_PLUGIN_ROOT}/templates/core/claude-settings-hook.json`
   into `.claude/settings.json` — same rule adopt/init already follow: **append** to existing
   arrays per event, never overwrite, drop the `_strata_note` key. If `.claude/settings.json`
   doesn't exist yet, create it from the template's `hooks` block directly. If an event
   (`PostToolUse`/`SessionStart`/`Stop`) already has a Strata command in its array, don't
   duplicate the entry.
4. Ensure `.gitignore` has the `.strata/*` / `!.strata/state/` pair (see
   `templates/core/gitignore.tmpl`) — merge, never overwrite; older adoptions may still have the
   blanket `.strata/` line, which also works but stops `.strata/state/` from ever being tracked,
   silently disabling the branch-state layer. Fix it if found.

## Step 4 — Stamp the version

Write the plugin's own version (`${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`'s `"version"`
field) to `.strata/version` (plain text, no trailing content beyond the version string). This is
what lets SessionStart notice a *future* drift without anyone running this skill by hand.

## Step 5 — Verify (evidence before assertion)

1. Re-run the Step 1 command — it must now report all `OK` and exit 0.
2. `python3 -c "import json; json.load(open('.claude/settings.json'))"` — still valid JSON.
3. `grep -c strata_stop_gate .claude/settings.json` and the same for
   `strata_session_start` and `sync_raw_mirror` — each present exactly once per event, not
   duplicated.
4. Report a one-line summary: files re-synced (count), settings.json merged (yes/no — it's fine
   if it was already current), version stamped.

## Do NOT use when

- Strata was never installed in this repo at all (no `scripts/`, no `wiki/`) — that's
  `/strata:init` (new project) or `/strata:adopt` (existing project), not an upgrade.
- The user wants a wiki/doc actually updated, not the hooks re-synced — that's `wiki-ingest` or
  `light-finish`'s drift-close, not this skill.
- The user is asking to change what a hook DOES (new trigger, different threshold) — that's a
  change to the plugin's own `templates/core/scripts/`, done in Strata's own repo, not a re-sync
  of an existing installation.
