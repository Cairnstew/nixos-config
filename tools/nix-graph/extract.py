#!/usr/bin/env python3
"""
extract.py — Static Nix file graph extraction for nixos-config.

Extraction strategy: tree-sitter-nix for structural data (imports,
option declarations, mk* occurrences), falling back to regex for
files where the grammar version produces incorrect byte offsets
for let-binding attrpaths and apply_expression function nodes.

The fallback is file-level, not field-level: if tree-sitter parses
a file with incorrect byte offsets (detected by comparing node.text
output against byte-indexed extraction on the first function_expression),
we fall back to regex for that entire file.

Usage (ephemeral nix shell):
  nix shell nixpkgs#python3 nixpkgs#python313Packages.tree-sitter \\
    nixpkgs#python313Packages.tree-sitter-grammars.tree-sitter-nix \\
    nixpkgs#python313Packages.pydantic \\
    nixpkgs#python313Packages.tree-sitter-config \\
    -c bash -c '
      export PYTHONPATH=$(find /nix/store/*python3.13* -name site-packages \\
        -type d | tr "\\n" ":"):$(find /nix/store/*tree-sitter* \\
        -name site-packages -type d | tr "\\n" ":"):$PYTHONPATH
      python3 extract.py --v1-scope --validate
    '
"""

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(
    os.environ.get("REPO_ROOT", "/home/seanc/nixos-config")
).resolve()

# ── V1 scope file list ─────────────────────────────────────────────────────

