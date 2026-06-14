# Scalable Python Service Architecture — A Reference for AI-Buildable Codebases

> **What this is.** A drop-in architecture reference for Python service
> projects. Designed to be read by an AI coding assistant (Claude, Copilot,
> Cursor, Codex, etc.) at the start of every session, and by humans during
> code review. Every section names a concrete pattern, the exact folder/file
> shape, and the failure modes to avoid. The goal: a codebase that grows from
> Day 1 to ~15K+ LoC without a rewrite.
>
> **License.** Public domain / CC0. Copy, fork, modify, remove sections that
> don't apply to your project.
>
> **Tech baseline** (assumed, but every pattern is framework-agnostic): Python
> 3.12+, FastAPI, asyncpg or SQLAlchemy, Pydantic v2, pytest-asyncio, Alembic,
> structlog, Prometheus, Docker. Swap any of these — only names change.
>
> **Domain neutrality.** Examples use generic domains (`User`, `Order`,
> `Job`, `Event`). Replace with your domain when copying patterns.
>
> **AI-specific sections** (§6.4 prompts, §11) are clearly marked. If your
> project doesn't use LLMs, delete those sections.
>
> **How to use this doc**
> 1. New project → copy folder skeleton from §3, settings from §5, base
>    service shapes from §6/§7.
> 2. New feature in an existing project → find the closest pattern in §6,
>    follow it. If the pattern is missing, add it here first, then implement.
> 3. Code review → §15 ("Anti-patterns") is the rejection list.

---

## 1. Core principles

Hard rules. If a PR violates one, the design is wrong, not the lint config.

1. **One reason to change per file.** A file holds one class, one router, one
   pure helper, or one tightly-coupled cluster (e.g. a DTO + its validators).
2. **Boundaries enforced by types.** Cross-layer hand-offs use Pydantic DTOs
   or `Protocol` classes — never raw dicts and never concrete subclasses
   passed through multiple layers.
3. **Strangler Fig over Big Bang.** New layer goes in alongside the old one;
   callers migrate one by one; the old layer is deleted only after the last
   caller is gone. Never block forward progress on a refactor.
4. **Pure functions where possible.** State transitions, formatters, and
   gates live as `staticmethod` or module-level functions — no `self`. Easier
   to test, easier to move.
5. **Fail loud at system boundaries, fail soft on secondary paths.** A failed
   primary write raises a typed error and the caller transitions to FAILED.
   A failed analytics/metrics write logs and continues.
6. **Observe everything important once.** One structured log per external
   call, per API request, per workflow step. Not zero, not three.
7. **No comments restating code.** Comments say *why* (constraint, gotcha,
   incident reference). Names say *what*.
8. **Tests follow the seams.** Unit tests target one layer (mocked
   collaborators). Integration tests cross 1–2 seams. End-to-end is rare and
   marked `@pytest.mark.slow`.
9. **Backward-compat shims are temporary.** Mark them `# TODO(remove after X)`
   in the same PR that creates them. The PR closing the migration deletes
   them.
10. **Write code for the agent that will edit it next.** Every project has a
    `CLAUDE.md` (or `AGENTS.md`) at the root that captures gotchas,
    invariants, and "DO NOT" rules. Update it the moment you discover a new
    gotcha.

---

## 2. Naming and module conventions

- **Modules**: `snake_case`. Singular for "one thing" (`pipeline.py`), plural
  only for collections of equals (`agents/`, `repositories/`, `services/`).
- **Classes**: `PascalCase`, suffix carries role: `*Repository`, `*Service`,
  `*Client`, `*Transport`, `*Router`, `*Middleware`, `*Error`.
- **Functions**: verb-first. `compute_*`, `build_*`, `parse_*`, `fetch_*`,
  `_internal_helper`. Async functions get no special prefix.
- **Constants**: `UPPER_SNAKE`. Module-level, frozen `dict`/`tuple`/`set`
  literals. Never mutate at runtime.
- **Enums**: `StrEnum` when values map to strings already used in the DB or
  on the wire (`Status.ACTIVE == "active"` is `True`). `IntEnum` only for
  ordered numeric domains. Never plain `Enum` for domain values.
- **Pydantic models**: suffix `DTO` only when there is a name-clash with a
  domain class. Otherwise plain `Foo`.
- **Private**: leading underscore. Prefer module-private over class-private.

---

## 3. Folder skeleton

Copy this verbatim into a new project. Empty folders get `__init__.py` so
imports work from day one.

