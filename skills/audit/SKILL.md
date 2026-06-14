---
name: audit
description: Use when the user asks to audit, health-check, or find drift/rot/stale-code in a Strata repo; when "we keep adding features but forget the pattern"; before a refactor sprint; or on a schedule. Read-only — produces a ranked findings report, fixes nothing.
---

# Strata Audit — drift detection (READ-ONLY)

You detect drift between a repo and its own declared rules, across four
dimensions, and emit ONE ranked report. **You never change a single file.**
The output is a findings table other tools (`/strata:refactor`) act on.

Strata makes a repo *self-describing* (STRUCTURE + KNOWLEDGE) and
*self-correcting* (PROCESS). This skill is the "self-correcting" sensor: it
measures how far the repo has drifted from `PROJECT_PATTERN.md`, its stack's
`SCALABLE_ARCHITECTURE_REFERENCE.md` (SAR), and its own `wiki/`/`docs/`.

## Hard rules

- **READ-ONLY.** No Edit/Write to repo files except the single report you
  emit under `docs/superpowers/specs/`. Never run a fixer. Never `git commit`.
- **Do not silently cap coverage.** If the repo is too large to scan whole,
  use parallel sub-agents (one per check, or one per top-level dir) and/or
  systematic globbing — and **log exactly what you skipped** in the report
  (`Coverage` section). A capped scan that hides its cap is a lie.
- **Cite evidence.** Every finding names `file:line` and the exact rule it
  violates (e.g. "SAR §15: Raw SQL outside `data/repositories/`"). No finding
  without a citation. Evidence before assertion.

## Phase 0 — Locate the rule set (verify: rules found or absence logged)

1. Find the structure canon:
   - `PROJECT_PATTERN.md` (root or `docs/`) — repo-layout rules.
   - The stack's `SCALABLE_ARCHITECTURE_REFERENCE.md` — pick the one matching
     the detected stack (check `pyproject.toml` → python-fastapi,
     `package.json` → node/react, etc.). Look in `docs/` and
     `${CLAUDE_PLUGIN_ROOT}/templates/stacks/<stack>/`.
   - `docs/ADR-Lean.md` (or `docs/adrs/`) — accepted/superseded decisions.
