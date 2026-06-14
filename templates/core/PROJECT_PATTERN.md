# Project Pattern — Claude-Code-Friendly Repo Layout

Transferable шаблон организации репо для проектов с AI-агентами в loop (Claude Code / Cursor / etc).
Не догма — отдельные блоки можно отключать (см. §9 skip-list).

---

## 1. Three-layer knowledge split: `docs/` ↔ `raw/` ↔ `wiki/`

| Слой | Кто пишет | Кто читает | Назначение |
|---|---|---|---|
| `docs/` | **люди** (markdown source of truth) | люди; AI — индирект через `raw/` | план, спеки, ADR, runbooks |
| `raw/` | **скрипт зеркалит** из `docs/` (`cp -p`) | AI (read-only) | стабильный input для ingest |
| `wiki/` | **AI** (ingest + lint) | AI (query) | knowledge graph: entities, sources, ADRs |

**Правила:**
- `raw/` никогда не редактируют вручную — это копия `docs/`.
- Любая правка в `docs/<file>.md` → обязательно `cp -p docs/<file>.md raw/<file>.md` + AI ingest.
- AI отвечает на вопросы про проект через `wiki/`, не через `raw/`. Если вики не отвечает — сигнал что ingest неполный.
- Lint раз в неделю: AI ищет противоречия / orphans / outdated и пишет в `wiki/log.md`.

Паттерн вдохновлён karpathy-wiki — pull-forward knowledge base, не append-only журнал.

---

## 2. `CLAUDE.md` структура (project root)

Семь обязательных секций, в этом порядке:

```markdown
# <Project Name>
1-абзац: что это, текущая фаза, что работает в проде сейчас.

## Phase / Gate status — ✅/🔄 <state> <date>
Таблица чек-пунктов: критерий | статус | ссылка на runbook/PR.

## Стек (целевой)
Одна строка через "·". Никаких диаграмм здесь — они в docs/Architecture.md.

## Layout
- Бэктики каждой ключевой директории + 1 строка что внутри.
- Особо отметить: monorepo / submodule / отдельные репо.

## Команды
Bash-блок с реальными командами: install, test, run, build, deploy.
ENV-переменные одной строкой.

## Workflow
- Plan mode → approval → execute. Никаких тихих изменений.
- /compact на 50%. Subagents для исследовательских задач.
- Smoke-test после schema-changes.

## Жёсткие правила
Bullet-list инвариантов которые НЕ обсуждаются.
Каждое правило ссылается на ADR.
```

**Принципы:**
- `CLAUDE.md` ≤ 200 строк. Длиннее — выносить в `docs/`.
- Каждая ссылка относительная и кликабельная: `[Architecture](docs/Architecture.md)`.
- Не дублировать `docs/` — линковать.

---

## 3. ADR-Lean

Один файл `docs/ADR-Lean.md`, не `docs/adr/NNNN-*.md`-простыня.

```markdown
## ADR #NN — <Title> (status: accepted | superseded by #MM)
**Context:** 2-3 строки почему встал вопрос.
**Decision:** что решили (одно предложение).
**Consequences:** что становится анти-паттерном после.
**Date:** YYYY-MM-DD.
```

Addendum формат (`## ADR #NN-addendum — ...`) — для уточнений без re-open старого ADR.

**Правило:** не переоткрывать без явного нового addendum. Цитировать в коде/PR: `// per ADR #NN`.

---

## 4. `services/<name>/` layout (per-service)

Каждый сервис — самодостаточный модуль (опционально — отдельный git-репо, см. §5).

```
services/<name>/
├── CLAUDE.md              # service-specific правила (схема DB, конвенции, gotchas)
├── README.md              # для людей
├── pyproject.toml         # или package.json — pinned tooling versions
├── .env.example           # все переменные с PREFIX_, без секретов
├── Dockerfile             # multi-stage, HEALTHCHECK
├── docker-compose.yml
├── .pre-commit-config.yaml
├── .gitlab-ci.yml         # или .github/workflows/
├── src/<name>/
│   ├── settings.py        # pydantic-settings / zod / typed config с PREFIX_
│   ├── main.py            # entry point
│   ├── data/              # DB layer (Protocol / interface + concrete)
│   ├── tools/             # API/MCP/CLI endpoints (один файл = один endpoint)
│   └── utils/             # validation, logging setup, secret redaction
├── tests/                 # ≥80% coverage на новый код
├── scripts/               # одноразовые: dump_schema, connection_check
└── <name>_explore/        # архив исследования + raw/ scripts/ results/
```

**Принципы:**
- Service-internal архитектура — отдельный документ типа `SCALABLE_ARCHITECTURE_REFERENCE.md`:
  folder skeleton, anti-patterns, adoption checklist, skip-list для маленьких сервисов.
- Маленький сервис (< 500 LoC) — пропускает большую часть скелета, см. §9.

