#!/usr/bin/env bash
# Behavioural test for the pre-commit secret guard:
#   templates/core/scripts/pre-commit/check_secrets.sh
#
# Same discipline as the other suites: throwaway repo, the real script, no mocks —
# except a fake `gitleaks` on PATH, to prove the built-in patterns still run when
# gitleaks is installed (upstreamed from app-b, 2026-09-06: installing gitleaks
# had silently switched the patterns off).
#
# Usage: bash scripts/test_secrets.sh      (exit 0 = all green)

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GUARD="$ROOT/templates/core/scripts/pre-commit/check_secrets.sh"
pass=0; fail=0
ok()   { echo "  ✓ $1"; pass=$((pass+1)); }
bad()  { echo "  ✗ $1"; fail=$((fail+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK" || exit 1
git init -q . && git config user.email t@t && git config user.name t
mkdir -p bin && printf '#!/bin/sh\nexit 0\n' > bin/gitleaks && chmod +x bin/gitleaks   # a gitleaks that finds nothing
NOLEAKS="$(printf '%s' "$PATH" | tr ':' '\n' | while read -r d; do [ -x "$d/gitleaks" ] || printf '%s:' "$d"; done)"

# The fake secrets are ASSEMBLED at run time: this file is itself committed through
# the guard (and gitleaks), so it must not contain a secret-shaped line.
PW="pass""word"; API="api""_key"; VAL="hunter""22secret"; LONGVAL="abcdef""1234567890xyz"

# verdict <file> <content> [with-gitleaks] → blocked | clean
verdict() {
  git reset -q; rm -f "$1"; printf '%s\n' "$2" > "$1"; git add "$1"
  if [ "${3:-}" = with-gitleaks ]; then PATH="$WORK/bin:$NOLEAKS" sh "$GUARD" >/dev/null 2>&1
  else PATH="$NOLEAKS" sh "$GUARD" >/dev/null 2>&1; fi
  [ $? -eq 0 ] && echo clean || echo blocked
}

echo "== hardcoded values are caught =="
check "quoted password literal"               "$(verdict a.py "$PW = '$VAL'")" "blocked"
check "unquoted env-style assignment"         "$(verdict a.env.sh "DB_$(printf '%s' "$PW" | tr a-z A-Z)=super${VAL}")" "blocked"
check "quoted api key in yaml"                "$(verdict c.yaml "$API: '$LONGVAL'")" "blocked"
check "committed .env file"                   "$(verdict .env "X=1")" "blocked"
check ".env.example is fine"                  "$(verdict .env.example "PASSWORD=")" "clean"

echo "== ordinary code is NOT a secret (false alarms teach --no-verify) =="
check "property access: env.SLACK_SIGNING_SECRET" "$(verdict b.ts "slackSigningSecret: env.SLACK_SIGNING_SECRET,")" "clean"
check "process.env lookup"                    "$(verdict d.js "const apiKey = process.env.OPENAI_API_KEY")" "clean"
check "reading a password from config"        "$(verdict e.py "$PW = settings.database_$PW")" "clean"

echo "== gitleaks ADDS to the patterns, never replaces them =="
check "gitleaks installed (finds nothing): hardcoded password still blocked" \
  "$(verdict f.py "$PW = '$VAL'" with-gitleaks)" "blocked"
check "gitleaks installed: clean code stays clean" \
  "$(verdict g.py "x = 1" with-gitleaks)" "clean"

echo
echo "Secret guard: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