2. If a canon file is **missing**, that is itself a HIGH finding ("no
   architecture canon to audit against") — record it and audit against the
   Strata default SAR for the stack.
3. Detect repo size: `git ls-files | wc -l`. If > ~800 tracked files OR
   multiple `services/<name>/`, plan to **fan out** (Phase 5).

**Verify:** you can name the exact PROJECT_PATTERN, SAR, and ADR files (or
state which are absent). Do not proceed otherwise.

## Phase 1 — Structure drift (repo vs PROJECT_PATTERN + SAR §15)

Scan source against the SAR anti-pattern list (§15) and layer table (§4).
Use `grep`/`rg` for the mechanical smells, then read context to confirm
(grep finds candidates; you confirm a real violation before reporting it):

- **Raw SQL outside the repository layer** — `SELECT|INSERT|UPDATE|DELETE`,
  `.execute(`, raw query strings in `api/`, handlers, services, controllers.
- **`SELECT *`** in shipped code.
- **Broad `except Exception:` / `except:` / `catch (e)` that swallows** —
  especially `pass`, bare `return None`, or log-and-continue on a primary path.
- **Config read outside config layer** — `os.environ`/`process.env` outside
  `config/`/`settings`.
- **Module-level side effects on import** — I/O, network, DB connect, or
  mutable global init at module top level.
- **Mutable global singletons** instead of injected registry/DI.
- **Plain dict/`any` across layer boundaries** instead of typed DTO.
- **Missing layer boundaries** — `api/` importing `db/`/repositories
  directly, layer-skip imports (cross-check SAR §4 import table).
- **`from x import *`**, `--no-verify`/`--no-gates`, ad-hoc retry loops,
  unbounded `get_all_*` in hot paths, oversized files (SAR §17 sizing).
- **PROJECT_PATTERN deviations** — missing `CLAUDE.md`, no `.env.example`,
  `raw/` edited by hand, `services/<name>/` lacking the §4 skeleton, secrets
  committed.

Record each as `[severity | structure | file:line | rule | suggested fix]`.

## Phase 2 — Knowledge drift (wiki + docs↔raw↔wiki sync)

1. **Run the wiki lint if present:** `python3 wiki/scripts/lint.py`
   (capture exit code + output). If absent, do the lint checks manually per
   `WIKI.md` §lint: contradictions, orphan pages (no inbound `[[links]]`),
   stale entities, missing cross-links.
2. **docs ↔ raw mirror:** for each `docs/<f>.md`, confirm `raw/<f>.md` exists
   and is not older than its `docs/` source (`git log -1 --format=%ct`). A
   `docs/` file newer than its `raw/` mirror = stale mirror (HIGH — the AI is
   reading stale knowledge). A `raw/` file with no `docs/` source = orphan.
3. **wiki ↔ reality:** wiki pages referencing entities/files/services that no
   longer exist (grep the cited paths); `wiki/index.md` entries pointing at
   deleted sources; numbers in `wiki/overview.md` contradicting current
   `docs/`.
4. **glossary drift:** if `wiki/glossary.md` has hash-pinned SoT facts
   (formulas, schema versions), re-hash the primary source and flag mismatches.

## Phase 3 — Doc freshness (Diataxis coverage map)

Read `${CLAUDE_PLUGIN_ROOT}/reference/diataxis-doc-map.md` for the four
quadrants (Reference / How-to / Tutorial / Explanation). Build a coverage map:

1. Classify existing docs into the four quadrants.
2. **Staleness:** a doc is stale when the code it describes changed after the
   doc's last commit — compare `git log -1 --format=%ct -- <doc>` vs the
   `git log -1` of the module/dir it documents. Flag stale = MEDIUM (HIGH if
   it's a how-to/runbook for an operational path).
3. **Gaps:** quadrants with no coverage for a major surface (e.g. a public API
   with no reference, a deploy flow with no how-to/runbook). Report the gap +
   which quadrant + what's missing.

Emit a compact 4-quadrant table (exists / stale / gap) in the report.

## Phase 4 — Dead-code / staleness

- **Un-wired modules** — files in `src/` never imported (grep the module name
  across the repo; zero non-self references = candidate dead code).
- **TODO/FIXME/XXX/HACK rot** — list each with file:line and **age** (blame
  the line: `git log -1 --format=%cr -L<line>,<line>:<file>` or
  `git blame -L`). Age > ~180d ⇒ MEDIUM, > ~365d ⇒ HIGH.
- **Superseded ADRs still cited in code** — for each `# per ADR #NN` (or
  `ADR-NN`) reference, check `docs/ADR-Lean.md`: if that ADR is
  `superseded by #MM`, flag the citation.
- **Feature flags past a stated ramp date** — grep flag names; if a flag's
  comment/spec gives a removal/ramp date now past, flag it.
- **Unused deps** — declared deps (`pyproject.toml`/`package.json`) with no
  import anywhere (grep the import name). Report as LOW unless heavy.

## Phase 5 — Scale-out (large repos)

If Phase 0 flagged size: dispatch parallel sub-agents via the Agent tool
(`general-purpose` or `Explore`), **one per check or per top-level dir**, each
returning its findings table fragment. Then you merge + dedupe + rank. Tell
each sub-agent: read-only, cite file:line + rule, report what it skipped.
**Never** let a sub-agent fix anything. Merge all `Coverage`/skipped notes
into one section — the union must honestly cover (or declare uncovered) the
whole tree.

## Phase 6 — Emit the report (verify: file written + chat summary given)

Write `docs/superpowers/specs/<YYYY-MM-DD>-strata-audit.md` with:

```markdown
# Strata Audit — <repo> — <YYYY-MM-DD>

## Coverage
Scanned: <dirs/files / N tracked>. Rule set: PROJECT_PATTERN=<path>,
SAR=<path>, ADR=<path>. Method: <direct | N parallel sub-agents>.
**Skipped (NOT audited):** <explicit list, or "none">.

## Findings (ranked)
| Severity | Category | Location | Rule | Suggested fix |
|---|---|---|---|---|
| CRITICAL | structure | src/api/orders.py:88 | SAR §15 raw SQL outside repositories | Move query to OrderRepository.get_items |
| HIGH | knowledge | docs/Arch.md→raw | docs newer than raw mirror | Re-run sync, re-ingest |
| ... |

## Top 3 to fix first
<one paragraph: the 3 highest-leverage findings and why they're first —
blast radius, safety, or unblocks the others.>

---
Run `/strata:refactor` to address these — **this audit was read-only,
nothing was changed.**
```

Severity rubric: **CRITICAL** = correctness/security/data risk or a layer
violation that will force a rewrite if it spreads; **HIGH** = active drift
that misleads the AI or breaks the pattern (stale knowledge, swallowed
errors); **MEDIUM** = rot accumulating (stale docs, aged TODOs, dead code);
**LOW** = cosmetic / low-blast-radius.

Then print a **concise chat summary**: counts per severity, the top-3
paragraph, the report path, and the literal line: "Run `/strata:refactor` to
address these — read-only, nothing was changed."

**Verify (skill done only when all pass):**
- Report file exists at the dated path (`ls` it).
- Every row has a `file:line` and a named rule (no blank citations).
- `Coverage` section names the rule-set files and lists skipped scope.
- Chat summary printed with severity counts + refactor hand-off line.

If any check can't run (no git history, no wiki, lint script missing), say so
explicitly in `Coverage` — do not silently skip and do not claim full coverage.
