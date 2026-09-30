#!/usr/bin/env python3
"""requirements.py — the deterministic half of Strata's behaviour specs (P6).

An entity page may carry a `## Requirements` section: `### <title>` per requirement, a
statement, and "- Scenario: … WHEN … THEN … · `test: <path>[::<needle>]`" (or
"`manual: <reason>`") items. A plan that changes specified behaviour carries a
`## Behaviour delta` (`### ADDED|MODIFIED|REMOVED [[entity]]` → `#### <title>` → body) that
light-finish applies to those pages on the branch before integrating — OpenSpec's archive
step, done by the agent. This script never edits a page; it reports (the P4 split, as
diagram_check.sh does). Format: WIKI.md "Requirements and behaviour deltas";
docs/superpowers/specs/2026-09-28-p6-behaviour-specs.md D2–D9.

Usage:
  requirements.py check [--strict]   lint every wiki/entities/*.md Requirements section:
                                     a requirement with no scenario, a scenario without
                                     WHEN/THEN or without exactly one pointer, a `test:` path
                                     that does not exist or a `::needle` not in it, a duplicate
                                     title. `manual:` is counted, never an error. Exit 0; with
                                     --strict, 1 on any error.
  requirements.py owed               the current branch's plan (state_tools.py plan) vs the
                                     wiki: every delta item the pages do not reflect yet, one
                                     line each. Silent + exit 0 when nothing is owed; exit 1
                                     when something is, or the delta is malformed. Run it on the
                                     branch, before integrating. Never writes wiki_debt.

Exit 2 on a usage error. A pointer is proved to RESOLVE, not to pass — running tests is the
floor's and CI's job. Stdlib only.
"""
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
# Importing state_tools would drop scripts/lib/__pycache__/ into the TARGET repo, which may
# not ignore it (seen in an adopted repo after the 0.15.0 rollout).
sys.dont_write_bytecode = True
from state_tools import find_plan  # noqa: E402 — the one plan lookup (spec D5)

VERBS = ("ADDED", "MODIFIED", "REMOVED")
# Any suffix is allowed ("## Behaviour delta (gates)") — a decorated heading must not read as no delta.
DELTA_HEADING = re.compile(r"##\s+behaviou?r\s+delta\b.*", re.IGNORECASE)


def repo_root() -> Path:
    try:
        out = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True, check=True)
        return Path(out.stdout.strip())
    except Exception:
        return Path.cwd()


def unfenced(text: str) -> list:
    """Lines with fenced code blanked out, line numbers kept — a page or spec that SHOWS the
    format must not be parsed as using it. CommonMark fences: ``` or ~~~, closed by the same
    character at least as long, with nothing after it."""
    lines, fence = [], None
    for line in text.splitlines():
        m = re.match(r" {0,3}(`{3,}|~{3,})", line)
        if fence is None:
            if m and not (m.group(1)[0] == "`" and "`" in line[m.end():]):
                fence = m.group(1)
                lines.append("")
            else:
                lines.append(line)
        else:
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence) \
                    and not line[m.end():].strip():
                fence = None
            lines.append("")
    return lines


def section(lines: list, heading):
    """(start, end) of the body under the first `## ` line matching `heading` (a str for an
    exact match, or a compiled pattern), or None."""
    for i, line in enumerate(lines):
        hit = line.strip() == heading if isinstance(heading, str) else heading.fullmatch(line.strip())
        if hit:
            end = next((j for j in range(i + 1, len(lines)) if lines[j].startswith("## ")), len(lines))
            return i + 1, end
    return None


def blocks(lines: list, start: int, end: int, marker: str) -> list:
    """Split lines[start:end] at `<marker> <title>` headings → [(title, lineno, body_lines)].
    Text before the first heading is dropped (a delta's `### ` block, a section's preamble)."""
    out = []
    for i in range(start, end):
        if lines[i].startswith(marker + " "):
            out.append([lines[i][len(marker) + 1:].strip(), i + 1, []])
        elif out:
            out[-1][2].append(lines[i])
    return [tuple(b) for b in out]


def norm(body_lines: list) -> str:
    """The compared body: every line after the heading up to the next heading, whitespace
    runs collapsed to one space, ends trimmed (spec D5)."""
    return " ".join(" ".join(body_lines).split())


def requirements(path: Path) -> list:
    lines = unfenced(path.read_text(encoding="utf-8", errors="replace"))
    span = section(lines, "## Requirements")
    return blocks(lines, *span, "###") if span else []


def scenarios(body_lines: list) -> list:
    """`- Scenario:` items, continuation lines (indented) joined with one space."""
    out, cur = [], None
    for line in body_lines:
        if re.match(r"- (\*\*)?Scenario:", line):
            cur = [line]
            out.append(cur)
        elif cur is not None and line[:1] in (" ", "\t") and line.strip():
            cur.append(line)
        else:
            cur = None
    return [" ".join(s.strip() for s in item) for item in out]


def pointers(scenario: str) -> list:
    """Evidence pointers: code spans whose content starts `test:` or `manual:`. Any other
    code span is text (``WHEN `X=1` is set`` is fine)."""
    out = []
    for span in re.findall(r"`([^`]+)`", scenario):
        m = re.match(r"\s*(test|manual):\s*(.*)$", span)
        if m:
            out.append((m.group(1), m.group(2).strip()))
    return out


# --- check -------------------------------------------------------------------------

