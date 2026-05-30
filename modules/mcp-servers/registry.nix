# =============================================================================
# registry.nix — uvx-wrapped MCP Server Registry
# =============================================================================
# Purpose: Thin uvx wrappers for MCP servers. Each server is a
#          writeShellApplication that exec's `uvx <package>` at runtime.
#
# To add a new server, add a line to the `servers` attrset below AND
# a re-export line in modules/flake-parts/mcp-server-packages.nix.
# =============================================================================

{ lib, uv, writeShellApplication, python3 }:

let
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
    mcp-nixos  = mkUvxMcp { name = "mcp-nixos"; };
    mcp-python = mkUvxMcp { name = "mcp-python"; };
  };
in
servers
