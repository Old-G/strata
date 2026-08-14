# Strata v-next — Deterministic Knowledge + HQ Mode

**Status:** thinking brief (input for `/strata:lean-plan` / `/strata:feature`) **Date:** 2026-08-14 **Author:** Gleb + Claude (research session)

---

## 0. TL;DR

Two problems, one root cause, three moves.

**Problems:** (1) the wiki silently falls behind — the agent forgets to run `wiki-ingest` at the end of a feature; (2) there is no single command center ("HQ") across all projects — no global index, no cross-project queries, no scheduled automations (e.g. weekly report).

**Root cause:** everything that keeps the wiki fresh today is _advisory prose_ in skills. The field consensus in 2026 is blunt: CLAUDE.md and skill text are probabilistic; **hooks are deterministic**. Rule of thumb: if you're writing "the agent must always…", that's a hook, not a paragraph.

**Moves:**

1. **Enforcement trio** — Stop-hook gate + pre-commit gate + SessionStart context injection. Wiki freshness stops depending on the model's memory.
2. **HQ mode** — a `~/hq` repo that is itself a Strata project; its wiki is a _meta-wiki_ (an index of all project indexes). MCP (Slack, ClickUp, GitLab) wired at HQ level. One entry point, progressive disclosure.
3. **Automations on native rails** — Claude Code now ships Desktop Scheduled Tasks (local, cron-like) and Routines (cloud; schedule / API / GitHub triggers). The Monday report is a scheduled task calling a new `/strata:hq-report` skill.

---

## 1. Diagnosis: why the wiki goes stale today

Traced through the current repo:

- `sync_raw_mirror.sh` (PostToolUse hook) mirrors `docs/*.md → raw/` and appends `pending_ingest: <file>` to `wiki/log.md`. **But nothing ever consumes those markers automatically.** They are write-only. No hook, no gate, no skill checks them at session end or commit time.
- The wiki update lives in `skills/feature/SKILL.md` step 3 ("Drift-close … run /strata:wiki-ingest") — advisory text the model follows early in a session and forgets late, exactly the observed failure.
- `light-finish` — the natural "feature is done" moment — **does not mention the wiki at all.** Green check, merge, cleanup, done. Knowledge step absent.
- Code-only changes (no `docs/` edits) never produce any wiki signal; drift is only caught much later by a manual `/strata:audit`.

So the failure isn't the model being lazy — it's that Strata has a _write-side_ pipeline (docs → raw → pending marker) with no _enforcement-side_ counterpart. Classic "advisory vs deterministic" gap.

---

## 2. Feature A — Deterministic wiki freshness

### A1. Stop-hook gate (`scripts/hooks/strata_stop_gate.sh`)

On the `Stop` event, Claude Code lets a hook **refuse to end the turn** and send control back to the model with a reason (exit code 2 / JSON `{"decision":"block","reason":"…"}`). Use it:

- Check `wiki/log.md` for unconsumed `pending_ingest:` lines.
- Check `git status` for substantive changes (docs or > N source lines) with no matching wiki log entry this session.
- If dirty → block once with reason: `"Pending wiki work: run /strata:wiki-ingest on <files>, update index.md, append a session line to wiki/log.md, then stop."`

Loop safety (non-negotiable):

- Read `stop_hook_active` from the hook input; if true → `exit 0`.
- Additionally cap at 1 forced continuation per session via a temp marker file — a gate that fires forever is worse than no gate.
- Fast path: if no pending markers and worktree clean → `exit 0` in <100 ms.

### A2. Commit gate (`scripts/pre-commit/check_wiki_fresh.sh`)

Strata already installs pre-commit guards (`check_secrets.sh`, `check_raw_mirror.sh`). Add one more: **fail the commit if** `pending_ingest` **markers exist**, printing the exact `/strata:wiki-ingest <file>` commands to run. Escape hatch: `STRATA_SKIP_WIKI=1 git commit …` for genuine WIP commits. This catches everything the Stop gate misses (manual commits, other tools).

### A3. SessionStart injection (`scripts/hooks/strata_session_start.sh`)

`SessionStart` hook stdout is added to context the model can see and act on. Inject a _small, fixed-budget_ block (~30–50 lines max — token economy):

```
## Strata context
Branch: <branch> · Last wiki log: <last 3 lines of wiki/log.md>
Pending ingest: <list or "none">
Wiki index head: <first ~20 TLDR lines of wiki/index.md>
Rule: answer project questions from wiki/ first (see /strata:wiki-ingest query).

```

This is the "every session starts with the right context" requirement, solved deterministically instead of hoping the model reads CLAUDE.md carefully.

