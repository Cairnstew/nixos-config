{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.programs.steam;
  inherit (flake.config.me) username;
in
{
  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = lib.mkDefault cfg.remotePlay.openFirewall;
      dedicatedServer.openFirewall = lib.mkDefault cfg.dedicatedServer.openFirewall;
    };

    environment.systemPackages = with pkgs; [
      steam-run
      steamcmd
    ] ++ cfg.extraPackages;

    programs.gamemode.enable = lib.mkDefault cfg.gamemode.enable;

    home-manager.users.${username}.home.sessionVariables =
      lib.mkIf (cfg.extraCompatPaths != null) {
        STEAM_EXTRA_COMPAT_TOOLS_PATHS = cfg.extraCompatPaths;
      };
  };
}
