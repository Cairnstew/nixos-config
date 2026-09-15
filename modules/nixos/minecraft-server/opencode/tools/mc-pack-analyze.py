#!/usr/bin/env python3
"""mc-pack-analyze — Run all extraction tools and merge into a single JSON.

Orchestrates ore, mobs, mobspawn, items, attributes, loot, and recipes
against a packwiz modpack, producing one unified analysis document.

Usage:
    python3 mc-pack-analyze.py <modpack-dir> [--tools ore,mobs,...] [--full-export [file]]

Each sub-tool is invoked with --json; their outputs are merged under a
top-level key per tool. The result is written to stdout or a file.
"""
import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

TOOLS_DIR = Path(__file__).parent
ALL_TOOLS = ["ore", "mobs", "mobspawn", "items", "attributes", "loot", "recipes"]

# Map tool name → (python script, extra args)
TOOL_CONFIG = {
    "ore":       ("ore.py", []),
    "mobs":      ("mobs.py", []),
    "mobspawn":  ("mobspawn.py", []),
    "items":     ("items.py", []),
    "attributes": ("attributes.py", []),
    "loot":      ("loot.py", []),
    "recipes":   ("recipes.py", []),
}


def die(msg: str) -> None:
    print(f"mc-pack-analyze: {msg}", file=sys.stderr)
    sys.exit(1)


def run_tool(tool_name: str, pack_dir: Path, timeout: int = 300) -> dict | None:
    """Run a single extraction tool and return its JSON output."""
    script, extra_args = TOOL_CONFIG[tool_name]
    script_path = TOOLS_DIR / script
    if not script_path.exists():
        print(f"  [SKIP] {tool_name}: {script} not found", file=sys.stderr)
        return None

    cmd = [sys.executable, str(script_path), str(pack_dir), "--json"] + extra_args
    print(f"  [{tool_name}] running...", file=sys.stderr, end="", flush=True)
    start = time.time()

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        elapsed = time.time() - start

        if result.returncode != 0:
            stderr_short = result.stderr.strip()[:200]
            print(f" FAILED ({elapsed:.1f}s): {stderr_short}", file=sys.stderr)
            return {"error": result.stderr.strip(), "tool": tool_name}

        try:
            data = json.loads(result.stdout)
            print(f" OK ({elapsed:.1f}s)", file=sys.stderr)
            return data
        except json.JSONDecodeError as e:
            print(f" JSON parse error ({elapsed:.1f}s): {e}", file=sys.stderr)
            return {"error": f"JSON parse failed: {e}", "tool": tool_name, "raw": result.stdout[:500]}

    except subprocess.TimeoutExpired:
        elapsed = time.time() - start
        print(f" TIMEOUT ({elapsed:.1f}s)", file=sys.stderr)
        return {"error": f"timeout after {timeout}s", "tool": tool_name}
    except Exception as e:
        print(f" ERROR: {e}", file=sys.stderr)
        return {"error": str(e), "tool": tool_name}


def main():
    parser = argparse.ArgumentParser(
        description="Run all extraction tools and merge into a single JSON document"
    )
    parser.add_argument("modpack_dir", help="Path to the packwiz modpack directory")
    parser.add_argument(
        "--tools", default=",".join(ALL_TOOLS),
        help=f"Comma-separated list of tools to run (default: all). Available: {','.join(ALL_TOOLS)}"
    )
    parser.add_argument(
        "--full-export", nargs="?", const=True, default=False, metavar="FILE",
        help="Write merged output to a file (default: <packname>-analyze.json)"
    )
    parser.add_argument(
        "--timeout", type=int, default=300,
        help="Per-tool timeout in seconds (default: 300)"
    )
    args = parser.parse_args()

    pack_dir = Path(args.modpack_dir).resolve()
    if not (pack_dir / "pack.toml").exists():
        die(f"{pack_dir}/pack.toml not found — is this a modpack directory?")

    # Parse tool list
    requested = [t.strip() for t in args.tools.split(",") if t.strip()]
    tools_to_run = [t for t in requested if t in ALL_TOOLS]
    invalid = [t for t in requested if t not in ALL_TOOLS]
    if invalid:
        print(f"  [WARN] unknown tools skipped: {', '.join(invalid)}", file=sys.stderr)

    if not tools_to_run:
        die("no valid tools to run")

    print(f"mc-pack-analyze: {pack_dir.name} — running {len(tools_to_run)} tools", file=sys.stderr)
    print(f"  tools: {', '.join(tools_to_run)}", file=sys.stderr)

    overall_start = time.time()
    results = {}
    errors = []

    for tool_name in tools_to_run:
        data = run_tool(tool_name, pack_dir, timeout=args.timeout)
        if data is not None:
            results[tool_name] = data
            if "error" in data:
                errors.append(tool_name)

    overall_elapsed = time.time() - overall_start

    # Build merged document
    output = {
        "modpack": pack_dir.name,
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "tools_run": tools_to_run,
        "tools_succeeded": [t for t in tools_to_run if t not in errors],
        "tools_failed": errors,
        "elapsed_seconds": round(overall_elapsed, 1),
    }
    output.update(results)

    # Write output
    if args.full_export is not False:
        outfile = args.full_export if isinstance(args.full_export, str) else f"{pack_dir.name}-analyze.json"
        outpath = pack_dir / outfile if not os.path.isabs(outfile) else Path(outfile)
        with open(outpath, "w") as f:
            json.dump(output, f, indent=2)
        print(f"\nmc-pack-analyze: wrote {outpath} ({os.path.getsize(outpath):,} bytes)", file=sys.stderr)
    else:
        json.dump(output, sys.stdout, indent=2)
        print()

    print(f"mc-pack-analyze: done in {overall_elapsed:.1f}s — "
          f"{len(tools_to_run) - len(errors)}/{len(tools_to_run)} succeeded", file=sys.stderr)


if __name__ == "__main__":
    main()
