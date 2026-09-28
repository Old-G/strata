---
title: "ADR #6 — The HQ registry lists projects where they already live, from one declared source"
type: decision
created: 2026-09-27
updated: 2026-09-27
status: accepted
---

# ADR #6 — The HQ registry lists projects where they already live, from one declared source

Supersedes [ADR #3](adr-3-hq-nested-layout.md).

> **2026-09-28:** HQ now lives in its own plugin, [strata-hq](https://github.com/Old-G/strata-hq), where this decision is
> ADR-1. Kept here as the record.

## Context

[ADR #3](adr-3-hq-nested-layout.md) nested every project physically under `~/hq/projects/` and
auto-discovered the registry from `projects/*/wiki`. It was never built, and it does not survive
contact with a real machine: moving repos breaks every tool that already knows their paths —
editor and workspace-manager state, worktrees, schedulers, deploy scripts, agent memory. The
alternative of crawling a folder for repos picks up clones, archives and experiments that were
never meant to be managed.

What a person actually works on is usually already written down somewhere: in their own list, or
in a workspace manager that holds their projects and groups (Orca is the first such tool Strata
reads).

## Decision

1. **Projects stay where they are.** HQ is its own git repo holding only the meta-layer; nothing
   is moved into it and nothing under it is a member repo.
2. **One declared source.** `hq.yaml` names where the registry comes from:
   - `paths` (default) — an explicit list of project paths; needs no other tool;
   - `orca` — the projects added to Orca, with their groups (`<cli> repo list --json`, group
     names from `<cli> repo groups --json`); the CLI name is a setting.
   No folder crawl. HQ's own repo is never listed.
3. **One writer.** Only the sync (`scripts/hq_registry.py`, later `hq-sync`) writes
   `registry.yaml` and project pages. Tools outside HQ may ask for a sync; they never write into it.
4. **Identity comes from the source, not from the name.** Each entry keeps `id` (the Orca repo id,
   or the absolute path for `paths`), `source`, `path`, `kind` (git | folder), `group` and a page
   slug fixed at creation, so a rename or a move updates the entry instead of creating a second
   page.
5. **Removal needs positive evidence.** A project leaves the registry only when a *successful*
   read of the source no longer contains it; its page moves to `projects/_archive/`. A source that
   cannot be read keeps the last registry untouched.
6. **Group ≠ hub.** A group is a working set. A hub is an optional Strata project that owns a set of
   project pages; a project belongs to the hub whose root contains its path, or to one named
   explicitly for its group. HQ links project → hub → project wiki; it never copies a hub's pages.
7. **Pure read of members** (unchanged from [[hq-mode]]): the sync reads HEAD, manifests, the head
   of `wiki/index.md` and the tail of `wiki/log.md`; it never writes into a member project.

## Consequences

- Sessions opened inside a project no longer inherit HQ's `CLAUDE.md` by directory walk (the one
  real benefit of ADR #3). The route to HQ is the short user-scope pointer in `~/.claude/CLAUDE.md`
  that the brief (§3 B1) already planned.
- Strata needs no external tool for HQ: `paths` works anywhere. An adapter is optional and thin —
  it only turns a tool's own listing into entries.
- The Orca adapter degrades instead of failing when the CLI has no `repo groups`: group ids still
  come from `repo list`, names fall back to the previous registry, else `null`, with a warning.
  A failed `repo list` is a failed read (rule 5).
- Folder workspaces have no HEAD: change detection uses a file fingerprint (paths + mtimes)
  instead of `synced_sha`. Remote (SSH) projects are listed with their host and marked
  `unverifiable` until the sync can read them through that host — never guessed from local disk.
- No nested-git `.gitignore` trap: HQ contains no member repos.

## Sources

[[vnext-brief]] §3, §10 · [ADR #3](adr-3-hq-nested-layout.md)
