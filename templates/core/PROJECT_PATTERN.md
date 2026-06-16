# Project Pattern — Claude-Code-Friendly Repo Layout

A transferable template for organizing repos that have AI agents in the loop (Claude Code / Cursor / etc).
Not dogma — individual blocks can be turned off (see the §9 skip-list).

---

## 1. Three-layer knowledge split: `docs/` ↔ `raw/` ↔ `wiki/`

| Layer | Who writes | Who reads | Purpose |
|---|---|---|---|
| `docs/` | **humans** (markdown source of truth) | humans; AI indirectly via `raw/` | plans, specs, ADRs, runbooks |
| `raw/` | **a script mirrors** from `docs/` (`cp -p`) | AI (read-only) | a stable input for ingest |
| `wiki/` | **AI** (ingest + lint) | AI (query) | knowledge graph: entities, sources, ADRs |

**Rules:**
- `raw/` is never hand-edited — it's a copy of `docs/`.
- Any change to `docs/<file>.md` → always `cp -p docs/<file>.md raw/<file>.md` + AI ingest.
- The AI answers project questions via `wiki/`, not `raw/`. If the wiki can't answer — that's a signal the ingest is incomplete.
- Lint weekly: the AI looks for contradictions / orphans / outdated pages and writes to `wiki/log.md`.

The pattern is inspired by karpathy-wiki — a pull-forward knowledge base, not an append-only journal.

---

## 2. `CLAUDE.md` structure (project root)

Seven mandatory sections, in this order:

```markdown
# <Project Name>
1 paragraph: what this is, the current phase, what's running in prod right now.

## Phase / Gate status — ✅/🔄 <state> <date>
A checklist table: criterion | status | link to runbook/PR.

## Stack (target)
One line, separated by "·". No diagrams here — those live in docs/Architecture.md.

## Layout
- Backtick each key directory + 1 line on what's inside.
- Call out specifically: monorepo / submodule / separate repos.

## Commands
A bash block with real commands: install, test, run, build, deploy.
ENV variables on one line.

## Workflow
- Plan mode → approval → execute. No silent changes.
- /compact at 50%. Subagents for research tasks.
- Smoke-test after schema changes.

## Hard rules
A bullet list of invariants that are NOT up for discussion.
Each rule references an ADR.
```

**Principles:**
- `CLAUDE.md` ≤ 200 lines. Longer → move it into `docs/`.
- Every link is relative and clickable: `[Architecture](docs/Architecture.md)`.
- Don't duplicate `docs/` — link to it.

---

## 3. ADR-Lean

A single file `docs/ADR-Lean.md`, not a `docs/adr/NNNN-*.md` sprawl.

```markdown
## ADR #NN — <Title> (status: accepted | superseded by #MM)
**Context:** 2-3 lines on why the question came up.
**Decision:** what was decided (one sentence).
**Consequences:** what becomes an anti-pattern afterward.
**Date:** YYYY-MM-DD.
```

Addendum format (`## ADR #NN-addendum — ...`) — for refinements without re-opening the old ADR.

**Rule:** don't re-open without an explicit new addendum. Cite it in code/PRs: `// per ADR #NN`.

---

## 4. `services/<name>/` layout (per-service)

Each service is a self-contained module (optionally its own git repo, see §5).

```
services/<name>/
├── CLAUDE.md              # service-specific rules (DB schema, conventions, gotchas)
├── README.md              # for humans
├── pyproject.toml         # or package.json — pinned tooling versions
├── .env.example           # all variables with PREFIX_, no secrets
├── Dockerfile             # multi-stage, HEALTHCHECK
├── docker-compose.yml
├── .pre-commit-config.yaml
├── .gitlab-ci.yml         # or .github/workflows/
├── src/<name>/
│   ├── settings.py        # pydantic-settings / zod / typed config with PREFIX_
│   ├── main.py            # entry point
│   ├── data/              # DB layer (Protocol / interface + concrete)
│   ├── tools/             # API/MCP/CLI endpoints (one file = one endpoint)
│   └── utils/             # validation, logging setup, secret redaction
├── tests/                 # ≥80% coverage on new code
├── scripts/               # one-offs: dump_schema, connection_check
└── <name>_explore/        # research archive + raw/ scripts/ results/
```

**Principles:**
- Service-internal architecture is its own document, like `SCALABLE_ARCHITECTURE_REFERENCE.md`:
  folder skeleton, anti-patterns, adoption checklist, skip-list for small services.
