---
title: "ADR #3 — Projects live inside HQ"
type: decision
created: 2026-08-15
updated: 2026-08-15
status: accepted
---

# ADR #3 — Projects live inside HQ

## Context

[[hq-mode]] needs member projects reachable from one session. Two layouts were possible:
projects scattered in their existing locations and referenced by path from `registry.yaml`, or
projects physically nested under `~/hq/projects/`.

## Decision

One global folder with projects nested inside it. `~/hq` is a git repo tracking only the
meta-layer (`.gitignore: projects/`); each project keeps its own git repo and its own `wiki/`.
`registry.yaml` is **auto-discovered** from `projects/*/wiki` (this also answers OQ#2).

## Consequences

- Claude Code loads `CLAUDE.md` up the directory tree, so a session opened inside
  `projects/horos/` automatically also gets `~/hq/CLAUDE.md` — global rules for free, no
  `--add-dir` ceremony.
- A session opened at `~/hq` has the whole world in reach.
- Context economy is preserved by two wiki levels rather than by physical distance: the global
  session resolves in three small hops (`hq/wiki/index.md` → `hq/wiki/projects/<name>.md` →
  the project's own `wiki/index.md` → entity) and never bulk-reads project wikis.
- Cost: existing repos must be moved into `~/hq/projects/`, and nesting git repos inside a git
  repo requires the `projects/` ignore rule to be correct or HQ's git will try to track them.

## Sources

[[vnext-brief]] §10 (also resolves OQ#2)
