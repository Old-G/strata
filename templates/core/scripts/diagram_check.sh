#!/usr/bin/env bash
# Strata P4 — diagram_check.sh: does a diagram in wiki/diagrams/ owe an update?
#
# The diagram layer (docs/superpowers/specs/2026-09-12-p4-field-patterns.md, D2–D3)
# keeps one Archify JSON per bounded story in wiki/diagrams/, each component pinned
# to path[:line] at meta.repository.revision. This script is the DETERMINISTIC half
# of keeping those pictures true. Two checks per *.architecture.json:
#
#   1. pinned paths ∩ files changed SINCE THE DIAGRAM WAS PINNED — the diff from
#      meta.repository.revision to HEAD when that revision is an ancestor of HEAD,
#      else from the merge-base with the base branch — plus the working tree.
#      Pure git + python; always runs. (A diagram authored on this branch after
#      the changes it depicts is therefore not flagged by its own branch.)
#   2. if archify is present: copy the JSON, re-pin revision to HEAD, run
#      `validate --repo-root .` and report every repository-evidence/* code
#      (file-missing, line-out-of-range, …). Layout diagnostics are NOT findings —
#      they were the same before the re-pin.
#
# Every finding is printed AND appended to the current branch's
# .strata/state/<slug>.json wiki_debt when that file exists (state_tools.py
# add-debt, idempotent) — the Stop gate's trigger (c) already enforces wiki_debt,
# so no second marker is introduced. Without a state file the finding is only
# printed. The actual refresh (edit the changed area, re-pin, validate → deliver
# through the archify skill, compare, snapshot the JSON when semanticSha256
# changed) is agent work in light-finish; this script never edits a diagram.
#
# Not a gate: exit 0 always (2 on usage error). Never call it from a hook — it
# runs inside light-finish step 5 and audit Phase 2. Archify: declared, not
# bundled; ARCHIFY_BIN overrides the default install location. The update check
# is disabled so the script makes no network requests.
#
# Usage: bash scripts/diagram_check.sh [base-ref]
#   base-ref defaults to origin/HEAD, else main, else master; it is the fallback
#   window for a diagram whose pinned revision is not an ancestor of HEAD (or has
#   none). On the base branch itself that fallback covers only the working tree.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$REPO_ROOT" || exit 0

case "${1:-}" in
  -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
