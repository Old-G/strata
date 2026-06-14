#!/usr/bin/env sh
# check_secrets.sh — Strata pre-commit secret guard.
#
# Blocks a commit if staged content looks like a leaked secret or a committed .env.
# Prefers `gitleaks` when present (authoritative); otherwise falls back to portable
# grep patterns. POSIX sh, no hard dependencies beyond git + grep.
#
# Wired by .pre-commit-config.yaml as a local hook, or callable directly:
#   sh scripts/pre-commit/check_secrets.sh
#
# Exit 1 on any hit (commit blocked); exit 0 when clean.

set -u

RED='\033[0;31m'; YEL='\033[0;33m'; NC='\033[0m'
fail() { printf "${RED}✗ secret-guard: %s${NC}\n" "$1" >&2; }
warn() { printf "${YEL}! secret-guard: %s${NC}\n" "$1" >&2; }

# Files staged for commit (added/copied/modified), excluding deletions.
STAGED="$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)"
[ -z "$STAGED" ] && exit 0

HITS=0

# --- Hard block: a real .env (or .env.<env>) being committed. .env.example is fine. ---
for f in $STAGED; do
  case "$f" in
    *.env|.env|.env.*)
      case "$f" in
        *.env.example|*.env.sample|*.env.template) : ;;
        *) fail "refusing to commit env file: $f  (add it to .gitignore)"; HITS=$((HITS+1)) ;;
      esac
      ;;
  esac
done

# --- Prefer gitleaks if installed (scans staged changes). ---
if command -v gitleaks >/dev/null 2>&1; then
  if ! gitleaks protect --staged --redact --no-banner >/dev/null 2>&1; then
    fail "gitleaks flagged staged content — run 'gitleaks protect --staged --verbose' to inspect"
    HITS=$((HITS+1))
  fi
  [ "$HITS" -gt 0 ] && exit 1
  exit 0
fi

# --- Fallback: grep patterns over the staged diff (added lines only). ---
warn "gitleaks not found — using built-in grep patterns (install gitleaks for stronger coverage)"

# Collect only added lines (leading '+', excluding the '+++' file header).
ADDED="$(git diff --cached --unified=0 --diff-filter=ACM 2>/dev/null \
          | grep -E '^\+' | grep -Ev '^\+\+\+' | sed 's/^\+//')"
[ -z "$ADDED" ] && { [ "$HITS" -gt 0 ] && exit 1; exit 0; }

# pattern|human-readable label
PATTERNS="
-----BEGIN [A-Z ]*PRIVATE KEY-----|private key block
AKIA[0-9A-Z]{16}|AWS access key id
ASIA[0-9A-Z]{16}|AWS temporary access key id
aws_secret_access_key[[:space:]]*=[[:space:]]*[A-Za-z0-9/+]{40}|AWS secret access key
gh[pousr]_[A-Za-z0-9]{36,}|GitHub token
glpat-[A-Za-z0-9_-]{20,}|GitLab personal access token
xox[baprs]-[A-Za-z0-9-]{10,}|Slack token
sk-[A-Za-z0-9]{20,}|OpenAI-style API key
sk-ant-[A-Za-z0-9_-]{20,}|Anthropic API key
AIza[0-9A-Za-z_-]{35}|Google API key
eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|JWT
password[\"' ]*[:=][\"' ]*[A-Za-z0-9/+=_.-]{8,}|hardcoded password
passwd[\"' ]*[:=][\"' ]*[A-Za-z0-9/+=_.-]{8,}|hardcoded passwd
secret[\"' ]*[:=][\"' ]*[A-Za-z0-9/+=_.-]{12,}|hardcoded secret
api[_-]?key[\"' ]*[:=][\"' ]*[A-Za-z0-9/+=_.-]{12,}|hardcoded api key
"

# Use `grep -e "$pat"` so patterns that start with '-' (e.g. PEM headers) are
# treated as patterns, not options. The loop runs in a subshell, so signal a
# match via exit 7 and re-read $? after the pipeline.
if printf '%s\n' "$PATTERNS" | while IFS='|' read -r pat label; do
     [ -z "$pat" ] && continue
     if printf '%s\n' "$ADDED" | grep -Eiq -e "$pat"; then
       fail "possible $label in staged changes"
       exit 7
     fi
   done; [ $? -eq 7 ]; then
  HITS=$((HITS+1))
fi

if [ "$HITS" -gt 0 ]; then
  fail "commit blocked. Move secrets to .env (gitignored). To override a false positive, commit with --no-verify and document why."
  exit 1
fi

exit 0
