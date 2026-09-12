---
title: "P4 — Friction, evidence-pinned diagrams, and the promotion ladder (spec)"
type: source
source: raw/superpowers/specs/2026-09-12-p4-field-patterns.md
created: 2026-09-12
updated: 2026-09-13
links: [friction-capture, diagram-layer, stop-gate, branch-state, session-reflector, executable-wiki, upgrade-path, gardener]
---

# P4 — Friction, evidence-pinned diagrams, and the promotion ladder

Sources: [spec](../../raw/superpowers/specs/2026-09-12-p4-field-patterns.md) ·
[plan](../../raw/superpowers/plans/2026-09-12-p4-field-patterns-plan.md) · status: approved and implemented
2026-09-13 on `strata/p4-field-patterns`, shipped as v0.8.0.

## Summary

Three field reports read against Strata v0.7.0 on 2026-09-12: Tencent's **TeamAI-CLI** (a git
repo of team skills / rules / learnings pulled into every member's agent, a friction-scored Stop
hook, confidence-ranked learnings, MIT, 4.3k stars), **Archify** (an agent skill plus a
dependency-free Node CLI compiling typed JSON into validated self-contained HTML diagrams with
commit-pinned source evidence, MIT), and **OpenAI's Agents API** (public beta 2026-09-10; a
managed harness with compaction, tool search, programmatic tool calling, sandboxes and a
file-based memory directory). Verdict: all three independently converge on git-as-memory,
index-first progressive disclosure and skills-as-a-directory — confirmation of Strata's bets,
and none of them has a deterministic gate on knowledge freshness. What they contribute are
mechanisms, not architecture.

## The three gaps they expose

1. **Strata cannot tell a painful session from a routine one.** TeamAI's insight — the sessions
   worth documenting are the ones with friction, and friction is countable without an LLM —
   answers the reflector's open question OQ#8. Verified on this repo's four transcripts: tool
   errors, "Request interrupted by user" and permission denials are plain JSONL lines the Stop
   hook already receives via `transcript_path`. → [[friction-capture]].
2. **Strata has no diagram story and no check that documented architecture matches code.**
   Archify's evidence pins (`sources[] {path, line, end_line}` verified against the blob at
   `meta.repository.revision`, failing with stable rule codes) are [[executable-wiki]] applied
   to architecture. → [[diagram-layer]]. Mermaid leaves the SAR.
3. **The promotion ladder is real but unnamed.** gotcha → `wiki/log.md` → `CLAUDE.md` on the
   second occurrence → hook when the line says always/never. One `WIKI.md` section fixes that;
   the same pass names Claude Code's auto memory as a third memory next to claude-mem and `wiki/`.

## Hands-on evidence recorded in the spec

Archify unpacked in a scratch directory on Node 22: a nine-node architecture of Strata's
knowledge and enforcement layers with five pins on real template scripts reached `validate`
9/9 with `--repo-root` after about eight diagnosed repairs; `deliver` produced an 807,645-byte
HTML with zero external references and every pinned node linking to
`github.com/Old-G/strata/blob/<sha>/<path>`; breaking a pin (missing file, line past EOF,
unknown revision) failed with `repository-evidence/file-missing`, `line-out-of-range`,
`revision-unavailable`; `compare` returned per-kind change counts plus a `semanticSha256`, and a
2.2 MB delta HTML. Anthropic counterparts to the Agents API were verified the same day
(Managed Agents beta, compaction, tool search, memory tool, Claude Code auto memory).

## Decisions D1–D7

- **D1** friction is Stop-gate trigger (d): three `grep -c` counts over the session's own
  transcript, thresholds `1 / 2 / 8` via env, one-block cap unchanged, satisfiable by a `gotcha:`
  or `no-gotcha:` line; the correction-keyword heuristic is not adopted.
- **D2** `wiki/diagrams/<name>.architecture.json` canonical + one tracked `<name>.html`; dated
  JSON history only when `semanticSha256` changed; history HTML and deltas never committed
  (owner may choose otherwise).
- **D3** `diagram_check.sh`: pinned paths ∩ branch diff, plus a re-pin-to-HEAD validate when
  archify is present; hits become `wiki_debt`; runs in `light-finish` step 5 and `audit`
  Phase 2; the refresh itself is scoped agent work through the archify skill.
- **D4** declared, not bundled: `tool-integration.md` section, `onboard` row, `init`/`adopt`
  offer a seed; `link_mode` web for GitHub/Gitee, `local-only` for other forges.
- **D5** Mermaid removed from SAR §14; `PROJECT_PATTERN.md` names `wiki/diagrams/`.
- **D6** ladder written once in `WIKI.md`; auto-memory paragraph in the never-double-store rule.
- **D7** deferred with a paragraph each: recall counts → [[gardener]]; owned-region `CLAUDE.md`
  markers → [[upgrade-path]]. Not adopted: code graph, roles/tags, MR-gated knowledge,
  Agents-API mechanisms, an own renderer.

## Plan

T0 prerequisites (archify installed, branch state) → T1 friction (tests first, one grep pass over the
transcript, `validate.sh` §12) → T2 docs (ladder in `WIKI.md`, auto-memory paragraph) → T3 diagram
layer (`state_tools.py add-debt`, `diagram_check.sh` + §13, skill wiring, Mermaid out, Strata's own
`system` diagram) → T4 deferred paragraphs → T5 `0.8.0` and dogfood close. T1 ∥ T3. Every step
names its verify command in the plan file.

## Related

[[friction-capture]] · [[diagram-layer]] · [[stop-gate]] · [[branch-state]] ·
[[session-reflector]] · [[executable-wiki]] · [[upgrade-path]] · [[gardener]] · [[sdlc-right-side]]
