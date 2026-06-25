# AI-led one-line onboarding — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a single line that, dropped into an AI agent (or run in a terminal), self-installs Strata and then lets the AI conduct the whole framework setup conversationally.

**Architecture:** Three new artifacts + doc edits. `install.sh` does an idempotent, non-destructive JSON merge of two keys into `~/.claude/settings.json` (the only genuinely unit-testable unit → real TDD). `BOOTSTRAP.md` is an AI-addressed conductor for session 1 (prereq scan → write config → breadcrumb → print the restart bridge). `skills/onboard/SKILL.md` is a thin conductor for session 2 that delegates to `/strata:init` or `/strata:adopt` then runs the first `/strata:audit`. The unavoidable one-restart seam is bridged by a precise, copy-pasteable continuation prompt with a `/plugin` fallback.

**Tech Stack:** POSIX `sh` + `python3` (installer), Markdown skills (Claude Code plugin), `bash` test/validate harness. No runtime deps.

**Spec:** [docs/superpowers/specs/2026-06-25-ai-led-onboarding-design.md](../specs/2026-06-25-ai-led-onboarding-design.md)

---

## File structure

| File | New/Mod | Responsibility |
|---|---|---|
| `install.sh` | new | Idempotent JSON merge of marketplace+enable keys; backup/validate; print bridge |
| `scripts/test_install.sh` | new | Behavioral tests for `install.sh` against a temp settings file |
| `BOOTSTRAP.md` | new | Session-1 conductor doc, addressed to the AI (chat path) |
| `skills/onboard/SKILL.md` | new | Session-2 conductor skill; delegates to init/adopt, runs first audit |
| `scripts/validate.sh` | mod | Add a syntax check for root `install.sh` |
| `.github/workflows/ci.yml` | mod | Run `scripts/test_install.sh` |
| `README.md` | mod | "⚡ Instant setup (AI-led)" section + TOC entry |
| `skills/using-strata/SKILL.md` | mod | Add `onboard` row to the skills table |
| `CLAUDE.md` | mod | Update phase/status table |

**Shared bridge text** lives in two mediums (BOOTSTRAP.md prose + install.sh heredoc) — that duplication is intentional and acceptable; keep the two in sync by eye.

---

## Task 1: `install.sh` + behavioral tests (TDD)

**Files:**
- Create: `scripts/test_install.sh`
- Create: `install.sh`
- Modify: none

The installer must target a configurable path so it is testable: it reads `STRATA_SETTINGS` (default `$HOME/.claude/settings.json`). The merge: create file if absent; never clobber existing keys; abort (non-zero, file untouched) if existing JSON is invalid; idempotent on re-run.

- [ ] **Step 1: Write the failing test**

Create `scripts/test_install.sh`:

```bash
#!/usr/bin/env bash
# Behavioral tests for install.sh — runs it against a temp settings file
# (STRATA_SETTINGS override) and asserts the resulting JSON. bash + python3 only.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT/install.sh"
fail=0
err() { echo "  ✗ $1"; fail=1; }
ok()  { echo "  ✓ $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

has_strata() {
  python3 -c "
import json
d=json.load(open('$1'))
assert d.get('extraKnownMarketplaces',{}).get('strata',{}).get('source',{}).get('url')=='https://github.com/Old-G/strata.git', 'marketplace missing'
assert d.get('enabledPlugins',{}).get('strata@strata') is True, 'plugin not enabled'
" 2>/dev/null
}

echo "== T1: fresh file (does not exist) =="
S="$TMP/fresh.json"
STRATA_SETTINGS="$S" sh "$INSTALL" >/dev/null 2>&1
{ [ -f "$S" ] && has_strata "$S"; } && ok "fresh install writes both keys" || err "fresh install failed"

echo "== T2: preserves existing keys =="
S="$TMP/existing.json"
printf '{"env":{"FOO":"bar"},"enabledPlugins":{"other@x":true}}' > "$S"
STRATA_SETTINGS="$S" sh "$INSTALL" >/dev/null 2>&1
python3 -c "
import json
d=json.load(open('$S'))
assert d['env']['FOO']=='bar'
assert d['enabledPlugins']['other@x'] is True
assert d['enabledPlugins']['strata@strata'] is True
" 2>/dev/null && ok "existing keys preserved + strata added" || err "merge clobbered existing keys"

echo "== T3: idempotent =="
S="$TMP/idem.json"
STRATA_SETTINGS="$S" sh "$INSTALL" >/dev/null 2>&1
A="$(python3 -c "import json;print(json.dumps(json.load(open('$S')),sort_keys=True))")"
STRATA_SETTINGS="$S" sh "$INSTALL" >/dev/null 2>&1
B="$(python3 -c "import json;print(json.dumps(json.load(open('$S')),sort_keys=True))")"
[ "$A" = "$B" ] && ok "second run is a no-op" || err "not idempotent"

echo "== T4: refuses corrupt JSON, leaves file unchanged =="
S="$TMP/corrupt.json"
printf '{ this is not json ' > "$S"
before="$(cat "$S")"
STRATA_SETTINGS="$S" sh "$INSTALL" >/dev/null 2>&1
rc=$?
after="$(cat "$S")"
{ [ "$rc" -ne 0 ] && [ "$before" = "$after" ]; } && ok "aborts on corrupt JSON, file untouched" || err "did not protect corrupt file"

echo
if [ "$fail" -eq 0 ]; then echo "✅ install.sh tests PASSED"; else echo "❌ install.sh tests FAILED"; fi
exit "$fail"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash scripts/test_install.sh`
Expected: FAIL — every case errors because `install.sh` does not exist yet (`sh: install.sh: No such file`). Final line `❌ install.sh tests FAILED`, exit 1.

