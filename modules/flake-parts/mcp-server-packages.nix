# =============================================================================
# mcp-server-packages.nix — Re-export MCP servers as top-level packages
# =============================================================================
# Purpose: Calls modules/mcp-servers/registry.nix and flattens the result
#          so each server is available as .#<name> (e.g. .#mcp-nixos).
#
# To add a new server:
#   1. Add an entry to the `servers` attrset in modules/mcp-servers/registry.nix
#   2. Done — this module re-exports the whole set automatically.
# =============================================================================

{ lib, ... }: {
  perSystem = { pkgs, ... }: {
    packages = import ../../modules/mcp-servers/registry.nix {
      inherit (pkgs) lib uv nodejs writeScript writeShellApplication python3;
    };
  };
}
