#!/usr/bin/env python3
"""Generate a new MCP server from the canonical scaffold (ADR-024).

Usage:
  scripts/scaffold_mcp_server.py --name clickup --prefix CLICKUP --port 8500
"""
import argparse
import sys
from pathlib import Path

TEMPLATE_DIR = Path(__file__).parent / "_scaffold_templates"
ROOT = Path(__file__).parent.parent

def render(template: Path, dest: Path, name: str, prefix: str, port: int) -> None:
    text = template.read_text()
    text = text.replace("__NAME__", name)
    text = text.replace("__PREFIX__", prefix)
    text = text.replace("__PORT__", str(port))
    text = text.replace("__NAME_DASH__", name)  # for paths like services/mcp-server-<name>
    text = text.replace("__NAME_UNDERSCORE__", name.replace("-", "_"))
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(text)

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--name", required=True, help="lowercase, dash-separated (e.g., 'clickup')")
    ap.add_argument("--prefix", required=True, help="UPPERCASE env prefix (e.g., 'CLICKUP')")
    ap.add_argument("--port", type=int, required=True, help="HTTP port (e.g., 8500)")
    ap.add_argument("--out", type=Path, default=ROOT, help="Output root (default: repo root)")
    args = ap.parse_args()

    service_dir = args.out / "services" / f"mcp-server-{args.name}"
    if service_dir.exists():
        print(f"refusing to overwrite existing {service_dir}", file=sys.stderr)
        sys.exit(1)

    name_u = args.name.replace("-", "_")

    # Walk the template dir, render every file
    for template in TEMPLATE_DIR.rglob("*"):
        if not template.is_file():
            continue
        rel = template.relative_to(TEMPLATE_DIR)
        # Substitute placeholders in path
        rel_str = str(rel).replace("__NAME_UNDERSCORE__", name_u)
        dest = service_dir / rel_str
        render(template, dest, args.name, args.prefix, args.port)

    # Create empty .gitkeep markers for empty dirs
    for empty in ["tests/unit", "tests/integration", "tests/contract"]:
        empty_dir = service_dir / empty
        empty_dir.mkdir(parents=True, exist_ok=True)
        (empty_dir / ".gitkeep").touch()

    print(f"✓ Created {service_dir}")
    print(f"  Next: cd {service_dir} && uv sync && uv run pytest")

if __name__ == "__main__":
    main()
