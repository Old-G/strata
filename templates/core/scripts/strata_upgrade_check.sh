#!/usr/bin/env bash
# Strata upgrade check — pure diff reporter, no side effects.
#
# Compares this repo's INSTALLED scripts/** (copied in once by init/adopt) against
# the TEMPLATES tree currently shipped by the plugin, and reports what's missing
# or stale. Never writes anything — /strata:upgrade (the skill) reads this output
# and does the actual copying + settings.json merge, the same way init/adopt
# already do, so the human sees a diff before anything changes.
#
# Why this exists: init/adopt COPY templates/core/scripts/** once, at adoption
# time. There is no re-sync path — updating the plugin never reaches a repo
# adopted in the past (confirmed on a real project: wiki/ existed, all three
# hooks did not). See docs/superpowers/specs/2026-09-01-episodic-state-layer.md.
#
# Usage: bash strata_upgrade_check.sh <templates-scripts-dir> [<installed-scripts-dir>]
#   <templates-scripts-dir>   e.g. $CLAUDE_PLUGIN_ROOT/templates/core/scripts
#   <installed-scripts-dir>   default: ./scripts (repo root, from cwd)
#
# Output (stdout), one line per file relative to scripts/:
#   MISSING  <path>     installed repo has no such file at all
#   STALE    <path>     both exist, the TEMPLATE has lines the installed file lacks
#   AHEAD    <path>     both exist, the INSTALLED file is the template PLUS local
#                       lines — re-syncing would DELETE project-specific guards
#   OK       <path>     both exist, byte-identical
# Exit 0 when nothing is MISSING or STALE (clean — nothing to COPY; AHEAD is
#   reported but is not drift, so a repo that deliberately extends a shipped
#   script can still reach a green check instead of failing forever).
# Exit 1 when at least one file needs attention.
# Exit 2 on usage error (bad args, templates dir not found).

set -uo pipefail

TEMPLATES_DIR="${1:-}"
INSTALLED_DIR="${2:-scripts}"

if [ -z "$TEMPLATES_DIR" ] || [ ! -d "$TEMPLATES_DIR" ]; then
  echo "usage: strata_upgrade_check.sh <templates-scripts-dir> [<installed-scripts-dir>]" >&2
  echo "  templates dir not found: '${TEMPLATES_DIR}'" >&2
  exit 2
fi

status=0
# Walk every file the CURRENT plugin ships. A file that exists only in the
# installed tree (a project's own local script) is none of our business —
# this reports drift FROM the templates, not a two-way diff.
while IFS= read -r -d '' tpl_file; do
  rel="${tpl_file#"$TEMPLATES_DIR"/}"
  installed_file="${INSTALLED_DIR%/}/${rel}"

  if [ ! -f "$installed_file" ]; then
    echo "MISSING  $rel"
    status=1
  elif ! cmp -s "$tpl_file" "$installed_file"; then
    # "Differs" hides two OPPOSITE situations, and reporting one word for both
    # is what made this check useless on a real repo. Either the template moved
    # ahead (re-sync is the fix), or the INSTALLED file did — a project bolting
    # genuine guards onto a shipped script, which a copy would silently DELETE.
    #
    # Direction is decidable: if no template line is absent from the installed
    # file, the installed file is the template PLUS local additions. A template
    # that truly evolved always leaves at least one line the installed file
    # lacks, so a real STALE can never be misread as AHEAD; the reverse (a
    # reordered file reported STALE) is the safe way to be wrong.
    #
    # NOTE: `diff | grep` cannot be used directly here — `set -o pipefail` is on,
    # and diff exits 1 whenever files differ, which would poison the pipeline
    # status regardless of what grep found.
    file_diff="$(diff "$tpl_file" "$installed_file" || true)"
    if printf '%s\n' "$file_diff" | grep -q '^<'; then
      echo "STALE    $rel"
      status=1
    else
      # Nothing to copy: the plugin has nothing this repo is missing. Printed,
      # not silenced — the human still needs to see that the file diverged.
      echo "AHEAD    $rel"
    fi
  else
    echo "OK       $rel"
  fi
done < <(find "$TEMPLATES_DIR" -type f -print0 | sort -z)

exit "$status"