```
project_root/
├── src/
│   ├── __init__.py
│   ├── main.py                     # FastAPI app + lifespan + bg tasks
│   ├── protocols.py                # structural typing for cross-layer collaborators
│   │
│   ├── config/
│   │   ├── __init__.py             # re-exports settings()
│   │   └── settings.py             # nested Pydantic BaseSettings
│   │
│   ├── api/                        # HTTP layer
│   │   ├── __init__.py
│   │   ├── auth.py                 # Bearer token, CORS guards
│   │   ├── middleware.py           # X-Request-ID, structured request log
│   │   ├── dependencies.py         # FastAPI Depends() factories
│   │   ├── dto/                    # response_model classes
│   │   │   └── *.py
│   │   ├── <domain>.py             # one router per domain
│   │   └── ...
│   │
│   ├── orchestrator/               # business workflow / pipeline (optional)
│   │   ├── __init__.py
│   │   ├── state.py                # PipelineContext (one dataclass shared by all steps)
│   │   ├── pipeline.py             # orchestrator, state machine
│   │   └── fast_paths.py           # pure-function shortcuts
│   │
│   ├── services/                   # business services (external systems, cross-cutting)
│   │   ├── __init__.py
│   │   ├── registry.py             # ServiceRegistry singleton (DI container)
│   │   ├── rate_limiter.py
│   │   ├── <provider>/
│   │   │   ├── client.py           # transport: HTTP/SDK
│   │   │   ├── service.py          # business logic: retry, fallback, cost
│   │   │   └── dto.py              # provider-specific Pydantic models
│   │   └── ...
│   │
│   ├── data/                       # data layer
│   │   ├── __init__.py
│   │   ├── enums/
│   │   │   ├── <domain>.py         # one file per coherent enum cluster
│   │   │   └── ...
│   │   ├── dto/                    # cross-layer Pydantic models
│   │   │   └── *.py
│   │   └── repositories/           # SQL lives here, NOWHERE else
│   │       ├── base.py             # BaseRepository(pool) primitives
│   │       ├── <aggregate>_repo.py # one per aggregate root
│   │       └── ...
│   │
│   ├── db/
│   │   ├── connection.py           # pool primitives only — fetch/execute
│   │   └── migrations/             # Alembic
│   │       ├── alembic.ini
│   │       ├── env.py
│   │       └── versions/
│   │
│   ├── observability/
│   │   ├── logging.py              # configure_logging() — structlog
│   │   └── metrics.py              # Prometheus collectors + helpers
│   │
│   ├── prompts/                    # OPTIONAL — only for AI/LLM projects
│   │   └── static/
│   │       └── *.py                # PROMPT = """..."""
│   │
│   └── utils/                      # tiny pure-function helpers (no I/O)
│       └── *.py                    # one file per concern, < 200 LoC each
│
├── tests/
│   ├── conftest.py
│   ├── test_<file_under_test>.py   # mirror src/ layout, one file per source file
│   └── ...
│
├── scripts/                        # one-off CLI tools, never imported by src/
│   └── *.py
│
├── docs/
│   ├── SCALABLE_ARCHITECTURE_REFERENCE.md   ← this file
│   └── ...                          # ADRs, runbooks, schema dumps
│
├── pyproject.toml                   # ruff, pytest, project metadata
├── .env.example                     # checked in; .env is git-ignored
├── docker-compose.yml
├── Dockerfile
├── CLAUDE.md                        # per-project rules for AI assistants
└── README.md
```

**Optional folders**: `orchestrator/` (skip if you have no multi-step
workflow), `prompts/` (skip if no LLM use), `agents/` (skip if no LLM use —
`agents/` is a special kind of service, see §6.10).

**When to add a new top-level folder under `src/`**: only when you have ≥ 2
files that share a clear axis of change AND don't fit any existing folder.
Until then, put the file in the closest match.

---

## 4. Layer responsibilities (what goes where)

A request flows top-down; data flows back up as DTOs. No layer skips down.

| Layer            | May import from                          | May NOT import |
|------------------|------------------------------------------|----------------|
| `api/`           | `services/`, `data/dto`, `data/enums`, `orchestrator/`, `config/`, `observability/` | `db/`, repositories directly |
| `orchestrator/`  | `services/`, `data/`, `config/`, `observability/`, `utils/` | `api/` |
| `services/`      | `data/dto`, `data/enums`, `config/`, `observability/`, `utils/` | `api/`, `orchestrator/` |
| `data/repositories/` | `db/`, `data/dto`, `data/enums`            | everything else |
| `data/dto`, `data/enums` | (nothing project-internal)               | everything |
| `db/`            | (driver only, e.g. asyncpg / SQLAlchemy) | everything else |
| `utils/`         | (stdlib only)                            | everything project-internal |

**Cycle check.** Run `ruff check` regularly. If you get a circular import you
have a layering violation — fix the layering, not the import (no lazy
`import` inside functions just to silence it).

---

## 5. Configuration

**Single source of truth**: `src/config/settings.py`. Nested Pydantic
`BaseSettings`. One `AppSettings` instance returned by a memoised `settings()`.

```python
# src/config/settings.py
from functools import lru_cache
from pydantic import SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class DatabaseConfig(BaseSettings):
    url: SecretStr
    pool_min: int = 2
    pool_max: int = 10


class HttpClientConfig(BaseSettings):
    api_key: SecretStr
    base_url: str
    timeout_seconds: float = 30.0


class AppSettings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_nested_delimiter="__",
        extra="ignore",
        case_sensitive=False,
    )

    database: DatabaseConfig
    upstream: HttpClientConfig
    log_format: str = "console"          # "console" | "json"
    dry_run: bool = False                # if True, skip side-effecting writes upstream

    @model_validator(mode="before")
    @classmethod
    def _backward_compat_flat_envs(cls, values: dict) -> dict:
        # Accept legacy DATABASE_URL alongside DATABASE__URL.
        # Delete this validator once the last legacy env var is gone.
        ...
        return values


@lru_cache(maxsize=1)
def settings() -> AppSettings:
    return AppSettings()
```

Rules:

