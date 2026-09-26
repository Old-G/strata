#!/usr/bin/env bash
# Behavioural test for P4 / T1 — Stop-gate trigger (d): friction.
#   scripts/hooks/strata_stop_gate.sh reads the session's own transcript
#   (transcript_path in the Stop payload) and, when the session hurt — user
#   interrupts, denied tool calls, tool errors past a threshold — refuses to end
#   the turn ONCE unless a gotcha (or an explicit no-gotcha) was recorded.
#
# Same discipline as test_p1_gates.sh / test_p2_state.sh: throwaway git repo,
# the real shipped scripts, synthetic transcripts, no mocks. Branch pinned to
# main. See docs/superpowers/specs/2026-09-12-p4-field-patterns.md, D1.
#
# Usage: bash scripts/test_p4_friction.sh          (exit 0 = all green)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TPL="$ROOT/templates/core/scripts"
pass=0; fail=0

ok()   { echo "  ✓ $1"; pass=$((pass+1)); }
bad()  { echo "  ✗ $1"; fail=$((fail+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }
has()  { case "$1" in *"$2"*) echo yes ;; *) echo no ;; esac; }

WORK="$(mktemp -d)"
# Transcripts live OUTSIDE the fixture repo: inside it they would be untracked
# files and trigger (b) would count them as code.
TR="$(mktemp -d)"
trap 'rm -rf "$WORK" "$TR"' EXIT
cd "$WORK" || exit 1

git init -q .
git config user.email test@strata.local
git config user.name "Strata Test"
git checkout -q -b main
mkdir -p docs raw wiki src scripts/lib scripts/hooks
cp "$TPL/lib/pending_ingest.sh"          scripts/lib/
cp "$TPL/lib/tree_snapshot.sh" scripts/lib/
cp "$TPL/lib/state_tools.py"             scripts/lib/
cp "$TPL/hooks/strata_session_start.sh"  scripts/hooks/
cp "$TPL/hooks/strata_stop_gate.sh"      scripts/hooks/
printf 'seed\n' > seed.txt
: > wiki/log.md
printf '.strata/*\n!.strata/state/\n' > .gitignore
git add -A >/dev/null && git commit -qm seed

START=scripts/hooks/strata_session_start.sh
GATE=scripts/hooks/strata_stop_gate.sh

# --- synthetic transcript ----------------------------------------------------
# mk_transcript <path> <interrupts> <denials> <errors> [sidechain true|false] [filler lines]
# (arithmetic loops, not `seq 1 N`: BSD seq counts DOWN for N=0 and emits two lines)
# Line shapes copied from real Claude Code transcripts (compact JSON, one event
# per line): a user interrupt is a user message whose content starts with
# "[Request interrupted by user"; a denial is a tool_result with is_error:true
# and the CLI's refusal text; a plain tool error is any other is_error:true.
mk_transcript() {
  local p="$1" i="$2" d="$3" e="$4" sc="${5:-false}" fill="${6:-20}" n
  : > "$p"
  for ((n = 1; n <= fill; n++)); do
    echo '{"type":"assistant","isSidechain":false,"message":{"role":"assistant","content":[{"type":"text","text":"working on it"}]}}' >> "$p"
  done
  for ((n = 1; n <= i; n++)); do
    echo "{\"type\":\"user\",\"isSidechain\":$sc,\"message\":{\"role\":\"user\",\"content\":\"[Request interrupted by user]\"}}" >> "$p"
  done
  for ((n = 1; n <= d; n++)); do
    echo "{\"type\":\"user\",\"isSidechain\":$sc,\"message\":{\"role\":\"user\",\"content\":[{\"type\":\"tool_result\",\"content\":\"The user doesn't want to proceed with this tool use.\",\"is_error\":true,\"tool_use_id\":\"t$n\"}]}}" >> "$p"
  done
  for ((n = 1; n <= e; n++)); do
    echo "{\"type\":\"user\",\"isSidechain\":$sc,\"message\":{\"role\":\"user\",\"content\":[{\"type\":\"tool_result\",\"content\":\"Exit code 1\\nno such file\",\"is_error\":true,\"tool_use_id\":\"e$n\"}]}}" >> "$p"
  done
}

