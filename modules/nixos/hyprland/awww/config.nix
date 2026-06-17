{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  awwwCfg = cfg.awww;

  mkEnvValue = name: value:
    lib.optionalAttrs (value != null) { "${name}" = toString value; };

  environment = lib.mkMerge [
    (mkEnvValue "AWWW_TRANSITION" awwwCfg.transition.type)
    (mkEnvValue "AWWW_TRANSITION_STEP" awwwCfg.transition.step)
    (mkEnvValue "AWWW_TRANSITION_FPS" awwwCfg.transition.fps)
  ] // lib.optionalAttrs (awwwCfg.transition.angle != null) {
    "AWWW_TRANSITION_ANGLE" = toString awwwCfg.transition.angle;
  };

  awwwBin = "${awwwCfg.package}/bin/awww";

  initialImageCmds = builtins.map (img:
    let
      outputFlag = lib.optionalString (img.output != null) "-o ${lib.escapeShellArg img.output}";
    in
    "${awwwBin} img ${outputFlag} ${lib.escapeShellArg img.path} --no-cache"
  ) awwwCfg.images;
in
{
  config = lib.mkIf (cfg.enable && awwwCfg.enable) {
    environment.systemPackages = [ awwwCfg.package ];

    systemd.user.services.awww-daemon = {
      description = "awww animated wallpaper daemon for Wayland";
      documentation = [ "https://codeberg.org/LGFae/awww" ];
      wantedBy = [ "hyprland-session.target" ];
      partOf = [ "hyprland-session.target" ];
      after = [ "hyprland-session.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${awwwCfg.package}/bin/awww-daemon ${lib.escapeShellArgs awwwCfg.daemonArgs}";
        Restart = "on-failure";
        RestartSec = 2;
      };

      environment = lib.mkIf (initialImageCmds != [ ]) environment;

      postStart = lib.mkIf (initialImageCmds != [ ]) (
        lib.concatStringsSep "\n" initialImageCmds
      );
    };
  };
}