### A4. `light-finish` gains a knowledge step

Insert between "Do it" and "Clean up":

> **Drift-close.** Run `/strata:wiki-ingest` on every `docs/*.md` touched by the branch; if only code changed, append a one-line summary to `wiki/log.md` and update affected `entities/` pages. Not optional.

The Stop gate then acts as the net for ad-hoc work done _outside_ the flow.

### A5. (Later) `FileChanged` hook migration

Newer Claude Code versions add a `FileChanged` event where the matcher is a filename pattern. It fires even when the user edits `docs/*.md` in the IDE, which `PostToolUse(Edit|Write)` never sees. Migrate the mirror there when the minimum supported CC version allows; keep PostToolUse as fallback.

### A6. (Optional, phase 3) Session distiller

Pattern from coleam00/claude-memory-compiler and the Karpathy-KB builds: a `SessionEnd`/`PreCompact` hook spawns a **background** `claude -p` (Agent SDK) that replays the transcript and appends distilled decisions/gotchas to `wiki/log.md` (or a `wiki/journal/` dir) for later curated ingest. Claude-mem already covers episodic memory, so ship this only if the claude-mem → wiki handoff proves too lossy. Keep thin-glue: prefer _declaring_ claude-mem over rebuilding it.

**Verify (feature A):** finish a feature via `/strata:feature` and via ad-hoc edits; in both cases the session cannot end and a commit cannot land while `pending_ingest` is non-empty, and a fresh session shows the injected context block.

---

## 3. Feature B — HQ mode (the multi-project command center)

Concept: **one repo to enter from, progressive disclosure downward.** `wiki/index.md` is the table of contents of a project; the HQ wiki is the table of contents of the tables of contents.

### B1. `/strata:hq-init`

Scaffolds `~/hq` as a normal Strata project plus:

```
hq/
├── CLAUDE.md            # HQ rules: registry-first, query protocol
├── .mcp.json            # Slack, ClickUp, GitLab, … wired ONCE here
├── registry.yaml        # name, path, stack, status, wiki path per project
└── wiki/
    ├── index.md         # meta-index: one TLDR line per project
    ├── projects/<name>.md   # per-project page: TLDR, links, last-sync digest
    └── log.md

```

`~/.claude/CLAUDE.md` (user scope) gets 3 lines: "cross-project questions → open ~/hq, read wiki/index.md first." Per-project CLAUDE.md stays untouched — no global side effects, per Strata philosophy.

### B2. `/strata:hq-sync`

For each `registry.yaml` entry: pull the head of that project's `wiki/index.md`, the tail of its `wiki/log.md`, and `git log --since=<last sync>`; refresh `wiki/projects/<name>.md`; bump the meta-index TLDRs. Pure read — never writes into member projects. This is the skill a scheduled task will call nightly.

### B3. `/strata:hq-report`

Input: time window (default: since last Monday). Gathers per project: commits, wiki-log entries, closed work items; optionally enriches via ClickUp MCP tasks and Slack MCP threads. Output: a short structured report (shipped / in-progress / blocked / next) written to `hq/reports/<date>-weekly.md` **and posted as a draft** — first destination: DM to self / Slack draft for review; switch to fully automatic send only after a few good weeks. Human-approval gate first, always.

### B4. Scheduling — native, no cron needed

Claude Code now has two first-party rails:

- **Desktop Scheduled Tasks** — local, persistent, run against the real working tree, min interval 1 minute; the task prompt lives at `~/.claude/scheduled-tasks/<name>/SKILL.md`.
- **Routines** — run in Anthropic's cloud on a schedule / API call / GitHub event (configure at claude.ai/code/routines or `/schedule` in CLI); min interval 1 hour, fresh clone + connectors.

Plan: Monday 16:00 scheduled task in `~/hq` → prompt = "run /strata:hq-report --since last-monday and post the draft to Slack #…". Nightly task → `/strata:hq-sync`. Strata ships these as _documented templates_, not auto-installed state (same "no global side effects" rule).

### B5. Work-state layer — evaluate Beads (`bd`)

Steve Yegge's Beads: a git-backed, dependency-aware issue graph built _for agents_ (JSONL in git, `bd compact` = LLM memory decay, ~18k stars, Jira sync exists → a ClickUp bridge is writable). It would give `hq-report` a clean "what actually got done / what's ready next" data source instead of parsing markdown plans. Fits Strata as an **optional declared tool** (like claude-mem / RTK), never a dependency. Decision point: adopt bd, or keep the markdown `plans/` + log as the source. Prototype hq-report both ways before deciding.

