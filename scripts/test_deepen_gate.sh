#!/usr/bin/env bash
# Behavioural test for bin/strata-deepen-gate — the UserPromptSubmit hook that asks for
# /strata:deepen on messages that build or change something. Real script, no mocks.
#
# Usage: bash scripts/test_deepen_gate.sh          (exit 0 = all green)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GATE="$ROOT/bin/strata-deepen-gate"
pass=0; fail=0
ok()   { echo "  ✓ $1"; pass=$((pass+1)); }
bad()  { echo "  ✗ $1"; fail=$((fail+1)); }
unset STRATA_DEEPEN STRATA_DEEPEN_MIN_CHARS STRATA_DEEPEN_SKIP
# No skip file from the machine running the test: an empty one by default.
export STRATA_DEEPEN_SKIP_FILE="$(mktemp)"

# asks <name> <prompt> — the gate adds the deepen note; quiet <name> <prompt> — it adds nothing.
run() { python3 -c 'import json,sys; print(json.dumps({"session_id":"s","prompt":sys.argv[1]}))' "$1" | bash "$GATE"; }
asks()  { out="$(run "$2")"; case "$out" in *strata:deepen*) ok "$1";; *) bad "$1 (no note)";; esac; }
quiet() { out="$(run "$2")"; if [ -z "$out" ]; then ok "$1"; else bad "$1 (got a note)"; fi; }

echo "== deepen gate =="
asks  "RU build request"            "Добавь в отчёт экспорт в CSV для бухгалтерии"
asks  "EN build request"            "Add a CSV export to the report so accounting can open it"
asks  "RU 'надо чтобы' request"     "Надо, чтобы страница открывалась быстрее на телефоне"
out="$(run "Implement retries for the webhook sender with backoff")"
if python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d["hookSpecificOutput"]["hookEventName"]=="UserPromptSubmit"' "$out" 2>/dev/null; then ok "output is UserPromptSubmit additionalContext JSON"; else bad "output shape"; fi
quiet "short reply"                 "да, делай"
quiet "slash command"               "/strata:audit please add nothing"
quiet "no build verb"               "Почему тест падает только на CI под Linux?"
quiet "empty prompt"                ""
# Machine messages: a harness notice and a relayed message pass, the same words typed by a person do not.
quiet "harness tag notice"          "<task-notification> <task-id>b1</task-id> <summary>Background command \"fix the build\" completed</summary>"
asks  "a tag later in the text"     "Add a CSV export to the <report> page so accounting can open it"
printf '# relays from another chat\nRelay · a message from thread \n(\n' > "$STRATA_DEEPEN_SKIP_FILE"
quiet "skip-file pattern"           "Relay · a message from thread app/chat-1: add a CSV export to the report"
asks  "skip-file matches only the start" "Add a CSV export, then Relay · a message from thread app/chat-1"
asks  "bad regex line is ignored"   "Добавь в отчёт экспорт в CSV для бухгалтерии"
printf 'R\xe9lay \n' > "$STRATA_DEEPEN_SKIP_FILE"
asks  "a non-UTF-8 skip file keeps the gate on" "Add a CSV export to the report for accounting"
printf '\xef\xbb\xbfBOM relay: \n' > "$STRATA_DEEPEN_SKIP_FILE"
quiet "a BOM does not break the first pattern" "BOM relay: add a CSV export to the report"
asks  "a pasted HTML tag first is still a person" "<div> on the report page — add a CSV export button there"
: > "$STRATA_DEEPEN_SKIP_FILE"
xdg="$(mktemp -d)"; mkdir -p "$xdg/strata"; echo 'XDG relay: ' > "$xdg/strata/deepen-skip"
out="$(unset STRATA_DEEPEN_SKIP_FILE; XDG_CONFIG_HOME="$xdg" run "XDG relay: add a CSV export to the report")"; rm -rf "$xdg"
if [ -z "$out" ]; then ok "default skip file under XDG_CONFIG_HOME"; else bad "default skip file under XDG_CONFIG_HOME"; fi
out="$(STRATA_DEEPEN_SKIP='Bot says: ' run "Bot says: please add a CSV export to the report")"
if [ -z "$out" ]; then ok "STRATA_DEEPEN_SKIP pattern"; else bad "STRATA_DEEPEN_SKIP pattern"; fi
rm -f "$STRATA_DEEPEN_SKIP_FILE"
STRATA_DEEPEN=0 asks_off="$(STRATA_DEEPEN=0 run "Добавь в отчёт экспорт в CSV для бухгалтерии")"
if [ -z "$asks_off" ]; then ok "STRATA_DEEPEN=0 disables"; else bad "STRATA_DEEPEN=0 disables"; fi
bad_json="$(printf 'not json' | bash "$GATE"; echo "exit=$?")"
if [ "$bad_json" = "exit=0" ]; then ok "fails open on bad input"; else bad "fails open on bad input (got '$bad_json')"; fi

shadow="$(mktemp -d)"; echo 'raise SystemExit("shadowed")' > "$shadow/json.py"
out="$(cd "$shadow" && printf '{"prompt":"Add a CSV export to the report for accounting"}' | bash "$GATE")"; rm -rf "$shadow"
case "$out" in *strata:deepen*) ok "a json.py in the project dir does not run (python3 -I)";; *) bad "module shadowing from the project dir";; esac

# The gate runs from ~/.claude/settings.json in every project, also where the plugin is not enabled and
# the skill is not loaded: the note must point at the skill file so the pass can be followed by hand.
out="$(run "Add a CSV export to the report so accounting can open it")"
case "$out" in *"$ROOT/skills/deepen/SKILL.md"*) ok "note names the skill file as a fallback";; *) bad "no SKILL.md fallback in the note";; esac

# The gate already ran the pass; /strata:feature must reuse it, not run it (and its range subagents) again.
if grep -qi "already ran" "$ROOT/skills/feature/SKILL.md" && grep -qi "reuse" "$ROOT/skills/feature/SKILL.md"; then
  ok "feature reuses a deepen pass already run this session"
else bad "feature runs deepen again after the gate"; fi

echo "Deepen gate: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