- A small service (< 500 LoC) skips most of the skeleton, see §9.

---

## 5. Repo strategy: monorepo vs. nested independent repos

Three options:
- **Monorepo** — shared dependencies, shared tooling, < 5 people, deploy with one pipeline.
- **Nested independent** — `services/<name>/` physically lives inside the root repo but is **in the root's
  `.gitignore`** and has its own git repo. Two independent histories, independent deploy, independent CI.
  Choose when: different teams deploy independently, different security boundaries, different release cadence.
- **Submodule** — almost never. The CI and update pain outweighs the benefit.

**Mandatory:** when you choose nested independent — record the fresh-clone fix-procedure in the root README:
which nested repos must be cloned separately and where.

---

## 6. `.env` rules

- Commit `.env.example`, never `.env`.
- Prefix per service (`<SERVICE>_DB_HOST`, not bare `DB_HOST`) — gives isolation on a shared host.
- chmod 600 in prod.
- **Syntax:** only `#` for comments (not `//` JS-style — the docker `env_file` parser breaks).
- No secrets in code. Vault / Secrets Manager upgrade-path is a separate ADR.
- gitleaks / trufflehog in pre-commit and CI.

---

## 7. Workflow conventions

- **Plan mode → approval → execute.** No silent changes.
- **/compact at 50%** context. Subagents for research tasks — saves the main agent's context.
- **Smoke-test after schema changes** — a dedicated `<service>_explore/scripts/http_smoke_test.<ext>` script.
- **Deploy via git** (push → server pull → rebuild), not scp. Always reproducible.
- **Goal-Driven Execution** (see §8): every plan step has a verify command.

---

## 8. Goal-Driven Execution (recommended in `~/.claude/CLAUDE.md` or equivalent)

```markdown
# Goal-Driven Execution

Before a multi-step task, turn it into verifiable goals, not actions.

- A weak goal ("make it work", "add validation") → constant clarifications and silent compromise.
  A strong goal names a verify-check that either passes or doesn't.
- Rephrase before starting:
  - "Add validation" → "Write tests for invalid inputs, then make them pass"
  - "Fix the bug" → "Write a test that reproduces it, then make it pass"
  - "Refactor X" → "Tests green before and after; diff doesn't change behavior"
  - "Wire integration" → "Endpoint is called end-to-end and returns the expected shape on live data"
- Plan format for >2 steps: `step → verify` (verify = a concrete command, not "I'll check it works").
- Loop rule: a step is done only when verify passes. If verify is impossible (no prod / no key /
  no data) — say so explicitly, don't claim success.
- Evidence before assertion — always.
```

Adapted from the Karpathy guidelines (https://github.com/multica-ai/andrej-karpathy-skills §4).

---

## 9. Skip-list (when NOT to apply)

- **The `raw/` layer** — only if there's an AI agent that reads the project. For a bare human-only project it's overkill.
- **`wiki/`** — needed only with > 10 `docs/` files or an explicit multi-source knowledge base.
- **Full service skeleton (§4)** — for a small service (< 500 LoC, single endpoints file)
  `src/<name>/main.<ext> + tests/` is enough.
- **ADR-Lean** — not needed for a 2-week prototype. It appears once there's >1 person or >1 month of life.
- **Phase status table in `CLAUDE.md`** — only for projects with a roadmap and stakeholders.

---

## 10. Bootstrap checklist for a new project

```
□ git init + first commit with README.md
□ docs/Architecture.md (even 1 page) + docs/ADR-Lean.md (empty template)
□ CLAUDE.md per the §2 structure (with an honest "Phase 0: planning" status)
□ .gitignore: .env, .venv/, __pycache__, *.pyc, node_modules/, dist/, build/
□ .env.example with a <SERVICE>_ prefix
□ pre-commit-config: linter + formatter + gitleaks (or the stack equivalent)
□ pyproject.toml / package.json with pinned tooling versions
□ tests/ with one passing smoke-test ("project imports")
□ CI pipeline: lint + type-check + tests, must be green from the first commit
□ If an AI agent will read it: create raw/ + wiki/ + WIKI.md (the ingest schema)
□ If there will be services: create services/ and add a link to your SAR equivalent
```

---

## Sources

- Karpathy guidelines — https://github.com/multica-ai/andrej-karpathy-skills (§4 Goal-Driven Execution).
- Anthropic Claude Code docs — https://docs.claude.com/claude-code.
- ADR pattern — https://adr.github.io.
