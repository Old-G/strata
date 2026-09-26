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
# Usage: bash strata_upgrade_check.sh [--apply-safe] <templates-scripts-dir> [<installed-scripts-dir>]
#
# --apply-safe (v0.9.0 — used by the SessionStart auto-sync and strata-upgrade-all):
#   also COPIES every file whose copy cannot lose a local line — MISSING files, and
#   STALE files that are either a strict subset of the template (no line the
#   template lacks) or byte-identical to a version the plugin once shipped: the
#   manifest <templates-scripts-dir>.history lists "<git blob hash>  <path>" for
#   every version of every template (scripts/gen_template_history.sh). Prints
#   SYNCED for those, CONFLICT for a STALE file that diverged on BOTH sides (left
#   untouched — that one needs a human, /strata:upgrade), AHEAD untouched as
#   always. Files are REPLACED (temp + mv, new inode), never rewritten in place: a
#   running bash script — SessionStart syncing itself — reads its file as it goes.
#   Exit 0 when nothing is left to do, 1 while a CONFLICT remains.
#
#   Only a MISSING file, or a file byte-identical to a shipped version, is ever
#   replaced — never "the diff looks one-sided": a template line the copy lacks
#   may be a line the owner deleted on purpose (P5 review round 2).
#
# Also reported in both modes:
#   KEPT     <path>   scripts/.strata-keep holds "<template blob>  <path>": the owner
#                     reviewed THIS template version and keeps their copy (or its
#                     absence). A new template version makes it CONFLICT again.
#   LINKED   <path>   the installed script is a symlink — managed elsewhere, untouched.
#   UNWIRED  .claude/settings.json: <command>
#                     a hook command from templates/core/claude-settings-hook.json is
#                     not in the project's settings — a synced script nobody runs is
#                     not an up-to-date install (exit 1; /strata:upgrade merges it).
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

APPLY=0
if [ "${1:-}" = "--apply-safe" ]; then APPLY=1; shift; fi
TEMPLATES_DIR="${1:-}"
INSTALLED_DIR="${2:-scripts}"

HISTORY="${TEMPLATES_DIR%/}.history"
KEEP="${INSTALLED_DIR%/}/.strata-keep"
# Did the owner keep their copy against exactly this template version?
kept() { # <template-file> <rel>
  [ -f "$KEEP" ] || return 1
  local h; h="$(git hash-object -- "$1" 2>/dev/null)" || return 1
  grep -qxF "$h  $2" "$KEEP"
}
# Was this installed file a version the plugin once shipped (= never edited here)?
shipped_before() { # <installed-file> <rel>
  [ -f "$HISTORY" ] || return 1
  local h; h="$(git hash-object -- "$1" 2>/dev/null)" || return 1
  grep -qxF "$h  $2" "$HISTORY"
}

# Replace dest with src atomically: temp file in the same directory, then mv.
replace_file() {
  local src="$1" dest="$2" tmp
  mkdir -p "$(dirname "$dest")" || return 1
  tmp="$(dirname "$dest")/.strata-sync.$$.$(basename "$dest")"
  cp -p "$src" "$tmp" && mv -f "$tmp" "$dest" || { rm -f "$tmp"; return 1; }
}

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

  if [ -L "$installed_file" ]; then
    echo "LINKED   $rel"
  elif [ ! -f "$installed_file" ] && kept "$tpl_file" "$rel"; then
    echo "KEPT     $rel"
  elif [ ! -f "$installed_file" ]; then
    if [ "$APPLY" -eq 1 ] && replace_file "$tpl_file" "$installed_file"; then
      echo "SYNCED   $rel"
    else
      echo "MISSING  $rel"
      status=1
    fi
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
      if kept "$tpl_file" "$rel"; then
        echo "KEPT     $rel"
      elif [ "$APPLY" -eq 0 ]; then
        echo "STALE    $rel"
        status=1
      elif ! shipped_before "$installed_file" "$rel"; then
        # Not a version we ever shipped: the owner changed it (added OR removed
        # lines). A copy would undo their work.
        echo "CONFLICT $rel"
        status=1
      elif replace_file "$tpl_file" "$installed_file"; then
        echo "SYNCED   $rel"
      else
        echo "STALE    $rel"
        status=1
      fi
    else
      # Nothing to copy: the plugin has nothing this repo is missing. Printed,
      # not silenced — the human still needs to see that the file diverged.
      echo "AHEAD    $rel"
    fi
  else
    echo "OK       $rel"
  fi
done < <(find "$TEMPLATES_DIR" -type f -print0 | sort -z)

# The hook block: every command the template registers must be in the project's
# settings (Stop gate, SessionStart, …). Only checked when both files exist.
SETTINGS_TPL="$(dirname "${TEMPLATES_DIR%/}")/claude-settings-hook.json"
SETTINGS="$(dirname "${INSTALLED_DIR%/}")/.claude/settings.json"
if [ -f "$SETTINGS_TPL" ] && [ -f "$SETTINGS" ]; then
  unwired="$(python3 -c '
import json, sys
def cmds(path):
    try:
        hooks = json.load(open(path)).get("hooks") or {}
    except Exception:
        return None
    return {h.get("command") for groups in hooks.values() for g in groups for h in g.get("hooks", []) if h.get("command")}
want, have = cmds(sys.argv[1]), cmds(sys.argv[2])
if want is None or have is None:
    sys.exit(0)
for c in sorted(want - have):
    print(c)
' "$SETTINGS_TPL" "$SETTINGS" 2>/dev/null)"
  if [ -n "$unwired" ]; then
    while IFS= read -r c; do echo "UNWIRED  .claude/settings.json: $c"; done <<< "$unwired"
    status=1
  fi
fi

exit "$status"