V1_SCOPE = [
    "modules/nixos/common.nix",
    "modules/nixos/tailscale/default.nix",
    "modules/nixos/tailscale/options.nix",
    "modules/nixos/tailscale/config.nix",
    "modules/nixos/tailscale/meta.nix",
    "modules/nixos/tailscale/tests.nix",
    "modules/nixos/tailscale/manager.nix",
    "modules/nixos/docker/default.nix",
    "modules/nixos/docker/options.nix",
    "modules/nixos/docker/config.nix",
    "modules/nixos/docker/meta.nix",
    "modules/nixos/docker/tests.nix",
    "modules/nixos/profiles/default.nix",
    "modules/nixos/profiles/meta.nix",
    "modules/nixos/profiles/tests.nix",
    "modules/nixos/profiles/system/default.nix",
    "modules/nixos/profiles/system/workstation.nix",
    "modules/nixos/profiles/system/server.nix",
    "modules/nixos/profiles/system/minimal.nix",
    "modules/nixos/profiles/system/development.nix",
    "modules/nixos/profiles/system/entertainment.nix",
    "modules/nixos/profiles/system/gaming.nix",
    "modules/nixos/profiles/home/default.nix",
    "modules/nixos/profiles/home/common.nix",
    "modules/nixos/profiles/home/desktop.nix",
    "modules/nixos/profiles/home/development.nix",
    "modules/nixos/profiles/home/minimal.nix",
    "modules/nixos/hyprland/default.nix",
    "modules/nixos/hyprland/options.nix",
    "modules/nixos/hyprland/meta.nix",
    "modules/nixos/hyprland/tests.nix",
    "modules/nixos/hyprland/enable.nix",
    "modules/nixos/hyprland/core/options.nix",
    "modules/nixos/hyprland/core/config.nix",
    "modules/nixos/hyprland/core/default.nix",
    "modules/nixos/hyprland/bar/options.nix",
    "modules/nixos/hyprland/bar/config.nix",
    "modules/nixos/hyprland/bar/default.nix",
    "modules/nixos/hyprland/launcher/options.nix",
    "modules/nixos/hyprland/launcher/config.nix",
    "modules/nixos/hyprland/launcher/default.nix",
    "modules/nixos/hyprland/notifications/options.nix",
    "modules/nixos/hyprland/notifications/config.nix",
    "modules/nixos/hyprland/notifications/default.nix",
    "modules/nixos/hyprland/lockscreen/options.nix",
    "modules/nixos/hyprland/lockscreen/config.nix",
    "modules/nixos/hyprland/lockscreen/default.nix",
    "modules/nixos/hyprland/screenshot/options.nix",
    "modules/nixos/hyprland/screenshot/config.nix",
    "modules/nixos/hyprland/screenshot/default.nix",
    "modules/nixos/hyprland/clipboard/options.nix",
    "modules/nixos/hyprland/clipboard/config.nix",
    "modules/nixos/hyprland/clipboard/default.nix",
    "modules/nixos/hyprland/portal/options.nix",
    "modules/nixos/hyprland/portal/config.nix",
    "modules/nixos/hyprland/portal/default.nix",
    "modules/nixos/hyprland/display-manager/options.nix",
    "modules/nixos/hyprland/display-manager/config.nix",
    "modules/nixos/hyprland/display-manager/default.nix",
    "modules/nixos/hyprland/audio/options.nix",
    "modules/nixos/hyprland/audio/config.nix",
    "modules/nixos/hyprland/audio/default.nix",
    "modules/nixos/hyprland/utilities/options.nix",
    "modules/nixos/hyprland/utilities/config.nix",
    "modules/nixos/hyprland/utilities/default.nix",
    "modules/nixos/hyprland/nvidia/options.nix",
    "modules/nixos/hyprland/nvidia/config.nix",
    "modules/nixos/hyprland/nvidia/default.nix",
    "modules/nixos/hyprland/idle/options.nix",
    "modules/nixos/hyprland/idle/config.nix",
    "modules/nixos/hyprland/idle/default.nix",
    "modules/nixos/hyprland/colorpicker/options.nix",
    "modules/nixos/hyprland/colorpicker/config.nix",
    "modules/nixos/hyprland/colorpicker/default.nix",
    "modules/nixos/hyprland/night-light/options.nix",
    "modules/nixos/hyprland/night-light/config.nix",
    "modules/nixos/hyprland/night-light/default.nix",
    "modules/nixos/hyprland/pyprland/options.nix",
    "modules/nixos/hyprland/pyprland/config.nix",
    "modules/nixos/hyprland/pyprland/default.nix",
    "modules/nixos/hyprland/awww/options.nix",
    "modules/nixos/hyprland/awww/config.nix",
    "modules/nixos/hyprland/awww/default.nix",
    "modules/nixos/hyprland/wallpapers/options.nix",
    "modules/nixos/hyprland/wallpapers/config.nix",
    "modules/nixos/hyprland/wallpapers/default.nix",
    "modules/nixos/hyprland/wallpaper/options.nix",
    "modules/nixos/hyprland/wallpaper/config.nix",
    "modules/nixos/hyprland/wallpaper/default.nix",
    "modules/home/bash.nix",
    "modules/home/core/git.nix",
    "modules/home/core/default.nix",
    "modules/home/core/meta.nix",
    "modules/home/core/agenix.nix",
    "modules/home/core/nix.nix",
    "modules/home/opencode/default.nix",
    "modules/home/opencode/options.nix",
    "modules/home/opencode/config.nix",
    "modules/home/opencode/meta.nix",
    "modules/home/opencode/tests.nix",
    "modules/home/opencode/providers.nix",
    "configurations/nixos/desktop/default.nix",
    "configurations/nixos/desktop/configuration.nix",
    "configurations/nixos/desktop/hardware-configuration.nix",
    "configurations/nixos/desktop/disk-config.nix",
    "configurations/nixos/laptop/default.nix",
    "configurations/nixos/laptop/configuration.nix",
    "configurations/nixos/laptop/hardware-configuration.nix",
    "configurations/nixos/laptop/disk-config.nix",
    "configurations/nixos/server/default.nix",
    "configurations/nixos/server/configuration.nix",
    "configurations/nixos/server/hardware-configuration.nix",
    "configurations/nixos/server/disk-config.nix",
    "configurations/nixos/minimal/default.nix",
    "configurations/nixos/minimal/configuration.nix",
    "configurations/nixos/minimal/hardware-configuration.nix",
    "configurations/nixos/minimal/disk-config.nix",
    "configurations/nixos/wsl/default.nix",
    "configurations/nixos/wsl/configuration.nix",
    "flake.nix",
]

# ── Category / convention helpers ──────────────────────────────────────────

