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

Safe merge (same intent as `install.sh`; the canonical, no-op-safe version lives there):

```bash
STRATA_SETTINGS="$HOME/.claude/settings.json" python3 - <<'PY'
import copy, json, os, time, shutil, sys
path = os.environ["STRATA_SETTINGS"]
os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
data, existed = {}, False
if os.path.exists(path) and open(path, encoding="utf-8").read().strip():
    try:
        data = json.load(open(path, encoding="utf-8"))
    except json.JSONDecodeError as e:
        sys.exit(f"settings.json is not valid JSON ({e}); fix it first, aborting.")
    existed = True
if not isinstance(data, dict):
    sys.exit("settings.json top-level is not an object; aborting.")
before = copy.deepcopy(data)
data.setdefault("extraKnownMarketplaces", {})["strata"] = {"source": {"source": "git", "url": "https://github.com/Old-G/strata.git"}}
data.setdefault("enabledPlugins", {})["strata@strata"] = True
if existed and data == before:
    print("OK: strata already registered in", path, "— no change"); sys.exit(0)
if existed:
    shutil.copy2(path, f"{path}.strata-bak.{int(time.time())}")
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

> ✅ Strata is in your config. Two steps left:
> 1. Run `/reload-plugins` (or restart Claude Code).
> 2. Send: `/strata:onboard`
>
> If `/strata:onboard` isn't found, first run `/plugin marketplace add Old-G/strata` and
> `/plugin install strata@strata`, then `/strata:onboard`.

(Match the user's language if they wrote in another tongue. Russian variant: ✅ Strata записана в
конфиг. 1) Выполни `/reload-plugins` (или перезапусти Claude Code). 2) Вставь `/strata:onboard`.
Если не найден — сначала `/plugin marketplace add Old-G/strata` и `/plugin install strata@strata`,
затем `/strata:onboard`.)