- **Secrets are `SecretStr`.** Logs and `repr()` mask them.
  `.get_secret_value()` only at the call site.
- **Nested env via `__`**: `DATABASE__URL`, `UPSTREAM__API_KEY`. Flat
  fallbacks are accepted via `model_validator(mode="before")` while
  migrating; document them in `CLAUDE.md` and remove on a deadline.
- **`.env.example` checked into git**. Add a `scripts/generate_env_example.py`
  that introspects `AppSettings` and re-emits `.env.example`; run it in CI to
  prevent drift.
- **No `os.environ.get(...)` outside `config/`.** Anywhere else, ask
  `settings()`.
- **Fail-fast at startup.** Required fields have no default. Empty CORS list
  in prod → raise on startup, don't silently allow any origin.

---

## 6. Pattern catalog

### 6.1 Repository pattern (Strangler Fig)

SQL lives in `data/repositories/` — nowhere else. The connection module
holds *only* pool primitives.

```python
# src/data/repositories/base.py
class BaseRepository:
    def __init__(self, pool):
        self._pool = pool

    async def _fetch(self, sql: str, *args):
        async with self._pool.acquire() as conn:
            return await conn.fetch(sql, *args)

    async def _fetchrow(self, sql: str, *args):
        async with self._pool.acquire() as conn:
            return await conn.fetchrow(sql, *args)

    async def _execute(self, sql: str, *args):
        async with self._pool.acquire() as conn:
            return await conn.execute(sql, *args)


# src/data/repositories/order_repo.py
class OrderRepository(BaseRepository):
    async def get_items(self, order_id: str) -> list[OrderItem]:
        rows = await self._fetch(
            "SELECT order_id, sku, quantity, price FROM order_items WHERE order_id = $1",
            order_id,
        )
        return [OrderItem(**dict(r)) for r in rows]
```

**Migration playbook** (Strangler Fig — when an existing project has SQL
spread everywhere):

1. Create `data/repositories/<X>_repo.py` with the new methods.
2. Constructors accept the repo as a parameter (keep the old `db` param too,
   for now).
3. Migrate call sites one by one; each PR removes one raw SQL string from
   the legacy module.
4. When the old SQL constant is unused, delete it.
5. Final PR: remove the legacy `db` param. The connection module ends up
   with only `fetch_*`, `fetchrow_*`, `execute_*` primitives.

**Bounded queries.** Never expose `get_all_*` returning an unbounded list.
Pair it with `get_subset(ids: list[X])` for hot paths.

```python
# Avoid (memory grows with table size):
async def get_processed_ids(self) -> list[str]:
    return [r["entity_id"] for r in await self._fetch(
        "SELECT entity_id FROM processed"
    )]

# Prefer (memory bounded by candidate set):
async def get_processed_subset(self, candidate_ids: list[str]) -> set[str]:
    rows = await self._fetch(
        "SELECT entity_id FROM processed WHERE entity_id = ANY($1::text[])",
        candidate_ids,
    )
    return {r["entity_id"] for r in rows}
```

**Two-phase fetch** for the common "filter-large-table-by-membership-of-
small-set" pattern:

```python
candidates = await source_repo.fetch_candidates(limit=2 * limit)
processed = await audit_repo.get_processed_subset([c.id for c in candidates])
fresh = [c for c in candidates if c.id not in processed][:limit]
```

### 6.2 DTOs (Pydantic v2)

```python
# src/data/dto/order.py
from pydantic import BaseModel, ConfigDict


class OrderSummary(BaseModel):
    model_config = ConfigDict(extra="allow", frozen=True)
    order_id: str
    status: str
    total_cents: int
    currency: str = "USD"
```

Rules:
- `extra="allow"` for DTOs that round-trip from external services — keeps
  forward compat when upstream adds a field.
- `frozen=True` when the DTO represents a fact (immutable after creation).
- Cross-layer hand-offs use DTOs, not raw dicts. The schema is enforced at
  the boundary.

**Apply pattern** when bridging DTO ↔ legacy flat fields on a context object:

```python
def apply_classification(self, dto: ClassificationResult) -> None:
    self.classification = dto
    self.kind = dto.kind
    self.subkind = dto.subkind
```

The flat fields exist for backward compat. Never write them directly — that's
how DTO ↔ flat drift happens.

### 6.3 Enums

```python
# src/data/enums/order.py
from enum import StrEnum, IntEnum


class OrderStatus(StrEnum):
    NEW = "new"
    PROCESSING = "processing"
    SHIPPED = "shipped"
    CANCELLED = "cancelled"

    @property
    def is_terminal(self) -> bool:
        return self in (self.SHIPPED, self.CANCELLED)


class Priority(IntEnum):
    LOW = 0
    NORMAL = 1
    HIGH = 2
```

`StrEnum` values match the on-the-wire / DB strings exactly. This makes
`row["status"] == OrderStatus.NEW` work without `.value`. Add `@property`
for predicates that the codebase asks repeatedly — colocate them with the
enum, not with whoever asks.

### 6.4 Service layer

A "service" wraps an external system or coordinates a cross-cutting concern.
Two-file split:

```
services/<provider>/
├── client.py     # transport: HTTP, SDK clients, no retry, no business logic
├── service.py    # business: retry, fallback, mapping → DTO, cost tracking
└── dto.py
```

