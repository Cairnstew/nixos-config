#!/usr/bin/env python3
"""
build_graph.py — NetworkX graph construction from extractor output.

Reads extraction-result.json, constructs a directed graph matching the
schema below, and serializes to graph.json.

Nodes:  File{path,category}, Module{name}, Option{dotted_path}, Host{name}
Edges:  IMPORTS, BELONGS_TO, DEFINES, REFERENCES, MKFORCE_ON, ENABLED_ON,
        MKIF_ON, MKDEFAULT_ON, MKOVERRIDE_ON, VIOLATES

Usage:
  nix shell nixpkgs#python3 nixpkgs#python313Packages.networkx \\
    -c bash -c '
      export PYTHONPATH=$(find /nix/store/*python3.13* -name site-packages -type d | tr "\\n" ":"):$PYTHONPATH
      python3 tools/nix-graph/build_graph.py --input tools/nix-graph/extraction-result.json
    '
"""

import argparse
import json
import os
import sys
from pathlib import Path


# ── Edge type constants ────────────────────────────────────────────────────

IMPORTS = "IMPORTS"
BELONGS_TO = "BELONGS_TO"
DEFINES = "DEFINES"
REFERENCES = "REFERENCES"
MKFORCE_ON = "MKFORCE_ON"
MKIF_ON = "MKIF_ON"
MKDEFAULT_ON = "MKDEFAULT_ON"
MKOVERRIDE_ON = "MKOVERRIDE_ON"
VIOLATES = "VIOLATES"

# Map extractor key to edge type
MK_EDGE_MAP = {
    "mkForce": MKFORCE_ON,
    "mkIf": MKIF_ON,
    "mkDefault": MKDEFAULT_ON,
    "mkOverride": MKOVERRIDE_ON,
}


# ── Repo root for resolving relative import paths ──────────────────────────

REPO_ROOT = Path(
    os.environ.get("REPO_ROOT", "/home/seanc/nixos-config")
).resolve()


def resolve_import_path(source_file: str, import_target: str) -> str | None:
    """Resolve a potentially relative import target to an absolute repo path."""
    target = import_target.strip()

    # Flake input references — opaque, return as-is
    if target.startswith("inputs.") or target.startswith("flake.inputs."):
        return None

    # Inputs reference via self
    if target.startswith("flake.inputs.self."):
        # e.g. flake.inputs.self.nixosModules.common
        return None

    # ./relative/path
    if target.startswith("./"):
        source_dir = Path(source_file).parent
        resolved = (source_dir / target).resolve()
        try:
            return str(resolved.relative_to(REPO_ROOT))
        except ValueError:
            return None

    # Absolute path reference
    if target.startswith("/"):
        return None

    return None


def extract_host_name(file_path: str) -> str | None:
    """Extract host name from a host configuration file path."""
    parts = file_path.split("/")
    if "configurations" in parts and "nixos" in parts:
        idx = parts.index("nixos")
        if idx + 1 < len(parts):
            return parts[idx + 1]
    return None


def extract_module_name(file_path: str) -> str | None:
    """Derive a module name from a module file path.
    modules/nixos/foo/ → foo
    modules/nixos/foo/bar/ → foo.bar
    modules/home/foo/ → foo (home-manager)
    """
    parts = file_path.split("/")
    if "modules" in parts:
        idx = parts.index("modules")
        rest = parts[idx + 1:]  # e.g. ['nixos', 'tailscale', 'options.nix']
        if len(rest) >= 2:
            category = rest[0]  # nixos, home, flake-parts
            name_parts = []
            for p in rest[1:]:
                if p.endswith(".nix"):
                    name_parts.append(p[:-4])
                elif p:
                    name_parts.append(p)
                else:
                    break
            if name_parts:
                return f"{category}/{'.'.join(name_parts)}"
    return None


