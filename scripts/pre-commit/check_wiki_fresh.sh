#!/usr/bin/env bash
# Strata A2 — commit gate: block the commit while the wiki still owes an ingest.
#
# wiki/ is the layer the AI answers from. A commit that lands docs/ changes with
# no matching ingest ships stale knowledge, and nothing downstream will notice
# until someone asks the AI a question and gets last month's answer.
#
# This is the backstop that does NOT depend on Claude being in the loop: it
# catches manual commits, commits from another editor, and markers left over
# from earlier sessions — which the Stop gate deliberately ignores (ADR #4).
#
# Judged against the STAGED content of wiki/log.md, not the working tree: the
# question is what THIS COMMIT contains. Ingesting without staging wiki/ is
# exactly the mistake worth catching.
#
# Args are accepted and ignored (pre-commit passes staged paths; this gate is
# about the log as a whole, not about individual files).
#
# Bypass for a genuine WIP commit:  STRATA_SKIP_WIKI=1 git commit ...

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 0

if [[ "${STRATA_SKIP_WIKI:-0}" == "1" ]]; then
  echo "⚠️  STRATA_SKIP_WIKI=1 — wiki freshness gate skipped for this commit."
  exit 0
fi

LIB="$SCRIPT_DIR/../lib/pending_ingest.sh"
if [[ ! -f "$LIB" ]]; then
  # Nothing to enforce with. Fail open, but say so — a silent no-op gate is worse
  # than no gate, because it looks like protection.
  echo "⚠️  check_wiki_fresh: scripts/lib/pending_ingest.sh not found — gate inactive." >&2
  exit 0
fi
# shellcheck source=../lib/pending_ingest.sh
. "$LIB"

# Prefer the staged version of the log; fall back to the working tree when the
# file is untracked (first commit of a fresh wiki).
staged_log="$(mktemp)"
trap 'rm -f "$staged_log"' EXIT

if git rev-parse --verify -q :wiki/log.md >/dev/null 2>&1; then
  git show :wiki/log.md > "$staged_log" 2>/dev/null || : > "$staged_log"
elif [[ -f wiki/log.md ]]; then
  cp wiki/log.md "$staged_log"
else
  exit 0   # project does not use the knowledge layer
fi

pending="$(STRATA_WIKI_LOG="$staged_log" strata_pending_paths)"
n="$(printf '%s' "$pending" | grep -c . || true)"

if [[ "${n:-0}" -eq 0 ]]; then
  exit 0
fi

echo "❌ Wiki is behind: ${n} doc(s) mirrored into raw/ but never ingested."
echo "   wiki/ is what the AI answers from — this commit would ship stale knowledge."
echo
echo "Fix — ingest each, then re-stage wiki/ and commit again:"
while IFS= read -r doc; do
  [[ -z "$doc" ]] && continue
  echo "   /strata:wiki-ingest raw/${doc#docs/}"
done <<< "$pending"
echo "   git add wiki/"
echo
echo "Bypass (genuine WIP commit only): STRATA_SKIP_WIKI=1 git commit ..."
exit 1
