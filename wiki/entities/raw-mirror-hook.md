---
title: raw mirror hook
type: entity
created: 2026-08-15
updated: 2026-08-15
links: [pending-ingest-marker, enforcement-layer]
---

# raw mirror hook

## TLDR

`scripts/sync_raw_mirror.sh` — a PostToolUse hook that copies every edited `docs/*.md` into
the read-only `raw/` mirror and appends a [[pending-ingest-marker]] to `wiki/log.md`.

## Role

Keeps the AI-readable mirror byte-identical to the human source-of-truth without anyone
remembering to copy files, and emits the freshness signal the rest of the pipeline reads.
It is the write side of the three-layer split `docs/ → raw/ → wiki/`.

## Current solutions

Bash + a small `python3` shim to parse the hook's JSON payload. Two modes: hook mode reads
the PostToolUse event from stdin and extracts `tool_input.file_path` for
`Edit|Write|MultiEdit|NotebookEdit`; CLI mode takes explicit paths as arguments. It always
exits 0 — a mirror failure must never block Claude, since `check_raw_mirror.sh` catches the
same drift at commit time.

Installed **per target project** by `init` / `adopt` into that project's
`.claude/settings.json` (template: `templates/core/claude-settings-hook.json`); the plugin
itself ships no global hooks. The Strata repo dogfoods it on its own `docs/superpowers/`
tree.

Defect found and fixed while dogfooding this pipeline (v0.4.0): the marker was written only if
that exact string had *never* appeared in `wiki/log.md`, so a doc edited again after being ingested
produced no signal at all — permanently, for every doc ever ingested. It now consults the shared
retirement rule instead.

Known gap (deferred to P3 as A5): PostToolUse never fires when a human edits `docs/*.md` in
the IDE. A `FileChanged` event, whose matcher is a filename pattern, covers that case —
migrate when the minimum supported Claude Code version allows, keeping PostToolUse as
fallback.

## Related

[[pending-ingest-marker]] · [[enforcement-layer]] · [[commit-gate]]

## Sources

[[vnext-brief]] §1, §2 (A5) · `templates/core/scripts/sync_raw_mirror.sh`
