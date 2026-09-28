# Context gate — hand off before the context window tires

`bin/strata-context-gate` is a Claude Code `Stop` and `PostToolUse` hook. When the main
conversation's context passes a threshold (default **60%** of its window) it blocks **once per
session** and asks for `/strata:handoff`, which saves the session into `.claude/handoff/handoff-<session>.md`
with a ready first prompt and stops. The work then continues in a fresh session.

The plugin ships no global hooks ([ADR #1](../wiki/decisions/adr-1-deterministic-enforcement.md)),
so this one is opt-in: the user adds it to their own settings. Hook commands do **not** get the
plugin's `bin/` on `PATH` (only the Bash tool does — measured 2026-09-27: a by-name entry ran in
8 ms and never found the script), so the entry picks the newest installed copy from the plugin
cache. A plugin update is picked up with no settings change; with Strata uninstalled it is a no-op.

## Install (all projects)

Add the same command under `Stop` **and** `PostToolUse` in `~/.claude/settings.json` — do not
replace entries other tools own. `Stop` asks when a turn ends; `PostToolUse` asks mid-turn, for a
turn that never ends (queued messages and background-agent results keep one turn running until
auto-compact — seen 2026-09-28: 53% → 67% in one turn, no `Stop` between).

```json
{
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command",
        "command": "g=$(ls -d \"${CLAUDE_CONFIG_DIR:-$HOME/.claude}\"/plugins/cache/strata/strata/*/bin/strata-context-gate 2>/dev/null | sort -V | tail -1); if [ -n \"$g\" ]; then bash \"$g\"; fi" } ] }
    ],
    "PostToolUse": [
      { "matcher": "*", "hooks": [ { "type": "command",
        "command": "g=$(ls -d \"${CLAUDE_CONFIG_DIR:-$HOME/.claude}\"/plugins/cache/strata/strata/*/bin/strata-context-gate 2>/dev/null | sort -V | tail -1); if [ -n \"$g\" ]; then bash \"$g\"; fi" } ] }
    ]
  }
}
```

Use 0.13.1 or newer before adding `PostToolUse`: older copies do not skip subagent tool calls.

For one project only, put the same entry in that project's `.claude/settings.json`.

## How it measures

- **Used** = `input_tokens + cache_creation_input_tokens + cache_read_input_tokens` of the newest
  main-chain assistant message in `transcript_path` (sidechain/subagent and zero-usage synthetic
  messages are skipped). Output tokens are not context.
- **Window** = `$STRATA_CONTEXT_WINDOW`, else 1M when the configured model contains `[1m]`
  (`ANTHROPIC_MODEL`, then `<project>/.claude/settings.local.json`, `<project>/.claude/settings.json`,
  `~/.claude/settings.json`), or when more than 200k is already used; otherwise 200k. The hook
  input names no model, so a mid-session `/model` switch is not seen.
- **Once per session:** a marker in `$TMPDIR/strata-context-gate/<session>` (older than 14 days
  pruned), shared by both events; `stop_hook_active` is always let through.
- **Main agent only:** a subagent's tool call carries the main transcript but also `agent_id`,
  and is skipped. Mid-turn the reason asks to finish only the step in progress first.

## Knobs

| Env | Effect |
|---|---|
| `STRATA_HANDOFF_PCT` | Threshold in percent (default 60); `0` disables the gate. |
| `STRATA_CONTEXT_WINDOW` | Force the window size in tokens. |
| `STRATA_CONTEXT_GATE_DIR` | Marker directory (tests). |

Headless and SDK sessions are gated too: SDK-driven chats report `CLAUDE_CODE_SESSION_ATTENDED=0`
exactly like `claude -p`, so skipping "unattended" sessions would skip real conversations.

Tests: `bash scripts/test_context_gate.sh` (validate §16).
