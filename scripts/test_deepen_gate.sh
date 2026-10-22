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
unset STRATA_DEEPEN STRATA_DEEPEN_MIN_CHARS

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
