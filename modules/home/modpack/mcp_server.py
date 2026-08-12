#!/usr/bin/env python3
"""MCP stdio server for the Modrinth API (api.modrinth.com/v2).

Pure stdlib (urllib.request). No SDK, no external dependencies — mirrors the
hand-rolled JSON-RPC transport in modules/home/goals/mcp_server.py.

Usage:
  python3 mcp_server.py --base-url https://api.modrinth.com/v2 --user-agent "..."
"""

import argparse
import json
import sys
import traceback
import urllib.error
import urllib.parse
import urllib.request

BASE_URL = "https://api.modrinth.com/v2"
USER_AGENT = "nixos-config-modpack-mcp/0.1.0"


class ModrinthError(Exception):
    """Raised for Modrinth API/network failures; surfaced as a structured error."""


def _api_get(path: str, params: dict | None = None) -> dict | list:
    """GET a Modrinth API path with the required User-Agent."""
    url = BASE_URL.rstrip("/") + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(
        url,
        headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        raise ModrinthError(f"Modrinth API {e.code} {e.reason}: {body[:300]}") from e
    except urllib.error.URLError as e:
        raise ModrinthError(f"Modrinth API unreachable: {e.reason}") from e


# ── Tool implementations ────────────────────────────────────────────────────


def search_projects(
    query: str = "",
    project_type: str | None = None,
    facets: str | None = None,
    index: str = "relevance",
    limit: int = 10,
    offset: int = 0,
) -> dict:
    """Search Modrinth projects.

    `facets` is a JSON string of nested arrays, e.g.
    '[["project_type:modpack"],["categories:technology"]]'. When `project_type`
    is given it is merged into the facets. Hits include `latest_version`,
    `downloads`, and `icon_url`."""
    params = {
        "query": query,
        "index": index,
        "limit": max(1, min(limit, 100)),
        "offset": max(0, offset),
    }
    if project_type or facets:
        combined = []
        if project_type:
            combined.append([f"project_type:{project_type}"])
        if facets:
            try:
                combined.extend(json.loads(facets))
            except json.JSONDecodeError as e:
                raise ModrinthError(f"Invalid facets JSON: {e}") from e
        params["facets"] = json.dumps(combined)
    return _api_get("/search", params)


def get_project(project_id_or_slug: str) -> dict:
    """Fetch a project by its ID or slug.

    Includes the official `wiki_url`, `issues_url`, `source_url`, `discord_url`,
    plus `status`, `body`, `downloads`, `game_versions`, and `loaders`."""
    return _api_get(f"/project/{urllib.parse.quote(project_id_or_slug)}")


def get_project_versions(
    project_id_or_slug: str,
    game_versions: str | None = None,
    loaders: str | None = None,
) -> list:
    """List a project's versions.

    `game_versions` / `loaders` are JSON-string arrays, e.g. '["1.20.1"]' and
    '["fabric"]'. Each version includes its compact `dependencies` array."""
    params = {}
    if game_versions:
        params["game_versions"] = game_versions
    if loaders:
        params["loaders"] = loaders
    return _api_get(f"/project/{urllib.parse.quote(project_id_or_slug)}/version", params)


def get_version(version_id: str) -> dict:
    """Fetch one version by its ID.

    The `dependencies` field here is the compact {version_id, project_id,
    dependency_type} array — prefer this over /project/{id}/dependencies, which
    embeds full project objects and can be multi-MB."""
    return _api_get(f"/version/{urllib.parse.quote(version_id)}")


def get_version_dependencies(version_id: str) -> list:
    """Fetch only a version's compact dependency array."""
    return _api_get(f"/version/{urllib.parse.quote(version_id)}/dependencies")


# ── Tool registry ───────────────────────────────────────────────────────────

TOOLS: list[dict] = [
    {
        "name": "search_projects",
        "description": "Search Modrinth projects. `project_type` shortcuts to a facet (e.g. 'mod' or 'modpack'); `facets` is an optional JSON string of nested facet arrays.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Search query (slug, title, or keyword)"},
                "project_type": {
                    "type": "string",
                    "description": "Filter by project type: mod, modpack, resourcepack, shader, datapack, plugin",
                },
                "facets": {
                    "type": "string",
                    "description": "JSON string of nested facets, e.g. '[[\"project_type:modpack\"],[\"categories:technology\"]]'",
                },
                "index": {
                    "type": "string",
                    "description": "Sort: relevance, downloads, follows, newest, updated",
                    "default": "relevance",
                },
                "limit": {"type": "integer", "description": "Max results (1-100)", "default": 10},
                "offset": {"type": "integer", "description": "Pagination offset", "default": 0},
            },
        },
    },
    {
        "name": "get_project",
        "description": "Fetch a project by ID or slug. Returns wiki_url, issues_url, source_url, discord_url, status, body, downloads, game_versions, loaders.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_id_or_slug": {
                    "type": "string",
                    "description": "Project ID or slug (e.g. 'sodium' or 'AANobbMI')",
                },
            },
            "required": ["project_id_or_slug"],
        },
    },
    {
        "name": "get_project_versions",
        "description": "List a project's versions, optionally filtered by game versions and/or loaders (JSON-string arrays).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "project_id_or_slug": {"type": "string", "description": "Project ID or slug"},
                "game_versions": {"type": "string", "description": "JSON array, e.g. '[\"1.20.1\"]'"},
                "loaders": {"type": "string", "description": "JSON array, e.g. '[\"fabric\"]'"},
            },
            "required": ["project_id_or_slug"],
        },
    },
    {
        "name": "get_version",
        "description": "Fetch one version by its ID. The dependencies field is the compact {version_id, project_id, dependency_type} array.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "version_id": {"type": "string", "description": "Version ID (e.g. 'k8KQcSXR')"},
            },
            "required": ["version_id"],
        },
    },
    {
        "name": "get_version_dependencies",
        "description": "Fetch only a version's compact dependency array.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "version_id": {"type": "string", "description": "Version ID"},
            },
            "required": ["version_id"],
        },
    },
]

TOOL_DISPATCH = {
    "search_projects": search_projects,
    "get_project": get_project,
    "get_project_versions": get_project_versions,
    "get_version": get_version,
    "get_version_dependencies": get_version_dependencies,
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
                "serverInfo": {"name": "modrinth-mcp", "version": "0.1.0"},
            },
        }
    elif method == "notifications/initialized":
        return None
    elif method == "tools/list":
        return {"jsonrpc": "2.0", "id": _id, "result": {"tools": TOOLS}}
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
            if isinstance(result, ModrinthError):
                result = {"error": str(result)}
            text = json.dumps(result, indent=2, default=str)
            return {
                "jsonrpc": "2.0",
                "id": _id,
                "result": {"content": [{"type": "text", "text": text}]},
            }
        except ModrinthError as e:
            # Structured API/network failure — return as content, not MCP error,
            # so the agent sees the Modrinth message (404/429/etc.) cleanly.
            return {
                "jsonrpc": "2.0",
                "id": _id,
                "result": {
                    "content": [{"type": "text", "text": json.dumps({"error": str(e)}, indent=2)}]
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
    global BASE_URL, USER_AGENT

    parser = argparse.ArgumentParser(description="Modrinth MCP server")
    parser.add_argument("--base-url", default=BASE_URL, help="Modrinth API v2 base URL")
    parser.add_argument("--user-agent", default=USER_AGENT, help="User-Agent sent to the API")
    args = parser.parse_args()

    BASE_URL = args.base_url
    USER_AGENT = args.user_agent

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
