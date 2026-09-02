#!/usr/bin/env bash
# Routing evals (P3 / E1) — does a trigger phrase actually fire the skill it belongs to?
#
# validate.sh proves the DETERMINISTIC half of Strata (hooks, gates) with ~80 behavioural
# assertions. This is the first test of the PROBABILISTIC half — which skill Claude picks
# from plain language (ADR #2). It costs API calls, so it is NOT part of validate.sh;
# validate.sh only asserts (offline, free) that every skill has a case here.
#
# Mechanism: `claude plugin eval` is in early access on this CLI, so each case runs
# headless — `claude -p "<prompt>" --plugin-dir <root> --allowedTools Skill --max-turns 1`
# from an EMPTY temp dir (no project settings can bias the route) — and the first Skill
# tool call's `skill` must equal `strata:<expect>`. The case list (evals/routing-cases.json)
# is generated from the SKILL.md descriptions verbatim and is shaped to convert to native
# eval cases unchanged when that command opens up. The `strata:` prefix on the asserted
# skill name is what attributes the route to THIS plugin (no separate ablation arm).
#
# THREE OUTCOMES PER RUN, kept apart on purpose:
#   ✓  the expected skill fired
#   ✗  a different skill fired, or none, with the API healthy   -> a ROUTING miss (exit 1)
#   !  the API refused/failed (rate limit, overload, network)   -> INCONCLUSIVE (exit 2)
# The first full RUNS=3 pass reported 13 cases at 0.00 with nothing fired; every one of
# them routed correctly when re-run alone — the tail of an 8-wide queue had hit a rate
# limit, and the runner had recorded that as a routing failure. An eval that cannot tell
# "the model chose wrong" from "the API said no" is worse than no eval, so transient
# failures retry with backoff and, if they persist, are reported as inconclusive and never
# as a miss. Every non-✓ row prints the first line of what the CLI actually said.
#
# SAFETY: case text (prompts) comes from SKILL.md and evals/routing_cases.py — repo-
# controlled, and this runs in CI on every PR that touches skills/**. It is therefore passed
# to the worker as an ARGUMENT, never spliced into a `bash -c` script string (the diff review
# demonstrated `$(…)` in a prompt executing under the first cut).
#
# Usage:
#   bash scripts/test_routing_evals.sh                 # all cases, RUNS=3, threshold 1.0
#   RUNS=1 bash scripts/test_routing_evals.sh          # quick pass
#   CASE='routing-audit-*' bash scripts/test_routing_evals.sh
#   PARALLEL=2 STRATA_EVAL_MODEL=<model> STRATA_EVAL_MAX_USD=0.05 bash scripts/test_routing_evals.sh
# Exit 0 all cases ≥ THRESHOLD · 1 routing miss · 2 setup problem or inconclusive runs.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASES="$ROOT/evals/routing-cases.json"
RUNS="${RUNS:-3}"
THRESHOLD="${THRESHOLD:-1.0}"
PARALLEL="${PARALLEL:-4}"
RETRIES="${RETRIES:-3}"
CASE_GLOB="${CASE:-*}"
export STRATA_EVAL_MODEL="${STRATA_EVAL_MODEL:-}"
export STRATA_EVAL_MAX_USD="${STRATA_EVAL_MAX_USD:-0.10}"   # per run; a routing call is a fraction of this

command -v claude >/dev/null 2>&1 || { echo "✗ claude CLI not on PATH — cannot run routing evals" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "✗ python3 required" >&2; exit 2; }
python3 "$ROOT/evals/routing_cases.py" --check >/dev/null || {
  echo "✗ evals/routing-cases.json is stale against skills/*/SKILL.md — run: python3 evals/routing_cases.py" >&2; exit 2; }
# Spend cap only if this CLI build has the flag — older builds would reject it.
export STRATA_EVAL_BUDGET_FLAG=""
claude --help 2>/dev/null | grep -q -- '--max-budget-usd' && export STRATA_EVAL_BUDGET_FLAG="--max-budget-usd"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
RESULTS="$WORK/results"; mkdir -p "$RESULTS"

# Markers of "the API said no", not "the model chose wrong".
export TRANSIENT_RE='rate.?limit|429|529|overloaded|usage limit|ECONNRESET|ETIMEDOUT|fetch failed|timed out|Request timeout|network error|socket hang up|internal server error|"is_error":true'