- [ ] **Step 3: Write the minimal implementation**

Create `install.sh`:

```sh
#!/usr/bin/env sh
# Strata installer — registers the Strata marketplace and enables the plugin by
# merging two keys into your Claude Code settings.json. Idempotent and
# non-destructive: existing keys are preserved, a timestamped backup is taken,
# and the write is aborted if the existing file is not valid JSON.
#
#   curl -fsSL https://raw.githubusercontent.com/Old-G/strata/main/install.sh | sh
#
# Target: ~/.claude/settings.json  (override with STRATA_SETTINGS=/path, used by tests)
set -eu

SETTINGS="${STRATA_SETTINGS:-$HOME/.claude/settings.json}"
MARKETPLACE_URL="https://github.com/Old-G/strata.git"

command -v python3 >/dev/null 2>&1 || {
  echo "✗ python3 is required but was not found on PATH." >&2
  exit 1
}

SETTINGS="$SETTINGS" MARKETPLACE_URL="$MARKETPLACE_URL" python3 - <<'PY'
import json, os, sys, time, shutil

path = os.environ["SETTINGS"]
url  = os.environ["MARKETPLACE_URL"]
os.makedirs(os.path.dirname(path) or ".", exist_ok=True)

data = {}
if os.path.exists(path):
    raw = open(path, encoding="utf-8").read()
    if raw.strip():
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            print(f"✗ {path} is not valid JSON ({e}); refusing to touch it.", file=sys.stderr)
            sys.exit(1)
        backup = f"{path}.strata-bak.{int(time.time())}"
        shutil.copy2(path, backup)
        print(f"  backup: {backup}")

if not isinstance(data, dict):
    print(f"✗ {path} top-level JSON is not an object; refusing to touch it.", file=sys.stderr)
    sys.exit(1)

data.setdefault("extraKnownMarketplaces", {})["strata"] = {
    "source": {"source": "git", "url": url}
}
data.setdefault("enabledPlugins", {})["strata@strata"] = True

tmp = f"{path}.strata-tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, path)
print(f"✓ Strata registered in {path}")
PY

cat <<'EOF'

✅ Strata is in your config. Two steps left:
  1. Run  /reload-plugins   (or restart Claude Code).
  2. Send  /strata:onboard

If /strata:onboard isn't found, run  /plugin marketplace add Old-G/strata
and  /plugin install strata@strata  first, then  /strata:onboard.
EOF
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash scripts/test_install.sh`
Expected: PASS — `✅ install.sh tests PASSED`, exit 0. (`set -e` in install.sh guarantees T4: python exits 1 on corrupt JSON before any write, so the success banner never prints and the file is untouched.)

- [ ] **Step 5: Commit**

```bash
chmod +x install.sh scripts/test_install.sh
git add install.sh scripts/test_install.sh
git commit -m "feat(onboarding): add install.sh with idempotent settings merge + tests"
```