```python
# src/services/<provider>/client.py
class UpstreamTransport:
    def __init__(self, cfg: HttpClientConfig):
        self._client = httpx.AsyncClient(
            base_url=cfg.base_url,
            timeout=cfg.timeout_seconds,
            headers={"Authorization": f"Bearer {cfg.api_key.get_secret_value()}"},
        )

    async def get_resource(self, resource_id: str) -> dict:
        resp = await self._client.get(f"/resources/{resource_id}")
        resp.raise_for_status()
        return resp.json()


# src/services/<provider>/service.py
class UpstreamService:
    def __init__(self, transport: UpstreamTransport, rate_limiter: RateLimiter):
        self._transport = transport
        self._rl = rate_limiter

    async def get_resource(self, resource_id: str) -> Resource:
        await self._rl.acquire("upstream")
        raw = await self._call_with_retries(resource_id)
        return Resource(**raw)
```

### 6.5 Registry / DI

```python
# src/services/registry.py
class ServiceRegistry:
    def __init__(
        self, *,
        upstream: UpstreamService,
        order_repo: OrderRepository,
        audit_repo: AuditRepository,
        # ...
    ):
        self.upstream = upstream
        self.order_repo = order_repo
        self.audit_repo = audit_repo


# src/main.py (lifespan)
@asynccontextmanager
async def lifespan(app: FastAPI):
    db = await Database.connect(settings().database)
    transport = UpstreamTransport(settings().upstream)
    rate_limiter = RateLimiter(...)
    registry = ServiceRegistry(
        upstream=UpstreamService(transport, rate_limiter),
        order_repo=OrderRepository(db.pool),
        audit_repo=AuditRepository(db.pool),
    )
    app.state.registry = registry
    yield
    await db.close()


# src/api/dependencies.py
def get_registry(request: Request) -> ServiceRegistry:
    return request.app.state.registry
```

Why a registry, not module-level globals: testability. In tests, build a
registry with mocks; in scripts, build one with the two services you
actually need.

### 6.6 Protocols (structural typing)

```python
# src/protocols.py
from typing import Any, Protocol


class DatabaseProtocol(Protocol):
    async def fetch(self, sql: str, *args: Any) -> list: ...
    async def fetchrow(self, sql: str, *args: Any) -> Any: ...
    async def execute(self, sql: str, *args: Any) -> str: ...


class HttpClientProtocol(Protocol):
    async def get(self, path: str, **kw: Any) -> dict: ...
    async def post(self, path: str, **kw: Any) -> dict: ...
```

Use protocols on constructor type hints when the consumer needs only a few
methods and you want to mock easily. **Do not** use abstract base classes
for internal collaborators — `Protocol` keeps the contract explicit without
an inheritance tax.

### 6.7 Null Object pattern

```python
class NullCache:
    """Stand-in when caching is disabled — keeps callers branch-free."""
    async def get(self, _key: str) -> None:
        return None

    async def set(self, _key: str, _value: Any, _ttl: int = 0) -> None:
        return None


# Constructor wraps None into the null object so call-sites never branch.
self.cache = cache or NullCache()
```

When to use: an optional collaborator whose absence shouldn't sprinkle
`if x:` guards through the happy path. When NOT to use: when "absent"
should change behaviour (e.g. fallback to disk vs network — that's a real
decision, not an optionality).

### 6.8 Workflow / state machine

When a workflow has more than 3 steps, encode the steps as an enum and
declare valid transitions.

```python
# src/orchestrator/state.py
from enum import StrEnum
from dataclasses import dataclass, field


class Step(StrEnum):
    INIT = "init"
    VALIDATING = "validating"
    PROCESSING = "processing"
    NOTIFYING = "notifying"
    DONE = "done"
    FAILED = "failed"


VALID_TRANSITIONS: dict[Step, set[Step]] = {
    Step.INIT: {Step.VALIDATING},
    Step.VALIDATING: {Step.PROCESSING, Step.FAILED},
    Step.PROCESSING: {Step.NOTIFYING, Step.FAILED},
    Step.NOTIFYING: {Step.DONE, Step.FAILED},
}


@dataclass
class PipelineContext:
    entity_id: str
    current_step: Step = Step.INIT
    step_timings: dict[Step, float] = field(default_factory=dict)
    failed_step: Step | None = None
    error_message: str | None = None


# src/orchestrator/pipeline.py
class Pipeline:
    async def _run_step(self, ctx: PipelineContext, step: Step, body):
        self._transition(ctx, step)
        t0 = time.monotonic()
        try:
            await body()
        except Exception as exc:
            ctx.failed_step = step
            ctx.error_message = str(exc)
            self._transition(ctx, Step.FAILED)
            metrics.steps_total.labels(step=step, outcome="failed").inc()
            raise
        finally:
            ctx.step_timings[step] = time.monotonic() - t0
            metrics.step_duration_seconds.labels(step=step).observe(
                ctx.step_timings[step]
            )

    def _transition(self, ctx: PipelineContext, target: Step) -> None:
        if target not in VALID_TRANSITIONS.get(ctx.current_step, set()):
            msg = f"invalid transition {ctx.current_step} → {target}"
            if os.getenv("STRICT_STATE") == "1":
                raise InvalidTransition(msg)
            log.warning(msg)
        ctx.current_step = target
```