---

## 5. Repo strategy: monorepo vs. nested independent repos

Три варианта:
- **Monorepo** — общие зависимости, shared tooling, < 5 человек, deploy одним пайплайном.
- **Nested independent** — `services/<name>/` лежит физически внутри корневого, но **в `.gitignore`**
  корневого и имеет свой git-репо. Две независимые истории, независимый deploy, независимый CI.
  Выбирай когда: разные команды деплоят независимо, разные security boundaries, разный cadence релизов.
- **Submodule** — почти никогда. Боль с CI и обновлениями превышает выгоду.

**Обязательно:** при выборе nested independent — в корневом README зафиксировать fix-procedure для
свежего клона: какие nested репо нужно клонить отдельно и куда.

---

## 6. `.env` правила

- `.env.example` коммитим, `.env` — нет.
- Префикс на сервис (`<SERVICE>_DB_HOST`, не голый `DB_HOST`) — даёт изоляцию при общем хосте.
- chmod 600 на prod.
- **Синтаксис:** только `#` для комментариев (не `//` JS-style — docker `env_file` парсер ломается).
- Никаких секретов в коде. Vault / Secrets Manager upgrade-path — отдельный ADR.
- gitleaks / trufflehog в pre-commit и CI.

---

## 7. Workflow conventions

- **Plan mode → approval → execute.** Никаких тихих изменений.
- **/compact на 50%** контекста. Subagents для исследовательских задач — экономия контекста основного агента.
- **Smoke-test после schema-changes** — отдельный скрипт `<service>_explore/scripts/http_smoke_test.<ext>`.
- **Deploy через git** (push → server pull → rebuild), не scp. Всегда воспроизводимо.
- **Goal-Driven Execution** (см. §8): каждый шаг плана имеет verify-команду.

---

## 8. Goal-Driven Execution (рекомендую в `~/.claude/CLAUDE.md` или эквивалент)

```markdown
# Goal-Driven Execution

Перед многошаговой задачей преврати её в проверяемые цели, не в действия.

- Слабая цель ("make it work", "add validation") → постоянные уточнения и silent compromise.
  Сильная цель называет verify-чек, который либо проходит, либо нет.
- Переформулируй до старта:
  - "Add validation" → "Write tests for invalid inputs, then make them pass"
  - "Fix the bug" → "Write a test that reproduces it, then make it pass"
  - "Refactor X" → "Tests green до и после; diff не меняет поведения"
  - "Wire integration" → "Endpoint вызывается end-to-end и возвращает ожидаемый shape на live данных"
- Формат плана >2 шагов: `шаг → verify` (verify = конкретная команда, не "проверю что работает").
- Loop правило: шаг done только когда verify прошёл. Если verify невозможен (нет prod / ключа /
  данных) — скажи явно, не заявляй success.
- Evidence перед assertion — всегда.
```

Адаптировано из Karpathy guidelines (https://github.com/multica-ai/andrej-karpathy-skills §4).

---

## 9. Skip-list (когда НЕ применять)

- **`raw/` слой** — только если есть AI-агент, который читает проект. Для голого human-only проекта избыточно.
- **`wiki/`** — нужен только при > 10 `docs/` файлов или явно multi-source knowledge.
- **Полный service skeleton (§4)** — для маленького сервиса (< 500 LoC, один файл endpoints) хватит
  `src/<name>/main.<ext> + tests/`.
- **ADR-Lean** — для прототипа на 2 недели не нужен. Появляется когда есть >1 человека или >1 месяца жизни.
- **Phase status таблица в `CLAUDE.md`** — только для проектов с roadmap'ом и стейкхолдерами.

---

## 10. Bootstrap-чеклист для нового проекта

```
□ git init + первый коммит с README.md
□ docs/Architecture.md (даже 1 страница) + docs/ADR-Lean.md (пустой шаблон)
□ CLAUDE.md по структуре из §2 (с честным "Phase 0: planning" статусом)
□ .gitignore: .env, .venv/, __pycache__, *.pyc, node_modules/, dist/, build/
□ .env.example с <SERVICE>_ префиксом
□ pre-commit-config: linter + formatter + gitleaks (или эквивалент для стека)
□ pyproject.toml / package.json с pinned tooling versions
□ tests/ с одним passing smoke-test ("project imports")
□ CI пайплайн: lint + type-check + tests, должен быть зелёным с первого коммита
□ Если AI-агент будет читать: создать raw/ + wiki/ + WIKI.md (схему ingest)
□ Если будут сервисы: создать services/ и заложить ссылку на ваш SAR-эквивалент
```

---

## Источники

- Karpathy guidelines — https://github.com/multica-ai/andrej-karpathy-skills (§4 Goal-Driven Execution).
- Anthropic Claude Code docs — https://docs.claude.com/claude-code.
- ADR pattern — https://adr.github.io.