CONVENTION_NAMES = frozenset({
    "default.nix", "options.nix", "config.nix", "meta.nix",
    "tests.nix", "flake.nix", "hardware-configuration.nix",
})

NIXOS_STANDARD_NS = frozenset({
    "boot", "networking", "services", "programs", "systemd",
    "users", "environment", "hardware", "security", "nix",
    "home", "xdg", "i18n", "time", "fonts", "documentation",
    "power", "virtualisation", "assertions", "warnings",
    "fileSystems", "swapDevices", "launchd", "system",
})


def categorize_path(rel_path: str) -> str:
    parts = rel_path.replace("\\", "/").split("/")
    for p in parts:
        if p == "nixos":
            return "nixos"
        if p == "darwin":
            return "darwin"
        if p == "home":
            return "home"
        if p == "flake-parts":
            return "flake-parts"
        if p == "configurations":
            return "host"
    return "other"


def convention_label(filename: str) -> str:
    return filename if filename in CONVENTION_NAMES else "other"


# ── Tree-sitter parsing ────────────────────────────────────────────────────

def init_parser():
    try:
        import tree_sitter_nix as tsnix
        from tree_sitter import Language, Parser
    except ImportError:
        print("ERROR: tree-sitter-nix not available.", file=sys.stderr)
        print("Run via nix shell per the README.", file=sys.stderr)
        sys.exit(1)
    LANGUAGE = Language(tsnix.language())
    parser = Parser(LANGUAGE)
    return parser


# ── Regex fallback engine ──────────────────────────────────────────────────

IMPORTS_RE = re.compile(r'imports\s*=\s*\[(.*?)\];', re.DOTALL)
PATH_RE = re.compile(r'(\./[a-zA-Z0-9_./-]+(?:\.nix)?)')
INPUTS_REF_RE = re.compile(
    r'(inputs\.\w+(?:\.\w+)+|flake\.inputs\.\w+(?:\.\w+)+)'
)
COMMENT_LINE = re.compile(r'^\s*#.*$', re.MULTILINE)
OPTIONS_MY_RE = re.compile(
    r'options\.my\.[a-zA-Z][a-zA-Z0-9]*(\.[a-zA-Z][a-zA-Z0-9]*)*'
)
CONFIG_MY_RE = re.compile(
    r'config\.my\.[a-zA-Z][a-zA-Z0-9]*(\.[a-zA-Z][a-zA-Z0-9]*)*'
)
VIOLATION_RE = re.compile(r'options\.([a-zA-Z][a-zA-Z0-9]*)\.[a-zA-Z]')


def extract_regex(text: str) -> dict:
    """Fallback: extract all fields via regex for files where tree-sitter
    byte offsets are unreliable."""
    result = {
        "extraction_method": "regex",
        "imports": [],
        "option_declarations": [],
        "option_references": [],
        "mkForce": [],
        "mkIf": [],
        "mkDefault": [],
        "mkOverride": [],
        "namespace_violations": [],
    }

    for match in IMPORTS_RE.finditer(text):
        block = match.group(1)
        block = COMMENT_LINE.sub("", block)
        for pm in PATH_RE.finditer(block):
            result["imports"].append(pm.group(1))
        for im in INPUTS_REF_RE.finditer(block):
            result["imports"].append(im.group(1))

    result["option_declarations"] = list(set(
        m.group(0) for m in OPTIONS_MY_RE.finditer(text)
    ))
    result["option_references"] = list(set(
        m.group(0) for m in CONFIG_MY_RE.finditer(text)
    ))

    for fname in ("mkForce", "mkIf", "mkDefault", "mkOverride"):
        pattern = re.compile(rf'\blib\.{fname}\b')
        locs = []
        for m in pattern.finditer(text):
            line = text[:m.start()].count("\n") + 1
            locs.append(line)
        result[fname] = locs

    vio = []
    for m in VIOLATION_RE.finditer(text):
        ns = m.group(1)
        if ns != "my" and ns not in NIXOS_STANDARD_NS:
            full = m.group(0).rstrip(".")
            if full not in vio:
                vio.append(full)
    result["namespace_violations"] = vio

    return result


