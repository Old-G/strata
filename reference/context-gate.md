# Context gate — hand off before the context window tires

`bin/strata-context-gate` is a Claude Code `Stop` hook. When the main conversation's context
passes a threshold (default **60%** of its window) it blocks the stop **once per session** and
asks for `/strata:handoff`, which saves the session into `.claude/handoff/handoff-<session>.md`
with a ready first prompt and stops. The work then continues in a fresh session.

The plugin ships no global hooks ([ADR #1](../wiki/decisions/adr-1-deterministic-enforcement.md)),
so this one is opt-in: the user adds it to their own settings. Claude Code puts the plugin's
`bin/` on `PATH` for hooks, so the entry calls it by name and always runs the loaded plugin
version; with the plugin disabled the guard makes it a no-op.

## Install (all projects)

Add a second entry to the `Stop` array in `~/.claude/settings.json` — do not replace entries
other tools own:

```json
{
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command",
        "command": "if command -v strata-context-gate >/dev/null 2>&1; then strata-context-gate; fi" } ] }
    ]
  }
}
```

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
  pruned); `stop_hook_active` is always let through.

## Knobs

| Env | Effect |
|---|---|
| `STRATA_HANDOFF_PCT` | Threshold in percent (default 60); `0` disables the gate. |
| `STRATA_CONTEXT_WINDOW` | Force the window size in tokens. |
| `STRATA_CONTEXT_GATE_DIR` | Marker directory (tests). |

Headless and SDK sessions are gated too: SDK-driven chats report `CLAUDE_CODE_SESSION_ATTENDED=0`
exactly like `claude -p`, so skipping "unattended" sessions would skip real conversations.

Tests: `bash scripts/test_context_gate.sh` (validate §16).
