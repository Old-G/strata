#!/usr/bin/env bash
# Block commit if any docs/*.md is staged without its raw/*.md mirror
# being identical (or also staged with identical content).
#
# Rationale: wiki/ is regenerated from raw/, not docs/. If docs/ drifts
# from raw/, the AI reads stale source. This guard catches the drift at
# commit time so PostToolUse hook failures (or manual non-Claude edits)
# don't slip through.
#
# Bypass with `git commit --no-verify` if you intentionally want to
# commit docs/ ahead of raw/ (rare — typically the auto-mirror hook in
# .claude/settings.json handles this).

set -uo pipefail

violations=()

for f in "$@"; do
  norm="${f#./}"
  case "$norm" in
    docs/*.md) ;;
    *) continue ;;
  esac

  mirror="raw/${norm#docs/}"

  # Hash of the staged version of docs/<f>.
  src_hash="$(git hash-object -- "$norm" 2>/dev/null || echo MISSING)"

  # Hash of mirror — prefer staged version if it's in the index,
  # otherwise fall back to working-tree file.
  if git diff --cached --name-only | grep -qx "$mirror"; then
    mirror_hash="$(git hash-object -- "$mirror" 2>/dev/null || echo MISSING)"
  elif [[ -f "$mirror" ]]; then
    mirror_hash="$(git hash-object -- "$mirror" 2>/dev/null || echo MISSING)"
  else
    mirror_hash="MISSING"
  fi

  if [[ "$src_hash" != "$mirror_hash" ]]; then
    violations+=("$norm  (mirror $mirror is stale or missing)")
  fi
done

if (( ${#violations[@]} > 0 )); then
  echo "❌ docs/raw mirror drift detected. wiki/ is regenerated from raw/, so this commit"
  echo "   would leave the AI reading stale source for:"
  printf '   - %s\n' "${violations[@]}"
  echo
  echo "Fix:"
  echo "   bash scripts/wiki/sync_raw_mirror.sh \\"
  for v in "${violations[@]}"; do
    f="${v%%  *}"
    echo "       $f \\"
  done
  echo "   git add raw/"
  echo
  echo "Bypass (only if intentional): git commit --no-verify"
  exit 1
fi

exit 0