Benefits: every step is observable (timing + outcome), retryable (load
context, set `current_step` to the desired step, run from there), and the
transition table doubles as documentation.

**Fast paths** are pure functions in `orchestrator/fast_paths.py`. The
pipeline calls them after the first step and skips downstream work when
they fire. Keep them pure — trivially unit-testable.

### 6.9 Retry with fallback

```python
async def _call_with_retries(self, request):
    primary = self._primary_provider
    fallback = self._fallback_provider
    last_primary_exc = None
    for attempt in range(self.cfg.max_retries):
        try:
            return await primary.call(request)
        except (RateLimitError, TimeoutError) as exc:
            last_primary_exc = exc
            await asyncio.sleep(self._backoff(attempt) + random.uniform(0, 1.0))
    if fallback:
        try:
            return await fallback.call(request)
        except Exception as fb_exc:
            raise FallbackFailedError(
                primary=primary.name, fallback=fallback.name,
            ) from fb_exc
    raise last_primary_exc


class FallbackFailedError(RuntimeError):
    def __init__(self, *, primary: str, fallback: str):
        super().__init__(f"both {primary} and {fallback} failed")
        self.primary = primary
        self.fallback = fallback
```

Rules:
- **Jitter** in backoff (`uniform(0, 1.0)`) prevents thundering herd.
- **Named exception** with `__cause__` chain — operators read both errors in
  one log line.
- **No bare `except Exception`** for retries — you'll retry programming bugs
  and DDoS yourself. Whitelist the transient classes.

### 6.10 Rate limiter (sliding window, re-check after sleep)

```python
class SlidingWindowLimiter:
    def __init__(self, max_requests: int, window_seconds: float):
        self._max = max_requests
        self._window = window_seconds
        self._times: deque[float] = deque()
        self._lock = asyncio.Lock()

    async def acquire(self) -> None:
        while True:
            async with self._lock:
                now = time.monotonic()
                while self._times and self._times[0] < now - self._window:
                    self._times.popleft()
                if len(self._times) < self._max:
                    self._times.append(now)
                    return
                wait = self._times[0] + self._window - now
            await asyncio.sleep(wait)
            # re-check capacity in the next loop iteration; never break invariant
```

Critical: the `while True` re-check after sleep. Without it, two concurrent
callers can both wake up at `wait + ε` and both append, exceeding capacity.

### 6.11 Critical vs secondary write distinction

```python
class StepError(RuntimeError):
    """Critical write failed — workflow must transition to FAILED."""


# Critical: workflow stops if this fails
try:
    record_id = await repo.insert_primary_record(payload)
except Exception as exc:
    raise StepError(f"primary insert failed for {ctx.entity_id}") from exc

# Secondary: log and continue
try:
    await self._emit_analytics_event(ctx, record_id)
except Exception as exc:
    log.warning("analytics emit failed for %s: %s", ctx.entity_id, exc)
```

The line is: "if this write fails, can the user still get value from the
work we already did?" If yes → secondary. If no → critical.

### 6.12 Cost-aware accounting (when calling paid APIs)

```python
def estimate_cost(model: str, usage: dict) -> float:
    rate = MODEL_RATES[model]
    input_tokens = usage["prompt_tokens"]
    cached = (usage.get("prompt_tokens_details") or {}).get("cached_tokens", 0)
    output_tokens = usage["completion_tokens"]

    fresh_input = input_tokens - cached
    return (
        fresh_input * rate.input
        + cached * rate.input * rate.cached_discount
        + output_tokens * rate.output
    )
```

Log cost per call as a structured event. Aggregate in Prometheus by
provider/model/outcome. Drop this section if you don't have paid external
APIs.

---

## 7. API layer

```python
# src/api/<domain>.py
from fastapi import APIRouter, Depends
from src.api.auth import bearer_required
from src.api.dependencies import get_registry
from src.api.dto.orders import OrderListResponse

router = APIRouter(prefix="/api/orders", dependencies=[Depends(bearer_required)])


@router.get("/", response_model=OrderListResponse)
async def list_orders(
    limit: int = 50, registry=Depends(get_registry),
) -> OrderListResponse:
    items = await registry.order_repo.list(limit=limit)
    return OrderListResponse(items=items)
```

Rules:
- **One router per domain.** Mount at `/api/<domain>`.
- **`response_model=` for known shapes.** Implicit-shape JSON is technical
  debt — frontend / OpenAPI consumers can't rely on it.
- **Auth at router level via `dependencies=[Depends(bearer_required)]`.**
  Don't repeat the `Depends` on every endpoint. Use `hmac.compare_digest`.
- **CORS gates fail-fast in prod.** Empty `allowed_origins` in production →
  raise on startup. Dev can default to `localhost`.

```python
# src/api/auth.py
import hmac
from fastapi import Header, HTTPException


async def bearer_required(authorization: str = Header(default="")):
    expected = settings().api_token.get_secret_value()
    if not authorization.startswith("Bearer "):
        raise HTTPException(401, "missing bearer")
    if not hmac.compare_digest(authorization[7:], expected):
        raise HTTPException(401, "invalid token")
```

### 7.1 Request middleware

