# WIKI.md — Karpathy-style self-maintaining wiki

> This protocol instructs an AI agent (Claude or any agent) how to **disciplinedly** maintain `wiki/`.
> Sources of truth: `docs/` (for humans) and `raw/` (mirror for the AI). `wiki/` is derived.
> Strata template — replace the examples below with your project's real entities as you ingest.

---

## Principle

```
docs/   ──cp──>   raw/   ──ingest──>   wiki/   ──query/lint──>   AI answers
(humans)          (AI reads)           (AI writes)
```

- **`docs/`** — written and read by humans. Source of truth.
- **`raw/`** — read-only mirror of `docs/`. The AI **only reads** it, never edits it.
- **`wiki/`** — fully owned by the AI. Regenerated from `raw/` via the `ingest` operation.

After any change in `docs/`, always run: `cp -p docs/<file>.md raw/<file>.md` → `ingest <file>`.
(In a Strata project this copy is done for you by the `sync_raw_mirror.sh` PostToolUse hook.)

---

## Operational mode (how it runs)

| Stage | Mode | Meaning |
|---|---|---|
| **Bootstrap** | **Manual** | The AI runs ingest/query/lint only on explicit user command. No hooks, no cron. Goal: shake out the protocol on your first docs, catch issues early. |
| **Growing** | **Manual + scheduled lint** | A routine runs `lint` + a `docs/` vs `raw/` diff on a schedule (e.g. weekly); drift is reported to `wiki/log.md`. Ingest stays manual. |
| **Mature (optional)** | **+ hook** | If manual mode can't keep up, add a `PostToolUse` hook on `Edit\|Write` over `docs/*.md`. (Strata's `init`/`adopt` installs the docs→raw mirror hook into the project's `.claude/settings.json`.) |

Transitions are non-breaking: each mode **adds** automation on top of the previous one; `WIKI.md` stays the single protocol.

---

## Structure of wiki/

```
wiki/
├── index.md            # catalog: for each page — path + one-line TLDR
├── log.md              # journal of ingest/query/lint operations with timestamps
├── overview.md         # the big picture; evolves with each ingest
├── glossary.md         # terms (domain vocabulary, with definitions)
├── sources/            # one page per file in raw/, a summary (not a copy)
├── entities/           # pages per entity (components, technologies, agents, roles)
└── decisions/          # ADRs — one page per decision, with links
```

### Link conventions

- Internal links between wiki pages: `[[entity-name]]` — wiki-style. Target: a page in `entities/` with that slug.
- Links to sources in `raw/`: plain markdown `[Architecture.md](../raw/Architecture.md)`.
- Links to `docs/` sources only inside `sources/<file>.md` in the `source:` frontmatter field.

### Frontmatter on every page

```yaml
---
title: <short name>
type: source|entity|decision|analysis|index
source: raw/<file>.md   # for type=source
created: YYYY-MM-DD
updated: YYYY-MM-DD
links: [[entity-a]], [[entity-b]]
---
```

---

## The three operations

### 1. `ingest <raw-file>`

Trigger: `ingest raw/<file>.md` (or "ingest X").

The AI must:

1. Read `raw/<file>.md` in full.
2. Create/update `wiki/sources/<slug>.md` — a 3–7 paragraph summary: what it is, key claims, which entities it touches, which decisions it anchors, open questions.
3. Extract **entities** (components, technologies, roles, patterns) and update pages in `wiki/entities/`:
   - If the entity exists — add/refine a section linking to this source.
   - If it's new — create `wiki/entities/<slug>.md` with sections: TLDR, Role, Current solutions, Related (`[[...]]`), Sources.
4. If the file is an ADR source — create/update `wiki/decisions/<adr-slug>.md` (ADR number + title).
5. Augment `wiki/glossary.md` with new terms (short definitions).
6. Update `wiki/overview.md` if the change affects the big picture (structure or phases).
7. Update `wiki/index.md` — add a one-line TLDR entry.
8. Append to `wiki/log.md`: `[YYYY-MM-DDTHH:MM:SSZ] ingest raw/<file>.md → created/updated: <list>`.

**Cascade**: one source may touch 5–15 wiki pages. That's normal.

### 2. `query <question>`

Trigger: the user asks a question about the project.

The AI must:

