#!/usr/bin/env bash
# Strata A2b — push gate: refuse a push whose commits change code but never touch
# wiki/log.md.
#
# The Stop gate (A1) only sees sessions run through Claude Code, and the commit
# gate (A2) only fires on docs/ changes. Code committed from another agent, an
# editor or by hand reaches the remote with no knowledge trace at all. The push
# is the last point every one of those paths crosses.
#
# Judged per pushed branch, over the commits the remote does not have yet:
# changed lines outside wiki/ raw/ docs/ (no merges) against
# STRATA_PUSH_GATE_LINES (default 20; 0 disables). Any of those commits touching
# wiki/log.md satisfies it — one line, including "no-wiki-impact: <reason>".
# Tags and branch deletions pass. A repo without wiki/log.md passes.
#
# Wiring: git's pre-push hook (stdin "<local ref> <local sha> <remote ref>
# <remote sha>" lines, $1 = remote name), or the pre-commit framework's
# pre-push stage (PRE_COMMIT_FROM_REF / PRE_COMMIT_TO_REF / PRE_COMMIT_REMOTE_NAME).
#
# Bypass for one push:  STRATA_SKIP_WIKI=1 git push ...   (or git push --no-verify)

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 0

if [[ "${STRATA_SKIP_WIKI:-0}" == "1" ]]; then
  echo "⚠️  STRATA_SKIP_WIKI=1 — wiki push gate skipped for this push."
  exit 0
fi

[ -f wiki/log.md ] || exit 0

threshold="${STRATA_PUSH_GATE_LINES:-20}"
case "$threshold" in (''|*[!0-9]*) threshold=20 ;; esac
[ "$threshold" -gt 0 ] || exit 0

remote="${PRE_COMMIT_REMOTE_NAME:-${1:-origin}}"
zero_sha() { case "$1" in (*[!0]*) return 1 ;; esac; return 0; }

fail=0

# $1 = label, rest = rev-list arguments naming the commits being pushed.
check_range() {
  local label="$1"; shift
  local code logged
  code="$(git log --no-merges --format= --numstat "$@" -- . \
      ':(exclude)wiki' ':(exclude)raw' ':(exclude)docs' 2>/dev/null \
    | awk -F'\t' 'NF >= 3 { a = ($1 == "-") ? 0 : $1; d = ($2 == "-") ? 0 : $2; s += a + d } END { print s + 0 }')"
  case "$code" in (''|*[!0-9]*) code=0 ;; esac
  [ "$code" -ge "$threshold" ] || return 0
  logged="$(git log --format=%H -1 "$@" -- wiki/log.md 2>/dev/null)"
  [ -z "$logged" ] || return 0
  echo "❌ Wiki push gate: ${label} carries ~${code} lines of code and none of its commits touch wiki/log.md."
  fail=1
}

# A remote sha we do not have locally (not fetched) cannot bound a range: fall back
# to "everything not on any ref of this remote".
range_args() {
  local from="$1" to="$2"
  if [ -n "$from" ] && ! zero_sha "$from" && git cat-file -e "${from}^{commit}" 2>/dev/null; then
    printf '%s\n' "${from}..${to}"
  else
    printf '%s\n' "$to" "--not" "--remotes=${remote}"
  fi
}

run_range() {
  local label="$1" from="$2" to="$3" args=()
  while IFS= read -r a; do args+=("$a"); done < <(range_args "$from" "$to")
  check_range "$label" "${args[@]}"
}

if [ -n "${PRE_COMMIT_TO_REF:-}" ]; then
  run_range "this push" "${PRE_COMMIT_FROM_REF:-}" "$PRE_COMMIT_TO_REF"
else
  while read -r local_ref local_sha remote_ref remote_sha; do
    [ -n "${local_sha:-}" ] || continue
    zero_sha "$local_sha" && continue                 # branch deletion
    case "$remote_ref" in (refs/heads/*) ;; (*) continue ;; esac   # tags etc.
    run_range "${remote_ref#refs/heads/}" "$remote_sha" "$local_sha"
  done
fi

if [ "$fail" -ne 0 ]; then
  echo
  echo "Code went out without a knowledge trace — that is how the wiki goes stale."
  echo "Append ONE line to wiki/log.md (what changed and why, or 'no-wiki-impact: <reason>'),"
  echo "commit it, then push again. One-off bypass: STRATA_SKIP_WIKI=1 git push"
fi
exit "$fail"
