---
title: "v-next brief — Deterministic Knowledge + HQ Mode"
type: source
source: raw/superpowers/specs/2026-08-14-vnext-brief.md
created: 2026-08-15
updated: 2026-08-15
---

# Source — v-next brief (2026-08-14)

Research brief written across four sessions on 2026-08-14. It is the input document for
Strata v-next: 15 sections covering a diagnosis of why the wiki goes stale, three
feature tracks (A/B/C), a research digest, two approved innovations, and a nightly
execution architecture. It is a *thinking brief*, not a plan — it deliberately leaves 14
numbered open questions for the planning step.

## The diagnosis it anchors

Strata has a **write-side** knowledge pipeline with no **enforcement-side** counterpart.
[[raw-mirror-hook]] mirrors `docs/*.md → raw/` and appends a [[pending-ingest-marker]] to
`wiki/log.md`, but *nothing ever consumes those markers*. They are write-only. The wiki
update lives in `skills/feature/SKILL.md` as advisory prose the model follows early in a
session and forgets late; `light-finish` — the natural "feature is done" moment — does not
mention the wiki at all; and code-only changes emit no wiki signal whatsoever. The brief's
verdict: this is not model laziness, it is a missing deterministic layer. Its rule of
thumb — *"if you're writing 'the agent must always…', that's a hook, not a paragraph"*.

## Three feature tracks

**Feature A — deterministic wiki freshness** (§2): the [[enforcement-layer]] trio of
[[stop-gate]] (A1, blocks turn end), [[commit-gate]] (A2, blocks the commit), and
[[session-start-injection]] (A3, opens every session with wiki state), plus a drift-close
step in `light-finish` (A4). A5 (FileChanged migration) and A6 (session distiller) are
deferred to phase 3.

**Feature B — HQ mode** (§3, §10): [[hq-mode]] — a `~/hq` repo that is itself a Strata
project whose wiki is a meta-index of project indexes, with member projects physically
nested under `hq/projects/`. MCP connectors wired once at HQ level; `hq-sync` /
`hq-report` aggregate upward; scheduling rides native Claude Code rails. The brief states
an explicit dependency: **B is only as good as A** — aggregating drifted project wikis
aggregates garbage, so P1 ships before P2.

**Feature C — zero slash commands** (§6): [[native-invocation]] — the user never types
`/strata:*`; skill `description` fields become the entire routing surface, rewritten as
bilingual EN+RU trigger specs with explicit `Do NOT use when` guards, backed by a routing
map in `CLAUDE.md.tmpl` and `using-strata` recast as a coordinator. Hooks from Feature A
are the deterministic floor under probabilistic routing.

## Research digest and design pressure

§4 and §11 collect the field consensus: cc-spec-driven's *"Skill describes how; Hook
ensures only this way"*, the Karpathy LLM-wiki wave (SessionStart-inject + Stop-extract +
index retrieval, no vector DBs), [[agent-teams]] as a native multi-agent primitive, and
[[session-reflector]] / ACE's playbook model with its named failure modes (brevity bias,
context collapse). §7 adds the **Boris Cherny principle** — every 6 months delete your
CLAUDE.md, skills, and hooks and see what the model still needs; safety-critical hooks are
exempt from the purge. Strata's answer is [[ablate]], an empirical pruning tool the brief
notes nobody ships yet. §8 mines Anthropic's RH-campaign volume for orchestration
patterns: verdict-first structured reports, negative controls, hostile blind referees with
attack briefs, blind re-derivation, a ledger of failures (`wiki/closed-routes.md`),
provenance discipline, and an epistemic firewall in reporting.

## Approved additions and execution

§13 approves two: [[executable-wiki]] (entity pages carry `verify:` commands; a failed
check flips the fact to `stale` — the wiki reports its own lies) and [[career-ledger]]
(append-only `hq/ledger/ledger.jsonl` compiled on demand into review / raise-case /
portfolio docs). §14–15 specify the [[gardener]]: a two-tier nightly job — tier 1 is
deterministic and free, tier 2 is a scoped `claude -p` session — scheduled through
launchd with anacron semantics so a sleeping or powered-off laptop still gets exactly one
catch-up run. Safety invariants: never push to main, never touch `docs/` or `src/`.

## Open questions and what this session settled

The brief leaves 14 open questions. Two were resolved on 2026-08-15 when P1 planning
started: **#1** — the [[stop-gate]] blocks only on markers created in the *current*
session, with older markers left to the [[commit-gate]] (see [ADR #4](../decisions/adr-4-stop-gate-session-scope.md));
**#5** — bilingual EN+RU triggers live inline in each skill's `description`, with no
separate locale block (see [ADR #2](../decisions/adr-2-native-invocation.md)). Questions
#2–4 and #6–14 remain open and are deferred to P2/P3.