```python
# src/api/middleware.py
import time
from uuid import uuid4
import structlog


async def request_id_middleware(request, call_next):
    rid = request.headers.get("X-Request-ID", str(uuid4()))[:200]
    request.state.request_id = rid
    structlog.contextvars.bind_contextvars(request_id=rid, path=request.url.path)
    t0 = time.monotonic()
    try:
        response = await call_next(request)
    finally:
        elapsed = time.monotonic() - t0
        structlog.contextvars.clear_contextvars()
    if request.url.path not in {"/health", "/metrics"}:
        log.info(
            "api_request",
            method=request.method,
            status=response.status_code,
            duration_ms=int(elapsed * 1000),
            request_id=rid,
        )
    response.headers["X-Request-ID"] = rid
    return response
```

One log per request. `/health` and `/metrics` excluded — they're hot.

---

## 8. Observability

### 8.1 Structured logging

```python
# src/observability/logging.py
import structlog


def configure_logging(format: str = "console") -> None:
    processors = [
        structlog.contextvars.merge_contextvars,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.add_log_level,
        structlog.processors.StackInfoRenderer(),
    ]
    if format == "json":
        processors.append(structlog.processors.JSONRenderer())
    else:
        processors.append(structlog.dev.ConsoleRenderer())
    structlog.configure(processors=processors, wrapper_class=structlog.BoundLogger)
```

- **Console mode** in dev (human-readable, colored).
- **JSON mode** in prod (`LOG_FORMAT=json`) for log aggregators.
- **Bind context once** (`bind_contextvars(entity_id=...)`); every log inside
  that scope inherits it. Clear on exit.

### 8.2 Metrics

```python
# src/observability/metrics.py
from prometheus_client import Counter, Histogram

upstream_calls_total = Counter(
    "upstream_calls_total", "...", ["provider", "outcome"],
)
upstream_latency_seconds = Histogram(
    "upstream_latency_seconds", "...", ["provider"],
)
steps_total = Counter("workflow_steps_total", "...", ["step", "outcome"])
step_duration_seconds = Histogram(
    "workflow_step_duration_seconds", "...", ["step"],
)
```

Rules:
- **Bound label cardinality.** `provider` is enum-bounded; `entity_id` and
  `user_id` are unbounded — never label by them.
- **`/metrics` is unauthenticated** (Prometheus pulls it) but bound to an
  internal interface in prod.

---

## 9. Testing strategy

```toml
# pyproject.toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
markers = [
    "slow: marks tests >1s (deselect with -m 'not slow')",
    "integration: requires real DB / external service",
]
addopts = "--strict-markers"
```

Lanes:

- **Fast (default)**: `pytest -m "not slow"`, runs in <30s on a laptop. CI
  pre-merge gate.
- **Full**: `pytest`, runs slow + integration. CI nightly + pre-deploy.

Patterns:

- **One test file per source file.** `tests/test_<file>.py` mirrors `src/`.
  Easy to find, easy to refactor.
- **One class per concern.** `class TestValidationGate: ...` — pytest
  discovers methods automatically.
- **Fixtures for context builders.** A 10-arg `_make_ctx(**overrides)`
  helper beats 50 lines of arrange code in every test.
- **Mock at the seam.** Mock the repo, not the DB driver. Mock the service,
  not the SDK. Tests then survive transport upgrades.
- **Integration tests use a real DB** (testcontainers or docker compose
  service). No SQLite-as-Postgres-stand-in — the dialect drift bites.

### 9.1 Mocked repository test shape

```python
def _mock_pool():
    pool = MagicMock()
    conn = AsyncMock()
    pool.acquire.return_value.__aenter__ = AsyncMock(return_value=conn)
    pool.acquire.return_value.__aexit__ = AsyncMock(return_value=False)
    return pool, conn


@pytest.mark.asyncio
async def test_get_items_returns_rows():
    pool, conn = _mock_pool()
    conn.fetch = AsyncMock(return_value=[
        {"order_id": "O-1", "sku": "A", "quantity": 1, "price": 100},
    ])
    repo = OrderRepository(pool)
    items = await repo.get_items("O-1")
    assert items[0].sku == "A"
```

---

## 10. Database & migrations

- **Alembic from day one**, even if there's "just one table". Set up:
  `src/db/migrations/{alembic.ini, env.py, versions/}`.
- **Migration script** (`scripts/run_migrations.py`) wraps `alembic upgrade
  head` so it runs the same way locally, in Docker, in CI.
- **Multiple pools when relevant** (e.g. a read-only replica + writable
  primary) — keep them separate; method names disambiguate
  (`fetch_primary` vs `fetch_replica`).
- **Never `SELECT *`** in shipped code. List columns explicitly so renames
  surface as test failures.
- **Bound LIMIT** on every list query. No silent unbounded scans.
- **Vector embeddings** (if applicable): pgvector with explicit dim. Cast in
  the INSERT (`$N::vector`). Wrap query strings as Python multi-line
  constants in the repo file.

---

## 11. Prompts (OPTIONAL — only for AI/LLM projects)

Skip this section entirely if your project doesn't use LLMs.

- **Static prompts**: `src/prompts/static/<role>.py` as plain
  `PROMPT = """..."""`. Easier to grep, version, and review.
- **Dynamic prompts**: builder functions in `src/prompts/dynamic/`. They
  take a Pydantic context model and return a string. **Pure** — no I/O.
- **Versioning**: a top comment in each prompt file: "version: vN — last
  updated YYYY-MM-DD — tested at <link>". Update on every edit.
