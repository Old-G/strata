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
# TRIGGERS (any one blocks):
#   a) pending_ingest markers created AFTER this session started (ADR #4 — older
#      markers are the commit gate's job, not an interruption you did not earn).
#   b) substantive code-only change with nothing written to wiki/log.md this
#      session. Threshold: STRATA_STOP_GATE_LINES changed lines outside
#      wiki/ raw/ docs/ (default 50; set 0 to disable this trigger).
#      Always satisfiable in one line — including an explicit "no-wiki-impact:".
#   c) the current branch's .strata/state/<slug>.json (see lib/state_tools.py —
#      P2, docs/superpowers/specs/2026-09-01-episodic-state-layer.md) has a
#      non-empty wiki_debt array, or exists but fails schema validation. A
#      MISSING state file is not a trigger — the layer stays adoptable
#      incrementally, same as (a) and (b) on a project with no wiki/ at all.
#   d) friction (P4, docs/superpowers/specs/2026-09-12-p4-field-patterns.md D1):
#      this session's transcript (transcript_path in the payload) shows the
#      session HURT — user interrupts, denied tool calls, tool errors at or past
#      their thresholds — and nothing was recorded since the session started
#      (wiki/log.md unchanged, branch state not touched). The sessions worth a
#      lesson are the painful ones; the lesson is one gotchas entry or one
#      'gotcha:' / 'no-gotcha:' line in wiki/log.md. Thresholds via env:
#      STRATA_FRICTION_INTERRUPTS (1) · STRATA_FRICTION_DENIALS (2) ·
#      STRATA_FRICTION_ERRORS (8); 0 disables a signal, all three 0 disables
#      the trigger. Fires only when (a)-(c) did not; when one of them fires and
#      friction is present too, the counts ride along in that reason. Fails
#      open on a missing or unreadable transcript. Only fires where there is
#      somewhere to record (wiki/log.md or a branch state file exists).
#
# Install: Stop hook in the project's .claude/settings.json. Requires the
# SessionStart hook to be installed too, or it is inert by design.
#
# PERFORMANCE: the clean-state path must stay under 100 ms, so the payload is
# parsed with grep/sed rather than python3 (measured: ~36 ms of interpreter
# startup we cannot afford on every turn). The fields read here are flat scalars
# in a machine-generated payload. The friction pass (d) runs LAST: one grep pass
# over the transcript selects candidate lines, the counts run over those — no awk,
# no python; skipped entirely when the payload carries no transcript_path.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 0

LINES_THRESHOLD="${STRATA_STOP_GATE_LINES:-50}"

# Friction thresholds (trigger d). Non-numeric values fall back to the default.
num_or() { case "$1" in (''|*[!0-9]*) printf '%s' "$2" ;; (*) printf '%s' "$1" ;; esac; }
F_INT="$(num_or "${STRATA_FRICTION_INTERRUPTS:-1}" 1)"
F_DEN="$(num_or "${STRATA_FRICTION_DENIALS:-2}" 2)"
F_ERR="$(num_or "${STRATA_FRICTION_ERRORS:-8}" 8)"
# Default kept in its own assignment: bash 3.2 (macOS /bin/bash) mis-parses a
# quote character inside "${var:-default}".
F_DENY_DEFAULT="doesn't want to proceed"
F_DENY_RE="${STRATA_FRICTION_DENY_RE:-$F_DENY_DEFAULT}"

payload=""
if [ ! -t 0 ]; then payload="$(cat 2>/dev/null || true)"; fi

# --- 1. never fight ourselves ------------------------------------------------
printf '%s' "$payload" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0

# --- 2. session boundary or nothing ------------------------------------------
session_id="$(printf '%s' "$payload" \
  | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
session_id="$(printf '%s' "$session_id" | tr -cd 'A-Za-z0-9._-')"
[ -n "$session_id" ] || exit 0

transcript_path="$(printf '%s' "$payload" \
  | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"

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

log_lines_now=0
[ -f wiki/log.md ] && log_lines_now="$(wc -l < wiki/log.md | tr -d ' ')"

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

