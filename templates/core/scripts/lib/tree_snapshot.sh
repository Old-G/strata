#!/usr/bin/env bash
# Single source of truth for "which uncommitted code did THIS session change".
#
# Sourced by the SessionStart hook (writes the snapshot at session start into
# .strata/sessions/<id>.dirty) and the Stop gate (takes it again and compares
# for trigger (b)). Writer and reader must agree on the format, which is why it
# lives here once — same discipline as lib/pending_ingest.sh.
#
# Why: trigger (b) used to count `git diff HEAD` — the whole working tree. A
# session that started on top of someone's uncommitted work was billed for it
# (seen in P5: a fresh headless session blocked for a ~36k-line diff it never
# touched). Now a file is billed only if its content changed since the start
# snapshot — and a file that was already dirty is billed for the CHANGE in its
# diff size, not for the whole diff.
#
# Format: one "<blob-hash|deleted>\t<path>\t<changed-lines>" line per dirty file
# (tracked changes vs HEAD: numstat added+deleted; untracked, not ignored: line
# count), wiki/ raw/ docs/ excluded (trigger (b) never counts them). Paths are
# raw UTF-8 (core.quotePath=off). More than STRATA_SNAPSHOT_MAX (5000) dirty
# files → the single line "OVERFLOW": too much to judge cheaply, and (b) fails
# OPEN for that session rather than billing it for the whole tree.
# Linear throughout — one git call per kind, one awk pass (BSD grep -f is
# quadratic: 9 s at 5k lines, measured in the P5 review).

strata_tree_snapshot() {
  local max="${STRATA_SNAPSHOT_MAX:-5000}" tracked untracked n t_arr u_arr
  tracked="$(git -c core.quotePath=off diff HEAD --numstat 2>/dev/null \
    | awk -F'\t' '$3 !~ /^(wiki|raw|docs)\// {a=($1=="-")?0:$1; d=($2=="-")?0:$2; print $3 "\t" a+d}')"
  untracked="$(git -c core.quotePath=off ls-files --others --exclude-standard -- . \
    ':(exclude)wiki' ':(exclude)raw' ':(exclude)docs' 2>/dev/null)"
  [ -n "$tracked" ] || [ -n "$untracked" ] || return 0   # clean tree: the Stop gate's hot path
  # Count lines with builtins — no fork per count (the clean path has a 100 ms budget).
  t_arr=(); u_arr=()
  [ -n "$tracked" ] && IFS=$'\n' read -r -d '' -a t_arr <<< "$tracked"
  [ -n "$untracked" ] && IFS=$'\n' read -r -d '' -a u_arr <<< "$untracked"
  n=$(( ${#t_arr[@]} + ${#u_arr[@]} ))
  if [ "$n" -gt "$max" ]; then echo "OVERFLOW"; return 0; fi

  {
    # tracked: "<path>\t<n>" → hash each existing path (deleted → "deleted")
    [ -n "$tracked" ] && printf '%s\n' "$tracked" | while IFS=$'\t' read -r p c; do
      if [ -f "$p" ]; then printf 'T\t%s\t%s\n' "$p" "$c"; else printf 'D\t%s\t%s\n' "$p" "$c"; fi
    done
    # untracked: line counts in batches (wc prints "total" lines per batch — dropped)
    [ -n "$untracked" ] && printf '%s\n' "$untracked" | tr '\n' '\0' | xargs -0 wc -l 2>/dev/null \
      | awk '{c=$1; sub(/^[ \t]*[0-9]+ /, ""); if ($0 != "total") print "U\t" $0 "\t" c}'
  } > "${TMPDIR:-/tmp}/strata_snap.$$"

  # One git process for every hash of an existing file, in the same order.
  paste <(awk -F'\t' '$1 != "D" {print $2}' "${TMPDIR:-/tmp}/strata_snap.$$" | git hash-object --stdin-paths 2>/dev/null) \
        <(awk -F'\t' '$1 != "D" {print $2 "\t" $3}' "${TMPDIR:-/tmp}/strata_snap.$$")
  awk -F'\t' '$1 == "D" {print "deleted\t" $2 "\t" $3}' "${TMPDIR:-/tmp}/strata_snap.$$"
  rm -f "${TMPDIR:-/tmp}/strata_snap.$$"
  return 0
}

# Lines changed by THIS session, given the start snapshot <file>: a file whose
# (hash, path) is unchanged is skipped; a file that was already dirty is billed
# |now - start| of its diff size; a newly dirty file is billed in full.
strata_session_changed_lines() {
  local start="$1" now first=""
  [ -s "$start" ] && IFS= read -r first < "$start"
  [ "$first" = "OVERFLOW" ] && { echo 0; return 0; }
  now="$(strata_tree_snapshot)"
  [ -n "$now" ] || { echo 0; return 0; }
  [ "$now" = "OVERFLOW" ] && { echo 0; return 0; }
  printf '%s\n' "$now" | awk -F'\t' -v start="$start" '
    BEGIN { while ((getline l < start) > 0) { split(l, f, "\t"); seen[f[1] "\t" f[2]] = 1; was[f[2]] = f[3] } }
    NF >= 3 {
      if (($1 "\t" $2) in seen) next
      if ($2 in was) { d = $3 - was[$2]; total += (d < 0 ? -d : d) } else total += $3
    }
    END { print total + 0 }'
}