---

## Task 2: `BOOTSTRAP.md` (session-1 conductor for the chat path)

**Files:**
- Create: `BOOTSTRAP.md`

This is fetched by the chat one-liner and **executed** by the AI. It must work pre-install (only reads a doc, runs bash, writes files — no plugin needed).

- [ ] **Step 1: Write the failing check**

Run: `test -f BOOTSTRAP.md && echo EXISTS || echo MISSING`
Expected: `MISSING`.

- [ ] **Step 2: Create the file**

Create `BOOTSTRAP.md`:

````markdown
# Strata bootstrap — instructions for the AI

You have been asked to install and run **Strata** in this repository. Strata is a Claude Code
plugin that makes a repo self-describing and self-correcting.

**Execute the steps below in order. Each step names a `verify` — do not move on until it passes.
Do not just summarize this file; perform the actions.** Strata's plan rule applies: state the plan
and get the user's approval before writing to their config.

---

## Step 0 — Already installed? (idempotency)

Check whether Strata is already available — are `/strata:*` skills/commands present in this session
(e.g. `using-strata`, `onboard`)?
- **If yes:** skip installation. Invoke `strata:onboard` and stop reading this file.
- **If no:** continue.

## Step 1 — Prerequisite scan (report only, never block)

Detect and report which optional companions are present. Do **not** install them.
- **Superpowers** (recommended — Strata's PROCESS layer wraps it): are skills like
  `superpowers:brainstorming` / `superpowers:test-driven-development` available?
- **claude-mem** (recommended — episodic memory): are `claude-mem` MCP tools available?
- **RTK** (optional — command-output compaction): `command -v rtk`.

Report a short present/missing table with one line on what each unlocks. Missing tools only
degrade gracefully — proceed regardless.

## Step 2 — Install Strata into the user's config

Goal: register the Strata marketplace and enable the plugin **globally** so `/strata:*` work in
every project. Non-destructive, idempotent merge of two keys into `~/.claude/settings.json`.

Show the user the change, get approval, then merge (create the file if absent; never clobber
existing keys):
- `extraKnownMarketplaces.strata = { "source": { "source": "git", "url": "https://github.com/Old-G/strata.git" } }`
- `enabledPlugins["strata@strata"] = true`

Safe merge (same logic as `install.sh`):

```bash
STRATA_SETTINGS="$HOME/.claude/settings.json" python3 - <<'PY'
import json, os, time, shutil, sys
path = os.environ["STRATA_SETTINGS"]
os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
data = {}
if os.path.exists(path) and open(path, encoding="utf-8").read().strip():
    try:
        data = json.load(open(path, encoding="utf-8"))
    except json.JSONDecodeError as e:
        sys.exit(f"settings.json is not valid JSON ({e}); fix it first, aborting.")
    shutil.copy2(path, f"{path}.strata-bak.{int(time.time())}")
data.setdefault("extraKnownMarketplaces", {})["strata"] = {"source": {"source": "git", "url": "https://github.com/Old-G/strata.git"}}
data.setdefault("enabledPlugins", {})["strata@strata"] = True
json.dump(data, open(path, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
print("OK: strata registered in", path)
PY
```

**verify:** re-read `~/.claude/settings.json`; confirm it parses and both keys are present.

## Step 3 — Drop a resume breadcrumb

So the next session continues with context, write `.strata/onboard.json` in the project root. Look
at the repo first to set `projectType`: `new` (empty/near-empty, no real history) or `existing`.

```bash
mkdir -p .strata
cat > .strata/onboard.json <<'JSON'
{ "installedAt": "FILL-ISO-8601", "projectType": "new-or-existing", "configLocation": "global", "prereqs": { "superpowers": false, "claude_mem": false, "rtk": false } }
JSON
grep -qxF '.strata/' .gitignore 2>/dev/null || printf '\n.strata/\n' >> .gitignore
```

Edit the JSON to the real values you found in Steps 1–2. **verify:** `.strata/onboard.json` parses.

## Step 4 — Hand the user across the restart (the bridge)

You cannot reload plugins yourself — it is a user action. Print EXACTLY this block, then stop:

> ✅ Strata записана в конфиг. Осталось 2 шага:
> 1. Выполни `/reload-plugins` (или перезапусти Claude Code).
> 2. Вставь: `/strata:onboard`
>
> Если `/strata:onboard` не найден — сначала `/plugin marketplace add Old-G/strata` и
> `/plugin install strata@strata`, затем `/strata:onboard`.

(English: ✅ Strata is in your config. 1) Run `/reload-plugins` (or restart Claude Code). 2) Send
`/strata:onboard`. If `/strata:onboard` isn't found, run `/plugin marketplace add Old-G/strata`
and `/plugin install strata@strata` first, then `/strata:onboard`.)
````

