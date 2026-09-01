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
`OK|AHEAD|STALE|MISSING <path>` per file, exit 0 only when nothing needs attention. The skill runs it
against `${CLAUDE_PLUGIN_ROOT}/templates/core/scripts`, shows the human the diff, then — only for
files reported STALE/MISSING — copies them in (`chmod +x`), merges any new hook entries from
`claude-settings-hook.json` (append, never overwrite — same rule `adopt`/`init` already follow),
and writes `.strata/version` = the running plugin's version.

[[session-start-injection]] closes the loop from the other side: it compares `.strata/version`
against `$CLAUDE_PLUGIN_ROOT`'s own `plugin.json` on every session and prints one line suggesting
`/strata:upgrade` on a mismatch, so drift no longer requires anyone to think to check.

Idempotent by construction: a clean re-run reports all `OK` and touches nothing. Never touches
`wiki/`, `CLAUDE.md`, or application code — purely the mechanical layer.

**STALE ≠ safe to overwrite.** Found running this for real on an external project: its
`check_secrets.sh` was reported STALE, but the diff was the template PLUS ~80 lines of a real
PII guard and a documented AWS-placeholder exception — local additions, not drift behind. The
skill now requires reading the diff and only overwriting when it's the template's own evolution;
a file with genuine local additions gets surfaced to the human, never silently replaced.

**v0.6.1 — the direction is now decided by the script, not by the reader.** Requiring a human to
diff every STALE file was the right instinct and the wrong mechanism: a repo that deliberately
extends a shipped script stayed `STALE` on every single run, so the check exited 1 forever and its
exit code stopped meaning anything — the F4 pattern where a guard nobody can satisfy is a guard
nobody reads. Measured on HorOS: `check_secrets.sh` is the template plus 59 lines (guest-phone PII
guard, AWS-placeholder exception), permanently red. A fourth verdict `AHEAD` splits the two
directions: if no template line is absent from the installed file, the installed file is the
template plus local lines — nothing to copy, so it is printed but does not fail the check. Real
template evolution always leaves at least one line the installed file lacks, so a genuine STALE
cannot be misread as AHEAD; a reordered file reported STALE is the safe way to be wrong.

Two implementation notes worth keeping. `diff | grep` cannot be used to decide the direction —
`pipefail` is on and `diff` exits 1 on *any* difference, poisoning the pipeline status regardless
of what grep matched; the diff is captured into a variable first. And the verdict is behavioural,
not advisory: 4 mutations, 4 killed — inverted direction, `AHEAD` re-armed to fail the gate, the
`pipefail` workaround removed, and the STALE branch deleted outright.

## Related

[[enforcement-layer]] · [[session-start-injection]] · [[branch-state]]

## Sources

[[episodic-state-layer]]