# --- trigger (c): branch state owes the wiki, or is corrupt -------------------
# python3 only runs when a state file actually exists — the clean-state (no
# file) path stays a single [ -f ] check, so projects that never adopted the
# state layer pay nothing here.
state_path=""
if [ -z "$reason" ]; then
  branch_now="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  STATE_TOOLS="$SCRIPT_DIR/../lib/state_tools.py"
  if [ -n "$branch_now" ] && [ "$branch_now" != "HEAD" ] && [ -f "$STATE_TOOLS" ]; then
    state_path="$(python3 "$STATE_TOOLS" path "$branch_now" 2>/dev/null)"
    if [ -n "$state_path" ] && [ -f "$state_path" ]; then
      if ! v_out="$(python3 "$STATE_TOOLS" validate "$state_path" 2>&1)"; then
        reason="Branch state file is invalid: ${state_path}\n$(sanitize "$v_out")\n\n"
        reason="${reason}Fix it (or re-init with state_tools.py init) before stopping."
      else
        debt="$(python3 "$STATE_TOOLS" debt "$state_path" 2>/dev/null)"
        n_debt="$(printf '%s' "$debt" | grep -c . || true)"
        if [ "${n_debt:-0}" -gt 0 ]; then
          reason="Branch state still owes the wiki (${n_debt} item(s) in wiki_debt):\n"
          while IFS= read -r item; do
            [ -z "$item" ] && continue
            reason="${reason}  - $(sanitize "$item")\n"
          done <<< "$debt"
          reason="${reason}\nEither fold these into wiki/log.md now, or clear wiki_debt in ${state_path}\n"
          reason="${reason}once each item genuinely reached the wiki."
        fi
      fi
    fi
  fi
fi

# --- trigger (d): the session hurt and nobody wrote the lesson down -----------
# Three fixed-string grep pipelines over this session's own transcript; subagent
# sidechains are dropped. A denial is an is_error tool_result too, so it is
# subtracted from the error count rather than counted twice.
if [ -n "$transcript_path" ] && [ -r "$transcript_path" ] \
   && ! { [ "$F_INT" -eq 0 ] && [ "$F_DEN" -eq 0 ] && [ "$F_ERR" -eq 0 ]; }; then
  # One pass over the transcript selects the few candidate lines; the counts run
  # over that small set. LC_ALL=C: byte-wise matching — BSD grep in a UTF-8 locale
  # is several times slower on a multi-megabyte file.
  # A denial arrives as an is_error tool_result, so two fixed strings select
  # every candidate; the deny regex only ever runs over that small set.
  cand="$(LC_ALL=C grep -F -e '[Request interrupted by user' -e '"is_error":true' \
            "$transcript_path" 2>/dev/null | LC_ALL=C grep -vF '"isSidechain":true' || true)"
  n_int="$(printf '%s\n' "$cand" | LC_ALL=C grep -F '"type":"user"' | LC_ALL=C grep -cF '[Request interrupted by user' || true)"
  n_den="$(printf '%s\n' "$cand" | LC_ALL=C grep -cE "$F_DENY_RE" || true)"
  n_err="$(printf '%s\n' "$cand" | LC_ALL=C grep -F '"is_error":true' | LC_ALL=C grep -vE "$F_DENY_RE" | LC_ALL=C grep -c . || true)"
  n_int="$(num_or "$n_int" 0)"; n_den="$(num_or "$n_den" 0)"; n_err="$(num_or "$n_err" 0)"

  met=0
  [ "$F_INT" -gt 0 ] && [ "$n_int" -ge "$F_INT" ] && met=1
  [ "$F_DEN" -gt 0 ] && [ "$n_den" -ge "$F_DEN" ] && met=1
  [ "$F_ERR" -gt 0 ] && [ "$n_err" -ge "$F_ERR" ] && met=1

  if [ "$met" -eq 1 ]; then
    counts="This session had ${n_int} interrupt(s), ${n_den} denied tool call(s), ${n_err} tool error(s)."
    if [ -n "$reason" ]; then
      reason="${reason}\n\nAlso: ${counts} Record the gotcha too — a gotchas entry in the branch state, or one 'gotcha: <what>' line in wiki/log.md."
    else
      recordable=0
      [ -f wiki/log.md ] && recordable=1
      [ -n "$state_path" ] && [ -f "$state_path" ] && recordable=1
      recorded=0
      [ "$log_lines_now" -gt "$start_log_lines" ] && recorded=1
      if [ -n "$state_path" ] && [ -f "$state_path" ] \
         && [ -n "$(find "$state_path" -newer "$STAMP" -print 2>/dev/null)" ]; then recorded=1; fi
      if [ "$recordable" -eq 1 ] && [ "$recorded" -eq 0 ]; then
        reason="${counts}\n"
        reason="${reason}A session that hurt is a session with a lesson in it. Before stopping, record it ONCE:\n"
        reason="${reason}  - add a gotchas entry to $(sanitize "${state_path:-.strata/state/<branch>.json}") (if this branch keeps a state file), or\n"
        reason="${reason}  - append one line to wiki/log.md: 'gotcha: <what went wrong, what to do instead>' or 'no-gotcha: <why there is nothing to record>'.\n"
        reason="${reason}Thresholds: STRATA_FRICTION_INTERRUPTS / _DENIALS / _ERRORS (0 disables)."
      fi
    fi
  fi
fi

[ -z "$reason" ] && exit 0

# --- block, exactly once -----------------------------------------------------
mkdir -p .strata/sessions 2>/dev/null || true
: > "$BLOCKED" 2>/dev/null || true

printf '{"decision":"block","reason":"%s"}\n' "$reason"
exit 0