- [ ] **Step 3: Verify content anchors are present**

Run:
```bash
grep -q 'enabledPlugins' BOOTSTRAP.md \
&& grep -q 'extraKnownMarketplaces' BOOTSTRAP.md \
&& grep -q '/plugin marketplace add Old-G/strata' BOOTSTRAP.md \
&& grep -q '.strata/onboard.json' BOOTSTRAP.md \
&& grep -q 'strata:onboard' BOOTSTRAP.md \
&& echo "ANCHORS OK"
```
Expected: `ANCHORS OK`.

- [ ] **Step 4: Commit**

```bash
git add BOOTSTRAP.md
git commit -m "feat(onboarding): add BOOTSTRAP.md session-1 conductor (chat path)"
```

---

## Task 3: `skills/onboard/SKILL.md` (session-2 conductor)

**Files:**
- Create: `skills/onboard/SKILL.md`

Thin conductor — delegates to init/adopt, then runs the first audit. Must pass `validate.sh` §3 (name + description frontmatter).

- [ ] **Step 1: Write the failing check**

Run: `test -f skills/onboard/SKILL.md && echo EXISTS || echo MISSING`
Expected: `MISSING`.

- [ ] **Step 2: Create the file**

Create `skills/onboard/SKILL.md`:

```markdown
---
name: onboard
description: Use right after installing Strata (the bridge prompt tells the user to run "/strata:onboard"), or when the user says "onboard this repo / continue Strata setup / set up Strata here and walk me through it / lead me through Strata". Conducts the full setup end-to-end — detects new-vs-existing, checks prerequisites, then delegates to /strata:init or /strata:adopt and runs the first /strata:audit — asking one question at a time and calling the commands itself.
---

# /strata:onboard — conduct the full Strata setup

You are the conductor. The human should not have to know which `/strata:*` command to run — you
detect the situation, propose a plan, and drive it, asking ONE question at a time. You are **thin
glue**: do NOT reimplement init/adopt/audit — delegate to them and let each own its verifies. The
four-layer model lives in `${CLAUDE_PLUGIN_ROOT}/skills/using-strata/SKILL.md` if you need it.

## Step 1 — Resume context (if any)

If `.strata/onboard.json` exists, read it — it records `projectType` and prereq results from the
bootstrap step. Treat it as a HINT, not ground truth; still re-detect below (it can be stale).

## Step 2 — Detect new vs existing

Inspect the working directory:
- **new** — empty / near-empty, no substantial git history, no source tree → the `init` path.
- **existing** — real code and/or git history → the `adopt` path.
Confirm in one question ("This looks like an existing project — adopt Strata into it? [yes / it's
actually new]").

## Step 3 — Prerequisite report

Re-check (the session changed since bootstrap): Superpowers, claude-mem (recommended), RTK
(optional). Report present/missing and, for anything missing, the one concrete thing it costs
(e.g. "no Superpowers → /strata:feature's brainstorm/TDD steps degrade"). Do not block.

## Step 4 — Plan, then approval

State the path as `step → verify` and get approval before writing anything:
- new → "run /strata:init to scaffold structure + a green smoke test (+ wiki if an AI will read this repo)".
- existing → "run /strata:adopt to add CLAUDE.md + wiki + the docs→raw mirror hook and emit an adoption report".
Both then → "run /strata:audit for the first drift report".

## Step 5 — Delegate the setup

Invoke the matching skill and let it run to completion with ITS OWN verifies — do not duplicate its
logic here:
- **new:** invoke `/strata:init`.
- **existing:** invoke `/strata:adopt`.
Carry the prereq findings and project name into that skill's questions so the user isn't asked twice.

## Step 6 — First audit

When init/adopt has finished green, invoke `/strata:audit` (read-only — safe to auto-run). Present
the ranked drift report it writes to `docs/superpowers/specs/<date>-strata-audit.md`.

## Step 7 — Hand off

Summarize what now exists, then point the way (do NOT auto-run these):
- `/strata:refactor` — close the audit's findings, one TDD step at a time.
- `/strata:feature` — build the first feature through office-hours → council → TDD.
Finally remove the breadcrumb: `rm -f .strata/onboard.json` (its job is done).
```