1. **Read `wiki/index.md` first**, not `raw/`. Find relevant pages by their TLDR.
2. Read the relevant pages from `wiki/` (entities/, decisions/, sources/, overview.md).
3. **Only if the wiki lacks detail** — consult the specific `raw/<file>.md` (and note: the wiki is incomplete, flag it for a future ingest).
4. Answer with `[[entity]]` or `[ADR #X](decisions/...)` links.
5. Optionally (with the user's agreement): save the answer as `wiki/entities/analysis-<slug>.md` (type: analysis) and update the index.

### 3. `lint`

Trigger: an explicit `lint` command, or every N ingests.

The AI scans all of `wiki/` and looks for:

- **Contradictions**: page A says X, page B says ¬X. List → the user decides.
- **Orphan pages**: no incoming `[[links]]`. List → the user decides: linkify or delete.
- **Outdated**: a page references an entity that no longer exists; numbers in overview don't match the current sources.
- **Missing cross-links**: an entity is mentioned without `[[...]]`.

Output — a section in `wiki/log.md` under the date; **the AI does NOT auto-fix**, it only reports.
(`wiki/scripts/lint.py` is the mechanical helper for the structural checks.)

---

## Requirements and behaviour deltas

An entity page may state what the component **must do**, not only how it works: an optional
`## Requirements` section after `## Current solutions`. (After OpenSpec's living specs; the
section lives in the entity page, never in a second tree that could drift from it.)

```markdown
## Requirements

### Blocks at most once per session
The Stop gate never forces more than one continuation in a session.

- Scenario: second stop — WHEN the gate already blocked once in this session THEN the next
  Stop exits 0 · `test: scripts/test_p1_gates.sh::never blocks twice in one session`
- Scenario: … — WHEN … THEN … · `manual: needs a live Claude Code session`
```

- A requirement is a `### ` heading (unique within the page — deltas address it by title), a
  statement, and ≥1 scenario. A scenario is a `- Scenario:` item (continuation lines indented)
  with `WHEN` and `THEN` and exactly one **pointer** — a code span starting `test:` or `manual:`
  (other code spans are just text): `test: <repo-relative path>[::<string in that file>]` (a
  pytest id `tests/x.py::TestA::test_b` works — every `::` segment must be in the file), or
  `manual: <reason>` when only a live run can show it.
- `## Requirements` is a reserved heading in entity pages; a section without `###` headings is
  ignored, so a prose "requirements" paragraph is not parsed.
- **A plan that changes specified behaviour carries a `## Behaviour delta`**, and is therefore a
  file (`docs/superpowers/plans/<date>-<branch-slug>-plan.md`):

  ```markdown
  ## Behaviour delta

  ### ADDED [[stop-gate]]
  #### <new title>
  <full body, as above>

  ### MODIFIED [[stop-gate]]
  #### <existing title>
  <the full new body — it replaces the old one>

  ### REMOVED [[commit-gate]]
  #### <existing title>
  Why: <one line>
  ```

  A verb block holds one or more `####` requirements; a body runs to the next heading and is
  compared with whitespace collapsed, so re-wrapping is fine. A rename is REMOVED + ADDED. A
  malformed `###`, a verb block with no `####`, or the same title twice is an error — never read
  as "no delta". The plan is found by `state_tools.py plan <branch>`: the branch's last
  `/`-segment, exactly, as `<date>-<segment>-plan.md`.
- **Ingest never applies a delta** — the plan is ingested early (the commit gate sees to it),
  before the behaviour exists. `light-finish` step 1b applies it on the branch, before the
  merge / PR / keep / discard choice.
- `python3 scripts/lib/requirements.py owed` (on the branch) lists what the wiki does not reflect
  yet — exit 1 while anything is owed; `python3 scripts/lib/requirements.py check` lints every
  Requirements section and proves each `test:` pointer resolves (not that it passes).

---

## What we DON'T do

- **No embeddings / vector stores** until hundreds of pages. `index.md` + structural search is enough.
- **Don't hand-edit `raw/`** — it's a mirror of `docs/`. Change `docs/` → copy → ingest.
- **Don't duplicate content** — `wiki/sources/<X>.md` is a **summary**, not a copy. The full text lives in `raw/<X>.md`.
- **Don't record the ephemeral** — in-progress task state lives in the plan/TodoWrite, not the wiki.

---

## Promotion ladder — how an observation becomes a rule

Knowledge climbs one rung at a time; nothing is auto-promoted, and each rung has a cost paid by
a different reader. Write it at the lowest rung that fits and let repetition lift it.

| Rung | Where | Who pays | Lifts when |
|---|---|---|---|
| observation | the conversation, claude-mem, Claude Code auto memory | nobody — personal, per-machine, unversioned | it matters beyond this session |
| gotcha | `gotchas[]` in `.strata/state/<branch>.json` | this branch | the branch closes (`light-finish` folds it into `wiki/log.md`) |
| lesson | one line in `wiki/log.md` (`gotcha: …` / `no-gotcha: …`) | whoever greps the log | it happens a **second** time |
| rule | one line in `CLAUDE.md` ("Things Claude gets wrong") | every session, every turn | the line says **always** or **never** |
| invariant | a hook or pre-commit guard (`scripts/hooks/`, `scripts/pre-commit/`) | a few ms per event | — (the top; delete it when `audit` shows it no longer fires) |

Two forces keep the ladder honest. The Stop gate's friction trigger asks for the gotcha at the
moment a session hurt, so rung two is filled when the memory is fresh. The second-occurrence rule
in `light-finish` is the only path from rung three to rung four — a `CLAUDE.md` line without a
prior log line is a rule nobody proved was needed. Facts (formulas, paths, schemas) are not on
this ladder at all: they go to `wiki/` and are queried on demand, never into `CLAUDE.md`.

---

## Workflow for common scenarios

| Scenario | Actions |
|---|---|
| Added/edited a file in `docs/` | `cp -p docs/<f>.md raw/<f>.md` → `ingest raw/<f>.md` |
| Added a new service in `services/` | Create `raw/services-<name>.md` from the service README → `ingest` |
| User asks a question | `query <question>` (read the wiki, not raw) |
| Scheduled a weekly check | `lint` every Nth change or once a week |
| Repo structure changed | re-ingest all affected source files; update the `overview.md` "Layout" section |

---

## Minimal bootstrap (what should exist after the first run)

- `wiki/index.md` — one entry per file in `raw/` (placeholders at first, filled in as you ingest).
- `wiki/overview.md` — 1–2 pages: what you're building, phases, current phase, key decisions.
- `wiki/glossary.md` — your domain's core terms.
- `wiki/sources/` — one markdown file per `raw/<f>.md`.
- `wiki/entities/` — your core components (e.g. `{{component-a}}`, `{{component-b}}`, `{{technology}}`, ...).
- `wiki/decisions/` — one page per ADR from your `docs/ADR-Lean.md`.
- `wiki/log.md` — a bootstrap entry with the timestamp and the list of what was created.

After bootstrap, this verification should pass: a `query` like "what components are required for phase 0?" is answered from `wiki/` alone, without reading `raw/`.
