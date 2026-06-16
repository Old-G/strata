# Stack pack: python-fastapi

A Strata **stack pack** carries the stack-specific parts of the framework. The stack-neutral core
lives in `templates/core/`; this pack adds the architecture canon for Python services
(FastAPI · asyncpg · Pydantic v2 · pytest-asyncio · Alembic · structlog · Docker).

## Contents

| File | Purpose |
|---|---|
| `SCALABLE_ARCHITECTURE_REFERENCE.md` | The architecture **canon** — folder skeleton, layer boundaries, the pattern catalog, anti-patterns (used by `/strata:audit`), the adoption checklist, and sizing heuristics. `/strata:init` copies this into the project's `docs/`; `/strata:audit` checks the repo against its §15 anti-patterns. |

## How it's used

- `/strata:init` — copies `SCALABLE_ARCHITECTURE_REFERENCE.md` into the new project's `docs/` and
  scaffolds the §3 folder skeleton (`src/<name>/{settings,main,data,tools,utils}` + `tests/`).
- `/strata:audit` — loads this file's §15 anti-patterns as the structure-drift rule set.

## Manual scaffold

Until a per-stack generator ships, create a new service by following **§3 (folder skeleton)** and
**§16 (adoption checklist)** of `SCALABLE_ARCHITECTURE_REFERENCE.md`. For small services (< 500 LoC),
apply the §17/§18 skip-list and keep just `src/<name>/main.py` + `tests/`.

## Adding a new stack pack

Copy this directory to `templates/stacks/<your-stack>/`, replace the architecture reference with one
written for that stack, and keep the same two entry points (`init` copies the canon; `audit` reads the
anti-patterns).
