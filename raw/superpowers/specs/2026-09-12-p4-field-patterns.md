# P4 — Friction, evidence-pinned diagrams, and the promotion ladder

**Status:** spec, awaiting approval **Date:** 2026-09-12 **Tier:** risky
**Source:** three field reports read against Strata v0.7.0 — Tencent TeamAI-CLI, Archify, and
OpenAI's Agents API · [[sdlc-right-side]] [[enforcement-layer]] [[session-reflector]] [[branch-state]]

---

## Intent

Three independent teams shipped, in the same season, the same three bets Strata is built on:
git as the memory store, a small index paid every session with detail loaded on demand, and
skills as a directory in a repository. That is confirmation, not competition — none of the
three has a deterministic gate on knowledge freshness, which remains Strata's one real
differentiator. What they *do* have is a handful of mechanisms Strata lacks, each of which
lands on plumbing that already exists here:

1. **The sessions worth documenting are the painful ones, and pain is measurable.** TeamAI's
   Stop hook counts interruptions, denied tool calls and tool retries, and only then suggests
   writing a learning. Strata's Stop gate knows about wiki debt but has no notion of "this
   session hurt". Our open question OQ#8 — trigger the reflector on every session, or only on
   the ones that failed? — has an answer: on friction, and friction needs no LLM to detect.
   Verified on this repo's own four transcripts: `is_error` tool results, "Request interrupted
   by user" and permission denials are plain lines in the JSONL the Stop hook already receives.
2. **A diagram whose boxes are pinned to `file:line@commit` is a verifiable claim.** Archify
   compiles a typed JSON IR into a self-contained HTML viewer and refuses to render when a pin
   does not resolve at the pinned revision (`repository-evidence/file-missing`,
   `line-out-of-range`, `revision-unavailable`, each a stable rule code, exit 1). That is
   [[executable-wiki]] applied to architecture, and the first check Strata can run for "does
   the documented architecture still match the code". Strata today has no diagram story at all
   beyond one line in the SAR recommending Mermaid.
3. **The promotion ladder exists but is not named.** TeamAI states thresholds for a learning
   to become a rule (confidence ≥ 0.90, ≥ 5 upvotes, ≥ 2 contributors, ≥ 14 days). Strata's
   equivalent is spread across three files: branch-state `gotchas` → `wiki/log.md` → the
   second-occurrence rule → one `CLAUDE.md` line → a hook when the line says "always/never".
   Writing the ladder down once costs a paragraph.

When this ships: a session that ended with two interrupts and three denied tool calls cannot
close without either a recorded gotcha or an explicit `no-gotcha:` line; every Strata repo can
carry a `wiki/diagrams/` folder whose HTML opens as a whole-system picture with every node
linking to the commit-pinned source; a branch that changes a pinned file owes the diagram an
update and the Stop gate knows it; and the SAR no longer says Mermaid.

## What the field reports say (digest)

**TeamAI-CLI** (Tencent, MIT, 4.3k stars, 745 commits). A team repo of `skills/`, `rules/`,
`docs/`, `agents/`, `mcp/`, `hooks/`, `learnings/`, `teamwiki/`; `teamai push` opens a merge
request, a SessionStart hook runs `teamai pull` after the merge, resources are materialised
into each agent's config (Claude Code: `~/.claude/skills/`, `CLAUDE.md` between
`<!-- [teamai:rules:start] -->` markers, `~/.claude/agents/`; Cursor: `.mdc` rules). Roles,
tags and projects filter what a member receives. Learnings are markdown with `confidence`
0–1, auto-upvoted on recall, searched by BM25 with no vector store ("zero external
dependencies"). The friction hook counts `interrupt`, `toolReject`, `correction` (a follow-up
within 60 s containing a correction keyword) and suggests `/teamai-share-learnings` once. A
`teamwiki/` code graph is built with tree-sitter (TS/JS, Python, Go) plus regex fallback;
`--deep-enrich` shells out to the local `claude` CLI, no API call. Hooks are installed at
**user scope** — the opposite of Strata's per-project templates. Their own design doc defers
the "Reflect" layer until 20+ learnings exist: the cold-start problem is shared.

