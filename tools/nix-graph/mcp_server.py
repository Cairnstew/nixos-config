#!/usr/bin/env python3
"""MCP stdio server for querying the nix-graph graph.

Uses raw JSON-RPC over stdin/stdout (no SDK dependency).
Only needs python3 + networkx.

Usage:
  python3 mcp_server.py --graph graph.json
"""

import argparse
import json
import os
import sys
import traceback

import networkx as nx

# ── Load graph ──────────────────────────────────────────────────────────────

G: nx.Graph | None = None
EXTRACT_DATA: list[dict] = []
GRAPH_PATH = ""


def load_graph(path: str) -> nx.Graph:
    with open(path) as f:
        data = json.load(f)
    return nx.node_link_graph(data, edges="edges", nodes="nodes")


def load_extraction_json(path: str) -> list[dict]:
    """Load the extraction result JSON that was used to build the graph.
    Falls back to searching for it next to the graph."""
    if os.path.exists(path):
        with open(path) as f:
            data = json.load(f)
        if isinstance(data, dict) and "files" in data:
            return data["files"]
        if isinstance(data, list):
            return data
    return []


# ── Tool implementations ────────────────────────────────────────────────────


def _resolve_node_id(query: str) -> list[str]:
    """Find node IDs that match the query via suffix or prefix matching.
    Returns matches sorted by relevance: exact match first, then path-component
    suffix match, then generic suffix/prefix match."""
    q = query.lower()
    exact: list[str] = []
    path_suffix: list[str] = []
    generic: list[str] = []
    for n in G.nodes:
        nl = n.lower()
        if nl == q:
            exact.append(n)
        elif nl.endswith("/" + q) or nl.endswith(":" + q) or nl.endswith("." + q):
            path_suffix.append(n)
        elif nl.endswith(q) or nl.startswith(q):
            generic.append(n)
    return exact + path_suffix + generic


def get_dependents(module_path: str) -> list[dict]:
    """Return all files that import the given module path."""
    targets = _resolve_node_id(module_path)
    results = []
    for u, v, d in G.edges(data=True):
        if d.get("type") == "IMPORTS" and (v == module_path or v in targets):
            results.append({"source": u, "target": v, "type": "IMPORTS"})
    return results


def get_option_definers(option_path: str) -> list[dict]:
    """Return all files that declare the given option (DEFINES edges)."""
    targets = _resolve_node_id(option_path)
    results = []
    for u, v, d in G.edges(data=True):
        if d.get("type") == "DEFINES" and (v == option_path or v in targets):
            results.append({"source": u, "target": v, "type": "DEFINES"})
    return results


def find_mkforce_sites() -> list[dict]:
    """Return all mkForce sites in the graph."""
    results = []
    for u, v, d in G.edges(data=True):
        if d.get("type") == "MKFORCE_ON":
            src = G.nodes[u].get("location", u)
            results.append({"source": u, "target": v, "source_location": src})
    return results


def find_path(source: str, target: str) -> dict:
    """Shortest path between two nodes (by node id).
    Searches the undirected graph so you can go both ways along edges."""
    src_matches = _resolve_node_id(source)
    tgt_matches = _resolve_node_id(target)

    if not src_matches:
        return {"error": f"Source '{source}' not found", "path": []}
    if not tgt_matches:
        return {"error": f"Target '{target}' not found", "path": []}

    s = src_matches[0]
    t = tgt_matches[0]
    try:
        path = nx.shortest_path(G.to_undirected(), source=s, target=t)
        return {"path": path, "length": len(path)}
    except nx.NodeNotFound:
        return {"error": f"Node not found in graph", "path": []}
    except nx.NetworkXNoPath:
        # Check which component each node is in
        ug = G.to_undirected()
        comp_s = next(
            (i for i, c in enumerate(nx.connected_components(ug)) if s in c), None
        )
        comp_t = next(
            (i for i, c in enumerate(nx.connected_components(ug)) if t in c), None
        )
        msg = f"No path between '{s}' and '{t}'"
        if comp_s != comp_t:
            msg += f" (different connected components: #{comp_s} vs #{comp_t})"
        return {"error": msg, "path": []}


def find_namespace_violations() -> list[dict]:
    """Return all namespace violations (violation:* nodes)."""
    results = []
    for n, d in G.nodes(data=True):
        if d.get("type") == "NamespaceViolation":
            sources = []
            for u, v, ed in G.edges(data=True):
                if ed.get("type") == "VIOLATES" and v == n:
                    sources.append(u)
            results.append({"dotted_path": d.get("dotted_path", ""), "sources": sources})
    return results


def node_info(node_id: str) -> dict | None:
    """Return attributes for a single node."""
    matches = _resolve_node_id(node_id)
    if not matches or matches[0] not in G:
        return None
    nid = matches[0]
    d = dict(G.nodes[nid])
    d["id"] = nid
    return d


def search_nodes(query: str) -> list[dict]:
    """Search nodes by id substring match."""
    results = []
    q = query.lower()
    for n, d in G.nodes(data=True):
        if q in n.lower():
            entry = dict(d)
            entry["id"] = n
            results.append(entry)
    return results


