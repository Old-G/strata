#!/usr/bin/env bash
# Behavioural test for bin/strata-context-gate — the context-gate Stop hook that asks for
# /strata:handoff once the main conversation passes STRATA_HANDOFF_PCT of its window.
# Synthetic transcripts in a throwaway dir, the real script, no mocks; the user's own Claude
# config is hidden (HOME / CLAUDE_CONFIG_DIR point into the fixture).
#
# Usage: bash scripts/test_context_gate.sh          (exit 0 = all green)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GATE="$ROOT/bin/strata-context-gate"
pass=0; fail=0
ok()   { echo "  ✓ $1"; pass=$((pass+1)); }
bad()  { echo "  ✗ $1"; fail=$((fail+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home" CLAUDE_CONFIG_DIR="$WORK/home/.claude" STRATA_CONTEXT_GATE_DIR="$WORK/markers"
unset ANTHROPIC_MODEL STRATA_HANDOFF_PCT STRATA_CONTEXT_WINDOW
mkdir -p "$CLAUDE_CONFIG_DIR" "$WORK/proj/.claude"

# transcript <file> <main tokens> [sidechain tokens]: user line, main assistant, optional later sidechain.
transcript() {
  local f="$WORK/$1"
  printf '{"type":"user","message":{"content":"hi"}}\n' > "$f"
  printf '{"type":"assistant","message":{"model":"m","usage":{"input_tokens":2,"cache_creation_input_tokens":%s,"cache_read_input_tokens":0,"output_tokens":9999}}}\n' "$(( $2 - 2 ))" >> "$f"
  if [ -n "${3:-}" ]; then
    printf '{"type":"assistant","isSidechain":true,"message":{"usage":{"input_tokens":%s}}}\n' "$3" >> "$f"
  fi
  printf '{"type":"assistant","message":{"model":"<synthetic>","usage":{"input_tokens":0}}}\n' >> "$f"
  echo "$f"
}
gate() { # gate <session> <transcript> [stop_hook_active]
  printf '{"session_id":"%s","transcript_path":"%s","cwd":"%s","stop_hook_active":%s,"last_assistant_message":"x"}' \
    "$1" "$2" "$WORK/proj" "${3:-false}" | bash "$GATE"
}
ptu() { # ptu <session> <transcript> [extra json fields] — a PostToolUse input
  printf '{"session_id":"%s","transcript_path":"%s","cwd":"%s","hook_event_name":"PostToolUse","tool_name":"Bash"%s}' \
    "$1" "$2" "$WORK/proj" "${3:-}" | bash "$GATE"
}
decision() { local out; out="$(gate "$@")"; [ -z "$out" ] && { echo clear; return; }
  printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("decision","?"))' 2>/dev/null || echo malformed; }

echo "== context gate =="
check "under the threshold (100k of 200k = 50%) → clear" "$(decision s1 "$(transcript t1 100000)")" clear
check "over the threshold (130k of 200k = 65%) → block" "$(decision s2 "$(transcript t2 130000)")" block
out="$(STRATA_CONTEXT_GATE_DIR="$WORK/m2" gate s2b "$(transcript t2b 130000)")"
case "$out" in *strata:handoff*handoff-s2b.md*) ok "reason names the skill and this session's handoff file" ;; *) bad "reason: $out" ;; esac
check "same session again → clear (asks once)" "$(decision s2 "$WORK/t2")" clear
check "stop_hook_active → clear" "$(decision s3 "$(transcript t3 190000)" true)" clear
check "a later sidechain message is ignored (main 50k, subagent 190k) → clear" "$(decision s4 "$(transcript t4 50000 190000)")" clear
check "more than 200k used means a 1M window (300k = 30%) → clear" "$(decision s5 "$(transcript t5 300000)")" clear
check "1M window at 650k → block" "$(decision s6 "$(transcript t6 650000)")" block
printf '{"model":"opus[1m]"}' > "$CLAUDE_CONFIG_DIR/settings.json"
check "user settings model opus[1m]: 130k of 1M → clear" "$(decision s7 "$(transcript t7 130000)")" clear
printf '{"model":"sonnet"}' > "$WORK/proj/.claude/settings.json"
check "project settings model wins over the user's: 130k of 200k → block" "$(decision s8 "$(transcript t8 130000)")" block
check "ANTHROPIC_MODEL=…[1m] wins over settings → clear" "$(ANTHROPIC_MODEL='claude-opus-5-5[1m]' decision s9 "$(transcript t9 130000)")" clear
check "STRATA_CONTEXT_WINDOW override (130k of 150k) → block" "$(STRATA_CONTEXT_WINDOW=150000 decision s10 "$(transcript t10 130000)")" block
check "STRATA_HANDOFF_PCT=5: 20k of 200k → block" "$(STRATA_HANDOFF_PCT=5 decision s11 "$(transcript t11 20000)")" block
check "STRATA_HANDOFF_PCT=0 disables → clear" "$(STRATA_HANDOFF_PCT=0 decision s12 "$(transcript t12 190000)")" clear
check "missing transcript → clear" "$(decision s13 "$WORK/nope.jsonl")" clear
check "malformed input → clear" "$(printf 'garbage' | bash "$GATE"; echo clear)" clear
check "exit code is 0 when blocking" "$(gate s14 "$(transcript t14 190000)" >/dev/null; echo $?)" 0
big="$(python3 -c 'print("y"*400000)')"
out="$(printf '{"session_id":"s15","transcript_path":"%s","cwd":"%s","stop_hook_active":false,"last_assistant_message":"%s"}' \
  "$(transcript t15 190000)" "$WORK/proj" "$big" | bash "$GATE")"
case "$out" in *'"block"'*) ok "a 400 KB last message still blocks (input read from stdin)" ;; *) bad "large input did not block" ;; esac

echo "== mid-turn (PostToolUse) =="
out="$(ptu p1 "$(transcript tp1 130000)")"
case "$out" in *'"block"'*"Finish only the step in progress"*) ok "PostToolUse over the threshold → block, mid-turn wording" ;; *) bad "PostToolUse: $out" ;; esac
check "the Stop after a mid-turn ask → clear (one marker per session)" "$(decision p1 "$WORK/tp1")" clear
check "PostToolUse under the threshold → clear" "$( [ -z "$(ptu p2 "$(transcript tp2 100000)")" ] && echo clear || echo block)" clear
check "a subagent's tool call (agent_id) → clear" "$( [ -z "$(ptu p3 "$(transcript tp3 190000)" ',"agent_id":"a1","agent_type":"general-purpose"')" ] && echo clear || echo block)" clear
check "…and the main agent is still asked afterwards" "$(decision p3 "$WORK/tp3")" block

echo
echo "Context gate: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
