---
title: Diagram layer (wiki/diagrams, Archify)
type: entity
created: 2026-09-12
updated: 2026-09-12
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

Spec'd in P4 ([[p4-field-patterns]] D2–D5), not yet built. Verified by hand on 2026-09-12: a
nine-node architecture of Strata's knowledge and enforcement layers reached `validate` 9/9 and
`deliver` after about eight diagnosed repairs — 4,766 bytes of JSON, 807,645 bytes of HTML with
zero external references and fonts embedded, five pins linking to
`github.com/Old-G/strata/blob/<sha>/…`.

- **Layout.** `wiki/diagrams/<name>.architecture.json` (canonical, tracked) + `<name>.html`
  (current render, tracked, ≈0.8 MB, regenerable byte-for-byte) + `history/<date>-<name>.json`
  (tracked, only when `compare` reports a changed `semanticSha256`); `history/*.html` and the
  ≈2 MB delta pages are generated on demand and never committed. First diagram in every repo:
  `system`, ≤ 12 primary nodes, `meta.views` chapters for the main paths. Evidence pins are
  architecture-only; other Archify types (workflow, sequence, dataflow, lifecycle) are optional
  extra stories.
- **Trigger.** `scripts/diagram_check.sh` (template, delivered by [[upgrade-path]]): pinned
  paths ∩ `git diff --name-only <base>...HEAD`, plus — when archify is present — a copy of the
  JSON re-pinned to `HEAD` run through `validate --repo-root .`. Any hit appends
  `diagram <name>: <reason>` to the [[branch-state]] `wiki_debt`. Runs in `light-finish` step 5
  and as `audit` Phase 2 item 6. Archify absent → the debt still lands, the render waits.
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

## Related

[[executable-wiki]] · [[branch-state]] · [[stop-gate]] · [[upgrade-path]] · [[diff-review]] ·
[[gardener]]

## Sources

[[p4-field-patterns]] D2–D5 · Archify `SKILL.md`, `references/authoring-contract.md`,
`schemas/architecture.schema.json` · hands-on trial 2026-09-12