**Verify (feature B):** from a fresh session in `~/hq`, ask "what's the state of project X?" — answered from the meta-wiki without grepping X; run `/strata:hq-report` manually → a correct draft lands in `hq/reports/` and in Slack as a draft.

---

## 4. Research digest — what to borrow (Aug 2026)

- **cc-spec-driven (mkhrdev)** — the enforcement blueprint: SessionStart verifies state files, PostToolUse force-triggers next actions, **Stop hook blocks if the workflow state is incomplete**. Their motto: "Skill describes how; Hook ensures only this way." Directly maps to Feature A.
- **Anthropic's official** `spec-driven-development` **plugin** (anthropics/claude-plugins-community, 5-phase flow) — study for overlap; Strata's differentiator is knowledge (wiki) + drift (audit/refactor) + council, not the spec flow itself. Don't compete on their lane.
- **Karpathy LLM-wiki wave** (his 2026 posts + HackerNoon "6 projects" build
  - puvaan.dev build + coleam00/claude-memory-compiler) — strong validation of Strata's wiki bet; the recurring architecture is exactly SessionStart- inject + Stop/SessionEnd-extract + index-file retrieval, no RAG. Borrow the hook pair; skip vector DBs.
- **Claude Code native memory** — per-repo Auto Memory (`MEMORY.md`, ~200-line startup budget) now exists, plus a "Dreams" consolidation preview. Add a boundary rule to WIKI.md: MEMORY.md = model's private scratch prefs; `wiki/` = reviewed project truth; never duplicate a fact across them (same rule as with claude-mem).
- **External memory backends** (Hindsight w/ scopes, Mem0, Zep/Graphiti, Letta, Basic Memory) — only relevant if HQ outgrows markdown. Not now; thin glue.
- **smart-ralph** — Ralph-style autonomous loops + smart compaction; possible future engine for long `/strata:refactor` runs. Watch, don't adopt yet.
- **Hooks landscape** — ~30 lifecycle events now (FileChanged, TaskCompleted, SubagentStop, PreCompact, SessionEnd…), and Codex CLI has ported the same hook protocol — Strata's enforcement layer could become near cross-agent.

---

## 5. Roadmap

| Phase            | Scope                                                                         | Success criterion                                                                                        |
| ---------------- | ----------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| **P1 — Enforce** | A1 Stop gate · A2 commit gate · A3 SessionStart inject · A4 light-finish step | Wiki can no longer silently drift: gates fire in a staged test; injected block visible in fresh sessions |
| **P2 — HQ**      | B1 hq-init · B2 hq-sync · B3 hq-report · B4 scheduled-task templates          | Weekly draft report generated end-to-end from ≥2 real projects                                           |
| **P3 — Deepen**  | A5 FileChanged · A6 session distiller · B5 Beads decision                     | Chosen per evidence from P1/P2 usage                                                                     |

Open questions to settle in the plan:

1. Stop-gate scope: block on _any_ pending_ingest, or only when the session itself created it?
2. hq `registry.yaml` — manual, or auto-discovered from `~/projects/*/wiki`?
3. Report tone/template for Zhenya — reuse the internal-comms format already used at LH?
4. Beads vs markdown for work state — prototype criterion?

---

# Addendum (2026-08-14, part 2) — Native invocation, ablation, and orchestration patterns

## 6. Feature C — Zero slash commands: fully native invocation

**Requirement (Gleb):** never type `/strata:`\*. Plain natural-language input (mostly Russian); the agent decides from context which skill / file / flow to use. Everything automatic.

**Good news:** this is how Claude Code skills already work. `SKILL.md` files are _model-invoked_: Claude scans skill names + descriptions and auto-loads a skill when the request matches. The slash form is only an optional manual entry point. Hooks require zero invocation by design — they fire on lifecycle events. So the work is not "add a new mechanism"; it is "make routing reliable". Four changes:

### C1. Rewrite every skill `description` as a trigger spec

The description is the _entire_ routing surface at dispatch time. Current Strata descriptions are role-oriented ("Use when ingesting a docs/raw file…"). Rewrite each as: **Use when the user says/wants X** — with concrete phrase examples **in both English and Russian**, since matching happens against the user's actual words. `wiki-ingest` already does this once ("проингестим X") — generalize the pattern to all 12 skills. Examples:

- feature: "Use when the user asks to build/add/change anything — 'добавь', 'сделай фичу', 'надо чтобы…', 'запили' — before writing code."
- audit: "…'что-то грязно', 'проверь проект', 'наведи порядок', 'где дрифт'."
- light-finish: "…'заканчиваем', 'закончили фичу', 'мержи', 'подытожь ветку'."
- wiki-ingest query: "…any project question: 'как у нас работает X', 'где лежит Y', 'почему решили Z'."