def cmd_check(args: list) -> int:
    if args not in ([], ["--strict"]):
        print("usage: requirements.py check [--strict]", file=sys.stderr)
        return 2
    root = repo_root()
    errors, n_req, n_scen, n_manual, n_pages = [], 0, 0, 0, 0

    for page in sorted((root / "wiki" / "entities").glob("*.md")):
        reqs = requirements(page)
        if not reqs:
            continue
        n_pages += 1
        rel = page.relative_to(root)
        seen = set()
        for title, lineno, body in reqs:
            n_req += 1
            where = f"{rel}:{lineno} \"{title}\""
            if title in seen:
                errors.append(f"{where}: duplicate requirement title in this page")
            seen.add(title)
            scen = scenarios(body)
            if not scen:
                errors.append(f"{where}: no scenario (want '- Scenario: … WHEN … THEN … · `test: …`')")
            for s in scen:
                n_scen += 1
                if not (re.search(r"\bWHEN\b", s) and re.search(r"\bTHEN\b", s)):
                    errors.append(f"{where}: scenario lacks WHEN/THEN — {s[:70]}")
                ptrs = pointers(s)
                if not ptrs:
                    errors.append(f"{where}: scenario has no evidence pointer (`test: …` or `manual: …`)")
                elif len(ptrs) > 1:
                    errors.append(f"{where}: scenario has more than one evidence pointer")
                elif ptrs[0][0] == "manual":
                    n_manual += 1
                else:
                    err = resolve(root, ptrs[0][1])
                    if err:
                        errors.append(f"{where}: {err}")

    for e in errors:
        print(f"ERROR {e}")
    if n_pages:
        print(f"requirements: {n_pages} page(s), {n_req} requirement(s), {n_scen} scenario(s), "
              f"{n_manual} manual, {len(errors)} error(s)")
    return 1 if (errors and args == ["--strict"]) else 0


def resolve(root: Path, value: str):
    path, _, needle = value.partition("::")
    path = path.strip()
    if not path or path.startswith("/") or ".." in Path(path).parts:
        return f"test: pointer must be a repo-relative path, got '{value}'"
    target = root / path
    if not target.is_file():
        return f"test: {path} does not exist"
    if needle:
        text = target.read_text(encoding="utf-8", errors="replace")
        # the whole string, or every `::` segment (pytest ids: tests/x.py::TestA::test_b)
        if needle not in text and not all(seg and seg in text for seg in needle.split("::")):
            return f"test: '{needle}' not found in {path}"
    return None


# --- owed --------------------------------------------------------------------------

def delta_items(plan: Path):
    """([(verb, entity, title, body_lines)], [malformed messages]). A typo must never read as
    'no delta' — anything that is not exactly the D3 shape is reported."""
    lines = unfenced(plan.read_text(encoding="utf-8", errors="replace"))
    span = section(lines, DELTA_HEADING)
    if not span:
        return [], []
    items, bad, seen = [], [], set()
    for head, lineno, body in blocks(lines, *span, "###"):
        where = f"{plan.name}:{lineno}"
        m = re.fullmatch(r"(ADDED|MODIFIED|REMOVED)\s+\[\[([^\]\s]+)\]\]", head)
        if not m:
            bad.append(f"behaviour delta: malformed heading '### {head}' at {where} "
                       f"(want '### ADDED|MODIFIED|REMOVED [[entity]]')")
            continue
        verb, entity = m.groups()
        reqs = blocks(body, 0, len(body), "####")
        if not reqs:
            bad.append(f"behaviour delta: '### {head}' at {where} has no #### requirement under it")
        for title, _, rbody in reqs:
            if (entity, title) in seen:
                bad.append(f"behaviour delta: [[{entity}]] \"{title}\" appears twice in the delta")
            seen.add((entity, title))
            items.append((verb, entity, title, rbody))
    return items, bad


def cmd_owed(args: list) -> int:
    if args:
        print("usage: requirements.py owed   (no arguments — run it on the branch, before integrating)",
              file=sys.stderr)
        return 2
    root = repo_root()
    branch = subprocess.run(["git", "rev-parse", "--abbrev-ref", "HEAD"],
                            capture_output=True, text=True).stdout.strip() or "HEAD"
    plan = find_plan(root, branch)
    if plan is None:
        print(f"no plan for {branch} under docs/superpowers/plans/ — nothing to check", file=sys.stderr)
        return 0

    items, owed = delta_items(plan)
    for verb, entity, title, body in items:
        rel = f"wiki/entities/{entity}.md"
        page = root / rel
        if not page.is_file():
            if verb != "REMOVED":
                owed.append(f"behaviour delta: {verb} \"{title}\" → create {rel}")
            continue
        current = {t: b for t, _, b in requirements(page)}
        if verb == "REMOVED":
            if title in current:
                owed.append(f"behaviour delta: REMOVED \"{title}\" → still in {rel}")
        elif title not in current:
            owed.append(f"behaviour delta: {verb} \"{title}\" → not in {rel}")
        elif norm(current[title]) != norm(body):
            owed.append(f"behaviour delta: {verb} \"{title}\" → {rel} body differs from the plan")

    for line in owed:
        print(line)
    return 1 if owed else 0


def main(argv: list) -> int:
    cmds = {"check": cmd_check, "owed": cmd_owed}
    if not argv or argv[0] not in cmds:
        print(__doc__.split("Usage:")[1].split("Exit 2")[0].rstrip(), file=sys.stderr)
        return 2
    return cmds[argv[0]](argv[1:])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
