#!/usr/bin/env bash
# Single source of truth for "which docs still owe a wiki ingest".
#
# Sourced by the Stop gate (scripts/hooks/strata_stop_gate.sh), the commit gate
# (scripts/pre-commit/check_wiki_fresh.sh) and the mirror hook
# (scripts/sync_raw_mirror.sh). Never reimplement this rule per caller — the
# three gates disagreeing about what "pending" means is the failure this file
# exists to prevent.
#
# RETIREMENT RULE
#   A marker line   `- pending_ingest: docs/<p>.md (...)`   in wiki/log.md is
#   OUTSTANDING unless a LATER line in the same file mentions
#   `ingest raw/<p>.md` — i.e. the ingest that consumed it.
#   Pairing is by line order, so an edit → ingest → edit again cycle correctly
#   reopens the marker.
#
# CAVEAT: matching is textual. Only the canonical marker form (a list item at
# the start of a line) counts, so ordinary prose may mention the word without
# tripping the gates — but never write the literal `- pending_ingest: <path>`
# in a hand-authored log line unless you mean it.
#
# Usage:
#   source scripts/lib/pending_ingest.sh
#   strata_pending_ingest [MIN_LINE]      # only markers below line MIN_LINE
#   strata_pending_count  [MIN_LINE]
#   strata_pending_paths  [MIN_LINE]      # paths only, no line numbers
#
# Output: one `<lineno>\t<docs-path>` per outstanding marker, ascending.
# Exit code is always 0 — callers decide what to do about the result.
#
# Env:
#   STRATA_WIKI_LOG   override the log path (default: wiki/log.md). Used by tests.

# Resolve the log path relative to the repo root, not the caller's cwd.
strata_wiki_log() {
  if [ -n "${STRATA_WIKI_LOG:-}" ]; then
    printf '%s\n' "$STRATA_WIKI_LOG"
    return 0
  fi
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  printf '%s\n' "$root/wiki/log.md"
}

strata_pending_ingest() {
  local min_line="${1:-0}"
  local log
  log="$(strata_wiki_log)"
  [ -f "$log" ] || return 0

  awk -v min_line="$min_line" '
    # docs/a/b.md -> raw/a/b.md
    function raw_of(p) { sub(/^docs\//, "", p); return "raw/" p }

    # Canonical marker: a list item at the start of the line.
    /^[[:space:]]*-[[:space:]]+pending_ingest:[[:space:]]*[^[:space:]]/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]+pending_ingest:[[:space:]]*/, "", line)
      sub(/[[:space:]].*$/, "", line)          # drop the "(mirrored ...)" tail
      if (line != "") marker[line] = NR        # keep the LAST marker per path
    }

    # Retirement: any mention of `ingest raw/<path>`, anywhere in the line.
    # An ingest clause may list several raw/ paths at once — "ingest raw/A,
    # raw/B -> created: ..." — so after the first hit, keep consuming
    # comma-separated raw/ continuations too, or only the first path of a
    # multi-file ingest ever retires (every later path silently reports as
    # permanent backlog forever). Found via a real 338KB log: 325 markers
    # looked outstanding; the true count was near zero.
    {
      tail = $0
      while (match(tail, /ingest[[:space:]]+raw\/[^[:space:];,)]+/)) {
        hit = substr(tail, RSTART, RLENGTH)
        sub(/^ingest[[:space:]]+/, "", hit)
        ingested[hit] = NR                     # keep the LAST ingest per path
        tail = substr(tail, RSTART + RLENGTH)
        while (match(tail, /^[[:space:]]*,[[:space:]]*raw\/[^[:space:];,)]+/)) {
          hit2 = substr(tail, RSTART, RLENGTH)
          sub(/^[[:space:]]*,[[:space:]]*/, "", hit2)
          ingested[hit2] = NR
          tail = substr(tail, RSTART + RLENGTH)
        }
      }
    }

    END {
      for (p in marker) {
        r = raw_of(p)
        if (!(r in ingested) || ingested[r] < marker[p]) {
          if (marker[p] > min_line) printf "%d\t%s\n", marker[p], p
        }
      }
    }
  ' "$log" | sort -n
}

strata_pending_paths() {
  strata_pending_ingest "${1:-0}" | cut -f2
}

strata_pending_count() {
  strata_pending_ingest "${1:-0}" | grep -c . || true
}

# Standalone mode: `bash scripts/lib/pending_ingest.sh [MIN_LINE]`.
# BASH_SOURCE[0] == $0 only when this file was executed, not sourced.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  strata_pending_ingest "${1:-0}"
fi
