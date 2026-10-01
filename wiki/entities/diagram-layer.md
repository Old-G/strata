---
title: Diagram layer (wiki/diagrams, Archify)
type: entity
created: 2026-09-12
updated: 2026-09-13
links: [executable-wiki, branch-state, stop-gate, upgrade-path, diff-review]
---

# Diagram layer (`wiki/diagrams/`, Archify)

## TLDR

Every Strata repo may carry `wiki/diagrams/`: one Archify JSON per bounded story, rendered to
one self-contained HTML a human opens to see the whole system, with every node pinned to
`path:line@commit`. A branch that touches a pinned file owes the diagram an update, and
`diagram_check.sh` turns that into `wiki_debt` the [[stop-gate]] already enforces.

## Role

Strata had no diagram story — one SAR line recommending Mermaid — and no check that the
*documented* architecture still matches the code. Archify's evidence pins make a diagram a
verifiable claim: with `--repo-root`, validation reads blobs at the pinned revision and fails
with `repository-evidence/file-missing`, `line-out-of-range` or `revision-unavailable`. That is
[[executable-wiki]]'s `verify:` idea in architecture form, and `audit` gets its first
"architecture vs code" finding.

## Current solutions

**Shipped in v0.8.0.** `templates/core/scripts/diagram_check.sh` + `state_tools.py add-debt`,
`scripts/test_p4_diagrams.sh` (14 assertions) as `validate.sh` §13, wiring in `light-finish` step 5,
`audit` Phase 2 item 6, `onboard`/`init`/`adopt`, and this repo's own first diagram:
`wiki/diagrams/system.architecture.json` + `system.html` — 12 components across the knowledge,
enforcement and process layers, 11 connections, 3 boundaries, 3 guided views, every hook, gate,
skill and agent pinned to a file at the 0.8.0 commit; `validate` 9/9 with `--repo-root`, about
nine diagnosed repairs (positions, edge sides, label placement, a `viewBox` that projected node
copy below 6 px at 1440 px). The pre-spec trial on 2026-09-12 (nine nodes, 807,645-byte HTML,
zero external references) is what proved the path.

- **Layout.** `wiki/diagrams/<name>.architecture.json` (canonical, tracked) + `<name>.html`
  (current render, tracked, ≈0.8 MB, regenerable byte-for-byte) + `history/<date>-<name>.json`
  (tracked, only when `compare` reports a changed `semanticSha256`); `history/*.html` and the
  ≈2 MB delta pages are generated on demand and never committed. First diagram in every repo:
  `system`, ≤ 12 primary nodes, `meta.views` chapters for the main paths. Evidence pins are
  architecture-only; other Archify types (workflow, sequence, dataflow, lifecycle) are optional
  extra stories.
- **Trigger.** `scripts/diagram_check.sh` (template, delivered by [[upgrade-path]]): pinned
  paths ∩ files changed **since the diagram's pinned revision** (`git diff <revision> HEAD` when
  that revision is an ancestor of `HEAD`, else the merge-base window with the base branch) plus
  the working tree; and — when archify is present — a copy of the JSON re-pinned to `HEAD` run
  through `validate --repo-root .`, reporting only `repository-evidence/*` codes. Any hit appends
  `diagram <name>: <reason>` to the [[branch-state]] `wiki_debt` via `state_tools.py add-debt`
  (idempotent). Runs in `light-finish` step 5 and as `audit` Phase 2 item 6; exit 0 always.
  Archify absent → the git half still runs, one skip line, the render waits. The since-revision
  window matters: a diagram authored on a branch *after* the changes it depicts must not be
  flagged by its own branch, which the merge-base window would have done.
- **Refresh.** Agent work inside `light-finish`: edit the changed area (never re-author), set
  `revision` to `HEAD`, `validate` → `deliver` via the archify skill, `compare` against the
  previous JSON, log the summary line, snapshot the JSON if the semantics changed.
- **Declared, not bundled.** Node ≥ 18 plus `~/.claude/skills/archify/bin/archify.mjs`
  (installed by `npx skills add tt-a1i/archify -g`; the skills CLI symlinks into
  `~/.agents/skills/`). No npm dependencies, nothing vendored; `ARCHIFY_UPDATE_CHECK_DISABLED=1`
  wherever Strata invokes it; never called from a hook. `meta.repository.url` from
  `git remote get-url origin`; `link_mode: web` for GitHub/Gitee, `local-only` for other forges.
- **Mermaid** leaves SAR §14 and is not converted anywhere.
- **Not a gate.** A stale diagram is a debt item and an audit finding, never a refused commit.

**Since v0.16.0 — Archify 3.x** (checked against 3.0.1, 2026-10-01; 2.x still works): `meta.output`
is required, an explicit `meta.viewBox` is dropped (a declared canvas is held to 3.0's
desktop-readability floor — five of six diagrams on this machine failed it; without one all six pass
on both versions), `meta.repository.url` is the origin verbatim (an SSH host alias is not resolved),
`meta.views` is ignored. `diagram_check.sh` now prints `pins NOT verified` when Archify fails for a
non-pin reason — before, a schema error read as "all pins hold". Contract: `reference/tool-integration.md`.

## Related

[[executable-wiki]] · [[branch-state]] · [[stop-gate]] · [[upgrade-path]] · [[diff-review]] ·
[[gardener]]

## Sources

[[p4-field-patterns]] D2–D5 · Archify `SKILL.md`, `references/authoring-contract.md`,
`schemas/architecture.schema.json` · hands-on trial 2026-09-12
