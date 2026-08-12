{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf;
  cfg = config.my.programs.modpack;

  # Stdlib-only Python (urllib.request) — mirrors modules/home/goals. When a
  # later slice needs a third-party module (e.g. for jar introspection), extend
  # the withPackages list here and in home.packages together.
  modpackPython = pkgs.python3.withPackages (_: [ ]);
in
{
  config = mkIf cfg.enable {
    home.packages = [ modpackPython ] ++ cfg.extraPackages;

    home.file."${cfg.dataDir}/.keep".text = "";

    my.programs.opencode.mcp.modrinth = {
      enabled = true;
      type = "local";
      command = [
        "${modpackPython}/bin/python3"
        "${./mcp_server.py}"
        "--base-url"
        cfg.modrinth.baseUrl
        "--user-agent"
        cfg.modrinth.userAgent
      ];
      timeout = 120000;
    };
  };
}
