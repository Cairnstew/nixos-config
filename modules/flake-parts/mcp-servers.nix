# =============================================================================
# mcp-servers.nix — Model Context Protocol (MCP) Server Configuration
# =============================================================================
# Purpose: Defines MCP servers and generates configuration JSON for AI assistants
#          (Claude, Cline, etc.) to access external tools and APIs.
#
# Inputs: Uses top-level flake config options (mcp.servers)
#
# Outputs:
#   - options.mcp.servers — schema for declaring MCP servers
#   - perSystem.packages.mcp-config — generated JSON config file
#
# Consumed by: AI assistant configurations (Claude Desktop, Cline, etc.)
# =============================================================================

{ config, lib, ... }:
let
  # Generate MCP server configuration JSON
  mkMcpConfig = servers:
    {
      mcpServers = lib.mapAttrs
        (name: srv:
          {
            command = srv.command;
            args = srv.args;
          } // lib.optionalAttrs (srv ? env) { inherit (srv) env; }
        )
        servers;
    };
in
{
  # Expose MCP configuration options at the flake level
  options.mcp = {
    servers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          command = lib.mkOption {
            type = lib.types.str;
            description = "Command to run the MCP server";
          };

          args = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Arguments to pass to the command";
          };

          env = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            description = "Environment variables for the MCP server";
          };

          description = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Description of what this MCP server provides";
          };
        };
      });
      default = { };
      description = "MCP servers to make available";
    };
  };

  config = {
    # Generate packages per system
    perSystem = { system, pkgs, ... }:
      let
        mcpConfig = mkMcpConfig config.mcp.servers;
        configFile = pkgs.writeTextFile {
          name = "mcp-servers.json";
          text = builtins.toJSON mcpConfig;
          checkPhase = ''
            ${pkgs.jq}/bin/jq . $out > /dev/null
          '';
        };
      in
      {
        packages.mcp-config = configFile;
      };
  };
}