- **Prompt safety** at every user-content boundary:
  - `wrap_user_content(s)` — escape break-out tags (`</system>`, etc.)
  - `redact_pii(d)` — strip email/phone/address before sending to the LLM.
- **LLM JSON parsing** through one helper:
  `parse_llm_pydantic(text, Model)` — handles markdown fences, retries on
  `ValidationError`. Never inline `json.loads(re.sub(...))`.
- **Structured output**: define a Pydantic model, generate a strict JSON
  schema from it, parse the response with `Model.model_validate_json()`. No
  ad-hoc schema dicts.

```python
def strict_schema(model: type[BaseModel], name: str) -> dict:
    """Build OpenAI-style 'json_schema' response_format from a Pydantic model."""
    schema = model.model_json_schema()
    schema["additionalProperties"] = False
    return {"name": name, "schema": schema, "strict": True}
```

Treat agents (LLM-backed services) as a flavour of `services/`. Each agent
gets its own file with a `BaseAgent` parent (`run(ctx) -> AgentResult`) and
delegates the actual LLM call to an injected `LLMService`.

---

## 12. Deployment & ops

- **One container, one image, one role.** Background workers and HTTP can
  share an image but use a different command. Co-locate them in the same
  FastAPI process for small services; split out only when CPU/IO patterns
  diverge.
- **Branch-as-release**: prod pulls from a specific branch (e.g. `main` or
  `release`); deploy is `git pull && docker compose up -d --build`. No
  artifact registry needed for early-stage projects.
- **`docker-compose.yml`** committed; secrets via `.env` (git-ignored) or
  Docker secrets. Refuse to start if any required env var is missing.
- **Health endpoint** at `/health`: returns 200 only when DB pools are
  connected and the registry is initialised. Used by load balancer + CI.
- **Graceful shutdown**: lifespan tears down pools with `asyncio.wait`
  (NOT `wait_for` — Python 3.13 has subtle CancelledError swallowing on
  `wait_for(asyncio.gather(...))`).

---

## 13. CLAUDE.md — the per-project AI contract

Every project root has a `CLAUDE.md` (or `AGENTS.md` for tools that look for
that name). It's read by every AI assistant working on the codebase.
Sections (in order):

1. **One-line project description.**
2. **Tech stack** — Python version, key libs, model versions.
3. **Dev commands** — exact CLI for tests, run, migrate, lint.
4. **Architecture overview** — point to this file plus a 1-paragraph summary
   of the actual workflow / API surface.
