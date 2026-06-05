# =============================================================================
# registry.nix — MCP Server Registry (uvx + npx wrappers)
# =============================================================================
# Purpose: Thin uvx/npx wrappers for MCP servers. Each server is a
#          writeShellApplication that exec's `uvx <package>` or
#          `npx -y <package>` at runtime.
#
# Helpers:
#   mkUvxMcp — Python/uvx-based MCP servers
#   mkNpxMcp — Node/npm-based MCP servers (supports secretFiles for agenix)
#
# To add a new server, add a line to the `servers` attrset below.
# It is automatically re-exported as .#<name> via the flake-parts module.
# =============================================================================

{ lib, pkgs, uv, nodejs, writeShellApplication, python3 }:

let
  # Build a thin npx wrapper for an npm-based MCP server.
  # name        — attribute name and binary name (e.g. "mcp-nixos")
  # package     — npm package name (defaults to name)
  # extraArgs   — extra CLI args appended to the npx invocation
  # env         — env vars exported into the wrapper script
  # secretFiles — like env, but reads the value from a file at runtime
  #               (for agenix or other file-based secrets)
  mkNpxMcp = { name, package ? name, extraArgs ? [ ], env ? { }, secretFiles ? { } }:
    writeShellApplication {
      inherit name;
      runtimeInputs = [ nodejs ];
      text = ''
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}") env)}
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k}=$(cat ${lib.escapeShellArg v})\nexport ${k}") secretFiles)}
        exec npx -y ${package} ${toString extraArgs} "$@"
      '';
      meta = {
        description = "MCP server: ${name} (npx wrapper)";
        platforms = lib.platforms.all;
      };
    };

  # Build a thin uvx wrapper for an MCP server.
  # name        — attribute name and binary name (e.g. "mcp-nixos")
  # package     — uvx package name (defaults to name)
  # extraArgs   — extra CLI args appended to the uvx invocation
  # env         — env vars exported into the wrapper script (API keys etc.)
  mkUvxMcp = { name, package ? name, extraArgs ? [ ], env ? { } }:
    writeShellApplication {
      inherit name;
      runtimeInputs = [ uv python3 ];
      text = ''
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}") env)}
        export UV_PYTHON="${python3}/bin/python3"
        export UV_PYTHON_DOWNLOADS=never
        exec uvx ${package} ${toString extraArgs} "$@"
      '';
      meta = {
        description = "MCP server: ${name} (uvx wrapper)";
        platforms = lib.platforms.all;
      };
    };

  servers = {
    # Dev workflow
    mcp-nixos = mkUvxMcp { name = "mcp-nixos"; };
    mcp-server-fetch = mkUvxMcp { name = "mcp-server-fetch"; };

    # Git MCP server — Node.js implementation using @modelcontextprotocol/sdk
    # which handles Content-Length framing natively (no protocol proxy needed).
    mcp-server-git = pkgs.callPackage ./git-server { };

    # Python / data work
    mcp-server-sqlite = mkUvxMcp { name = "mcp-server-sqlite"; };
  };
in
servers