esac
[ $# -le 1 ] || { echo "usage: diagram_check.sh [base-ref]" >&2; exit 2; }

DIAG_DIR="wiki/diagrams"
[ -d "$DIAG_DIR" ] || exit 0
shopt -s nullglob
files=("$DIAG_DIR"/*.architecture.json)
[ "${#files[@]}" -gt 0 ] || exit 0

export ARCHIFY_UPDATE_CHECK_DISABLED=1
ARCHIFY_BIN="${ARCHIFY_BIN:-$HOME/.claude/skills/archify/bin/archify.mjs}"
have_archify=0
command -v node >/dev/null 2>&1 && [ -f "$ARCHIFY_BIN" ] && have_archify=1

# --- what changed on this branch ---------------------------------------------
head_sha="$(git rev-parse HEAD 2>/dev/null || true)"
base="${1:-}"
if [ -z "$base" ]; then
  base="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [ -z "$base" ]; then
    for b in main master; do
      git show-ref -q --verify "refs/heads/$b" 2>/dev/null && { base="$b"; break; }
    done
  fi
fi
worktree_changes="$(git diff --name-only HEAD 2>/dev/null || true)"   # working tree vs HEAD
branch_changes=""                                                     # fallback window
if [ -n "$base" ] && [ -n "$head_sha" ] && git rev-parse -q --verify "${base}^{commit}" >/dev/null 2>&1; then
  mb="$(git merge-base HEAD "$base" 2>/dev/null || true)"
  if [ -n "$mb" ] && [ "$mb" != "$head_sha" ]; then
    branch_changes="$(git diff --name-only "$mb" HEAD 2>/dev/null || true)"
  fi
fi
# changed_since <revision-or-empty>: files changed since the diagram's pinned revision
# when that revision is an ancestor of HEAD; otherwise the branch window.
changed_since() {
  local rev="$1"
  if [ -n "$rev" ] && git merge-base --is-ancestor "$rev" HEAD 2>/dev/null; then
    printf '%s\n%s\n' "$worktree_changes" "$(git diff --name-only "$rev" HEAD 2>/dev/null || true)"
  else
    printf '%s\n%s\n' "$worktree_changes" "$branch_changes"
  fi
}

# --- where findings go --------------------------------------------------------
STATE_TOOLS="$SCRIPT_DIR/lib/state_tools.py"
state_path=""
branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [ -f "$STATE_TOOLS" ] && [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
  state_path="$(python3 "$STATE_TOOLS" path "$branch" 2>/dev/null || true)"
  [ -n "$state_path" ] && [ -f "$state_path" ] || state_path=""
fi

findings=0
record() {
  printf '%s\n' "$1"
  findings=$((findings + 1))
  if [ -n "$state_path" ]; then
    python3 "$STATE_TOOLS" add-debt "$state_path" "$1" >/dev/null 2>&1 || true
  fi
}

skipped_evidence=0
for f in "${files[@]}"; do
  name="$(basename "$f" .architecture.json)"

  # 1. pinned paths that changed on this branch
  pinned="$(python3 - "$f" <<'PY' 2>/dev/null
import json, sys
try:
    o = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
paths = sorted({s["path"] for c in o.get("components", []) for s in (c.get("sources") or []) if isinstance(s, dict) and s.get("path")})
print("\n".join(paths))
PY
)"
  pinned_rev="$(python3 - "$f" <<'PY' 2>/dev/null
import json, sys
try:
    o = json.load(open(sys.argv[1]))
    print(((o.get("meta") or {}).get("repository") or {}).get("revision") or "")
except Exception:
    print("")
PY
)"
  changed_files="$(changed_since "$pinned_rev")"
  hits=""
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    if printf '%s\n' "$changed_files" | grep -qxF -- "$p"; then hits="${hits:+$hits, }$p"; fi
  done <<< "$pinned"
  [ -n "$hits" ] && record "diagram $name: pinned file changed since the diagram was pinned: $hits — update the changed area of $f, re-pin revision to HEAD, validate → deliver (archify skill)"

  # 2. do the pins still resolve at HEAD?
  has_repo="$(python3 - "$f" <<'PY' 2>/dev/null
import json, sys
try:
    o = json.load(open(sys.argv[1]))
    print(1 if (o.get("meta") or {}).get("repository") else 0)
except Exception:
    print(0)
PY
)"
  [ "${has_repo:-0}" = "1" ] || continue
  if [ "$have_archify" -ne 1 ]; then skipped_evidence=1; continue; fi
  [ -n "$head_sha" ] || continue

  tmpd="$(mktemp -d)"
  tmp="$tmpd/$name.architecture.json"
  python3 - "$f" "$tmp" "$head_sha" <<'PY' 2>/dev/null
import json, sys
o = json.load(open(sys.argv[1]))
o["meta"]["repository"]["revision"] = sys.argv[3]
json.dump(o, open(sys.argv[2], "w"))
PY
  out="$(node "$ARCHIFY_BIN" validate architecture "$tmp" --repo-root "$REPO_ROOT" --json 2>/dev/null || true)"
  rm -rf "$tmpd"
  codes="$(printf '%s' "$out" | python3 -c '
import json, sys
try:
    o = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for d in o.get("diagnostics") or []:
    code = d.get("code") or ""
    if code.startswith("repository-evidence/"):
        msg = (d.get("message") or "").replace("\n", " ")
        print(f"{code}: {msg[:160]}")
' 2>/dev/null)"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    record "diagram $name: pin fails at HEAD — $line"
  done <<< "$codes"
done

if [ "$skipped_evidence" -eq 1 ]; then
  echo "diagram layer: archify not found (set ARCHIFY_BIN, or install: npx skills add tt-a1i/archify -g) — pin verification skipped, only the diff intersection ran"
fi
if [ -n "$state_path" ] && [ "$findings" -gt 0 ]; then
  echo "→ recorded as wiki_debt in $state_path (Stop gate trigger c enforces it; light-finish clears it once the diagram is refreshed)"
fi
exit 0