# ── Tree-sitter extraction engine ──────────────────────────────────────────

def node_text_ts(node) -> str:
    """Extract text from a tree-sitter node using .text property
    (which returns correct bytes even when start_byte/end_byte are wrong)."""
    raw = node.text
    if raw is None:
        return ""
    return raw.decode("utf-8")


def collect_attrpath_ts(node):
    """Walk an attrpath node using .text for correct content."""
    parts = []
    for i in range(node.child_count):
        child = node.child(i)
        if child.type == "identifier":
            parts.append(node_text_ts(child))
        elif child.type == ".":
            pass
        elif child.type in ("attrpath",):
            parts.extend(collect_attrpath_ts(child))
    return parts


def detect_byte_offset_bug(root, text) -> bool:
    """Check if tree-sitter's byte offsets are reliable on this file
    by verifying that node.text matches content[byte:byte] on the
    first function_expression found."""
    for i in range(root.child_count):
        c = root.child(i)
        if c.type == "function_expression":
            fn_text = node_text_ts(c)
            byte_text = text[c.start_byte:c.end_byte]
            if fn_text and byte_text and fn_text != byte_text:
                return True
            return False
    return False


def extract_ts(text: str, root) -> dict:
    """Primary extraction: use tree-sitter AST with .text property."""
    result = {
        "extraction_method": "tree-sitter",
        "imports": [],
        "option_declarations": [],
        "option_references": [],
        "mkForce": [],
        "mkIf": [],
        "mkDefault": [],
        "mkOverride": [],
        "namespace_violations": [],
    }

    def find_all(n, ttype, md=80):
        results = []
        def walk(p, d):
            if d > md:
                return
            if p.type == ttype:
                results.append(p)
            for i in range(p.child_count):
                walk(p.child(i), d + 1)
        for i in range(n.child_count):
            walk(n.child(i), 0)
        return results

    bindings = find_all(root, "binding")

    for b in bindings:
        ap = b.child(0)
        if ap is None:
            continue
        if ap.type == "attrpath":
            parts = collect_attrpath_ts(ap)
            dotted = ".".join(parts)
        elif ap.type == "identifier":
            dotted = node_text_ts(ap)
        else:
            continue

        if dotted == "imports":
            found_eq = False
            for i in range(b.child_count):
                if b.child(i).type == "=":
                    found_eq = True
                    continue
                if found_eq and b.child(i).type != ";":
                    val_node = b.child(i)

                    def extract_imports(n, d=0, targets=None):
                        if targets is None:
                            targets = []
                        if d > 10:
                            return targets
                        if n.type == "path_expression":
                            targets.append(node_text_ts(n))
                        elif n.type == "select_expression":
                            targets.append(node_text_ts(n))
                        elif n.type == "apply_expression":
                            targets.append(node_text_ts(n))
                        elif n.type == "list_expression":
                            for j in range(n.child_count):
                                extract_imports(n.child(j), d + 1, targets)
                        return targets

                    result["imports"] = extract_imports(val_node)
                    break

        if dotted.startswith("options.my."):
            result["option_declarations"].append(dotted)

        if dotted.startswith("config.my."):
            result["option_references"].append(dotted)

        if dotted.startswith("options.") and not dotted.startswith("options.my."):
            parts = dotted.split(".")
            if len(parts) > 1:
                ns = parts[1]
                if ns not in NIXOS_STANDARD_NS and ns != "my":
                    if dotted not in result["namespace_violations"]:
                        result["namespace_violations"].append(dotted)

    apply_nodes = find_all(root, "apply_expression")
    for app in apply_nodes:
        fn = app.child(0)
        if fn is None:
            continue
        fn_text = node_text_ts(fn)
        line_num = text[:app.start_byte].count("\n") + 1

        if fn_text == "lib.mkForce":
            result["mkForce"].append(line_num)
        elif fn_text == "lib.mkIf":
            result["mkIf"].append(line_num)
        elif fn_text == "lib.mkDefault":
            result["mkDefault"].append(line_num)
        elif fn_text == "lib.mkOverride":
            result["mkOverride"].append(line_num)

    return result


# ── Per-file extraction ────────────────────────────────────────────────────

