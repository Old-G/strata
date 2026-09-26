#!/usr/bin/env bash
# Single source of truth for "which uncommitted files did THIS session touch".
#
# Sourced by the SessionStart hook (writes the snapshot at session start into
# .strata/sessions/<id>.dirty) and the Stop gate (takes it again and diffs the
# two for trigger (b)). Writer and reader must agree on the format, which is
# why it lives here once — same discipline as lib/pending_ingest.sh.
#
# Why: trigger (b) used to count `git diff HEAD` — the whole working tree. A
# session that started on top of someone's uncommitted work was billed for it
# (seen in P5: a fresh headless session blocked for a ~36k-line diff it never
# touched). A file counts as this session's change only if it is dirty now AND
# its (path, content hash) was not already in the start snapshot.
#
# Format: one "<blob-hash-or-deleted>\t<path>" line per dirty file (tracked
# changes vs HEAD + untracked, not ignored), sorted, wiki/ raw/ docs/ excluded
# (trigger (b) never counts them). Exit 0 always; prints nothing outside a repo.

strata_tree_snapshot() {
  local list existing
  list="$({ git diff HEAD --name-only 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } \
    | grep -v -e '^wiki/' -e '^raw/' -e '^docs/' | sort -u)"
  [ -n "$list" ] || return 0
  existing="$(printf '%s\n' "$list" | while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done)"
  if [ -n "$existing" ]; then
    # One git process for every hash; paste pairs them back line by line.
    paste <(printf '%s\n' "$existing" | git hash-object --stdin-paths 2>/dev/null) <(printf '%s\n' "$existing")
  fi
  printf '%s\n' "$list" | while IFS= read -r f; do [ -f "$f" ] || printf 'deleted\t%s\n' "$f"; done
  return 0
}

# Lines changed by THIS session: files in the current snapshot whose line is not
# in the start snapshot <file>. Tracked → numstat added+deleted; untracked → wc -l.
strata_session_changed_lines() {
  local start="$1" total=0 p n
  while IFS=$'\t' read -r _ p; do
    [ -n "$p" ] || continue
    if git ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
      n="$(git diff HEAD --numstat -- "$p" 2>/dev/null | awk '{a=($1=="-")?0:$1; d=($2=="-")?0:$2; s+=a+d} END {print s+0}')"
    else
      n="$(wc -l < "$p" 2>/dev/null | tr -d ' ')"
    fi
    total=$(( total + ${n:-0} ))
  done < <(strata_tree_snapshot | grep -vxF -f "$start" 2>/dev/null)
  printf '%s\n' "$total"
}
