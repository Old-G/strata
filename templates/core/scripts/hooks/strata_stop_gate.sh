#!/usr/bin/env bash
# Strata A1 — Stop gate: refuse to end the turn ONCE while this session still
# owes wiki work.
#
# This is the net for ad-hoc work done outside /strata:feature — the case where
# advisory prose fails, because the model is deep in a long session and the skill
# text it read an hour ago is long gone.
#
# LOOP SAFETY IS THE DESIGN, NOT A FOOTNOTE. In order:
#   1. stop_hook_active true            -> exit 0 immediately (we are already the
#                                          reason the model was resumed).
#   2. no session stamp                 -> exit 0 (SessionStart hook not installed,
#                                          or session predates it; a gate that
#                                          cannot see the session boundary must not
#                                          guess — ADR #4).
#   3. already blocked this session     -> exit 0. Hard cap: ONE forced
#                                          continuation per session, ever.
# A gate that fires forever is worse than no gate.
#
# TRIGGERS (either one blocks):
#   a) pending_ingest markers created AFTER this session started (ADR #4 — older
#      markers are the commit gate's job, not an interruption you did not earn).
#   b) substantive code-only change with nothing written to wiki/log.md this
#      session. Threshold: STRATA_STOP_GATE_LINES changed lines outside
#      wiki/ raw/ docs/ (default 50; set 0 to disable this trigger).
#      Always satisfiable in one line — including an explicit "no-wiki-impact:".
#
# Install: Stop hook in the project's .claude/settings.json. Requires the
# SessionStart hook to be installed too, or it is inert by design.
#
# PERFORMANCE: the clean-state path must stay under 100 ms, so the payload is
# parsed with grep/sed rather than python3 (measured: ~36 ms of interpreter
# startup we cannot afford on every turn). The fields read here are flat scalars
# in a machine-generated payload.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 0

LINES_THRESHOLD="${STRATA_STOP_GATE_LINES:-50}"

payload=""
if [ ! -t 0 ]; then payload="$(cat 2>/dev/null || true)"; fi

# --- 1. never fight ourselves ------------------------------------------------
printf '%s' "$payload" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0

# --- 2. session boundary or nothing ------------------------------------------
session_id="$(printf '%s' "$payload" \
  | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
session_id="$(printf '%s' "$session_id" | tr -cd 'A-Za-z0-9._-')"
[ -n "$session_id" ] || exit 0

STAMP=".strata/sessions/${session_id}.start"
BLOCKED=".strata/sessions/${session_id}.blocked"
[ -f "$STAMP" ] || exit 0

# --- 3. one forced continuation per session, hard ----------------------------
[ -e "$BLOCKED" ] && exit 0

start_log_lines=0
while IFS='=' read -r k v; do
  [ "$k" = "LOG_LINES" ] && start_log_lines="$v"
done < "$STAMP"
case "$start_log_lines" in (*[!0-9]*|'') start_log_lines=0 ;; esac

LIB="$SCRIPT_DIR/../lib/pending_ingest.sh"
[ -f "$LIB" ] || exit 0
# shellcheck source=../lib/pending_ingest.sh
. "$LIB"

# JSON-safe: these strings are interpolated into the reason field.
sanitize() { printf '%s' "$1" | tr -d '"\\' | tr '\n' ' '; }

reason=""

# --- trigger (a): markers this session created -------------------------------
pending="$(strata_pending_paths "$start_log_lines")"
n_pending="$(printf '%s' "$pending" | grep -c . || true)"

if [ "${n_pending:-0}" -gt 0 ]; then
  reason="Pending wiki work from THIS session: ${n_pending} doc(s) mirrored into raw/ but never ingested.\n"
  while IFS= read -r doc; do
    [ -z "$doc" ] && continue
    reason="${reason}  - raw/$(sanitize "${doc#docs/}")\n"
  done <<< "$pending"
  reason="${reason}\nBefore stopping: run /strata:wiki-ingest on each file above, update wiki/index.md, and append a session line to wiki/log.md."
fi

# --- trigger (b): substantive code change, wiki silent -----------------------
if [ -z "$reason" ] && [ "$LINES_THRESHOLD" -gt 0 ]; then
  log_lines_now=0
  [ -f wiki/log.md ] && log_lines_now="$(wc -l < wiki/log.md | tr -d ' ')"

  if [ "$log_lines_now" -le "$start_log_lines" ]; then
    changed="$(git diff HEAD --numstat -- . ':(exclude)wiki' ':(exclude)raw' ':(exclude)docs' 2>/dev/null \
      | awk '{a=($1=="-")?0:$1; d=($2=="-")?0:$2; s+=a+d} END {print s+0}')"
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      case "$f" in wiki/*|raw/*|docs/*) continue ;; esac
      [ -f "$f" ] && changed=$(( changed + $(wc -l < "$f" | tr -d ' ') ))
    done < <(git ls-files --others --exclude-standard 2>/dev/null)

    if [ "${changed:-0}" -ge "$LINES_THRESHOLD" ]; then
      reason="This session changed ~${changed} lines of code and wrote nothing to the wiki.\n"
      reason="${reason}Code-only changes leave no knowledge trace — that is how the wiki goes stale.\n\n"
      reason="${reason}Append ONE line to wiki/log.md before stopping: either a summary of what changed and why,\n"
      reason="${reason}or, if this genuinely has no knowledge impact, 'no-wiki-impact: <reason>'.\n"
      reason="${reason}Update affected wiki/entities/ pages if the change altered how something works."
    fi
  fi
fi

[ -z "$reason" ] && exit 0

# --- block, exactly once -----------------------------------------------------
mkdir -p .strata/sessions 2>/dev/null || true
: > "$BLOCKED" 2>/dev/null || true

printf '{"decision":"block","reason":"%s"}\n' "$reason"
exit 0
