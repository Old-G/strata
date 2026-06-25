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

## Step 2 — Enable the Strata plugin (this is a user action, by design)

`/strata:*` becomes available by enabling the plugin **globally** in `~/.claude/settings.json`. But
**you (the AI) cannot do this silently**: you can't type slash commands, and Claude Code's permission
guard treats *the assistant* writing `~/.claude/settings.json` to enable an external plugin as a
self-modification (in auto-mode it is auto-denied). That guard is correct — **never route around it**
(no Edit-tool workaround). Enabling a plugin is the human's call. So hand them the command.

**Primary path — have the user run the native command(s).** Use your Step 1 scan to see whether the
marketplace is already registered (is `extraKnownMarketplaces.strata` in their
`~/.claude/settings.json`?):
- **not registered yet** → tell them to run `/plugin marketplace add Old-G/strata`, then
  `/plugin install strata@strata`.
- **already registered** → tell them to run just `/plugin install strata@strata` (say the marketplace
  is already there, so only the enable step is left).

**No-slash-commands alternative:** the user runs the bundled installer in their **own terminal**
(outside Claude Code, so the in-session guard doesn't apply); it writes the same config safely and
idempotently:

```bash
curl -fsSL https://raw.githubusercontent.com/Old-G/strata/main/install.sh | sh
```

You *may* run that installer yourself only if the user explicitly authorizes it (approves the Bash
prompt, or the session isn't in auto-mode). If the guard denies the write, **stop and fall back to
the Primary path** — do not try to bypass it.

**verify:** the user confirms the plugin installed (or you read `~/.claude/settings.json` and see
`enabledPlugins["strata@strata"] = true`). It only takes effect after the reload in Step 4.

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