def extract_file(text: str, root, rel_path: str, use_regex_fallback: bool) -> dict:
    filename = os.path.basename(rel_path)
    category = categorize_path(rel_path)
    convention = convention_label(filename)

    if use_regex_fallback:
        raw = extract_regex(text)
    else:
        raw = extract_ts(text, root)

    result = {
        "path": rel_path,
        "category": category,
        "convention": convention,
        "extraction_method": raw["extraction_method"],
        "imports": raw["imports"],
        "option_declarations": raw["option_declarations"],
        "option_references": raw["option_references"],
        "namespace_violations": raw["namespace_violations"],
    }
    for k in ("mkForce", "mkIf", "mkDefault", "mkOverride"):
        lines = raw.get(k, [])
        result[k] = [f"{rel_path}:{ln}" for ln in lines]
    return result


# ── Aggregation ────────────────────────────────────────────────────────────

def extract_v1_scope(repo_root: Path, parser) -> dict:
    graph_data = {
        "files": [],
        "summary": {
            "total_files": 0,
            "ts_parsed": 0,
            "regex_fallback": 0,
            "errors": 0,
            "total_import_edges": 0,
            "total_option_declarations": 0,
            "total_option_references": 0,
            "total_mkForce": 0,
            "total_mkIf": 0,
            "total_mkDefault": 0,
            "total_mkOverride": 0,
            "namespace_violations": [],
        },
    }

    for rel_path in V1_SCOPE:
        full = repo_root / rel_path
        if not full.is_file():
            continue
        abspath = str(full.resolve())
        try:
            with open(abspath, "rb") as f:
                raw_bytes = f.read()
            text = raw_bytes.decode("utf-8")
            tree = parser.parse(raw_bytes)
            root = tree.root_node

            use_regex = detect_byte_offset_bug(root, text)
            result = extract_file(text, root, rel_path, use_regex)

            if use_regex:
                graph_data["summary"]["regex_fallback"] += 1
            else:
                graph_data["summary"]["ts_parsed"] += 1

            graph_data["files"].append(result)
        except Exception as e:
            graph_data["summary"]["errors"] += 1
            graph_data["files"].append({
                "path": rel_path,
                "error": str(e),
                "imports": [],
                "option_declarations": [],
                "option_references": [],
                "mkForce": [],
                "mkIf": [],
                "mkDefault": [],
                "mkOverride": [],
                "namespace_violations": [],
            })

    vio_set = set()
    for f in graph_data["files"]:
        for v in f.get("namespace_violations", []):
            vio_set.add(v)

    graph_data["summary"]["total_files"] = len(graph_data["files"])
    graph_data["summary"]["total_import_edges"] = sum(
        len(f.get("imports", [])) for f in graph_data["files"]
    )
    graph_data["summary"]["total_option_declarations"] = sum(
        len(f.get("option_declarations", [])) for f in graph_data["files"]
    )
    graph_data["summary"]["total_option_references"] = sum(
        len(f.get("option_references", [])) for f in graph_data["files"]
    )
    for k in ("mkForce", "mkIf", "mkDefault", "mkOverride"):
        graph_data["summary"][f"total_{k}"] = sum(
            len(f.get(k, [])) for f in graph_data["files"]
        )
    graph_data["summary"]["namespace_violations"] = sorted(vio_set)

    return graph_data


# ── Grep-based baseline (for validation) ───────────────────────────────────

def grep_baseline(file_paths: list[str]) -> dict:
    def run_grep(pattern):
        try:
            result = subprocess.run(
                ["grep", "-rn", pattern] + file_paths,
                capture_output=True, text=True,
            )
            return [l for l in result.stdout.split("\n") if l.strip()]
        except Exception:
            return []
    return {
        "mkForce": run_grep("lib.mkForce"),
        "mkIf": run_grep("lib.mkIf"),
        "mkDefault": run_grep("lib.mkDefault"),
        "mkOverride": run_grep("lib.mkOverride"),
    }


