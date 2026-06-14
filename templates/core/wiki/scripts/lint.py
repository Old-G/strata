#!/usr/bin/env python3
"""Wiki lint — drift, orphan, and freshness checks for the Karpathy-wiki.

Run from repo root: `python wiki/scripts/lint.py`.

Checks performed:

* **wikilinks**       — every `[[slug]]` reference points at a real
  `wiki/<dir>/<slug>.md`. Allowed dirs: entities, decisions, sources,
  sessions.
* **index sync**      — every file linked from `wiki/index.md` exists,
  and every wiki file (except `index.md`/`log.md`/`overview.md`/
  `glossary.md`) is mentioned in the index.
* **orphans**         — every entity/decision page has at least one
  inbound `[[slug]]` reference from another wiki page OR is linked from
  `index.md`. Pure index references count as weak, so we still warn
  when no other page links it.
* **source freshness** — for each `wiki/sources/<slug>.md` with frontmatter
  field `source: raw/<file>.md`, compare the source page's `updated:`
  field (or its mtime) against the `raw/` file's mtime. If raw is newer
  by >7 days, flag as stale.
* **frontmatter**     — first 2 chars are `---`; YAML parses; required
  fields present per page kind (entities/sources/decisions).

Exit code 0 on clean run, 1 on any error, 2 on warnings only.

Output also appended to `wiki/log.md` as a `## YYYY-MM-DDThh:mm:ssZ lint`
block.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

try:
    import yaml  # PyYAML is already a transitive dep across services
except ImportError:
    print("lint: PyYAML missing — `pip install pyyaml`", file=sys.stderr)
    sys.exit(1)


WIKI = Path("wiki")
RAW = Path("raw")
FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)
WIKILINK_RE = re.compile(r"\[\[([a-z0-9][a-z0-9_-]*)\]\]")
MD_LINK_RE = re.compile(r"\]\(([^)]+\.md)(#[^)]*)?\)")
SCANNED_DIRS = ("entities", "decisions", "sources", "sessions")
STALE_THRESHOLD_DAYS = 7


@dataclass
class Finding:
    level: str   # "error" | "warning"
    file: str
    msg: str

    def fmt(self) -> str:
        icon = "❌" if self.level == "error" else "⚠️ "
        return f"{icon} {self.file}: {self.msg}"


@dataclass
class LintReport:
    findings: list[Finding] = field(default_factory=list)

    def err(self, file: str, msg: str) -> None:
        self.findings.append(Finding("error", file, msg))

    def warn(self, file: str, msg: str) -> None:
        self.findings.append(Finding("warning", file, msg))

    @property
    def errors(self) -> list[Finding]:
        return [f for f in self.findings if f.level == "error"]

    @property
    def warnings(self) -> list[Finding]:
        return [f for f in self.findings if f.level == "warning"]

    def exit_code(self) -> int:
        if self.errors:
            return 1
        if self.warnings:
            return 2
        return 0


def parse_frontmatter(text: str) -> tuple[dict, str]:
    m = FRONTMATTER_RE.match(text)
    if not m:
        return {}, text
    raw_yaml = m.group(1)
    try:
        data = yaml.safe_load(raw_yaml) or {}
        if not isinstance(data, dict):
            data = {}
    except yaml.YAMLError:
        data = {}
    return data, text[m.end():]


def find_wiki_files() -> dict[str, list[Path]]:
    out: dict[str, list[Path]] = {d: [] for d in SCANNED_DIRS}
    for d in SCANNED_DIRS:
        sub = WIKI / d
        if not sub.is_dir():
            continue
        out[d] = sorted(p for p in sub.glob("*.md"))
    return out


def slug_of(p: Path) -> str:
    return p.stem


def known_slugs(files: dict[str, list[Path]]) -> set[str]:
    s = set()
    for paths in files.values():
        s.update(slug_of(p) for p in paths)
    return s


def _strip_code_blocks(text: str) -> str:
    """Remove fenced code blocks and inline backtick spans before scanning
    for wikilinks. Pages that document the `[[slug]]` syntax (e.g. WIKI.md
    examples in karpathy-wiki.md) would otherwise produce false positives."""
    text = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
    text = re.sub(r"`[^`\n]+`", "", text)
    return text


def check_wikilinks(
    files: dict[str, list[Path]],
    slugs: set[str],
    planned_slugs: set[str],
    rpt: LintReport,
) -> None:
    for d, paths in files.items():
        for p in paths:
            try:
                text = p.read_text(encoding="utf-8")
            except Exception as e:
                rpt.err(str(p), f"unreadable: {e}")
                continue
            scan = _strip_code_blocks(text)
            for m in WIKILINK_RE.finditer(scan):
                target = m.group(1)
                if target in slugs:
                    continue
                if target in planned_slugs:
                    # Declared as planned stub in index.md ⏳ section.
                    # Forward declaration, not a bug.
                    continue
                rpt.err(str(p), f"broken wikilink [[{target}]] — no wiki page with that slug")


_FRONTMATTER_FENCE = re.compile(r"^---\n.*?\n---\n", re.DOTALL)


def check_frontmatter(files: dict[str, list[Path]], rpt: LintReport) -> None:
    """Require that pages start with a frontmatter fence (`---` ... `---`).

    We deliberately do NOT require the body to be valid YAML — the wiki
    convention uses `links: [[slug]], [[slug]]` which is not parseable
    as YAML flow sequences (the `[[...]]` syntax is a wiki-link, not
    YAML). Source-freshness validation handles its own parse needs and
    fails silently when the YAML is unreadable.
    """
    for d, paths in files.items():
        for p in paths:
            try:
                text = p.read_text(encoding="utf-8")
            except Exception:
                continue
            if not _FRONTMATTER_FENCE.match(text):
                rpt.warn(str(p), "missing frontmatter fence (--- ... ---)")


def check_orphans(files: dict[str, list[Path]], rpt: LintReport) -> None:
    """An entity/decision is orphaned if no other wiki page references it via
    [[slug]] AND it isn't linked from index.md.

    Sources are not flagged as orphans — they're terminal nodes by design.
    """
    inbound: dict[str, set[Path]] = {}
    for d, paths in files.items():
        for p in paths:
            try:
                text = p.read_text(encoding="utf-8")
            except Exception:
                continue
            for m in WIKILINK_RE.finditer(text):
                target = m.group(1)
                inbound.setdefault(target, set()).add(p)

    index_path = WIKI / "index.md"
    index_text = index_path.read_text(encoding="utf-8") if index_path.exists() else ""

    for d in ("entities", "decisions"):
        for p in files.get(d, []):
            slug = slug_of(p)
            # Self-refs don't count.
            refs = {r for r in inbound.get(slug, set()) if r != p}
            in_index = (
                f"({d}/{slug}.md)" in index_text
                or f"`{d}/{slug}.md`" in index_text
                or f"[[{slug}]]" in index_text
            )
            if not refs and not in_index:
                rpt.warn(str(p), f"orphan: not referenced by any other wiki page nor index.md")


_INDEX_BACKTICK_RE = re.compile(r"`((?:entities|decisions|sources|sessions)/[^`]+\.md)`")
# Entries explicitly marked with ⏳ are planned stubs — the wiki declares
# them as "to be created on next ingest". We don't flag those as broken,
# but we DO surface them as planned (info) so they show up in the report.
_INDEX_PLANNED_LINE_RE = re.compile(
    r"`((?:entities|decisions|sources|sessions)/[^`]+\.md)`\s*⏳"
)


def _read_index_state(index_text: str) -> tuple[set[str], set[str], set[str]]:
    """Return (all_mentioned, planned_paths, planned_slugs)."""
    mentioned: set[str] = set()
    for m in MD_LINK_RE.finditer(index_text):
        href = m.group(1)
        if href.startswith("http"):
            continue
        cand = (WIKI / href).resolve()
        try:
            rel = cand.relative_to(WIKI.resolve())
            mentioned.add(str(rel))
        except ValueError:
            pass
    for m in _INDEX_BACKTICK_RE.finditer(index_text):
        mentioned.add(m.group(1))

    planned_paths = {m.group(1) for m in _INDEX_PLANNED_LINE_RE.finditer(index_text)}
    planned_slugs = {Path(p).stem for p in planned_paths}
    return mentioned, planned_paths, planned_slugs


def check_index_sync(
    files: dict[str, list[Path]],
    rpt: LintReport,
    mentioned: set[str],
    planned_paths: set[str],
) -> None:
    index_path = WIKI / "index.md"
    if not index_path.exists():
        rpt.err(str(index_path), "missing")
        return

    # Broken: index points at file that doesn't exist AND isn't explicitly
    # marked as a planned stub. Planned ⏳ entries are intentional forward
    # declarations and stay silent.
    for ref in sorted(mentioned):
        if (WIKI / ref).exists():
            continue
        if ref in planned_paths:
            continue
        rpt.err(str(index_path), f"references missing file: {ref}")

    # Missing: file exists but not in index (exclude meta files).
    exclude_names = {"index.md", "log.md", "overview.md", "glossary.md"}
    for d, paths in files.items():
        for p in paths:
            rel = f"{d}/{p.name}"
            if p.name in exclude_names:
                continue
            if rel not in mentioned:
                rpt.warn(str(p), f"not listed in wiki/index.md (rel: {rel})")


def check_source_freshness(files: dict[str, list[Path]], rpt: LintReport) -> None:
    for p in files.get("sources", []):
        try:
            text = p.read_text(encoding="utf-8")
        except Exception:
            continue
        fm, _ = parse_frontmatter(text)
        src = fm.get("source")
        if not src or not isinstance(src, str):
            continue
        # Accept both "raw/foo.md" and just "foo.md".
        src_path = Path(src) if src.startswith("raw/") else (RAW / src)
        if not src_path.exists():
            rpt.err(str(p), f"frontmatter source: {src} — file not found")
            continue
        raw_mtime = _dt.datetime.utcfromtimestamp(src_path.stat().st_mtime).date()
        wiki_updated_raw = fm.get("updated") or fm.get("last_ingested")
        wiki_date = _coerce_date(wiki_updated_raw) or _dt.datetime.utcfromtimestamp(p.stat().st_mtime).date()
        delta = (raw_mtime - wiki_date).days
        if delta > STALE_THRESHOLD_DAYS:
            rpt.warn(
                str(p),
                f"stale: raw/{src_path.name} updated {raw_mtime}, wiki page {wiki_date} ({delta} days behind)",
            )


_OVERWRITE_SHRINK_THRESHOLD = 0.40  # if file shrank by ≥40% in one commit


def check_entity_overwrites(files: dict[str, list[Path]], rpt: LintReport) -> None:
    """Detect destructive entity overwrites via git history.

    Catches the Andrey-pattern: ingesting a new doc that uses the same
    `entities/<slug>.md` filename for a different concept silently
    replaces the prior content. The new file is usually much smaller
    (different scope) — we flag any single-commit shrink of ≥40%.

    Only warns — intentional rewrites/cleanups will trigger this too.
    Inspect with `git log -p -- <path>` and decide if the change was
    correct. To silence permanently, add `allow_shrink: true` to the
    page's frontmatter.
    """
    import subprocess

    try:
        subprocess.run(
            ["git", "rev-parse", "--git-dir"],
            check=True,
            capture_output=True,
            text=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        # Not a git repo (or git missing) — skip silently.
        return

    for d in ("entities", "decisions"):
        for p in files.get(d, []):
            try:
                text = p.read_text(encoding="utf-8")
            except Exception:
                continue
            fm, _ = parse_frontmatter(text)
            if fm.get("allow_shrink") is True:
                continue

            # Get the last 2 commit SHAs that touched this file.
            try:
                out = subprocess.run(
                    ["git", "log", "--format=%H", "-n", "2", "--", str(p)],
                    check=True,
                    capture_output=True,
                    text=True,
                )
            except subprocess.CalledProcessError:
                continue
            shas = [s for s in out.stdout.strip().splitlines() if s]
            if len(shas) < 2:
                continue  # first version, nothing to compare
            new_sha, prev_sha = shas[0], shas[1]

            try:
                new_blob = subprocess.run(
                    ["git", "show", f"{new_sha}:{p}"],
                    check=True,
                    capture_output=True,
                    text=True,
                ).stdout
                prev_blob = subprocess.run(
                    ["git", "show", f"{prev_sha}:{p}"],
                    check=True,
                    capture_output=True,
                    text=True,
                ).stdout
            except subprocess.CalledProcessError:
                continue

            prev_len, new_len = len(prev_blob), len(new_blob)
            if prev_len == 0:
                continue
            shrink_ratio = (prev_len - new_len) / prev_len
            if shrink_ratio >= _OVERWRITE_SHRINK_THRESHOLD:
                rpt.warn(
                    str(p),
                    f"potential overwrite: {prev_len}→{new_len} chars "
                    f"({shrink_ratio*100:.0f}% shrink) in {new_sha[:8]} (prev {prev_sha[:8]}). "
                    f"Inspect: `git log -p {new_sha} -- {p}`. "
                    f"If intentional, add `allow_shrink: true` to frontmatter.",
                )


def _coerce_date(v) -> _dt.date | None:
    if v is None:
        return None
    if isinstance(v, _dt.date) and not isinstance(v, _dt.datetime):
        return v
    if isinstance(v, _dt.datetime):
        return v.date()
    if isinstance(v, str):
        for fmt in ("%Y-%m-%d", "%Y/%m/%d"):
            try:
                return _dt.datetime.strptime(v, fmt).date()
            except ValueError:
                pass
    return None


def append_log(report: LintReport, dry_run: bool) -> None:
    if dry_run:
        return
    log = WIKI / "log.md"
    ts = _dt.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    n_err = len(report.errors)
    n_warn = len(report.warnings)
    lines = [
        "",
        f"## {ts} lint",
        "",
        f"- errors: {n_err}, warnings: {n_warn}",
    ]
    if report.findings:
        lines.append("")
        for f in report.findings[:50]:
            lines.append(f"  - {f.fmt()}")
        if len(report.findings) > 50:
            lines.append(f"  - ... ({len(report.findings) - 50} more)")
    with log.open("a", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")


# === Semantic drift checks (ADR-025 quick win #1) =========================
#
# Manifest of "wiki claim ↔ source-of-truth" pairs the lint should cross-check.
# Format per entry:
#   entity:        wiki entity page that makes the claim
#   claim_pattern: regex with one capture group yielding the claimed count
#                  (the page may state the count multiple times; we accept any
#                  match, and warn if any of them disagrees with source)
#   source:        path glob to the upstream source-of-truth (first match wins)
#   source_count:  regex counted against the source file's lines (matches → count)
#   description:   human label for the drift warning
#
# Keep this list short and high-signal: only checks where drift would matter
# operationally. Add new pairs when a real drift incident happens, not
# speculatively.
SEMANTIC_DRIFT_CHECKS: list[dict] = [
    {
        "entity": "wiki/entities/mcp-server-odoo.md",
        "claim_pattern": r"\b(\d+)\s+tools?\b",
        "source": "services/mcp-server-odoo/src/server.py",
        "source_count": r"@\w+\.tool\(",
        "description": "mcp-server-odoo tool count (entity claim vs @*.tool() in server.py)",
    },
    {
        "entity": "wiki/entities/pay-admin-mcp.md",
        "claim_pattern": r"\b(\d+)\s+tools?\b",
        "source": "services/mcp-server-pay/src/server.py",
        "source_count": r"@\w+\.tool\(",
        "description": "pay-admin-mcp tool count (entity claim vs @*.tool() in server.py)",
    },
    {
        "entity": "wiki/entities/mcp-priority.md",
        "claim_pattern": r"\*\*(\d+)\s+tools?\*\*",
        "source": "services/mcp-server-priority/server.py",
        "source_count": r"@\w+\.tool\(",
        "description": "mcp-priority tool count (entity bold claim vs @*.tool() in server.py)",
    },
]


def check_semantic_drift(rpt: LintReport) -> None:
    """For each manifest entry, compare wiki claim against actual source count.

    Defensive failure mode: if entity is missing, source is missing, or no
    claim/source matches were found → silently skip (no false positives on
    services that live in a separate gitignored repo). Only WARN when both
    sides parse cleanly and disagree.
    """
    for check in SEMANTIC_DRIFT_CHECKS:
        entity_p = Path(check["entity"])
        if not entity_p.exists():
            continue
        source_p = Path(check["source"])
        if not source_p.exists():
            # Source lives in a sibling gitignored repo (e.g. mcp-server-*),
            # or hasn't been checked out here. Don't false-positive.
            continue
        try:
            entity_text = entity_p.read_text(encoding="utf-8")
            source_text = source_p.read_text(encoding="utf-8")
        except OSError:
            continue

        claim_matches = re.findall(check["claim_pattern"], entity_text)
        if not claim_matches:
            continue
        claimed_counts = {int(c) for c in claim_matches}

        actual = len(re.findall(check["source_count"], source_text))
        if actual == 0:
            continue  # source pattern didn't match anything — likely wrong pattern, skip

        if actual not in claimed_counts:
            claimed_str = "/".join(str(c) for c in sorted(claimed_counts))
            rpt.warn(
                check["entity"],
                f"semantic drift — {check['description']}: "
                f"page says {claimed_str}, source `{check['source']}` has {actual}",
            )


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-log", action="store_true", help="don't append result to wiki/log.md")
    ap.add_argument("--quiet", action="store_true", help="suppress per-finding output")
    args = ap.parse_args(argv)

    if not WIKI.is_dir():
        print(f"lint: {WIKI} not found — run from repo root", file=sys.stderr)
        return 1

    files = find_wiki_files()
    slugs = known_slugs(files)
    rpt = LintReport()

    index_path = WIKI / "index.md"
    index_text = index_path.read_text(encoding="utf-8") if index_path.exists() else ""
    mentioned, planned_paths, planned_slugs = _read_index_state(index_text)

    check_wikilinks(files, slugs, planned_slugs, rpt)
    check_frontmatter(files, rpt)
    check_orphans(files, rpt)
    check_index_sync(files, rpt, mentioned, planned_paths)
    check_source_freshness(files, rpt)
    check_entity_overwrites(files, rpt)
    check_semantic_drift(rpt)

    if planned_slugs:
        print(f"info: {len(planned_slugs)} planned stub(s) declared in wiki/index.md ⏳ section "
              f"(not flagged as missing)")

    if not args.quiet:
        for f in rpt.findings:
            print(f.fmt())

    print()
    print(f"lint: {len(rpt.errors)} error(s), {len(rpt.warnings)} warning(s)")
    append_log(rpt, dry_run=args.no_log)
    return rpt.exit_code()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
