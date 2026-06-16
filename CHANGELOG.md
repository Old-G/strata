# Changelog

All notable changes to Strata are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] — 2026-06-16

### Fixed
- **Plugin install failed** — `plugin.json` declared `"agents": ["./agents/"]` (an array containing a
  folder), which the Claude Code manifest validator rejects. A folder reference must be a **string**
  (`"agents": "./agents/"`), matching `skills`. `validate.sh` now catches this format regression.

## [0.1.0] — 2026-06-16

Initial release. Strata packaged as a Claude Code plugin.

### Added
- **Plugin manifests** — `.claude-plugin/plugin.json` + `marketplace.json` (the repo is its own marketplace).
- **9 skills** (`/strata:<name>`): `using-strata` (entry router), `init`, `adopt`, `audit`,
  `refactor`, `feature`, `office-hours`, `autoplan`, `wiki-ingest`.
- **4 review-council subagents** (read-only, parallel, may disagree): `strata-ceo-review`,
  `strata-eng-review`, `strata-design-review`, `strata-cso-review`.
- **templates/core** — `PROJECT_PATTERN.md`, `WIKI.md`, the `wiki/` skeleton, `CLAUDE.md`/`ADR-Lean`
  templates, the docs→raw mirror script, and pre-commit guards.
- **templates/stacks/python-fastapi** — `SCALABLE_ARCHITECTURE_REFERENCE.md` (the architecture canon).
- **reference/** — council personas, tool-integration (RTK / claude-mem / Caveman), Diataxis doc-map.
- **CI** — `scripts/validate.sh` + a GitHub Actions workflow validating manifests, skill/agent
  frontmatter, and script syntax.

### Security
- Genericized all templates for public release: removed an internal service inventory from `WIKI.md`,
  emptied the hardcoded drift-check manifest and an employee name reference in `lint.py`, and quoted a
  glob-expansion in `sync_raw_mirror.sh` (findings from a dogfooded `strata-cso-review` pass).
- Removed an incomplete MCP-scaffold script that referenced a non-bundled template directory.

### Notes
- Methodology adapts [gstack](https://github.com/garrytan/gstack) (MIT) and wraps
  [Superpowers](https://github.com/obra/superpowers); composes claude-mem and RTK as declared
  prerequisites (not bundled).
- All shipped templates and docs are in English.
