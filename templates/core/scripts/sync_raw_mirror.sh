#!/usr/bin/env bash
# Mirror docs/*.md -> raw/*.md and append a pending_ingest marker to wiki/log.md.
#
# Two modes:
#   1. PostToolUse hook from Claude Code: gets file path via $CLAUDE_FILE or
#      reads JSON event from stdin and extracts tool_input.file_path.
#   2. Manual / pre-commit: takes file paths as positional args.
#
# Exit 0 always when invoked as a hook (we don't want to block Claude on
# mirror failure — pre-commit catches the same drift later).

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 0

LOG="wiki/log.md"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

mirror_one() {
  local src="$1"
  [[ -z "$src" ]] && return 0

  # Normalize: strip leading ./ and absolute repo prefix.
  # Quote the patterns so paths with glob metacharacters ([ * ?) are matched
  # literally, not as globs (CSO review finding #3).
  src="${src#"./"}"
  src="${src#"$REPO_ROOT"/}"

  # Only mirror docs/*.md.
  case "$src" in
    docs/*.md) ;;
    *) return 0 ;;
  esac

  [[ -f "$src" ]] || return 0

  local dst="raw/${src#docs/}"
  mkdir -p "$(dirname "$dst")"
  cp -p "$src" "$dst"

  # Append pending_ingest marker if not already present for this file today.
  local marker="pending_ingest: $src"
  if [[ -f "$LOG" ]] && ! grep -qF "$marker" "$LOG"; then
    {
      echo ""
      echo "## $TS auto-mirror"
      echo ""
      echo "- $marker (mirrored docs/ -> raw/, ingest still owed)"
    } >> "$LOG"
  fi

  echo "📚 wiki: mirrored $src -> $dst (ingest still owed)" >&2
}

if [[ $# -gt 0 ]]; then
  # CLI mode: explicit file list.
  for f in "$@"; do mirror_one "$f"; done
  exit 0
fi

# Hook mode: read JSON from stdin (Claude Code PostToolUse payload).
if [[ ! -t 0 ]]; then
  payload="$(cat)"
  # Extract tool_input.file_path with python (robust, jq not guaranteed).
  fp="$(python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    tool = d.get('tool_name', '')
    if tool in ('Edit', 'Write', 'MultiEdit', 'NotebookEdit'):
        ti = d.get('tool_input', {}) or {}
        print(ti.get('file_path', ''))
except Exception:
    pass
" "$payload" 2>/dev/null)"
  mirror_one "$fp"
fi

exit 0