def build_graph(extraction_data: dict) -> dict:
    """Build the graph from extraction data.
    Returns a dict representation for JSON serialization
    (nodes + edges lists), avoiding a hard NetworkX dependency
    at read time — NetworkX is used only at build time."""
    try:
        import networkx as nx
    except ImportError:
        print("ERROR: networkx not available.", file=sys.stderr)
        print("Run via nix shell per the README.", file=sys.stderr)
        sys.exit(1)

    G = nx.MultiDiGraph()

    files_data = extraction_data.get("files", [])

    # ── Pass 1: add file nodes ──────────────────────────────────────────
    for fd in files_data:
        path = fd["path"]
        category = fd.get("category", "other")
        convention = fd.get("convention", "other")

        G.add_node(path, type="File", category=category, convention=convention,
                   extraction_method=fd.get("extraction_method", "?"))

        # Create Host node if this is a host config
        host = extract_host_name(path)
        if host:
            G.add_node(f"host:{host}", type="Host", name=host)
            G.add_edge(path, f"host:{host}", type=BELONGS_TO)

        # Create Module node if this is a module file
        module = extract_module_name(path)
        if module:
            G.add_node(f"module:{module}", type="Module", name=module)
            G.add_edge(path, f"module:{module}", type=BELONGS_TO)

    # ── Pass 2: import edges ────────────────────────────────────────────
    for fd in files_data:
        source = fd["path"]
        for imp in fd.get("imports", []):
            resolved = resolve_import_path(source, imp)
            if resolved:
                G.add_edge(source, resolved, type=IMPORTS)
            else:
                # External/opaque import — create a leaf node
                opaque_id = f"external:{imp}"
                G.add_node(opaque_id, type="ExternalImport", import_string=imp)
                G.add_edge(source, opaque_id, type=IMPORTS)

    # ── Pass 3: option declaration edges ────────────────────────────────
    for fd in files_data:
        source = fd["path"]
        for opt in fd.get("option_declarations", []):
            opt_id = f"option:{opt}"
            G.add_node(opt_id, type="Option", dotted_path=opt)
            G.add_edge(source, opt_id, type=DEFINES)

        for opt in fd.get("option_references", []):
            opt_id = f"option:{opt}"
            if not G.has_node(opt_id):
                G.add_node(opt_id, type="Option", dotted_path=opt)
            G.add_edge(source, opt_id, type=REFERENCES)

    # ── Pass 4: mk* edges ──────────────────────────────────────────────
    for fd in files_data:
        source = fd["path"]
        for mk_name, edge_type in MK_EDGE_MAP.items():
            for loc in fd.get(mk_name, []):
                # loc is like "path/to/file.nix:42"
                loc_id = f"mk:{loc.replace(':', '_')}"
                G.add_node(loc_id, type="MkSite", location=loc, kind=mk_name)
                G.add_edge(source, loc_id, type=edge_type)

    # ── Pass 5: namespace violation edges ──────────────────────────────
    for fd in files_data:
        source = fd["path"]
        for vio in fd.get("namespace_violations", []):
            vio_id = f"violation:{vio}"
            G.add_node(vio_id, type="NamespaceViolation", dotted_path=vio)
            G.add_edge(source, vio_id, type=VIOLATES)

    # ── Pass 6: label nodes created from imports outside v1 scope ─────
    # Files referenced in imports that weren't in extraction data were
    # auto-created by NetworkX with no attributes. Give them a type.
    v1_scope_paths = {fd["path"] for fd in files_data}
    for n in list(G.nodes):
        if not G.nodes[n]:
            if n.endswith(".nix") or (n.startswith("modules/") and "/" in n):
                G.nodes[n]["type"] = "File"
                G.nodes[n]["category"] = "other"
                G.nodes[n]["convention"] = "other"
                G.nodes[n]["in_v1_scope"] = False
            elif n.startswith("external:"):
                pass  # already typed as ExternalImport
            else:
                # A path-like reference (e.g. directory import)
                G.nodes[n]["type"] = "ImportRef"
                G.nodes[n]["in_v1_scope"] = False

    # ── Convert to JSON-serializable format ─────────────────────────────
    result = {
        "metadata": {
            "description": "nixos-config structural graph (v1 scope)",
            "node_count": G.number_of_nodes(),
            "edge_count": G.number_of_edges(),
        },
        "nodes": [],
        "edges": [],
    }

    # Group stats by type
    node_type_counts = {}
    for n, attrs in G.nodes(data=True):
        node_entry = {"id": n, **attrs}
        result["nodes"].append(node_entry)
        ntype = attrs.get("type", "Unknown")
        node_type_counts[ntype] = node_type_counts.get(ntype, 0) + 1

    edge_type_counts = {}
    for u, v, k, attrs in G.edges(data=True, keys=True):
        edge_entry = {"source": u, "target": v, **attrs}
        result["edges"].append(edge_entry)
        etype = attrs.get("type", "Unknown")
        edge_type_counts[etype] = edge_type_counts.get(etype, 0) + 1

    result["stats"] = {
        "nodes_by_type": node_type_counts,
        "edges_by_type": edge_type_counts,
    }

    return result


def print_stats(graph_result: dict):
    """Print a human-readable stats summary."""
    s = graph_result["stats"]
    print("=== GRAPH STATS ===")
    print(f"  Total nodes: {graph_result['metadata']['node_count']}")
    print(f"  Total edges: {graph_result['metadata']['edge_count']}")
    print()
    print("  Nodes by type:")
    for ntype, count in sorted(s["nodes_by_type"].items()):
        print(f"    {ntype:<25} {count}")
    print()
    print("  Edges by type:")
    for etype, count in sorted(s["edges_by_type"].items()):
        print(f"    {etype:<25} {count}")


def main():
    parser = argparse.ArgumentParser(
        description="Build NetworkX graph from extraction output"
    )
    parser.add_argument(
        "--input", "-i", type=str, required=True,
        help="Path to extraction-result.json"
    )
    parser.add_argument(
        "--output", "-o", type=str, default=None,
        help="Path to write graph.json (default: alongside input)"
    )

    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.is_file():
        print(f"ERROR: input file not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    with open(input_path, "r") as f:
        extraction_data = json.load(f)

    print(f"Building graph from {input_path}...", file=sys.stderr)
    graph_result = build_graph(extraction_data)
    print_stats(graph_result)

    if args.output:
        output_path = Path(args.output)
    else:
        output_path = input_path.parent / "graph.json"

    with open(output_path, "w") as f:
        json.dump(graph_result, f, indent=2, sort_keys=True)

    print(f"\nGraph written to {output_path}", file=sys.stderr)
    print(f"  Nodes: {graph_result['metadata']['node_count']}", file=sys.stderr)
    print(f"  Edges: {graph_result['metadata']['edge_count']}", file=sys.stderr)


if __name__ == "__main__":
    main()