def graph_stats() -> dict:
    """Return summary statistics about the graph."""
    nodes_by_type: dict[str, int] = {}
    for _, d in G.nodes(data=True):
        t = d.get("type", "Unknown")
        nodes_by_type[t] = nodes_by_type.get(t, 0) + 1
    edges_by_type: dict[str, int] = {}
    for _, _, d in G.edges(data=True):
        t = d.get("type", "Unknown")
        edges_by_type[t] = edges_by_type.get(t, 0) + 1
    return {
        "total_nodes": G.number_of_nodes(),
        "total_edges": G.number_of_edges(),
        "nodes_by_type": nodes_by_type,
        "edges_by_type": edges_by_type,
    }


# ── Tool registry ───────────────────────────────────────────────────────────

TOOLS: list[dict] = [
    {
        "name": "get_dependents",
        "description": "Return all files that import the given module path.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "module_path": {
                    "type": "string",
                    "description": "Module path (e.g. 'modules/nixos/tailscale')",
                }
            },
            "required": ["module_path"],
        },
    },
    {
        "name": "get_option_definers",
        "description": "Return all mk-sites (mkDefault/mkForce/mkIf) that define an option.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "option_path": {
                    "type": "string",
                    "description": "Option dotted path (e.g. 'my.services.tailscale.enable')",
                }
            },
            "required": ["option_path"],
        },
    },
    {
        "name": "find_mkforce_sites",
        "description": "Return all mkForce sites in the graph.",
        "inputSchema": {
            "type": "object",
            "properties": {},
        },
    },
    {
        "name": "find_path",
        "description": "Shortest path between two nodes.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "source": {"type": "string", "description": "Source node id"},
                "target": {"type": "string", "description": "Target node id"},
            },
            "required": ["source", "target"],
        },
    },
    {
        "name": "find_namespace_violations",
        "description": "Return all namespace violations (options set outside the my.* namespace).",
        "inputSchema": {
            "type": "object",
            "properties": {},
        },
    },
    {
        "name": "node_info",
        "description": "Return attributes for a single node.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "node_id": {
                    "type": "string",
                    "description": "Node id (e.g. 'modules/nixos/common.nix', 'option:my.services.tailscale.enable')",
                }
            },
            "required": ["node_id"],
        },
    },
    {
        "name": "search_nodes",
        "description": "Search nodes by id substring match.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Substring to match against node ids",
                }
            },
            "required": ["query"],
        },
    },
    {
        "name": "graph_stats",
        "description": "Return summary statistics about the graph.",
        "inputSchema": {
            "type": "object",
            "properties": {},
        },
    },
]

TOOL_DISPATCH = {
    "get_dependents": get_dependents,
    "get_option_definers": get_option_definers,
    "find_mkforce_sites": find_mkforce_sites,
    "find_path": find_path,
    "find_namespace_violations": find_namespace_violations,
    "node_info": node_info,
    "search_nodes": search_nodes,
    "graph_stats": graph_stats,
}


# ── MCP stdio transport ─────────────────────────────────────────────────────


def send(msg: dict) -> None:
    line = json.dumps(msg)
    sys.stdout.write(line + "\n")
    sys.stdout.flush()


def handle_request(msg: dict) -> dict | None:
    method: str = msg.get("method", "")
    _id = msg.get("id")
    params: dict = msg.get("params", {})

    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": _id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "nix-graph-mcp", "version": "0.1.0"},
            },
        }
    elif method == "notifications/initialized":
        # No response needed
        return None
    elif method == "tools/list":
        return {
            "jsonrpc": "2.0",
            "id": _id,
            "result": {"tools": TOOLS},
        }
    elif method == "tools/call":
        tool_name = params.get("name", "")
        arguments = params.get("arguments", {})
        fn = TOOL_DISPATCH.get(tool_name)
        if fn is None:
            return {
                "jsonrpc": "2.0",
                "id": _id,
                "error": {"code": -32601, "message": f"Unknown tool: {tool_name}"},
            }
        try:
            result = fn(**arguments)
            # MCP spec requires content array with text content items
            text = json.dumps(result, indent=2, default=str)
            return {
                "jsonrpc": "2.0",
                "id": _id,
                "result": {
                    "content": [{"type": "text", "text": text}]
                },
            }
        except Exception as e:
            tb = traceback.format_exc()
            return {
                "jsonrpc": "2.0",
                "id": _id,
                "error": {"code": -32603, "message": f"{e}\n{tb}"},
            }
    else:
        return {
            "jsonrpc": "2.0",
            "id": _id,
            "error": {"code": -32601, "message": f"Method not found: {method}"},
        }


def main() -> None:
    global G, GRAPH_PATH, EXTRACT_DATA

    parser = argparse.ArgumentParser(description="nix-graph MCP server")
    parser.add_argument("--graph", required=True, help="Path to graph.json")
    parser.add_argument(
        "--extraction",
        default="",
        help="Path to extraction-result.json (optional, enables richer queries)",
    )
    args = parser.parse_args()

    GRAPH_PATH = os.path.abspath(args.graph)
    G = load_graph(GRAPH_PATH)
    if args.extraction:
        EXTRACT_DATA = load_extraction_json(os.path.abspath(args.extraction))

    for raw in sys.stdin:
        line = raw.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        resp = handle_request(msg)
        if resp is not None:
            send(resp)


if __name__ == "__main__":
    main()
