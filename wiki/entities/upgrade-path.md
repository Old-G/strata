---
title: Upgrade path (/strata:upgrade)
type: entity
created: 2026-09-01
updated: 2026-09-01
links: [enforcement-layer, session-start-injection, branch-state]
---

# Upgrade path (/strata:upgrade)

## TLDR

`skills/upgrade/` + `scripts/strata_upgrade_check.sh` — re-syncs a repo's installed
`scripts/**` and `.claude/settings.json` hook block with whatever plugin version is currently
running.

## Role

`init` and `adopt` **copy** `templates/core/scripts/**` into a target repo once, at adoption
time. There was no re-sync command — updating the Strata plugin never reached a repo adopted in
the past. Confirmed on a real external project: `wiki/` fully populated, **zero** of the three
enforcement hooks installed, because it was adopted before v0.4.0 shipped them. Every later
plugin release stayed invisible to that repo. This is the fix.

## Current solutions

**Shipped in v0.5.0.** `strata_upgrade_check.sh <templates-dir> [<installed-dir>]` is a pure diff
reporter (no side effects): walks every file the current plugin ships and prints
`OK|STALE|MISSING <path>` per file, exit 0 only when nothing needs attention. The skill runs it
against `${CLAUDE_PLUGIN_ROOT}/templates/core/scripts`, shows the human the diff, then — only for
files reported STALE/MISSING — copies them in (`chmod +x`), merges any new hook entries from
`claude-settings-hook.json` (append, never overwrite — same rule `adopt`/`init` already follow),
and writes `.strata/version` = the running plugin's version.

[[session-start-injection]] closes the loop from the other side: it compares `.strata/version`
against `$CLAUDE_PLUGIN_ROOT`'s own `plugin.json` on every session and prints one line suggesting
`/strata:upgrade` on a mismatch, so drift no longer requires anyone to think to check.

Idempotent by construction: a clean re-run reports all `OK` and touches nothing. Never touches
`wiki/`, `CLAUDE.md`, or application code — purely the mechanical layer.

## Related

[[enforcement-layer]] · [[session-start-injection]] · [[branch-state]]

## Sources

[[episodic-state-layer]]
