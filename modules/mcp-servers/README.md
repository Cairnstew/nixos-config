# MCP Server Registry

This directory defines thin Nix wrappers for MCP (Model Context Protocol) servers.
Each server is a `writeShellApplication` that is auto-exported as `.<name>` via
the flake-parts module (`modules/flake-parts/mcp-server-packages.nix`).

## Files

| File | Purpose |
|------|---------|
| `registry.nix` | Central registry of all MCP servers |

## Adding a new MCP server

Add one line to the `servers` attrset in `registry.nix`. Use `mkUvxMcp` for
Python/uvx-based servers or `mkNpxMcp` for Node/npm-based servers.