new_session() { rm -rf .strata/sessions; echo "{\"session_id\":\"$1\"}" | bash "$START" >/dev/null 2>&1; }
# stop_gate <session> <transcript-path|-> ; env overrides are passed by the caller
stop_gate() {
  local sid="$1" tp="$2"
  if [ "$tp" = "-" ]; then
    echo "{\"session_id\":\"$sid\"}" | bash "$GATE" 2>/dev/null
  else
    echo "{\"session_id\":\"$sid\",\"transcript_path\":\"$tp\"}" | bash "$GATE" 2>/dev/null
  fi
}

echo "P4 / T1 — Stop-gate trigger (d): friction"

# 1. clean transcript → silent
mk_transcript "$TR/clean.jsonl" 0 0 0
new_session s1
check "clean transcript → silent" "$(stop_gate s1 "$TR/clean.jsonl")" ""

# 2. two interrupts → one block carrying the count; 3. same session again → silent (cap)
mk_transcript "$TR/int2.jsonl" 2 0 0
new_session s2
out="$(stop_gate s2 "$TR/int2.jsonl")"
check "2 interrupts → block"                       "$(has "$out" '"decision":"block"')" yes
check "  reason names the interrupt count"         "$(has "$out" '2 interrupt')" yes
check "  reason tells how to satisfy it (gotcha:)" "$(has "$out" 'gotcha:')" yes
check "second Stop in the same session → silent (one block per session)" "$(stop_gate s2 "$TR/int2.jsonl")" ""

# 4. denials: 1 is below the default threshold, 2 meets it
mk_transcript "$TR/den1.jsonl" 0 1 0
mk_transcript "$TR/den2.jsonl" 0 2 0
new_session s4a; check "1 denied tool call → silent (threshold 2)" "$(stop_gate s4a "$TR/den1.jsonl")" ""
new_session s4b; out="$(stop_gate s4b "$TR/den2.jsonl")"
check "2 denied tool calls → block"           "$(has "$out" '"decision":"block"')" yes
check "  reason names the denial count"       "$(has "$out" '2 denied')" yes
check "  a denial is not double-counted as a tool error" "$(has "$out" '0 tool error')" yes

# 5. tool errors: 7 silent, 8 blocks, env 0 disables
mk_transcript "$TR/err7.jsonl" 0 0 7
mk_transcript "$TR/err8.jsonl" 0 0 8
new_session s5a; check "7 tool errors → silent (threshold 8)" "$(stop_gate s5a "$TR/err7.jsonl")" ""
new_session s5b; check "8 tool errors → block" "$(has "$(stop_gate s5b "$TR/err8.jsonl")" '"decision":"block"')" yes
new_session s5c; check "STRATA_FRICTION_ERRORS=0 disables the error signal" "$(STRATA_FRICTION_ERRORS=0 stop_gate s5c "$TR/err8.jsonl")" ""

# 6. all thresholds zero → trigger off entirely
mk_transcript "$TR/loud.jsonl" 3 3 20
new_session s6
check "all thresholds 0 → silent on a loud transcript" \
  "$(STRATA_FRICTION_INTERRUPTS=0 STRATA_FRICTION_DENIALS=0 STRATA_FRICTION_ERRORS=0 stop_gate s6 "$TR/loud.jsonl")" ""

# 7. fail open: no transcript_path, or a path that does not exist
new_session s7a; check "payload without transcript_path → silent" "$(stop_gate s7a -)" ""
new_session s7b; check "transcript_path pointing nowhere → silent (fail open)" "$(stop_gate s7b "$TR/missing.jsonl")" ""
if [ "$(id -u)" != "0" ]; then   # root reads mode-000 files; the case is meaningless there
  mk_transcript "$TR/noread.jsonl" 3 3 20
  chmod 000 "$TR/noread.jsonl"
  new_session s7c; check "transcript unreadable (mode 000) → silent (fail open)" "$(stop_gate s7c "$TR/noread.jsonl")" ""
  chmod 644 "$TR/noread.jsonl"
else
  ok "transcript unreadable → skipped (running as root)"
fi

# 8. recorded via wiki/log.md after the session stamp → silent
new_session s8
echo "gotcha: the thing that went wrong" >> wiki/log.md
check "friction + a wiki/log.md line this session → silent (recorded)" "$(stop_gate s8 "$TR/int2.jsonl")" ""
git checkout -q -- wiki/log.md

