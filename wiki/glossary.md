---
title: Glossary
type: entity
created: 2026-08-15
updated: 2026-09-26
links: [overview]
---

# Glossary

Short definitions of project-specific terms, acronyms, and patterns. Each `ingest` adds
new terms here.

This table is **also the drift-protection source-of-truth**: for any fact that risks
diverging across pages (a formula, a schema name, a version number, a canonical value),
record the authoritative value here and point other pages at this row. When `lint`
finds a page contradicting the glossary, the glossary wins — fix the page.

| Term | Definition | Source of truth |
|---|---|---|
| Strata | The self-describing / self-correcting repo system: a curated, git-versioned `wiki/` the AI queries before grepping the codebase. | [[overview]] |
| ingest | The operation that turns a `raw/<file>.md` into wiki pages (source summary + entities + ADRs + glossary + index + log). | `WIKI.md` |
| drift | When `docs/`, `raw/`, and `wiki/` (or two wiki pages) disagree about a fact. Surfaced by `lint`, fixed by re-ingest — never auto-fixed. | `WIKI.md` |
| pending_ingest | Marker line in `wiki/log.md` meaning a doc was mirrored to `raw/` but not yet ingested. The single token the enforcement layer reads. | [[pending-ingest-marker]] |
| Stop gate | `Stop`-event hook that refuses to end the turn once while this session owes wiki work. | [[stop-gate]] |
| friction signal | One of three deterministic counts read from the session transcript at `Stop`: interrupts ("Request interrupted by user"), denials (the user declined a tool call), tool errors (`"is_error":true`). Default thresholds 1 / 2 / 8. | [[friction-capture]] |
| gotcha / no-gotcha | The one-line answer to a friction block: a `gotchas` entry in the branch state, or `gotcha: <what>` / `no-gotcha: <why>` in `wiki/log.md`. | [[friction-capture]] |
| evidence pin | An Archify `sources[]` entry (`path`, optional `line`/`end_line`, `label`) verified against the blob at `meta.repository.revision`; an unresolvable pin fails the render with a `repository-evidence/*` rule code. | [[diagram-layer]] |
| diagram layer | `wiki/diagrams/`: canonical `<name>.architecture.json` + one tracked `<name>.html`; dated JSON history only when `compare` reports a changed `semanticSha256`; history HTML never committed. | [[diagram-layer]] |
| promotion ladder | observation → branch-state `gotchas` → `wiki/log.md` (once) → `CLAUDE.md` "Things Claude gets wrong" (second occurrence) → a hook (when the line says always/never). | [[p4-field-patterns]] D6 |
| Archify | MIT agent skill + dependency-free Node CLI (`node bin/archify.mjs`) compiling typed JSON IR into validated, self-contained HTML diagrams; declared by Strata, never bundled. | [[diagram-layer]] |
| diagram_check.sh | `scripts/diagram_check.sh [base]` — pinned paths ∩ files changed since the pinned revision, plus a re-pin-to-HEAD archify validate; findings → `wiki_debt`; exit 0 always, never a hook. | [[diagram-layer]] |
| Agent-Session trailer | `Agent-Session: <id>` on every commit made inside a Claude Code session (`prepare-commit-msg`, id from `CLAUDE_CODE_SESSION_ID`); human commits carry none. `STRATA_SKIP_TRAILER=1` skips one. | [[agent-session-trailer]] |
| strata_why.sh | `scripts/strata_why.sh <file> [-L a,b] [--history]` — blame → commits → trailers → the local transcript, offered only if the session ran inside this repo. Read-only. | [[agent-session-trailer]] |
| provenance | The trail from a line of code to the session that wrote it; history, not specification — every claim re-checked against current code. | [[agent-session-trailer]] |
| lens | A reading bucket for a diff: non-implementation swept first, then implementation by design part in reading order. | [[diff-review]] |
| decided, not asked | A choice the agent made that neither the plan nor the user settled; unrecorded + behaviour-changing is Important at branch close. | [[diff-review]] |
| auto-sync | SessionStart re-syncing `scripts/**` from a newer plugin with `--apply-safe`; locally edited files are left and named; `STRATA_NO_AUTOSYNC=1` opts out. | [[upgrade-path]] |
| scripts.history | `templates/core/scripts.history` — blob hash of every version every template ever shipped; what auto-sync may replace. Regenerate: `scripts/gen_template_history.sh`. | [[upgrade-path]] |
| strata-upgrade-all | Plugin `bin/` command (on PATH in sessions): the safe sync for every Strata project on the machine; never commits. | [[upgrade-path]] |
| commit gate | Pre-commit guard that fails the commit while any `pending_ingest` marker is outstanding. Escape hatch: `STRATA_SKIP_WIKI=1`. | [[commit-gate]] |
| SessionStart injection | Hook whose stdout becomes model context; opens every session with branch, pending list, and wiki index head. Budget ~30–50 lines. | [[session-start-injection]] |
| advisory vs deterministic | Skill prose is probabilistic; hooks are deterministic. Rule: if you write "the agent must always…", that is a hook, not a paragraph. | [ADR #1](decisions/adr-1-deterministic-enforcement.md) |
| HQ | A separate Strata repo whose wiki is a meta-index of project indexes; its registry lists projects where they already live, from one declared source (`hq.yaml`). | [[hq-mode]] |
| gardener | Two-tier nightly job: deterministic fact verification (free), then one scoped `claude -p` curation session. Never pushes to main. | [[gardener]] |
| anacron semantics | "Run at 03:33; if the machine was asleep or off, run once on wake or login — never more than once per ~20h." launchd triggers + a stamp-file check in the wrapper. | [[gardener]] |
| ablation | Empirically deleting instructions to find which the current model still needs. Boris Cherny's 6-month purge; the enforcement layer is exempt. | [[ablate]] |
| ACE | Agentic Context Engineering (arXiv 2510.04618): Generator / Reflector / Curator with delta-bullet updates. | [[session-reflector]] |
| brevity bias | ACE failure mode: summarizing away the domain details that actually mattered. | [[session-reflector]] |
| context collapse | ACE failure mode: iterative full rewrites eroding accumulated knowledge. Why ingest appends and never clobbers. | [[session-reflector]] |
| executable wiki | Entity facts carrying a read-only `verify:` command and a freshness window; two consecutive failures flip the fact to `stale`. | [[executable-wiki]] |
| closed-routes | `wiki/closed-routes.md` — ledger of what was tried and why it failed, handed forward as a do-not-repeat list. | [[session-reflector]] |
| negative control | A deliberately broken variant a review or test suite is required to catch; one that passes it is itself broken. | [[agent-teams]] |
| epistemic firewall | Reporting house style: claims carry their verification status — verified-by-test / agent-claimed / assumed. | [[vnext-brief]] |
| Career ledger | Append-only `hq/ledger/ledger.jsonl` of shipped/decided events, compiled on demand into review, raise-case, or portfolio docs. | [[career-ledger]] |
| llms.txt / AGENTS.md | Cross-agent interop formats the wiki can compile to, so non-Claude agents read the same spine. | [[wiki-emit]] |
| thin glue | Strata composes claude-mem, RTK, and the project's tests; it never reimplements memory, token proxying, or testing. | `CLAUDE.md` |
