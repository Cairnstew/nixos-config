{ config, lib, pkgs, flake, ... }:

let
  inherit (lib) mkIf;
  cfg = config.my.programs.cv;
  # Server + schema live in the separate Cairnstew/CV repo, resolved from the
  # flake input (never hardcoded). The path is TEMPORARY until the input flips
  # to github:Cairnstew/CV (see flake.nix comment).
  cv = flake.inputs.cv;
in
{
  config = mkIf cfg.enable {
    home.packages = [
      (pkgs.python3.withPackages (ps: [ ]))
    ];

    home.file."${cfg.dataDir}/.keep".text = "";

    # Mirrors modules/home/goals/config.nix:17-43 exactly in shape: a "local"
    # stdio MCP server registered under my.programs.opencode.mcp.<name>.
    my.programs.opencode.mcp.cv = {
      enabled = true;
      type = "local";
      command = [
        "${pkgs.python3.withPackages (ps: [ ])}/bin/python3"
        "${cv}/mcp_server.py"
        "--db"
        "${cfg.dataDir}/cv.db"
        "--schema"
        "${cv}/schema.sql"
      ];
      timeout = 120000;
    };
  };
}