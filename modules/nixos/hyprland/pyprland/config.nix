{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  pyprCfg = cfg.pyprland;

  pyprlandToml = ''
    [pyprland]
    plugins = ${builtins.toJSON pyprCfg.plugins}
  '';
in
{
  config = lib.mkIf (cfg.enable && pyprCfg.enable) {
    environment.systemPackages = with pkgs; [ pyprland ];

    environment.etc."xdg/pyprland.toml".text = pyprlandToml;

    systemd.user.services.pyprland = {
      description = "Pyprland Hyprland IPC plugin system";
      wantedBy = [ "hyprland-session.target" ];
      partOf = [ "hyprland-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.pyprland}/bin/pypr";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
