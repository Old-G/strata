#!/usr/bin/env python3
"""strata_tools.py — CLI over the episodic state layer (.strata/state/<branch-slug>.json).

Why this exists: wiki/log.md is an append-only TRAJECTORY of ingest operations. It answers
"what happened". Nothing in Strata answered "what is true RIGHT NOW about this branch's
in-progress work" — the goal, decisions made and why, open questions, gotchas hit, and — the
missing signal — what still owes the wiki that isn't yet a docs/*.md edit. This file is the
schema + validator + summarizer for that missing object. See
docs/superpowers/specs/2026-09-01-episodic-state-layer.md OQ1 for why validation lives here
(one script owns the schema, same discipline as pending_ingest.sh owns the marker rule) and
not as a per-turn model-emitted patch (SKILL.state's mechanism) — we don't own Claude Code's
inference loop, so that mechanism does not port; the abstraction (explicit, schema-validated,
mutable state) does.

Usage:
  state_tools.py path   <branch>                         # print the file path for <branch>
  state_tools.py init   <branch> --goal "..." [--verify "..."]
  state_tools.py validate <path>                         # exit 0 valid, 1 invalid (stderr: why)
  state_tools.py debt   <path>                            # print wiki_debt entries, one per line
  state_tools.py summary <path>                           # short human summary (SessionStart)

Exit codes: 0 success, 1 validation/usage error, 2 file not found.
No third-party dependencies — stdlib only, matching the rest of this scripts/ tree.
"""
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

REQUIRED_KEYS = {"goal", "status", "branch", "updated"}
ALLOWED_KEYS = REQUIRED_KEYS | {
    "verify", "decisions", "open_questions", "gotchas", "wiki_debt", "files_touched",
}
STATUS_VALUES = {"active", "blocked", "done"}
TRUST_VALUES = {"session", "reviewed"}
DECISION_KEYS = {"what", "why", "evidence", "trust"}


def state_dir(repo_root: Path) -> Path:
    return repo_root / ".strata" / "state"


def slug(branch: str) -> str:
    # Filesystem-safe, deterministic, collision-resistant enough for a per-branch scratch file.
    s = re.sub(r"[^A-Za-z0-9._-]+", "-", branch.strip())
    s = s.strip("-.") or "unknown"
    return s[:120]


def find_repo_root() -> Path:
    import subprocess
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=True
        )
        return Path(out.stdout.strip())
    except Exception:
        return Path.cwd()


def cmd_path(args):
    if not args:
        print("usage: state_tools.py path <branch>", file=sys.stderr)
        return 1
    root = find_repo_root()
    print(state_dir(root) / f"{slug(args[0])}.json")
    return 0


def validate_obj(obj) -> list:
    """Return a list of error strings; empty list means valid."""
    errors = []
    if not isinstance(obj, dict):
        return ["top-level value must be a JSON object"]

    missing = REQUIRED_KEYS - obj.keys()
    if missing:
        errors.append(f"missing required key(s): {', '.join(sorted(missing))}")

    unknown = obj.keys() - ALLOWED_KEYS
    if unknown:
        errors.append(f"unknown top-level key(s): {', '.join(sorted(unknown))}")

    if "status" in obj and obj["status"] not in STATUS_VALUES:
        errors.append(f"status must be one of {sorted(STATUS_VALUES)}, got {obj['status']!r}")

    for key in ("goal", "branch", "updated"):
        if key in obj and not isinstance(obj[key], str):
            errors.append(f"{key} must be a string")

    for key in ("open_questions", "gotchas", "wiki_debt", "files_touched"):
        if key in obj and not (isinstance(obj[key], list) and all(isinstance(x, str) for x in obj[key])):
            errors.append(f"{key} must be an array of strings")

    if "decisions" in obj:
        decisions = obj["decisions"]
        if not isinstance(decisions, list):
            errors.append("decisions must be an array")
        else:
            for i, d in enumerate(decisions):
                if not isinstance(d, dict):
                    errors.append(f"decisions[{i}] must be an object")
                    continue
                dmissing = {"what", "why"} - d.keys()
                if dmissing:
                    errors.append(f"decisions[{i}] missing key(s): {', '.join(sorted(dmissing))}")
                dunknown = d.keys() - DECISION_KEYS
                if dunknown:
                    errors.append(f"decisions[{i}] unknown key(s): {', '.join(sorted(dunknown))}")
                trust = d.get("trust", "session")
                if trust not in TRUST_VALUES:
                    errors.append(f"decisions[{i}].trust must be one of {sorted(TRUST_VALUES)}, got {trust!r}")

    return errors