# ── CLI ────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Extract graph data from nixos-config .nix files"
    )
    parser.add_argument(
        "--v1-scope", action="store_true",
        help="Run against the predefined v1 scope file list"
    )
    parser.add_argument(
        "--validate", action="store_true",
        help="Also run grep baseline and compare"
    )
    parser.add_argument(
        "--output", "-o", type=str, default=None,
        help="Write output JSON to path"
    )
    parser.add_argument(
        "--repo-root", type=str, default=str(REPO_ROOT),
        help="Repository root directory"
    )

    args = parser.parse_args()
    repo_root = Path(args.repo_root).resolve()

    if not args.v1_scope:
        print("ERROR: specify --v1-scope", file=sys.stderr)
        sys.exit(1)

    ts_parser = init_parser()
    print(f"Scanning v1 scope ({len(V1_SCOPE)} files)...", file=sys.stderr)
    graph_data = extract_v1_scope(repo_root, ts_parser)

    s = graph_data["summary"]
    print(f"\n=== EXTRACTOR RESULTS ===", file=sys.stderr)
    print(f"  Files scanned:       {s['total_files']}", file=sys.stderr)
    print(f"  tree-sitter parsed:  {s['ts_parsed']}", file=sys.stderr)
    print(f"  Regex fallback:      {s['regex_fallback']}", file=sys.stderr)
    print(f"  Errors:              {s['errors']}", file=sys.stderr)
    print(f"  Import edges:        {s['total_import_edges']}", file=sys.stderr)
    print(f"  Option declarations: {s['total_option_declarations']}", file=sys.stderr)
    print(f"  Option references:   {s['total_option_references']}", file=sys.stderr)
    print(f"  lib.mkForce:         {s['total_mkForce']}", file=sys.stderr)
    print(f"  lib.mkIf:            {s['total_mkIf']}", file=sys.stderr)
    print(f"  lib.mkDefault:       {s['total_mkDefault']}", file=sys.stderr)
    print(f"  lib.mkOverride:      {s['total_mkOverride']}", file=sys.stderr)
    print(f"  Namespace violations:{s['namespace_violations']}", file=sys.stderr)

    if args.validate:
        v1_abspaths = [str(repo_root / p) for p in V1_SCOPE]
        baseline = grep_baseline(v1_abspaths)

        print(f"\n=== VALIDATION (v1 scope, grep vs extractor) ===", file=sys.stderr)
        print(f"{'Metric':<25} {'Extractor':<10} {'Grep baseline':<15} {'Match':<8}", file=sys.stderr)
        print("-" * 60, file=sys.stderr)

        checks = [
            ("mkForce",     s["total_mkForce"],     len(baseline["mkForce"])),
            ("mkIf",        s["total_mkIf"],        len(baseline["mkIf"])),
            ("mkDefault",   s["total_mkDefault"],    len(baseline["mkDefault"])),
            ("mkOverride",  s["total_mkOverride"],   len(baseline["mkOverride"])),
        ]
        for name, ext, grep_cnt in checks:
            match = "✓" if ext == grep_cnt else "✗"
            print(f"{name:<25} {ext:<10} {grep_cnt:<15} {match:<8}", file=sys.stderr)

        print(f"\n--- Extractor mkForce locations ---", file=sys.stderr)
        for f in graph_data["files"]:
            for loc in f.get("mkForce", []):
                print(f"  {loc}", file=sys.stderr)

        print(f"\n--- Namespace violations ---", file=sys.stderr)
        for v in graph_data["summary"]["namespace_violations"]:
            print(f"  {v}", file=sys.stderr)

        print(f"\n--- Extraction method per file ---", file=sys.stderr)
        for f in graph_data["files"]:
            method = f.get("extraction_method", "?")
            print(f"  [{method:10}] {f['path']}", file=sys.stderr)

    if args.output:
        outpath = args.output
    else:
        outpath = str(repo_root / "tools/nix-graph/extraction-result.json")
    os.makedirs(os.path.dirname(outpath), exist_ok=True)
    with open(outpath, "w") as f:
        json.dump(graph_data, f, indent=2, sort_keys=True)
    rel_out = os.path.relpath(outpath, str(repo_root))
    print(f"\nOutput written to {rel_out}", file=sys.stderr)


if __name__ == "__main__":
    main()