5. **Critical gotchas** — every footgun the team has hit. One bullet each,
   imperative voice ("**Status values**: `'new'`/`'active'` in DB — use
   `Status.NEW` enum.").
6. **Latest results / state** — last benchmark numbers, deployment status.
7. **Server & git** — host, deploy command, branch followed by prod.

Update CLAUDE.md in the same PR that introduces a gotcha. Don't let it rot —
stale CLAUDE.md misleads the next AI session and costs hours.

---

## 14. Documentation conventions

- **`docs/` is for humans + AI**, not auto-generated API docs. Keep:
  - `SCALABLE_ARCHITECTURE_REFERENCE.md` (this file).
  - `ARCHITECTURE.md` — project-specific architecture: actual modules,
    actual data flow, diagrams.
  - `db_schema/` — table dumps + sample rows (refreshed via a script).
  - `runbooks/` — "what to do when X breaks", one file per failure mode.
  - `adrs/` — Architecture Decision Records for non-obvious choices.
- **Diagrams** in Mermaid (`*.mermaid.md`) — text-diffable, render in GitHub.
- **No screenshots** of code. Quote the file with a permalink.

---

## 15. Anti-patterns (rejection list for code review)

| Anti-pattern | Why it's bad | Do this instead |
|---|---|---|
| Raw SQL outside `data/repositories/` | Layer violation — refactors break callers | Move SQL to a repository method |
| `os.environ.get()` outside `config/` | Hidden config surface — `.env.example` rots | Add the field to `AppSettings` |
| `try/except Exception: pass` | Silent failures, debug nightmares | Catch the specific class, log+raise typed error, or use Null Object |
| Plain `dict` between layers | No schema, no validation, drift everywhere | Pydantic DTO with `extra="allow"` |
| Mutable global registry | Tests interfere; concurrency hazards | `ServiceRegistry` injected via lifespan + `Depends()` |
| `if x is None: ... else: ...` for an optional collaborator on every call | Branching everywhere, easy to forget | Null Object pattern |
| Module-level side effects on import | Import-time errors, slow startup, untestable | Move to `lifespan()` / explicit init |
| `from foo import *` | Unknown deps, ruff can't help | Explicit imports |
| Ad-hoc retry loops | Inconsistent backoff, no jitter, no log | One retry helper per service |
| Comments restating code | Rot quickly, add noise | Delete the comment; rename the symbol |
| Test that mocks the SQL dialect | Tests pass, prod migration fails | Real DB in integration tests |
| `--no-verify` / skip hooks | Ships broken code | Fix the underlying issue |
| Unbounded `get_all_*` in hot path | OOM as table grows | Bounded `get_subset(ids)` + two-phase fetch |
| Flat field written by hand after DTO | DTO ↔ flat drift | `apply_<aspect>(dto)` setter method |
| `wait_for(asyncio.gather(...))` for shutdown | Py3.13 swallows CancelledError | `asyncio.wait([task], timeout=...)` |
| Logging every call AND every retry AND every... | Log spam hides signal | Exactly one structured event per logical operation |
| Prometheus label per `entity_id` / `user_id` | Cardinality explosion → OOM | Label by enum-bounded values only |
| `SELECT *` in shipped code | Renames silently break callers | Explicit column list |

---

## 16. Adoption checklist for a new project

Run through this on day one. Each item is ≤ 30 minutes.

- [ ] Create folder skeleton from §3.
- [ ] Add `pyproject.toml` with ruff + pytest config (markers,
      `asyncio_mode`).
- [ ] Write `AppSettings` (§5) with at least one nested config + one
      `SecretStr` field. Run a sanity test that loads it.
- [ ] Set up `configure_logging()` (§8.1) and call it in `main.py` lifespan.
- [ ] Stand up Alembic migrations folder; add the initial `001_init.py` even
      if empty. Add `scripts/run_migrations.py` wrapper.
- [ ] Build `BaseRepository` + one real repo with one method + a test using
      a mocked pool (§6.1, §9.1).
- [ ] Build `ServiceRegistry` + lifespan wiring (§6.5).
- [ ] Add `/health` endpoint, X-Request-ID middleware, `/metrics`.
- [ ] Commit `CLAUDE.md` with the §13 sections filled in.
- [ ] Add `docs/SCALABLE_ARCHITECTURE_REFERENCE.md` (this file).
- [ ] Add `.env.example` and a check-in-CI script that regenerates it from
      `AppSettings`.
- [ ] First feature: implement it end-to-end through every layer (api →
      orchestrator → service → repo → db) so the seams are exercised before
      they harden into shortcuts.

When the project hits ~3K LoC, audit against §15. When it hits ~10K LoC,
audit against §1–4. The cost of catching a layering violation at 10K is 5×
the cost at 3K. The cost at 30K is "rewrite".

---

## 17. Sizing heuristics

- **File**: < 400 LoC. Above that, split.
- **Class**: < 250 LoC. Above that, extract collaborators.
- **Function**: < 50 LoC. Above that, extract pure helpers.
- **Test file**: ~1.5× its source file is normal. > 3× means the source
  file has too many branches — split the source, not the tests.
- **Top-level folder under `src/`**: ≤ 12. More than that, you're missing a
  grouping (e.g. `api/`, `data/`).
- **Repository methods**: 5–15 per repo is healthy. > 25 means the
  aggregate is too large — split (e.g. `OrderRepository` +
  `OrderItemRepository`).
- **Number of services / agents**: as many as you need; each is < 250 LoC.

These are heuristics, not laws. The actual rule is: **if a future
maintainer (or AI) opens this file and can't tell the one reason it
changes, it's too big.**

---

## 18. What to skip when starting small

You can defer (but not forget):

- **Repositories**: skip until ≥ 5 SQL queries; just keep them in
  `db/queries.py`. Then refactor in a single Strangler PR.
- **Service split (`client.py` + `service.py`)**: skip until you add retry
  or fallback. A single `service.py` with the SDK call is fine until then.
- **State machine**: skip if your workflow has ≤ 3 steps. Use plain
  sequential awaits.
- **Metrics**: skip until production. Logs are enough in dev.
- **Multiple pools**: skip until you actually have separate read/write or
  cross-environment access.

You **must NOT skip**, even on day one:
- `AppSettings` with `SecretStr` + `.env.example`.
- `CLAUDE.md` at the project root.
- Folder structure from §3 (empty folders are fine).
- One health endpoint.
- One structured log line per request.
- pytest with `--strict-markers`.

---

## 19. Working with this doc

When the AI assistant reads this file:

1. **Skim §1 (principles), §3 (folder skeleton), §15 (anti-patterns), §16
   (checklist) on every session.** They're the executive summary.
2. **Look up the specific pattern in §6 / §7 when implementing.** Don't
   reinvent.
3. **If you're about to do something not covered here, write it up FIRST,
   add it to this file, then implement.** That's how the doc stays current.

When the human owner reads this file: anything that bit you in production
and isn't here yet — add it to §15 with the failure mode, then to §6 with
the pattern that prevents it.

---

## 20. Customising for your project

Sections you'll likely tweak per project:

- **§3 folder skeleton** — drop `orchestrator/`, `agents/`, `prompts/` if
  you don't have a multi-step workflow or LLM use.
- **§5 settings** — replace example field names with your domain.
- **§6.4 service split** — keep the pattern; rename the example provider.
- **§11 prompts** — delete entirely for non-AI projects.
- **§6.12 cost accounting** — delete if no paid external APIs.
- **§13 CLAUDE.md** — keep, even if your AI tool uses a different filename
  (`AGENTS.md`, `.cursorrules`, etc.). The principle is the same.

Keep:

- **§1 principles** — apply to any Python service regardless of domain.
- **§2 naming, §4 layer boundaries, §15 anti-patterns, §16 checklist,
  §17 sizing** — universal.
- **§9 testing, §10 DB, §12 deploy, §14 docs** — universal with minor
  tweaks.

---

*Living reference. Last revised: keep this footer up to date with patterns
that prove themselves in your project. Contributions welcome — open a PR
against the upstream copy.*
