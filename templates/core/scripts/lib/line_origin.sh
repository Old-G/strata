#!/usr/bin/env bash
# line_origin.sh — did this branch write these lines, or were they there before it?
# strata-diff-review labels a finding Pre-existing from this, never from a guess.
#
# Usage: line_origin.sh <base> <file>:<line>[-<end>] ...
#   <base>  the branch's merge-base with the default branch; <file> is repo-relative.
# One line per location:
#   PRE-EXISTING <loc> <sha>  every line was last changed by a commit already in <base>
#   BRANCH       <loc> <sha>  a line was last changed by a commit after <base>
#   UNCOMMITTED  <loc>        a line is changed in the working tree
#   UNKNOWN      <loc>        untracked, no such line, or not a line number
# Plain blame, no -M/-C/-w: a moved, copied or reindented line counts as the branch's.
# A false "branch" costs the author one look; a false "pre-existing" hides a bug the
# branch wrote. Treat UNKNOWN as not pre-existing.
# Exit: 0 every location printed · 1 usage error or <base> is not a commit.

set -u
if [ $# -lt 2 ]; then
  sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 1
fi
base="$1"; shift
top="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "line_origin.sh: not in a git repo" >&2; exit 1; }
cd "$top" || exit 1
git rev-parse -q --verify "${base}^{commit}" >/dev/null || { echo "line_origin.sh: not a commit: $base" >&2; exit 1; }

zero=0000000000000000000000000000000000000000
for loc in "$@"; do
  file="${loc%:*}"; range="${loc##*:}"
  start="${range%%-*}"; end="${range#*-}"
  if [ -z "$file" ] || [ "$file" = "$loc" ]; then echo "UNKNOWN $loc"; continue; fi
  case "$start" in ''|*[!0-9]*) echo "UNKNOWN $loc"; continue ;; esac
  case "$end" in ''|*[!0-9]*) echo "UNKNOWN $loc"; continue ;; esac
  # Header lines of --porcelain start with the 40-hex sha; content lines start with a tab.
  shas="$(git blame --porcelain -L "$start,$end" -- "$file" 2>/dev/null \
    | awk '/^[0-9a-f]/ && length($1) == 40 && !seen[$1]++ { print $1 }')"
  if [ -z "$shas" ]; then echo "UNKNOWN $loc"; continue; fi
  verdict=""; who=""
  for sha in $shas; do
    if [ "$sha" = "$zero" ]; then verdict="UNCOMMITTED"; who=""; break; fi
    if ! git merge-base --is-ancestor "$sha" "$base" 2>/dev/null; then
      [ -n "$verdict" ] || { verdict="BRANCH"; who="$sha"; }
    fi
    [ -n "$who" ] || who="$sha"
  done
  [ -n "$verdict" ] || verdict="PRE-EXISTING"
  echo "$verdict $loc${who:+ $who}"
done
exit 0