**Archify** (tt-a1i, MIT, GitHub shows ~59k stars, v2.17). An agent skill plus a Node CLI
(`node bin/archify.mjs`, Node ≥ 18, **no npm dependencies**, 6.4 MB unpacked, 79 files,
installed by `npx skills add tt-a1i/archify -g` into `~/.claude/skills/archify`). Five
diagram types — `architecture`, `workflow`, `sequence`, `dataflow`, `lifecycle`. The agent
authors JSON (components with semantic `type`, connections, boundaries, ≤ 12 primary nodes,
explicit `pos`/`size` or a `grid` layout), then `validate` → `deliver`: nine artifact checks,
fail-closed, atomic replace, SHA-256 receipts. Explicitly not Mermaid: "don't build generic
Mermaid beautifiers". Evidence: `meta.repository {url, revision(40-hex), link_mode
web|local-only}` plus `components[].sources[] {path, line, end_line, label}` (≤ 3 per node);
`--repo-root` makes validation read blobs *at the pinned commit*, locally, no network.
`compare base.json head.json` yields a delta HTML and a JSON summary with per-kind
added/removed/changed/moved counts and a `semanticSha256` that ignores presentation.
`visual-check` is optional and drives an already-installed Chrome over DevTools; no
Playwright. Only the `guide`/update check touches the network, disabled by
`ARCHIFY_UPDATE_CHECK_DISABLED=1`.

**OpenAI Agents API** (public beta 2026-09-10). One call creates a session — model,
instructions, tools (`programmatic_tool_calling`, `mcp`, `web_search`), environment
(`openai_hosted` or `self_hosted` with `capability_directories` for skills), subagents.
Harness features: automatic compaction near the limit, tool search (schemas loaded on
demand), programmatic tool calling, hosted or partner sandboxes; tokens-and-containers
pricing, US-only, no ZDR. The SDK's sandbox memory is a directory: `memory_summary.md` →
`MEMORY.md` → `raw_memories/` → `rollout_summaries/`. Anthropic's counterparts, verified
2026-09-12: Managed Agents (beta, tokens only, skills discovered from a git repo), server-side
compaction, the tool search tool, the memory tool, and Claude Code's auto memory
(`MEMORY.md` index, first 200 lines / 25 KB loaded per session). Verdict: harness-level;
nothing to port. Two consequences only — the memory shape converged three times
independently (index → page → raw), and Claude Code's auto memory is a *third* memory next to
claude-mem and `wiki/` that `reference/tool-integration.md` does not mention yet.

## Hands-on evidence (2026-09-12, this repo)

- **Transcripts.** Four session transcripts under this project's Claude directory: 21
  `"is_error":true` tool results, 5 "Request interrupted by user" lines, 10 permission
  denials. Every line carries `timestamp`, `sessionId`, `gitBranch`, `isSidechain`.
- **Archify end to end.** `archify.zip` unpacked in a scratch directory, `doctor` all `[ok]`
  on Node 22. A nine-component / eight-connection / two-boundary architecture of Strata's
  knowledge and enforcement layers, with five `sources` pins on real template scripts and
  `revision` = `HEAD`, reached `validate` 9/9 with `--repo-root` after about eight
  diagnosed repairs (positions, edge sides, label placement — each diagnostic names the
  subject and often the fix). `deliver` wrote **807,645 bytes** of HTML: zero external
  references, fonts embedded, every pinned node linking to
  `github.com/Old-G/strata/blob/<sha>/<path>`; the JSON is **4,766 bytes**. Breaking one pin
  (missing file, line past EOF, unknown revision) failed validation with the three rule codes
  above. Without `--repo-root` a diagram that declares evidence refuses to render
  (`repository-evidence/root-required`). `compare` on the bundled base/head fixtures returned
  a summary (`components.added 1, removed 1, changed 1, moved 1 …`) and a **2.2 MB** delta HTML.

## Constraints

- **Thin glue holds.** Archify is declared like RTK and claude-mem — detected, used if
  present, skipped with one line if not. Nothing is vendored; no `node_modules` enter a
  target repo. Node ≥ 18 is the only requirement, and only on machines that render.
- **Reuse the enforcement shapes.** Friction is a fourth trigger inside the existing Stop
  gate, under the existing one-block-per-session cap, satisfiable in one line, escapable by
  env var, fail-open on an unreadable transcript, measured on the clean path. No new hook
  event, no new gate.
- **No archify in hooks.** The diagram scripts run inside `light-finish` and `audit` and in a
  standalone check, never from a `Stop`/`PreToolUse`/`PostToolUse` hook. Gates stay
  offline and fast; `ARCHIFY_UPDATE_CHECK_DISABLED=1` is set wherever Strata invokes it.
- **One marker rule, one implementation.** Diagram debt is expressed as a `wiki_debt` item in
  the branch state — the Stop gate's trigger (c) already enforces those. No second marker.
- **Diagrams are a human artifact, never a blocking gate.** The AI reads `wiki/` text; the
  HTML exists so a person can open one file and see the system. A stale diagram is a debt
  item and an `audit` finding, not a refused commit.
- `CLAUDE.md` ≤ 200 lines. Release rule: shipped behaviour → `0.7.0 → 0.8.0` in both
  manifests. Repo artifacts in English.
- **Dogfood.** Strata's own `wiki/diagrams/system.architecture.json` is the first diagram, and
  the branch that ships this closes through a `light-finish` that runs the new diagram check.

## Decisions (made here so the implementing session does not re-litigate)

**D1 — Friction is Stop-gate trigger (d), computed from `transcript_path`.**
The gate reads the session's own transcript (already its file; sidechains dropped by
`"isSidechain":true`), counts three signals with `grep -c`: `interrupts` = lines containing
`Request interrupted by user`; `denials` = tool results whose text says the user declined
(`doesn't want to proceed` and the current CLI's equivalents, kept in one pattern variable);
`tool_errors` = `"is_error":true`. Defaults, tunable by env: `STRATA_FRICTION_INTERRUPTS=1`,
`STRATA_FRICTION_DENIALS=2`, `STRATA_FRICTION_ERRORS=8` (`is_error` includes every failed
`grep`; this repo's baseline is ~5 per session). `STRATA_FRICTION_INTERRUPTS=0` and friends
disable a signal; all zero disables the trigger. Trigger (d) fires only when no earlier
trigger fired, when at least one signal meets its threshold, and when nothing was recorded
this session — `wiki/log.md` unchanged since the session stamp and the branch state (if any)
not modified after it. Reason text: the three counts, then *"Record what went wrong: add a
`gotchas` entry to `.strata/state/<branch>.json`, or append one line `gotcha: <what>` or
`no-gotcha: <why>` to `wiki/log.md`."* When (a)/(b)/(c) fire anyway and friction is also
present, the counts are appended to that reason for free. The transcript pass runs last and
only after the cheap checks; budget ≤ 50 ms on a 5 MB transcript, verified in the test. TeamAI's
"correction keyword" heuristic is **not** adopted — language-dependent and noisy in a
bilingual repo. The `gotcha` lands where gotchas already go: `light-finish` folds it into
`wiki/log.md`, the second-occurrence rule lifts it to `CLAUDE.md`.

**D2 — The diagram layer lives in `wiki/diagrams/`, JSON canonical, one current HTML.**
Derived from code by the agent and re-verified by script, a diagram is wiki-layer knowledge,
not a human `docs/` source. Per diagram `<name>`:

```
wiki/diagrams/
├── <name>.architecture.json          # canonical, tracked (≈5 KB)
├── <name>.html                       # current render, tracked (≈0.8 MB, regenerable)
└── history/
    ├── <YYYY-MM-DD>-<name>.architecture.json   # tracked, written only when semanticSha256 changed
    └── *.html                        # NOT tracked — regenerate with `archify render`
```

The first diagram in every repo is `system` — the whole project in ≤ 12 primary nodes, with
`meta.views` chapters for the main paths. Additional bounded stories (a `workflow` of the
feature flow, a `sequence` of the hook chain) are welcome but optional; note that
`--repo-root` evidence is architecture-only. History keeps the small JSON, because git plus a
deterministic compiler make the HTML reproducible byte-for-byte; a delta view is one command
(`compare history/<old>.json <name>.architecture.json`), its 2 MB output never committed. Its
JSON summary line *is* recorded in `wiki/log.md`. **Alternative the owner may prefer:** track
`history/*.html` too, at ≈ 0.8 MB per architectural change, for click-and-see on any clone.

**D3 — Refresh is triggered deterministically, performed by the agent, verified by script.**
`scripts/diagram_check.sh` (template, installed with the other scripts, delivered to adopted
repos by [[upgrade-path]]) does two things for every `wiki/diagrams/*.architecture.json`:
(1) intersects the union of `sources[].path` with `git diff --name-only <base>...HEAD` — pure
git and python, always runs; (2) if archify is present, copies the JSON to a temp file, sets
`meta.repository.revision` to `HEAD` and runs `validate --repo-root .`, reporting any
`repository-evidence/*` code. Either hit appends `diagram <name>: <reason>` to the branch
state's `wiki_debt` (creating no state file where none exists — it prints instead). It runs
in `light-finish` step 5 before the ingest, and as `audit` Phase 2 item 6 (MEDIUM; HIGH when a
pin no longer resolves). The refresh itself is agent work inside `light-finish`: edit the
changed area of the JSON, never re-author the whole thing, set `revision` to `HEAD`,
`validate` → `deliver` through the archify skill, `compare` against the previous JSON; if
`semanticSha256` changed, write the dated history copy and log the summary. Archify absent →
the debt item still lands; the render waits for a machine that has it.

**D4 — Declared, not bundled; detected in three places.**
`reference/tool-integration.md` gets an Archify section (detect: `node` on PATH and
`${ARCHIFY_BIN:-$HOME/.claude/skills/archify/bin/archify.mjs}` exists — the skills CLI
symlinks `~/.claude/skills/<name>` to `~/.agents/skills/<name>`; install:
`npx skills add tt-a1i/archify -g`). `onboard` step 3's companion table gets a row. `init`
Phase 3 and `adopt` Phase 3 offer — never force — seeding `wiki/diagrams/system` from the
`docs/Architecture.md` sketch and the scanned layout. `meta.repository.url` comes from
`git remote get-url origin`; GitHub and Gitee get `link_mode: web`, any other forge (the
owner's work GitLab included) gets `local-only`, which keeps SRC markers and paths without
hyperlinks. A repo with no origin cannot carry evidence; the check says so and skips.

**D5 — Mermaid leaves the canon.** SAR §14's "Diagrams in Mermaid (`*.mermaid.md`)" becomes
"Diagrams are Archify JSON in `wiki/diagrams/`, rendered to self-contained HTML with
commit-pinned sources; Mermaid is not used." `PROJECT_PATTERN.md` §1 gains one line naming
`wiki/diagrams/`. Nothing converts existing Mermaid files anywhere; Archify's own skill reads
Mermaid as input if a project wants to migrate one by hand.

**D6 — The ladder is written once, and the third memory is named.** `WIKI.md` gains a
"Promotion ladder" section: *observation → `gotchas` in branch state (this branch) →
`wiki/log.md` (once) → `CLAUDE.md` "Things Claude gets wrong" (second occurrence) → a hook
(when the line reads "always" or "never")*; `wiki/glossary.md` gets the terms. `reference/
tool-integration.md`'s never-double-store rule gets a paragraph on Claude Code's auto memory:
personal, per-machine, unversioned — like claude-mem it is *not* where canonical facts live;
if a fact surfaces there twice, it moves to `wiki/`.

**D7 — Explicitly deferred, recorded where they belong.** Wiki recall counts as gardener
input (a PostToolUse `Read` hook over `wiki/**` writing hit counts, TeamAI's "silent
candidates" report) — one paragraph in [[gardener]], built only with the gardener. Owned-region
markers in `CLAUDE.md` so `/strata:upgrade` can re-sync the routing map idempotently — one
paragraph in [[upgrade-path]]. Not adopted at all: a tree-sitter code graph (claude-mem's job),
role/tag-scoped distribution (not a solo concern; revisit with [[hq-mode]]), merge-request-gated
knowledge (HQ later), any Agents-API mechanism (Claude Code already has them), and a diagram
renderer of our own.

## Success criterion

`bash scripts/validate.sh` green with two new sections: §12 friction — synthetic transcripts
prove clean → no block, two interrupts → one block whose reason carries the counts, second
Stop → silent, env thresholds honoured, unreadable transcript → fail open, clean path timing
holds; §13 diagram check — a fixture repo with a pinned diagram reports no debt on an
unrelated change, one `wiki_debt` item when a pinned file changes, a rule code when a pinned
file is deleted (archify present), and a one-line skip when archify is absent. On this repo:
`wiki/diagrams/system.architecture.json` validates 9/9 with `--repo-root .`, `strata.html`
opens offline with every SRC link pinned to the shipping commit, and
`grep -ri mermaid templates/ skills/ reference/` returns nothing. The shipping branch closes
through `light-finish` with the diagram check having run, and both manifests read `0.8.0`.

## Plan shape

In the order the owner approved: **T1** friction trigger (script, tests as §12, `SessionStart`
untouched, `upgrade` delivers it) → **T2** docs: ladder, auto-memory paragraph, glossary →
**T3** diagram layer: tool-integration section, `diagram_check.sh` + §13, `light-finish` step 5
and `audit` Phase 2 wiring, `.gitignore` templates, `onboard`/`init`/`adopt` rows, Mermaid
removal, then Strata's own `system` diagram authored through the installed archify skill →
**T4** deferred paragraphs in [[gardener]] and [[upgrade-path]] → **T5** `0.8.0`, dogfood
close. T1 and T3 are independent and may run in parallel worktrees; T2 and T4 are documentation
and can ride either. Step 0 for the implementing session: `npx skills add tt-a1i/archify -g`
on this machine, then `node ~/.claude/skills/archify/bin/archify.mjs doctor`.

Plan: to be written on approval — [2026-09-12-p4-field-patterns-plan.md](../plans/2026-09-12-p4-field-patterns-plan.md)

## Sources

TeamAI-CLI repo, `docs/usage-guide.md`, `docs/designs/git-native-memory.md` · Archify repo,
`archify/SKILL.md`, `references/authoring-contract.md`, `references/delivery-contract.md`,
`schemas/architecture.schema.json`, `DESIGN.md` · OpenAI Agents API overview and Sandbox
Agents guide (developers.openai.com), AiCybr write-up · Anthropic docs: Managed Agents, tool
search tool, memory tool, compaction, Claude Code hooks and memory.