# 9. branch state: older than the stamp does not count as recorded; touched after it does
python3 scripts/lib/state_tools.py init main --goal "fixture" >/dev/null
STATE="$(python3 scripts/lib/state_tools.py path main)"
sleep 1
new_session s9a
check "friction + branch state older than the stamp → block" "$(has "$(stop_gate s9a "$TR/int2.jsonl")" '"decision":"block"')" yes
new_session s9b
sleep 1; touch "$STATE"
check "friction + branch state touched after the stamp → silent (recorded)" "$(stop_gate s9b "$TR/int2.jsonl")" ""
rm -rf .strata/state

# 10. friction + trigger (b) due → one block, reason carries both
new_session s10
for n in $(seq 1 60); do echo "echo line $n" >> src/big.sh; done
out="$(stop_gate s10 "$TR/int2.jsonl")"
check "friction + code-only change → one block" "$(has "$out" '"decision":"block"')" yes
check "  reason carries the code-only text"     "$(has "$out" 'lines of code')" yes
check "  reason also carries the friction counts" "$(has "$out" '2 interrupt')" yes
rm -f src/big.sh

# 11. sidechain lines (subagents) are ignored
mk_transcript "$TR/side.jsonl" 3 3 20 true
new_session s11
check "friction only on isSidechain:true lines → silent" "$(stop_gate s11 "$TR/side.jsonl")" ""

# 11b. the marker QUOTED inside a tool result is not an interrupt. Reading or grepping
# the gate's own code puts "[Request interrupted by user" into a "type":"user"
# tool_result line — escaped, because it is inside a JSON string. Found by the P5
# diff review on this repo's own transcript (1 false interrupt, 0 real ones).
mk_transcript "$TR/quoted.jsonl" 0 0 0
echo '{"type":"user","isSidechain":false,"message":{"role":"user","content":[{"type":"tool_result","content":"193:  n_int=\"$(grep -cF '"'"'[Request interrupted by user'"'"')\"\n{\"type\":\"text\",\"text\":\"[Request interrupted by user]\"}","tool_use_id":"r1"}]}}' >> "$TR/quoted.jsonl"
new_session s11b
check "marker quoted inside a tool_result → silent (not an interrupt)" "$(stop_gate s11b "$TR/quoted.jsonl")" ""
# …while the real shape (a text block, as current Claude Code writes it) still counts.
mk_transcript "$TR/realint.jsonl" 0 0 0
echo '{"type":"user","isSidechain":false,"message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user for tool use]"}]}}' >> "$TR/realint.jsonl"
new_session s11c
check "a text-block interrupt ('for tool use') → block" "$(has "$(stop_gate s11c "$TR/realint.jsonl")" '"decision":"block"')" yes

# 12. nowhere to record (no wiki/log.md, no branch state) → silent
rm -f wiki/log.md
new_session s12
check "no wiki/log.md and no branch state → silent (nothing to ask for)" "$(stop_gate s12 "$TR/int2.jsonl")" ""
git checkout -q -- wiki/log.md

# 13. timing: a 5 MB clean transcript must not make the gate noticeably slower
python3 - "$TR/big.jsonl" <<'PY'
import sys
line = '{"type":"assistant","isSidechain":false,"message":{"role":"assistant","content":[{"type":"text","text":"' + ("x" * 100) + '"}]}}\n'
with open(sys.argv[1], "w") as f:
    for _ in range(5 * 1024 * 1024 // len(line) + 1):
        f.write(line)
PY
best_with=999999; best_without=999999
for n in 1 2 3 4 5 6 7; do
  new_session "t$n"
  t0=$(date +%s%N); stop_gate "t$n" "$TR/big.jsonl" >/dev/null; t1=$(date +%s%N)
  ms=$(( (t1 - t0) / 1000000 )); [ "$ms" -lt "$best_with" ] && best_with="$ms"
  new_session "u$n"
  t0=$(date +%s%N); stop_gate "u$n" - >/dev/null; t1=$(date +%s%N)
  ms=$(( (t1 - t0) / 1000000 )); [ "$ms" -lt "$best_without" ] && best_without="$ms"
done
delta=$(( best_with - best_without )); [ "$delta" -lt 0 ] && delta=0
check "5 MB transcript adds < 150 ms to the gate (best of 7: +${delta}ms; ${best_with}ms vs ${best_without}ms)" \
  "$([ "$delta" -lt 150 ] && echo yes || echo no)" yes

echo
echo "P4 friction: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
