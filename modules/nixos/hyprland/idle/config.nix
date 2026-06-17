{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  idleCfg = cfg.idle;

  lockCmd = if cfg.lockscreen.useHyprlock then "hyprlock" else "swaylock";

  listenerBlocks = lib.concatStringsSep "\n" (builtins.map (l: ''
    listener {
        timeout = ${toString l.timeout}
        on-timeout = ${l.on-timeout}
        ${lib.optionalString (l ? on-resume) "on-resume = ${l.on-resume}"}
    }
  '') (lib.filter (l: l ? timeout && l.timeout > 0) [
    (lib.optionalAttrs (idleCfg.lockTimeout > 0) {
      timeout = idleCfg.lockTimeout;
      on-timeout = "loginctl lock-session";
    })
    (lib.optionalAttrs (idleCfg.dpmsTimeout > 0) {
      timeout = idleCfg.dpmsTimeout;
      on-timeout = "hyprctl dispatch dpms off";
      on-resume = "hyprctl dispatch dpms on";
    })
    (lib.optionalAttrs (idleCfg.suspendTimeout > 0) {
      timeout = idleCfg.suspendTimeout;
      on-timeout = "systemctl suspend";
    })
  ]));

  hypridleConf = ''
    general {
        lock_cmd = pidof ${lockCmd} || ${lockCmd}
        unlock_cmd = pidof ${lockCmd} && killall ${lockCmd} || true
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = hyprctl dispatch dpms on
    }

    ${listenerBlocks}
  '';
in
{
  config = lib.mkIf (cfg.enable && idleCfg.enable) {
    environment.etc."hypr/hypridle.conf".text = hypridleConf;

    # hypridle 0.1.7 has a bug where --config is ignored and
    # getMainConfigPath() only searches standard paths.
    # Place the config in ~/.config/hypr/ so it's found automatically.
    home-manager.users.${cfg.user}.home.file.".config/hypr/hypridle.conf" = {
      text = hypridleConf;
      enable = true;
    };

    systemd.user.services.hypridle = {
      description = "Hyprland's idle daemon";
      documentation = [ "https://wiki.hyprland.org/Hypr-Ecosystem/hypridle" ];
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      path = [
        config.programs.hyprland.package
        config.programs.hyprlock.package
        pkgs.procps
      ];
      unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.hypridle}/bin/hypridle";
        Restart = "on-failure";
      };
    };
  };
}