- [ ] **Step 3: Verify frontmatter + anchors**

Run:
```bash
bash scripts/validate.sh >/tmp/strata_validate.log 2>&1; echo "validate exit: $?"
grep -q 'name: onboard' skills/onboard/SKILL.md \
&& grep -q '/strata:init' skills/onboard/SKILL.md \
&& grep -q '/strata:adopt' skills/onboard/SKILL.md \
&& grep -q '/strata:audit' skills/onboard/SKILL.md \
&& echo "ANCHORS OK"
```
Expected: `validate exit: 0` and `ANCHORS OK` (validate.sh §3 now lists `skills/onboard/SKILL.md ✓`).

- [ ] **Step 4: Commit**

```bash
git add skills/onboard/SKILL.md
git commit -m "feat(onboarding): add /strata:onboard conductor skill"
```

---

## Task 4: Wire validation + CI

**Files:**
- Modify: `scripts/validate.sh` (add root `install.sh` syntax check)
- Modify: `.github/workflows/ci.yml` (run installer tests)

- [ ] **Step 1: Add the install.sh syntax check to validate.sh**

In `scripts/validate.sh`, immediately after the `== 5. shell templates pass 'bash -n' ==` block (the `done` on line 62), insert:

```bash
echo "== 5b. root install.sh parses =="
if [ -f install.sh ]; then
  sh -n install.sh 2>/dev/null && ok "install.sh" || err "install.sh has a shell syntax error"
fi
```

- [ ] **Step 2: Add the installer-test step to CI**

In `.github/workflows/ci.yml`, after the `Validate plugin structure` step, insert:

```yaml
      - name: Test installer (idempotent settings merge)
        run: bash scripts/test_install.sh
```

- [ ] **Step 3: Verify locally**

Run: `bash scripts/validate.sh && bash scripts/test_install.sh`
Expected: `✅ Strata plugin validation PASSED` (now including `install.sh ✓`) **and** `✅ install.sh tests PASSED`, both exit 0.

- [ ] **Step 4: Commit**

```bash
git add scripts/validate.sh .github/workflows/ci.yml
git commit -m "ci: validate install.sh syntax and run installer tests"
```

---

## Task 5: Documentation