Add a `## Do NOT use when` line to each to prevent false triggers (over-broad descriptions are the classic failure mode).

### C2. CLAUDE.md.tmpl gets a 6–8 line routing map — and nothing else grows

A tiny intent table, not prose rules:

```
Routing (auto — user never types commands):
  build/change request      → feature flow (triage first)
  question about project    → wiki query (index.md first, never grep-first)
  "done / wrap up / merge"  → light-finish (includes drift-close)
  "messy / check / drift"   → audit
  risky or unclear idea     → office-hours grill

```

### C3. `using-strata` becomes the coordinator

Model its description on a dispatcher: broad-intent match, loads early, routes to the right skill, never does the work itself. (See §8 — this is literally the coordinator pattern from Anthropic's RH campaign: the human types one-line natural-language intents; the orchestrator writes briefs and launches the right agents.)

### C4. Hooks guarantee what routing misses

Feature A's Stop gate + SessionStart injection mean that even when description-matching fails, the invariant (wiki freshness) still holds and every session still opens with the routing map + wiki state in context. Native happy path via descriptions; deterministic floor via hooks.

**Verify (C):** run a full feature start-to-finish in Russian without typing a single `/strata:` command; correct skills observed loading at each phase; wiki updated without being asked.

## 7. The Boris Cherny principle — Strata must shrink, not grow

Boris Cherny (Claude Code creator), YC Startup School, July 2026, the day after Opus 5 shipped: _"Every 6 months, delete your CLAUDE.md file, delete your skills, and delete your hooks. Then see what the model does. It might surprise you. For Opus 5 we strongly recommend trying to delete all of these things because the model may no longer need the extensive instructions that were necessary for previous models."_ His team deleted 80%+ of Claude Code's own system prompt for Opus 5 via ablation. His prompting philosophy: define the **task, guardrails, and exit criteria** — then let the model work; make self-verification possible. Community caveat that matters: safety-critical hooks (destructive-command blocks, deny rules) are exempt from the purge.

Implications for Strata:

1. **Design pressure: fewer words per skill.** Each SKILL.md should trend toward task + guardrails + exit criteria + verify. Cut step-by-step hand-holding written for 2025-era models. This also directly serves C1 (short, sharp descriptions route better).
2. **The enforcement layer is exempt.** Stop/commit gates and secret checks are invariants, not model-capability scaffolding — they stay even after an ablation pass. Everything advisory is a candidate for deletion.
3. **New skill:** `/strata:ablate` (auto-triggered ~every 6 months via a scheduled task, or on model-version change). Protocol: snapshot current CLAUDE.md/skills/hooks → generate an ablation matrix (rule → what breaks without it?) → run the project's verify suite + a scripted feature dry-run with each candidate rule removed → report "still needed / dead scaffolding / move to hook". This is `audit` for _instructions_ instead of code — perfectly in Strata's DNA, and (per a quick landscape scan) nobody ships this yet. Possible headline feature.
4. **Wiki over instructions.** Facts belong in `wiki/` (queried on demand), not in CLAUDE.md (paid for every session). The ablation skill should detect "this CLAUDE.md paragraph is actually knowledge" and move it.

## 8. Orchestration patterns from Anthropic's RH-campaign volume

Source: Anthropic's companion volume "How the two-thirds argument was found" (www-cdn.anthropic.com/d7f3ecf1…ed.pdf) — Claude's own account of a 54-hour campaign: one human typing one-line prompts, one coordinator agent, ~60 sub-agents (researchers, hostile referees, re-derivers, a paper writer). The methodology transfers to Strata almost verbatim:

1. **Briefs are research memos, not task tickets.** Each sub-agent brief carried: the target, a template, a reading list of prior reports, the coordinator's own forecast of the outcome, and a mandatory control case. → Strata's lean-plan/council briefs should add a `forecast:` line and a `control:` line (see #3).
2. **Verdict-first structured reports with a prescribed enum.** Briefs demanded the summary open with `VIABLE / EMPTY / PARTIAL: …`. → Standardize council/audit sub-agent outputs the same way; synthesis gets machine-checkable inputs instead of prose.
3. **Control cases ("proves too much" test).** Every research brief demanded a known-false model on which the claimed method must fail; a "barrier checker" tool classified new ideas by which known-false model kills them. → For code: reviews and test plans must include a _negative control_ — a deliberately broken variant the tests/review are required to catch. A review that passes the broken variant is itself broken. Add to the council personas and the TDD step.
4. **Hostile blind referees, one joint each, with a worked attack plan.** Referees were forbidden to read one another and each got a specific suspected weakness plus a plan of attack, launched with the stance "my prior is that it's wrong." → Upgrade `autoplan`: the risk-matched reviewers each receive an explicit attack brief for _their_ joint, not the generic persona alone.
5. **Blind re-derivation.** A separate agent re-implements the critical piece from the spec alone, forbidden to read the original. → Optional council member for CRITICAL-risk work: re-implement the core function from the spec; diff behavior against the candidate.
6. **Ledger of failures = first-class knowledge.** A prior session's only useful artifact was a ledger of 106 tried-and-deflated ideas, handed to every sub-agent as a do-not-repeat list. → Add `wiki/closed-routes.md` (what was tried, why it failed, evidence link). `hq-sync` aggregates these across projects — cross-project "don't repeat my mistakes" memory, which is exactly the HQ vision.
7. **Provenance discipline.** The volume corrects the coordinator's own attribution slips _from the logs_ — summaries drift, logs don't. → Every wiki/log entry links its evidence (commit, report file). The hq-report cites sources per claim.
8. **Epistemic firewall in reporting.** The coordinator to the human: "I am not telling you half the zeros are on the line. I'm telling you an agent produced an argument with that conclusion." → House style for audit findings and the weekly hq-report: claims carry their verification status (verified-by-test / agent-claimed / assumed).
9. **Resumability via disk.** A run died mid-proof; the coordinator read the orphaned files, verified line-by-line, resumed the same agent with a checklist. Validates spec/plan-on-disk; consider a tiny `state.md` per feature branch so any session can resume any work cold.

## 9. Roadmap (updated)

| Phase                    | Scope                                                              | Success criterion                                                                      |
| ------------------------ | ------------------------------------------------------------------ | -------------------------------------------------------------------------------------- |
| **P1 — Enforce + Route** | A1–A4 · C1–C4                                                      | Full feature in Russian, zero slash commands, wiki cannot silently drift               |
| **P2 — HQ**              | B1–B4 · closed-routes ledger (§8.6)                                | Weekly draft report from ≥2 projects, claims carry provenance                          |
| **P3 — Deepen**          | A5–A6 · B5 · `/strata:ablate` (§7.3) · council upgrades (§8.2–8.5) | Ablation report produced on a real project; council catches a planted negative control |

New open questions: 5. Description language: bilingual EN+RU triggers in every skill, or a separate locale block? 6. `/strata:ablate` cadence — fixed 6 months, or trigger on model change detected at SessionStart? 7. Which council upgrade first: negative controls (§8.3) or attack briefs (§8.4)?

---

## 10. Layout decision (2026-08-14, part 3) — projects live _inside_ HQ

Gleb's call: one global folder, projects physically nested. Adopt:

```
~/hq/                      # git repo (HQ itself; .gitignore: projects/)
├── CLAUDE.md              # global rules + routing map (thin)
├── .mcp.json              # Slack, ClickUp, GitLab… wired once
├── registry.yaml          # AUTO-DISCOVERED from projects/*/wiki (answers OQ#2)
├── docs/ → raw/ → wiki/   # HQ's own Strata pipeline; wiki/ = meta-index
└── projects/
    ├── horos/             # own git repo, own wiki/ (normal Strata project)
    ├── lh-ai-brain/       # own git repo, own wiki/
    └── …

```

Why nesting wins: Claude Code loads CLAUDE.md **up the directory tree** — a session opened inside `projects/horos/` automatically also gets `~/hq/CLAUDE.md` (global rules for free), and a session opened at `~/hq` has the whole world in reach with no --add-dir ceremony. Each project keeps its own git; HQ's git tracks only the meta-layer.

Context economy (the point of two wiki levels): the global session never bulk- reads project wikis. Resolution path is 3 small hops — `hq/wiki/index.md` (1 line per project) → `hq/wiki/projects/<name>.md` (TLDR + digest from last sync) → the project's own `wiki/index.md` → entity. Progressive disclosure, exactly the "table of contents of tables of contents".

Dependency to state explicitly in the plan: **B is only as good as A.** hq-sync aggregates project wikis; if project wikis drift (no Stop/commit gates), the global wiki aggregates garbage. Ship P1 before P2.

---

# Round 2 research (2026-08-14, part 4) — new primitives + innovation shortlist

## 11. Four new findings

### 11.1 Agent Teams — native multi-agent in Claude Code

Experimental since v2.1.32 / Opus 4.6 (Feb 2026), enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. One session = team lead; teammates are full independent Claude Code instances with isolated contexts, a **shared task list with file locking**, and **peer-to-peer mailbox messaging** (not just report-to-parent like Task-tool subagents). Split-pane display via tmux/iTerm2. Hook events TeammateIdle / TaskCompleted integrate. Known rough edges: session resumption, shutdown behavior. → Strata implications: council v2 (reviewers as real teammates who can _argue with each other_ before synthesis — today's council only disagrees at the synthesis step); HQ lead spawning per-project teammates for cross-project work. Keep behind a capability check: fall back to Task-tool subagents when the env var is off.

### 11.2 ACE (Agentic Context Engineering, Stanford/SambaNova, arXiv 2510.04618)

Context as an **evolving playbook**: three roles — Generator (does the work), Reflector (distills concrete lessons from successes AND failures), Curator (merges lessons as **incremental delta bullets**, never monolithic rewrites) — plus a **grow-and-refine** loop (append + dedupe + prune). Names the two failure modes precisely: _brevity bias_ (summaries drop the domain details that mattered) and _context collapse_ (iterative full rewrites erode knowledge). +10.6% on agent benchmarks from context alone. → Validates wiki-ingest's "never clobber prior knowledge" rule and gives it theory. The missing Strata piece is the **Reflector**: nothing today turns session outcomes into playbook deltas.

### 11.3 Wiki interop standards — llms.txt + AGENTS.md

llms.txt adoption is real: Google added it as a Lighthouse signal (new "Agentic Browsing" category, May 2026); Cursor and other tools reference it for docs lookup. Microsoft's agent-skills ships a "Deep Wiki Plugin" that generates a full wiki/ **including llms.txt, llms-full.txt, AGENTS.md, a CLAUDE.md pointer, and role-based onboarding guides** (contributor / staff engineer / executive / PM). AGENTS.md is the cross-agent instruction standard (Codex, Cursor, Gemini CLI read it). Notable rule: write llms.txt in the repo's working language, not default English. → Competitor watch (Microsoft's plugin overlaps Strata's knowledge layer) AND an interop opportunity — see innovation #2.

### 11.4 Ablation: universal advice, zero automation (niche confirmed)

Anthropic's own best-practices doc now says it plainly: per line ask "would removing this cause Claude to make mistakes? If not, cut it — or **convert it to a hook**"; bloated CLAUDE.md causes rule-loss; target <200 lines. Community adds: flip prohibitions to affirmations (~half the violations), review quarterly, use `/memory` to see what's actually loaded; Auto Memory itself is "accretion, automated" and part of the ablation surface (`autoMemoryEnabled: false` to opt out). **But every source describes a manual practice — no shipped tool runs the pruning test empirically.** `/strata:ablate` (§7.3) stands as an open niche.

## 12. Innovation shortlist (build-someday → build-next order)

1. **Session Reflector → self-learning playbook** _(the big one)_. SessionEnd/Stop pipeline runs an ACE-style Reflector over the transcript: extract what worked / what failed / what surprised → Curator writes **delta bullets** to `wiki/playbook.md` (tactics) and `wiki/closed-routes.md` (failures, per §8.6), never rewriting wholesale; nightly grow-and-refine dedupes. `lean-plan`/`feature` read the playbook first. Nobody today combines Karpathy-wiki structure + ACE delta updates

- hook enforcement: this is Strata's flag-plant. Kill criterion: if after 2 weeks the playbook isn't changing plans, drop it.

2. **Wiki as compile target** (`/strata:wiki-emit`). One command compiles `wiki/` → `llms.txt` + `llms-full.txt` + `AGENTS.md` (+ CLAUDE.md pointer block). Every non-Claude agent (Cursor, Codex, Gemini) instantly benefits from the same knowledge spine; public repos get the Lighthouse signal for free. Cheap to build (it's a renderer over an already-structured wiki), high differentiation: "maintained by gates, readable by every agent."
3. `/strata:ablate` **with an empirical protocol** (upgraded from §7.3): for each CLAUDE.md rule / skill paragraph, run the project's verify suite

- a scripted feature dry-run **with and without** the rule; classify still-needed / dead scaffolding / convert-to-hook / move-to-wiki. First tool to automate what Anthropic and Cherny prescribe manually.

4. **Council v2 on Agent Teams**: risk-tier ≥ risky spawns reviewers as teammates with p2p mailboxes; they must exchange at least one challenge/response before verdicts; lead synthesizes; falls back to subagents without the env var. Bonus pattern: builder + shadow-reviewer teammate running concurrently on CRITICAL work.
5. **Wiki gardener** (scheduled Curator): nightly Desktop scheduled task — dedupe entities, merge near-duplicates, decay stale TLDRs, keep `index.md` under a fixed token budget, propose deletions per the Boris principle. Complements #1 (Reflector grows, gardener prunes).

New open questions: 8. Reflector trigger: every session end (noisy) or only sessions that closed a feature / hit a failure (signal)? 9. playbook.md scope: per-project only, or does hq-sync lift cross-project-worthy bullets into the HQ playbook? 10. wiki-emit: llms.txt language = repo language (RU for HorOS-adjacent repos?) — decide per project in registry.yaml.

---

# Part 5 (2026-08-14) — Approved innovations + nightly execution architecture

## 13. Two approved additions

### 13.1 Executable wiki (self-verifying knowledge) — APPROVED

Entity pages may carry verifiable claims in frontmatter or a `## Verified facts` block:

```yaml
facts:
  - claim: 'auth is handled only in middleware/auth.py'
    verify: "! grep -rl 'jwt.decode' src/ --include='*.py' | grep -v middleware/auth.py"
    freshness: 7d # re-check cadence
    last_pass: 2026-08-14
  - claim: 'webhook retries = 3'
    verify: 'python -c "from app.config import S; assert S.WEBHOOK_RETRIES==3"'
    freshness: 30d
```

Rules: verify commands are read-only and repo-local; a failed verify flips the fact (and its entity) to `stale: true` and lands in the morning digest — the wiki _reports its own lies_. Start narrow: only facts with cheap, obvious checks; never block on flaky verifies (2 consecutive fails = stale, 1 fail = warn). Audit gains a new lint: entities with zero verified facts on CRITICAL paths.

### 13.2 Career Ledger — APPROVED

Append-only `hq/ledger/ledger.jsonl`; one event per shipped/decided thing:

```json
{
	"ts": "...",
	"project": "lh-ai-brain",
	"type": "shipped",
	"what": "support automation to 40%",
	"evidence": ["gitlab:MR!142", "clickup:task#..."],
	"metric": { "name": "automation_rate", "from": 0.31, "to": 0.4 }
}
```

Writers: light-finish appends on merge; hq-report appends weekly rollups; manual `ledger add` for non-code wins. Compilers (on demand, not scheduled): `ledger compile review` → performance-review doc; `ledger compile case` → raise/promo case with provenance links; `ledger compile portfolio`. Privacy rule: work evidence links resolve only inside work context; the ledger stores references, never confidential payloads.

## 14. Nightly execution architecture (how "runs at night" actually works)

Core clarification: Claude Code is a CLI agent runtime, not IDE-resident code. `claude -p "<prompt>"` runs a full agentic session headlessly from any shell — cron, launchd, CI, a VPS — no IDE, no chat window.

**Two-tier night job (cost-aware):**

```
TIER 1 — deterministic, zero LLM, zero tokens (cron/launchd script)
  wiki_verify_runner.sh:
    for each fact due by freshness → run verify → write pass/fail
    to wiki/.verify-status.json; flip stale flags; git commit to
    branch `gardener/nightly` (never main)

TIER 2 — LLM curator, one scoped session (only if tier 1 found work
         OR weekly)
  claude -p "/strata:gardener" --max-turns 30
    reads .verify-status.json + wiki/log.md tail
    → fixes stale TLDRs it can prove, merges dupes, decays,
      proposes deletions
    → commits to same branch + writes morning-digest.md
Human: morning review of the branch/digest; merge = one click.

```

**Where it physically runs — three options:**

| Runtime                                                      | Needs                                                                                                                         | Best for                                                                                                           |
| ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| **A. Local: launchd/cron or Claude Desktop scheduled tasks** | machine awake at trigger time (or anacron-style "run on next wake if missed")                                                 | simplest start; Desktop tasks fire while the app runs, prompt lives in `~/.claude/scheduled-tasks/<name>/SKILL.md` |
| **B. Own VPS** (reg.cloud box already exists for HorOS)      | repos cloned there + `claude` CLI authenticated; cron                                                                         | true 24/7, laptop closed; personal projects; GitLab work repos if policy allows                                    |
| **C. Anthropic cloud Routines**                              | repo reachable from a fresh clone (GitHub) + connectors; min interval 1h; configure at claude.ai/code/routines or `/schedule` | zero infra; public/GitHub projects like strata itself                                                              |

Recommended rollout: start with A (launchd + anacron semantics) for everything; move personal repos' tier-2 to B when the VPS is set up; use C for strata-the-repo itself as dogfood. Tier 1 runs everywhere for free.

**Safety invariants:** gardener never pushes to main; never edits docs/ or src/ (wiki + status files only); token budget cap per run; if two consecutive runs propose conflicting changes, stop and flag for human.

New open questions: 11. verify sandboxing: plain subprocess with timeout, or run inside a read-only container? 12. ledger event taxonomy: shipped/decided/learned/prevented — enough? 13. Tier-2 model: cheapest capable (Haiku/Sonnet) vs house default — measure curation quality first month.

---

## 15. B6 — Gardener scheduler with anacron semantics (launchd/systemd) — APPROVED

**Goal:** the nightly gardener (§14) must survive a sleeping or powered-off laptop: "run at 03:33; if the machine was asleep, run on wake; if it was off, run at next login — but never more than once per ~20h."

**Why launchd alone is 90% but not 100%:** `StartCalendarInterval` natively fires a missed job on wake-from-sleep (coalesced to one run — this is launchd's documented advantage over cron). But it does NOT fire after a full power-off/reboot night. Fix: add `RunAtLoad=true` (fires at login) and let a **stamp-file check in the wrapper** decide whether a run is actually due. launchd provides the triggers; the wrapper provides the anacron brain.

### 15.1 Wrapper — `hq/scripts/gardener_wrapper.sh` (one job for all of HQ)

```bash
#!/usr/bin/env bash
# Anacron-style gardener for the whole HQ. Triggers: calendar, wake, login.
set -uo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

HQ="${1:?usage: gardener_wrapper.sh /path/to/hq}"
MIN_GAP_H="${2:-20}"
STAMP="$HQ/.strata/gardener.last"; LOCK="$HQ/.strata/gardener.lock"
mkdir -p "$HQ/.strata"

mkdir "$LOCK" 2>/dev/null || exit 0            # single-flight (mkdir = portable lock)
trap 'rmdir "$LOCK"' EXIT

now=$(date +%s); last=$(cat "$STAMP" 2>/dev/null || echo 0)
(( now - last < MIN_GAP_H*3600 )) && exit 0    # ran recently → not due

on_batt=0
pmset -g batt 2>/dev/null | grep -q "Battery Power" && on_batt=1

while IFS= read -r repo; do                    # projects from registry
  [ -d "$repo" ] || continue
  ( cd "$repo"
    bash scripts/wiki_verify_runner.sh || true            # TIER 1: free
    if [ "$on_batt" = 0 ] && grep -q '"fail"' wiki/.verify-status.json 2>/dev/null; then
      claude -p "/strata:gardener" --max-turns 30 || true # TIER 2: LLM
    fi )
done < <(yq -r '.projects[].path' "$HQ/registry.yaml")

date +%s > "$STAMP"

```

Design points: stamp written only after a full pass; battery → tier 1 only; lock prevents wake+login double-fire; `|| true` so one sick repo never blocks the rest.

### 15.2 LaunchAgent — `~/Library/LaunchAgents/com.strata.hq-gardener.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.strata.hq-gardener</string>
  <key>ProgramArguments</key><array>
    <string>/bin/bash</string>
    <string>/Users/USER/hq/scripts/gardener_wrapper.sh</string>
    <string>/Users/USER/hq</string>
  </array>
  <key>StartCalendarInterval</key>
    <dict><key>Hour</key><integer>3</integer><key>Minute</key><integer>33</integer></dict>
  <key>RunAtLoad</key><true/>
  <key>ProcessType</key><string>Background</string>
  <key>StandardOutPath</key><string>/tmp/strata-gardener.log</string>
  <key>StandardErrorPath</key><string>/tmp/strata-gardener.err</string>
</dict></plist>

```

Absolute paths only (launchd does not expand `~`). 03:33, not 03:30 — avoid the :00/:30 stampede habit.

Install / manage:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.strata.hq-gardener.plist
launchctl print gui/$(id -u)/com.strata.hq-gardener   # status
launchctl kickstart -k gui/$(id -u)/com.strata.hq-gardener  # run now (test)
launchctl bootout gui/$(id -u)/com.strata.hq-gardener # uninstall

```

### 15.3 Same semantics elsewhere (installer detects OS)

- **VPS / Linux (option B):** systemd user timer with `Persistent=true` — literally the same catch-up behavior in one flag:

  ```ini
  # gardener.timer[Timer]OnCalendar=*-*-* 03:33Persistent=true

  ```

- **Windows:** Task Scheduler `StartWhenAvailable=true`.

### 15.4 Delivery

New small skill `/strata:gardener-install` (called optionally by `hq-init`): renders wrapper + unit for the detected OS with real paths, installs, runs `kickstart` once, and appends a wiki log line. Uninstall verb included. **Verify:** stamp file updates after a forced run; a simulated missed night (set stamp to -48h, sleep the Mac past 03:33, wake) produces exactly one run.

Open question 14: `yq` as a dependency for registry parsing — bundle a python one-liner fallback instead?
