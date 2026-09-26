#!/usr/bin/env bash
# Strata P5 — "why is this code here?": the mechanical half of provenance.
#
# Walks  lines → commits (git blame) → Agent-Session trailers → the session's
# transcript on THIS machine, and prints what it found. It does not open, parse
# or summarise a transcript — reading the events is the model's job, under the
# evidence rules in skills/wiki-ingest/sections/provenance.md. Read-only.
#
# Trust boundary: commit messages are attacker-writable (a forked PR, a
# hand-crafted commit), so every trailer value is re-validated here, not just
# where strata_commit_trailer.sh wrote it. An invalid value is reported, never
# used in a path. And a transcript is only offered when the session it records
# ran inside THIS repository (the transcript's own "cwd" is under one of this
# repo's worktrees) — a forged trailer copying a session id from another project
# gets that project named, never its transcript path.
#
# Usage: strata_why.sh <file> [-L <start>,<end>] [--history]
#   default     the commits that last touched those lines (blame -w -M)
#   --history   up to 20 commits that ever touched the file (git log --follow) —
#               for when the last touch was a move or a reformat, not the reason
# Exit: 0 printed a report · 2 usage error (no file, file not found, bad -L)
#
# Transcripts: ${CLAUDE_CONFIG_DIR:-~/.claude}/projects/<dir>/<id>.jsonl, plus
# <id>/subagents/ — a commit made by a subagent carries the PARENT's id, so the
# tool call that made it lives there, not in the main file.

set -uo pipefail

usage() { echo "usage: strata_why.sh <file> [-L <start>,<end>] [--history]" >&2; exit 2; }

file=""; range=""; history=0
while [ $# -gt 0 ]; do
  case "$1" in
    -L) [ $# -ge 2 ] || usage; range="$2"; shift 2 ;;
    -L*) range="${1#-L}"; shift ;;
    --history) history=1; shift ;;
    -h|--help) usage ;;
    *) [ -z "$file" ] || usage; file="$1"; shift ;;
  esac
done
[ -n "$file" ] || usage
[ -e "$file" ] || { echo "strata_why.sh: no such file: $file" >&2; usage; }
if [ -n "$range" ]; then
  case "$range" in *[!0-9,]* | ,* | *, | *,*,*) echo "strata_why.sh: bad -L '$range' (want a,b)" >&2; usage ;; esac
fi
git rev-parse --git-dir >/dev/null 2>&1 || { echo "strata_why.sh: not a git repository" >&2; exit 2; }

PROJECTS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
ZERO="0000000000000000000000000000000000000000"

# Every worktree of this repo, physical path — a session "belongs here" when its
# recorded cwd is one of these or below one.
roots="$(git worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' \
  | while IFS= read -r p; do (cd "$p" 2>/dev/null && pwd -P); done)"

valid_id() {
  case "$1" in "" | [!A-Za-z0-9]* | *[!A-Za-z0-9._-]*) return 1 ;; esac
  [ "${#1}" -le 128 ]
}

transcript_line() { # <id> → one "session …" line
  local id="$1" f cwd root here=0 others=""
  for f in "$PROJECTS"/*/"$id".jsonl; do
    [ -f "$f" ] || continue
    cwd="$(grep -m1 -o '"cwd":"[^"]*"' "$f" 2>/dev/null | sed 's/^"cwd":"//; s/"$//')"
    while IFS= read -r root; do
      [ -n "$root" ] && [ -n "$cwd" ] || continue
      case "$cwd" in "$root" | "$root"/*) here=1 ;; esac
    done <<< "$roots"
    if [ "$here" -eq 1 ]; then
      echo "  session $id · transcript $f"
      [ -d "${f%.jsonl}/subagents" ] && echo "    subagents ${f%.jsonl}/subagents"
      return
    fi
    others="${others:+$others, }$(basename "$(dirname "$f")")"
  done
  if [ -n "$others" ]; then
    echo "  session $id · transcript: another project ($others) — not opened"
  else
    echo "  session $id · transcript: not on this machine"
  fi
}

# --- the commits -------------------------------------------------------------
uncommitted=0
if [ "$history" -eq 1 ]; then
  shas="$(git log --follow -n 20 --format=%H -- "$file" 2>/dev/null)"
else
  blame="$(git blame -w -M --porcelain ${range:+-L "$range"} -- "$file" 2>/dev/null)" \
    || { echo "strata_why.sh: git blame failed for $file${range:+ -L $range}" >&2; exit 2; }
  # Porcelain header lines are "<40-hex> <orig> <final>[ <count>]"; content lines
  # start with a tab and are skipped by the anchor.
  shas="$(printf '%s\n' "$blame" | sed -n 's/^\([0-9a-f]\{40\}\) [0-9]\{1,\} [0-9]\{1,\}.*/\1/p' | awk '!seen[$0]++')"
  if printf '%s\n' "$shas" | grep -qx "$ZERO"; then
    uncommitted=1
    shas="$(printf '%s\n' "$shas" | grep -vx "$ZERO")"
  fi
fi

[ -n "$shas" ] || [ "$uncommitted" -eq 1 ] || { echo "no commits found for $file"; exit 0; }

# One git call for all of them: a record per commit, fields split by US (0x1f),
# records by RS (0x1e). %B is kept for Agent-Session lines that are NOT trailers —
# a squash merge copies the squashed commits' trailers into the body, indented.
if [ -n "$shas" ]; then
  # shellcheck disable=SC2086
  git log --no-walk=unsorted \
    --format='%H%x1f%h%x1f%ad%x1f%an%x1f%s%x1f%(trailers:key=Agent-Session,valueonly,separator=%x1d)%x1f%B%x1e' \
    --date=short $shas 2>/dev/null \
  | while IFS=$'\x1f' read -r -d $'\x1e' full short date author subject trailer_vals body; do
      full="${full#$'\n'}"
      echo "commit ${full:0:12} $date $author — $subject"
      found=0
      IFS=$'\x1d' read -r -a vals <<< "$trailer_vals"
      for v in ${vals[@]+"${vals[@]}"}; do  # bash 3.2 + set -u: an empty array is "unbound"
        v="$(printf '%s' "$v" | tr -d '\r\n')"; [ -n "$v" ] || continue
        found=1
        if valid_id "$v"; then transcript_line "$v"
        else echo "  invalid Agent-Session value (not used): $(printf '%s' "$v" | cut -c1-60 | tr -cd '[:print:]')"; fi
      done
      # Body lines that look like trailers but are not in the trailer block.
      printf '%s\n' "$body" | sed -n 's/^[[:space:]*-]*Agent-Session:[[:space:]]*\([^[:space:]]*\).*/\1/p' | awk '!seen[$0]++' \
      | while IFS= read -r v; do
          case "$(printf '\x1d%s\x1d' "$trailer_vals")" in *$'\x1d'"$v"$'\x1d'*) continue ;; esac
          if valid_id "$v"; then transcript_line "$v" | sed 's/^  session /  session (from message body — squashed?) /'
          else echo "  invalid Agent-Session value (not used): $(printf '%s' "$v" | cut -c1-60 | tr -cd '[:print:]')"; fi
        done
      [ "$found" -eq 1 ] || printf '%s\n' "$body" | grep -q 'Agent-Session:' \
        || echo "  no Agent-Session trailer (a human commit, or made before the trailer hook)"
    done
fi

[ "$uncommitted" -eq 1 ] && echo "uncommitted: some of these lines are not committed yet"
exit 0
