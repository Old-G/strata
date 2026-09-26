#!/usr/bin/env bash
# Regenerate templates/core/scripts.history — every version every shipped script
# template ever had, as "<git blob hash>  <path relative to templates/core/scripts>".
#
# Why: strata_upgrade_check.sh --apply-safe (the SessionStart auto-sync and
# strata-upgrade-all) may replace an installed script only when that loses no
# local work. A changed line in the template makes the diff two-sided, so "no
# local lines" cannot be read off the diff; "the installed file is byte-identical
# to a version we shipped" can — hence this manifest. It ships with the plugin,
# next to (not inside) the scripts dir, so it is never copied into a project.
#
# Sources: git history of templates/core/scripts/ (every blob on this branch)
# plus the working tree, so a commit that changes a template carries its own
# new hash. validate.sh §2d fails when a version visible here is missing from it.
#
# Usage: bash scripts/gen_template_history.sh [--check]   (--check: exit 1 if stale)

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2
DIR="templates/core/scripts"
OUT="templates/core/scripts.history"

gen() {
  {
    # --raw lines: ":<mode> <mode> <old-blob> <new-blob> <status>\t<path>"
    git log --format= --raw --no-abbrev --no-renames -- "$DIR" 2>/dev/null \
      | awk -F'\t' -v d="$DIR/" '{ split($1, f, " "); if (f[4] !~ /^0+$/ && index($2, d) == 1) print f[4] "  " substr($2, length(d) + 1) }'
    find "$DIR" -type f | while IFS= read -r f; do
      printf '%s  %s\n' "$(git hash-object -- "$f")" "${f#"$DIR"/}"
    done
  } | LC_ALL=C sort -u
}

if [ "${1:-}" = "--check" ]; then
  # Subset, not equality: a shallow CI clone (fetch-depth 1) sees only HEAD's blobs,
  # so it can regenerate FEWER lines than the committed manifest, never more. What
  # must hold everywhere: every version visible here — above all the working tree's
  # current templates — is listed. That is exactly the "forgot to regenerate" case.
  missing="$(LC_ALL=C comm -23 <(gen) <(LC_ALL=C sort -u "$OUT" 2>/dev/null))"
  if [ -z "$missing" ]; then exit 0; fi
  printf '%s\n' "$missing" | sed 's/^/  not in scripts.history: /' >&2
  echo "templates/core/scripts.history is stale — run: bash scripts/gen_template_history.sh" >&2
  exit 1
fi
gen > "$OUT"
echo "wrote $OUT ($(wc -l < "$OUT" | tr -d ' ') versions)"
