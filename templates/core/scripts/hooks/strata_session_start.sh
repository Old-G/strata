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
# v0.9.0 — AUTO-SYNC: when the Strata plugin on this machine is newer than
# .strata/version, re-sync scripts/** from the plugin's templates BEFORE anything
# else runs, with strata_upgrade_check.sh --apply-safe: only files whose copy
# cannot lose a local line (missing, or byte-identical to a version the plugin
# once shipped). A locally edited file is left alone and named — that one is
# /strata:upgrade's. The version is stamped only when nothing is left over, so
# the next session tries again. The changes are ordinary uncommitted files, said
# out loud in this context — commit them like any other change.
# Escape: STRATA_NO_AUTOSYNC=1. Plugin location: $CLAUDE_PLUGIN_ROOT when set,
# else Claude Code's own registry (plugins/installed_plugins.json — the entry
# for this project, else the user-scope one).
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

# --- plugin auto-sync (v0.9.0) -----------------------------------------------
strata_plugin_root() {
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" ]; then
    printf '%s\n' "$CLAUDE_PLUGIN_ROOT"; return
  fi
  python3 -c '
import json, os, sys
root, reg = sys.argv[1], sys.argv[2]
try:
    plugins = json.load(open(reg))["plugins"]
except Exception:
    sys.exit(0)
user = None
for key, entries in plugins.items():
    if key.split("@")[0] != "strata":
        continue
    for e in entries:
        p = e.get("installPath") or ""
        if not os.path.isfile(os.path.join(p, ".claude-plugin", "plugin.json")):
            continue
        if e.get("scope") in ("local", "project") and e.get("projectPath") == root:
            print(p); sys.exit(0)
        if e.get("scope") == "user" and user is None:
            user = p
if user:
    print(user)
' "$REPO_ROOT" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json" 2>/dev/null
}
plugin_version() { sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1/.claude-plugin/plugin.json" 2>/dev/null | head -1; }

# a > b as release versions: numeric parts, and a prerelease (-rc1) sorts BELOW its
# release — `sort -V` gets that backwards (0.9.0-rc1 > 0.9.0 on macOS).
strata_version_gt() {
  python3 -c '
import re, sys
def key(v):
    m = re.match(r"\s*v?(\d+(?:\.\d+)*)(?:-(\S+))?\s*$", v)
    if not m:
        return None
    return (tuple(int(x) for x in m.group(1).split(".")), 0 if m.group(2) else 1, m.group(2) or "")
a, b = key(sys.argv[1]), key(sys.argv[2])
sys.exit(0 if a is not None and b is not None and a > b else 1)
' "$1" "$2" 2>/dev/null
}

# A linked worktree is another branch's checkout: it gets the scripts when that
# branch merges (same rule as bin/strata-upgrade-all).
in_linked_worktree() {
  [ "$(git rev-parse --path-format=absolute --git-dir 2>/dev/null)" != "$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" ]
}

autosync_msg=""
PLUGIN_ROOT=""
if [ -f .strata/version ] && [ -d scripts ]; then
  PLUGIN_ROOT="$(strata_plugin_root)"
fi
if [ -n "$PLUGIN_ROOT" ] && [ "${STRATA_NO_AUTOSYNC:-}" != "1" ] && ! in_linked_worktree; then
  have_v="$(tr -d '[:space:]' < .strata/version 2>/dev/null)"
  plug_v="$(plugin_version "$PLUGIN_ROOT")"
  tpl="$PLUGIN_ROOT/templates/core/scripts"
  if [ -n "$have_v" ] && [ -n "$plug_v" ] && [ -f "$tpl/strata_upgrade_check.sh" ] \
     && strata_version_gt "$plug_v" "$have_v"; then
    sync_out="$(bash "$tpl/strata_upgrade_check.sh" --apply-safe "$tpl" scripts 2>/dev/null)"; sync_rc=$?
    n_synced="$(printf '%s\n' "$sync_out" | grep -c '^SYNCED' || true)"
    left="$(printf '%s\n' "$sync_out" | grep -E '^(CONFLICT|MISSING|STALE) ' | awk '{print $2}' | tr '\n' ' ')"
    if [ "$sync_rc" -eq 0 ]; then
      printf '%s\n' "$plug_v" > .strata/version
      autosync_msg="Strata auto-synced hooks ${have_v} → ${plug_v}: ${n_synced} file(s) under scripts/ (uncommitted — commit them)."
    else
      autosync_msg="Strata ${plug_v} auto-synced ${n_synced} file(s); edited locally, not touched: ${left}— merge those via /strata:upgrade (version stays ${have_v} until then)."
    fi
  fi
fi

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

# Snapshot of the uncommitted files that were ALREADY dirty when this session
# began, so the Stop gate's trigger (b) bills a session only for its own code
# (lib/tree_snapshot.sh — one format for writer and reader).
if [ -f "$SCRIPT_DIR/../lib/tree_snapshot.sh" ]; then
  # shellcheck source=../lib/tree_snapshot.sh
  . "$SCRIPT_DIR/../lib/tree_snapshot.sh"
  strata_tree_snapshot > ".strata/sessions/${session_id}.dirty" 2>/dev/null || true
fi

# Keep the directory from growing forever.
find .strata/sessions -type f -mtime +7 -delete 2>/dev/null || true

# --- context block -----------------------------------------------------------
# Nothing to say in a project that does not use the knowledge layer.
if [ ! -f "$INDEX" ] && [ ! -f "$LOG" ]; then
  [ -n "$autosync_msg" ] && echo "$autosync_msg"
  exit 0
fi

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")"
dirty="$(git status --porcelain 2>/dev/null | grep -c . || true)"

echo "## Strata context"
echo "Branch: ${branch} · uncommitted files: ${dirty:-0}"
[ -n "$autosync_msg" ] && echo "$autosync_msg"

# --- branch state summary (P2) -----------------------------------------------
STATE_TOOLS="$SCRIPT_DIR/../lib/state_tools.py"
if [ -f "$STATE_TOOLS" ] && [ "$branch" != "?" ]; then
  state_path="$(python3 "$STATE_TOOLS" path "$branch" 2>/dev/null)"
  [ -n "$state_path" ] && [ -f "$state_path" ] && python3 "$STATE_TOOLS" summary "$state_path" 2>/dev/null
fi

# --- plugin version nudge (P2) ------------------------------------------------
if [ -f .strata/version ] && [ -n "$PLUGIN_ROOT" ]; then
  installed_v="$(cat .strata/version 2>/dev/null | tr -d '[:space:]')"
  running_v="$(plugin_version "$PLUGIN_ROOT")"
  if [ -n "$installed_v" ] && [ -n "$running_v" ] && strata_version_gt "$running_v" "$installed_v"; then
    echo "Strata plugin is v${running_v}; installed hooks are v${installed_v} — run /strata:upgrade."
  fi
fi

# --- stale test-file guard (P3 / A5) -------------------------------------------
# feature/refactor set this toggle at "make the failing test pass" and clear it
# once green. If it survives into a new session, every test file is read-only
# for reasons nobody remembers — say so once, up front.
if [ -e .strata/guard-tests ]; then
  echo "Stale test-file guard: .strata/guard-tests is set — a previous fix session did not clear it; remove it or tests stay read-only."
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
