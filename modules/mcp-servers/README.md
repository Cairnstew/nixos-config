# MCP Server Registry

This directory defines thin Nix wrappers for MCP (Model Context Protocol) servers.
Each server is a `writeShellApplication` that is auto-exported as `.<name>` via
the flake-parts module (`modules/flake-parts/mcp-server-packages.nix`).

## Files

| File | Purpose |
|------|---------|
| `registry.nix` | Central registry of all MCP servers |
| `mcp-git-proxy.py` | Protocol adapter for the git MCP server |

## Protocol Adapter: Why It Exists

`mcp-server-git` (the PyPI package) depends on MCP Python SDK 1.x, which uses an
**old line-based protocol** — it reads raw JSON lines from stdin, one per message.

Modern MCP clients like **OpenCode** use the **standard Content-Length header format**:

```
Content-Length: 153\r\n\r\n{"jsonrpc":"2.0",...}
```

The MCP Python SDK 1.x tries to parse `Content-Length:` as a JSON line, fails, and
— because it runs with `raise_exceptions=True` — crashes the entire server.

`mcp-git-proxy.py` sits between the client and `uvx mcp-server-git`, translating:

- **Inbound** (Client → Proxy → Child): Strips Content-Length headers, passes
  raw JSON lines to the child process (`uvx mcp-server-git`)
- **Outbound** (Child → Proxy → Client): Reads raw JSON lines from the child,
  wraps them with Content-Length headers for the client

## Adding a new MCP server

Add one line to the `servers` attrset in `registry.nix`. Use `mkUvxMcp` for
Python/uvx-based servers or `mkNpxMcp` for Node/npm-based servers.
