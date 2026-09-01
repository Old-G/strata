#!/usr/bin/env bash
# Strata A3 — SessionStart injection.
#
# Claude Code adds this script's stdout to the model's context, so every session
# opens knowing the branch, what the wiki still owes, and where the index starts.
# Budget is deliberately small (<= 50 lines): this text is paid for on EVERY
# session, so it carries only state the model cannot otherwise see. The routing
# map is NOT duplicated here — it lives once in CLAUDE.md, which is already in
# context.
#
# Side effect (load-bearing for the Stop gate): records the session's starting
# point in .strata/sessions/<session_id>.start, so strata_stop_gate.sh can tell
# "markers this session created" from "markers that were already there".
# See ADR #4.
#
# P2 additions (docs/superpowers/specs/2026-09-01-episodic-state-layer.md):
# if the current branch has a .strata/state/<slug>.json, print its summary —
# this is the "pop up what we already knew" half of the episodic-state layer;
# the Stop gate's trigger (c) is the "don't let it go stale" half. And if
# .strata/version disagrees with the plugin actually running, say so once —
# the whole point of /strata:upgrade is that this can no longer go unnoticed.
#
# Install: SessionStart hook in the project's .claude/settings.json.
# Exit code is always 0 — a context hook must never break session startup.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 0

LOG="wiki/log.md"
INDEX="wiki/index.md"
MAX_PENDING_SHOWN=5
MAX_INDEX_ROWS=15

# --- session stamp -----------------------------------------------------------
# Read session_id from the hook payload; tolerate no stdin, empty stdin, or junk.
session_id=""
if [ ! -t 0 ]; then
  payload="$(cat 2>/dev/null || true)"
  if [ -n "$payload" ]; then
    session_id="$(python3 -c "
import json, sys
try:
    print((json.loads(sys.argv[1]) or {}).get('session_id', '') or '')
except Exception:
    pass
" "$payload" 2>/dev/null || true)"
  fi
fi

# Sanitize: this value becomes a filename.
session_id="$(printf '%s' "$session_id" | tr -cd 'A-Za-z0-9._-')"
[ -n "$session_id" ] || session_id="unknown"

log_lines=0
[ -f "$LOG" ] && log_lines="$(wc -l < "$LOG" | tr -d ' ')"

mkdir -p .strata/sessions 2>/dev/null || true
{
  echo "EPOCH=$(date +%s)"
  echo "LOG_LINES=$log_lines"
} > ".strata/sessions/${session_id}.start" 2>/dev/null || true

# Keep the directory from growing forever.
find .strata/sessions -type f -mtime +7 -delete 2>/dev/null || true

# --- context block -----------------------------------------------------------
# Nothing to say in a project that does not use the knowledge layer.
[ -f "$INDEX" ] || [ -f "$LOG" ] || exit 0

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")"
dirty="$(git status --porcelain 2>/dev/null | grep -c . || true)"

echo "## Strata context"
echo "Branch: ${branch} · uncommitted files: ${dirty:-0}"

# --- branch state summary (P2) -----------------------------------------------
STATE_TOOLS="$SCRIPT_DIR/../lib/state_tools.py"
if [ -f "$STATE_TOOLS" ] && [ "$branch" != "?" ]; then
  state_path="$(python3 "$STATE_TOOLS" path "$branch" 2>/dev/null)"
  [ -n "$state_path" ] && [ -f "$state_path" ] && python3 "$STATE_TOOLS" summary "$state_path" 2>/dev/null
fi

# --- plugin version nudge (P2) ------------------------------------------------
if [ -f .strata/version ] && [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] \
   && [ -f "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" ]; then
  installed_v="$(cat .strata/version 2>/dev/null | tr -d '[:space:]')"
  running_v="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" | head -1)"
  if [ -n "$installed_v" ] && [ -n "$running_v" ] && [ "$installed_v" != "$running_v" ]; then
    echo "Strata plugin is v${running_v}; installed hooks are v${installed_v} — run /strata:upgrade."
  fi
fi

if [ -f "$SCRIPT_DIR/../lib/pending_ingest.sh" ]; then
  # shellcheck source=../lib/pending_ingest.sh
  . "$SCRIPT_DIR/../lib/pending_ingest.sh"
  pending="$(strata_pending_paths || true)"
  n_pending="$(printf '%s' "$pending" | grep -c . || true)"
  if [ "${n_pending:-0}" -eq 0 ]; then
    echo "Pending ingest: none"
  else
    echo "Pending ingest: ${n_pending} file(s) — ingest each into wiki/ before finishing:"
    printf '%s\n' "$pending" | head -n "$MAX_PENDING_SHOWN" | sed 's/^/  - /'
    [ "$n_pending" -gt "$MAX_PENDING_SHOWN" ] \
      && echo "  … and $((n_pending - MAX_PENDING_SHOWN)) more (scripts/lib/pending_ingest.sh)"
  fi
fi

if [ -f "$LOG" ]; then
  echo "Last wiki log:"
  grep -v '^[[:space:]]*$' "$LOG" | tail -n 3 | cut -c1-150 | sed 's/^/  /'
fi

if [ -f "$INDEX" ]; then
  echo "Wiki index head:"
  # Table rows only — drop separator rows and the repeated column header, which
  # would otherwise spend the budget on the word "Page" three times.
  grep '^|' "$INDEX" \
    | grep -v '^|[[:space:]]*-\{2,\}' \
    | grep -v '^|[[:space:]]*Page[[:space:]]*|' \
    | head -n "$MAX_INDEX_ROWS" | cut -c1-150 | sed 's/^/  /'
fi

echo "Rule: answer project questions from wiki/index.md first — never grep-first."

exit 0