**Files:**
- Modify: `README.md`
- Modify: `skills/using-strata/SKILL.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add the README section + TOC entry**

In `README.md`, add this line to the Table of contents list (right after `- [Why Strata](#why-strata)`):

```markdown
- [Instant setup (AI-led)](#-instant-setup-ai-led)
```

Then insert this new section immediately **before** `## Installation` (line 70):

````markdown
## ⚡ Instant setup (AI-led)

Don't want to learn the commands? Drop **one line** into a fresh Claude Code session in your repo
and let the AI install Strata and walk you through the whole setup — it detects new-vs-existing,
checks prerequisites, runs `init` or `adopt`, and produces your first audit, asking questions as it
goes.

**In a Claude Code chat (recommended):**

> Install and run Strata in this repo: fetch and follow
> https://raw.githubusercontent.com/Old-G/strata/main/BOOTSTRAP.md

**Or in your terminal:**

```bash
curl -fsSL https://raw.githubusercontent.com/Old-G/strata/main/install.sh | sh
```

Either way you do exactly **one** manual action: when prompted, run `/reload-plugins` (or restart
Claude Code), then send `/strata:onboard`. That single restart is a Claude Code limitation — newly
installed plugin commands only activate after a reload. From there the AI leads the rest.

Prefer to do everything by hand? See [Manual install](#installation) below.

---
````

- [ ] **Step 2: Add the onboard row to using-strata**

In `skills/using-strata/SKILL.md`, in the "Skills — what to invoke when" table, add this as the FIRST data row (right under the header separator, before the `Start a brand-new project` row):

```markdown
| Get set up end-to-end (let the AI lead it) | `/strata:onboard` | Detects new/existing, checks prereqs, then delegates to `init`/`adopt` and runs the first `audit` |
```

- [ ] **Step 3: Update the CLAUDE.md phase table**

In `CLAUDE.md`, in the "Phase / status" table, update the skills row and add an onboarding row. Replace:

```markdown
| Skills: init / adopt / audit / refactor / feature / office-hours / autoplan / wiki-ingest | 🔄 building |
```

with:

```markdown
| Skills: init / adopt / audit / refactor / feature / office-hours / autoplan / wiki-ingest / onboard | 🔄 building |
| One-line AI-led onboarding (BOOTSTRAP.md + install.sh + /strata:onboard) | 🔄 building |
```

- [ ] **Step 4: Verify docs**

Run:
```bash
grep -q 'Instant setup (AI-led)' README.md \
&& grep -q 'BOOTSTRAP.md' README.md \
&& grep -q 'strata:onboard' skills/using-strata/SKILL.md \
&& grep -q 'AI-led onboarding' CLAUDE.md \
&& echo "DOCS OK"
awk 'END{print "CLAUDE.md lines:", NR}' CLAUDE.md
bash scripts/validate.sh >/dev/null 2>&1 && echo "validate OK"
```
Expected: `DOCS OK`, `CLAUDE.md lines:` ≤ 200, `validate OK`.

- [ ] **Step 5: Commit**

```bash
git add README.md skills/using-strata/SKILL.md CLAUDE.md
git commit -m "docs: add AI-led instant-setup one-liners and onboard routing"
```

---

## Task 6: Final dogfood verify + manual fresh-profile check (R1)

**Files:** none (verification only)

- [ ] **Step 1: Full automated suite**

Run: `bash scripts/validate.sh && bash scripts/test_install.sh`
Expected: both green (exit 0). Paste the observed output — do not claim success on red.

- [ ] **Step 2: Manifests still parse**

Run: `python3 -c "import json; json.load(open('.claude-plugin/plugin.json')); json.load(open('.claude-plugin/marketplace.json')); print('manifests OK')"`
Expected: `manifests OK`.

- [ ] **Step 3: Manual fresh-profile check — the #1 risk (R1)**

This cannot be automated in this repo; it verifies whether config-only install triggers the marketplace clone on reload. On a clean machine/profile (or a throwaway `CLAUDE_CONFIG_DIR`):

1. Run `sh install.sh` (or paste the chat one-liner and let the AI run BOOTSTRAP.md).
2. Start Claude Code, run `/reload-plugins`.
3. Check whether `/strata:onboard` resolves.
   - **If yes:** config-only auto-clone works → record this in the spec (§8.2) as confirmed; the `/plugin` fallback is belt-and-suspenders.
   - **If no:** run `/plugin marketplace add Old-G/strata` + `/plugin install strata@strata`, confirm `/strata:onboard` then resolves → the fallback in the bridge is load-bearing. Record this outcome.

Write the observed result into the spec's §8 verify #2 so the behavior is documented, not assumed.

- [ ] **Step 4: Final commit (if Step 3 produced a spec note)**

```bash
git add docs/superpowers/specs/2026-06-25-ai-led-onboarding-design.md
git commit -m "docs: record observed config-only install behavior (R1)"
```

---

## Self-review (completed by plan author)

**Spec coverage:** §5.1 BOOTSTRAP.md → Task 2 · §5.2 onboard skill → Task 3 · §5.3 install.sh → Task 1 · §5.4 docs → Task 5 · §6 bridge → Tasks 1+2 · §7 one-liners → Tasks 1+2+5 · §8 verifies → Tasks 1/4/6 · §2/§8.2 R1 fresh-profile → Task 6.3 · breadcrumb → written in Task 2, read+removed in Task 3. No gaps.

**Placeholder scan:** none — every file ships full content; the only intentional FILL tokens are inside the BOOTSTRAP.md breadcrumb template, which the AI fills at runtime (documented in that step).

**Type/name consistency:** settings keys `extraKnownMarketplaces.strata` + `enabledPlugins["strata@strata"]`, env override `STRATA_SETTINGS`, breadcrumb path `.strata/onboard.json`, and command `/strata:onboard` are spelled identically across install.sh, test_install.sh, BOOTSTRAP.md, onboard skill, and docs.
