{ config, lib, ... }:
let
  # Generate MCP server configuration JSON
  mkMcpConfig = servers:
    {
      mcpServers = lib.mapAttrs (name: srv:
        {
          command = srv.command;
          args = srv.args;
        } // lib.optionalAttrs (srv ? env) { inherit (srv) env; }
      ) servers;
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
            default = [];
            description = "Arguments to pass to the command";
          };

          env = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = {};
            description = "Environment variables for the MCP server";
          };

          description = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Description of what this MCP server provides";
          };
        };
      });
      default = {};
      description = "MCP servers to make available";
    };
  };

  config = {
    # Always provide the nixos MCP server
    mcp.servers.nixos = {
      command = "nix";
      args = [ "run" "./.#mcp-nixos" ];
      description = "Nix/NixOS operations - eval, build, flake check, search";
    };

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

        apps.mcp-nixos = {
          type = "app";
          program = "${pkgs.mcp-nixos}/bin/mcp-nixos";
        };

        packages.mcp-nixos = pkgs.mcp-nixos;
      };
  };
}