def cmd_validate(args):
    if not args:
        print("usage: state_tools.py validate <path>", file=sys.stderr)
        return 1
    path = Path(args[0])
    if not path.exists():
        print(f"not found: {path}", file=sys.stderr)
        return 2
    try:
        obj = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"invalid JSON: {e}", file=sys.stderr)
        return 1
    errors = validate_obj(obj)
    if errors:
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1
    return 0


def cmd_init(args):
    if not args:
        print("usage: state_tools.py init <branch> --goal '...' [--verify '...']", file=sys.stderr)
        return 1
    branch = args[0]
    rest = args[1:]
    opts = {}
    i = 0
    while i < len(rest):
        if rest[i] in ("--goal", "--verify") and i + 1 < len(rest):
            opts[rest[i][2:]] = rest[i + 1]
            i += 2
        else:
            i += 1

    root = find_repo_root()
    path = state_dir(root) / f"{slug(branch)}.json"
    path.parent.mkdir(parents=True, exist_ok=True)

    obj = {
        "goal": opts.get("goal", ""),
        "status": "active",
        "branch": branch,
        "updated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "verify": opts.get("verify", ""),
        "decisions": [],
        "open_questions": [],
        "gotchas": [],
        "wiki_debt": [],
        "files_touched": [],
    }
    errors = validate_obj(obj)
    if errors:
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1
    path.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(str(path))
    return 0


def cmd_debt(args):
    if not args:
        print("usage: state_tools.py debt <path>", file=sys.stderr)
        return 1
    path = Path(args[0])
    if not path.exists():
        return 0  # no file = no debt, not an error — the layer stays adoptable incrementally
    try:
        obj = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return 0  # cmd_validate is the source of truth for "corrupt"; debt just reports content
    for item in obj.get("wiki_debt", []) or []:
        print(item)
    return 0


def cmd_summary(args):
    if not args:
        print("usage: state_tools.py summary <path>", file=sys.stderr)
        return 1
    path = Path(args[0])
    if not path.exists():
        return 0
    try:
        obj = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        print("State: ⚠ .strata/state file exists but is not valid JSON — run state_tools.py validate")
        return 0

    goal = (obj.get("goal") or "(no goal recorded)").strip()
    status = obj.get("status", "?")
    oq = len(obj.get("open_questions") or [])
    debt = len(obj.get("wiki_debt") or [])
    decisions = obj.get("decisions") or []
    unreviewed = sum(1 for d in decisions if isinstance(d, dict) and d.get("trust", "session") == "session")

    print(f"Branch state: [{status}] {goal}")
    if decisions:
        print(f"  decisions: {len(decisions)} ({unreviewed} unreviewed)")
    if oq:
        print(f"  open questions: {oq}")
    if debt:
        print(f"  wiki debt: {debt} item(s) owed")
    return 0


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    cmd, rest = argv[0], argv[1:]
    dispatch = {
        "path": cmd_path,
        "init": cmd_init,
        "validate": cmd_validate,
        "debt": cmd_debt,
        "summary": cmd_summary,
    }
    fn = dispatch.get(cmd)
    if fn is None:
        print(f"unknown command: {cmd}", file=sys.stderr)
        return 1
    return fn(rest)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