# One case-run: writes "<skill>" | "-" (routing miss) | "!" (inconclusive) to $RESULTS/<id>.<i>,
# and the first useful line of the CLI's output to $RESULTS/<id>.<i>.why when not ✓.
run_case() {  # $1=id $2=prompt $3=run-index
  local id="$1" prompt="$2" i="$3" attempt out skill why dir="$WORK/run-$1-$3"
  local -a extra=()
  [ -n "$STRATA_EVAL_MODEL" ] && extra+=(--model "$STRATA_EVAL_MODEL")
  [ -n "$STRATA_EVAL_BUDGET_FLAG" ] && extra+=("$STRATA_EVAL_BUDGET_FLAG" "$STRATA_EVAL_MAX_USD")
  mkdir -p "$dir"
  for attempt in $(seq 1 "$RETRIES"); do
    out="$(cd "$dir" && timeout 180 claude -p "$prompt" --plugin-dir "$ROOT" \
            --output-format stream-json --verbose --max-turns 1 --allowedTools Skill \
            "${extra[@]}" 2>"$dir/stderr" || true)"
    skill="$(printf '%s' "$out" | grep -o '"name":"Skill","input":{"skill":"[^"]*"' | head -1 \
             | sed 's/.*"skill":"//; s/"$//')"
    if [ -n "$skill" ]; then printf '%s\n' "$skill" > "$RESULTS/$id.$i"; return 0; fi
    if printf '%s\n%s' "$out" "$(cat "$dir/stderr")" | grep -Eqi "$TRANSIENT_RE"; then
      sleep $(( attempt * 5 ))          # back off, then try again — the API said no
      continue
    fi
    break                               # healthy API, nothing fired: a real miss
  done
  why="$( { grep -Eo '"text":"[^"]{0,160}' <<<"$out" | head -1 | sed 's/^"text":"//'; head -c 160 "$dir/stderr"; } | head -1)"
  if [ "$attempt" -ge "$RETRIES" ] && printf '%s\n%s' "$out" "$(cat "$dir/stderr")" | grep -Eqi "$TRANSIENT_RE"; then
    printf '!\n' > "$RESULTS/$id.$i"; printf 'transient after %s attempts: %s\n' "$RETRIES" "${why:-no output}" > "$RESULTS/$id.$i.why"
  else
    printf -- '-\n' > "$RESULTS/$id.$i"; printf '%s\n' "${why:-no Skill call, no text}" > "$RESULTS/$id.$i.why"
  fi
}
export -f run_case; export WORK RESULTS ROOT RETRIES

# Fan out: every (case × run) is independent.
python3 - "$CASES" "$CASE_GLOB" "$RUNS" <<'PY' > "$WORK/jobs.tsv"
import json, sys, fnmatch
d = json.load(open(sys.argv[1])); glob_ = sys.argv[2]; runs = int(sys.argv[3])
for c in d["cases"]:
    if fnmatch.fnmatch(c["id"], glob_):
        for i in range(1, runs + 1):
            print(f'{c["id"]}\t{c["prompt"]}\t{i}')
PY
n_jobs="$(wc -l < "$WORK/jobs.tsv" | tr -d ' ')"
[ "$n_jobs" -gt 0 ] || { echo "✗ no cases match CASE='$CASE_GLOB'" >&2; exit 2; }
echo "== routing evals: $n_jobs runs ($(cut -f1 "$WORK/jobs.tsv" | sort -u | wc -l | tr -d ' ') cases × RUNS=$RUNS), parallel=$PARALLEL, retries=$RETRIES =="

# The job line is passed to the worker as $1 — an argument, never interpolated into the script.
tr '\t' '\034' < "$WORK/jobs.tsv" | xargs -P "$PARALLEL" -I{} bash -c '
  IFS=$'"'"'\034'"'"' read -r id prompt i <<< "$1"
  run_case "$id" "$prompt" "$i"' _ {}

# Score: per case, fraction of CONCLUSIVE runs whose fired skill == strata:<expect>.
python3 - "$CASES" "$RESULTS" "$RUNS" "$THRESHOLD" "$CASE_GLOB" <<'PY'
import json, sys, os, fnmatch
cases = json.load(open(sys.argv[1]))["cases"]; res = sys.argv[2]; runs = int(sys.argv[3])
thr = float(sys.argv[4]); glob_ = sys.argv[5]
miss = 0; inconclusive = 0; rows = []
def why(cid, i):
    p = os.path.join(res, f"{cid}.{i}.why")
    return open(p).read().strip() if os.path.exists(p) else ""
for c in cases:
    if not fnmatch.fnmatch(c["id"], glob_): continue
    fired = []
    for i in range(1, runs + 1):
        p = os.path.join(res, f'{c["id"]}.{i}')
        fired.append(open(p).read().strip() if os.path.exists(p) else "!")
    want = f'strata:{c["expect"]}'
    if "!" in fired:
        inconclusive += 1
        first = next(i for i, f in enumerate(fired, 1) if f == "!")
        rows.append(f'  ! {c["id"]:<38} inconclusive ({fired.count("!")}/{runs} runs failed transiently) — {why(c["id"], first)}')
        continue
    hits = sum(1 for f in fired if f == want); score = hits / runs
    if score >= thr:
        rows.append(f'  ✓ {c["id"]:<38} {score:.2f}'); continue
    miss += 1
    wrong = sorted(set(f for f in fired if f != want))
    first = next(i for i, f in enumerate(fired, 1) if f != want)
    note = f'  ← neighbour {c["must_not"]} fired' if c.get("must_not") and f'strata:{c["must_not"]}' in fired else ""
    rows.append(f'  ✗ {c["id"]:<38} {score:.2f}  fired={",".join(wrong) or "-"}{note}  — {why(c["id"], first)}')
print("\n".join(rows))
total = sum(1 for c in cases if fnmatch.fnmatch(c["id"], glob_))
print(f"\nrouting evals: {total - miss - inconclusive}/{total} cases at ≥{thr} (RUNS={runs})"
      + (f", {inconclusive} inconclusive (API refused — rerun, lower PARALLEL)" if inconclusive else "")
      + (f", {miss} routing miss(es)" if miss else ""))
sys.exit(1 if miss else (2 if inconclusive else 0))
PY
