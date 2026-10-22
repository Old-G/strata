# Deepen gate — ask for the result on every build request

`bin/strata-deepen-gate` is a Claude Code `UserPromptSubmit` hook. When a message asks to build or
change something (a build verb in English or Russian, at least `STRATA_DEEPEN_MIN_CHARS`, default 25,
characters, not a slash command), it adds one line of context asking the model to invoke
`/strata:deepen` before planning. Everything else passes untouched.

Why a hook: `/strata:feature` runs deepen itself, but a plain "add X" often never reaches `feature` —
measured 2026-10-22, three fresh sessions with the skill installed and a SessionStart rule: zero
Skill calls. With this gate, a politely worded note still got 0/1; the imperative note it ships now
("your FIRST action is the Skill tool with strata:deepen") got 2/2 — `strata:deepen` was the first
tool call in both sessions.

The plugin ships no global hooks ([ADR #1](../wiki/decisions/adr-1-deterministic-enforcement.md)),
so this one is opt-in, installed like the [context gate](context-gate.md): the entry runs the newest
copy from the plugin cache, so an update needs no settings change and an uninstalled Strata makes it
a no-op.

## Install (all projects)

Append under `UserPromptSubmit` in `~/.claude/settings.json` — keep entries other tools own:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command",
        "command": "g=$(ls -d \"${CLAUDE_CONFIG_DIR:-$HOME/.claude}\"/plugins/cache/strata/strata/*/bin/strata-deepen-gate 2>/dev/null | sort -V | tail -1); if [ -n \"$g\" ]; then bash \"$g\"; fi" } ] }
    ]
  }
}
```

For one project only, put the same entry in that project's `.claude/settings.json`.
Installed for all projects while the plugin is enabled in only some, the note also names the
skill file, so where `strata:deepen` is not loaded the model follows the pass by hand.

## Knobs

- `STRATA_DEEPEN=0` — off (per shell or in settings `env`).
- `STRATA_DEEPEN_MIN_CHARS` — shorter messages pass (default 25), so "yes, go" never triggers it.

The model still decides: the note says to skip one-line fixes, questions and exact specs, and the
skill's own `## Do NOT use when` holds the same line. A request the gate already deepened and that
then routes to `/strata:feature` reuses that pass; feature does not run it again.
