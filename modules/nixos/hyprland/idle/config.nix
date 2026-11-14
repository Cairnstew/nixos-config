{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  idleCfg = cfg.idle;

  # The locker is whichever `lockscreen.package` resolves to (hyprlock when
  # useHyprlock, swaylock otherwise). Use the store path, not a bare name, and
  # take the pidof/killall name from the package so the two never disagree.
  locker = cfg.lockscreen.package;
  lockerName = lib.getName locker;
  lockCmd = lib.getExe locker;

  # Hyprland 0.57 parses the config as Lua, and `hyprctl dispatch` now parses its
  # whole argument as Lua as well — the legacy `hyprctl dispatch dpms off` fails
  # with "')' expected near 'off'" (GOTCHAS.md:2339). `hl.dsp.*` only *builds* a
  # dispatcher object, so it must be handed to `hl.dispatch()` to actually run:
  # `hyprctl eval 'hl.dsp.dpms("off")'` returns `ok` and does nothing.
  # The action must be a TABLE: the bare-string form `hl.dsp.dpms("off")` silently
  # toggles DPMS instead of setting it, so `off` flipped the screens back on
  # (verified 2026-11-13: string form alternated ON/OFF on every call, table form
  # set the requested state every time).
  luaDispatch = expr: "hyprctl eval \"hl.dispatch(${expr})\"";

  dpmsAction = action: luaDispatch "hl.dsp.dpms({ action = '${action}' })";

  listenerBlocks = lib.concatStringsSep "\n" (builtins.map
    (l: ''
      listener {
          timeout = ${toString l.timeout}
          on-timeout = ${l.on-timeout}
          ${lib.optionalString (l ? on-resume) "on-resume = ${l.on-resume}"}
      }
    '')
    (lib.filter (l: l ? timeout && l.timeout > 0) [
      (lib.optionalAttrs (idleCfg.lockTimeout > 0) {
        timeout = idleCfg.lockTimeout;
        on-timeout = "loginctl lock-session";
      })
      (lib.optionalAttrs (idleCfg.dpmsTimeout > 0) {
        timeout = idleCfg.dpmsTimeout;
        on-timeout = dpmsAction "off";
        on-resume = dpmsAction "on";
      })
      (lib.optionalAttrs (idleCfg.suspendTimeout > 0) {
        timeout = idleCfg.suspendTimeout;
        on-timeout = "systemctl suspend";
      })
    ]));

  hypridleConf = ''
    general {
        lock_cmd = pidof ${lockerName} || ${lockCmd}
        unlock_cmd = pidof ${lockerName} && killall ${lockerName} || true
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = ${dpmsAction "on"}
    }

    ${listenerBlocks}
  '';
in
{
  config = lib.mkMerge [
    # `programs.hyprlock.enable` (what lockscreen.useHyprlock turns on) *also*
    # force-enables nixpkgs' `services.hypridle`, whose unit is
    # `wantedBy = graphical-session.target` and whose package brings its own
    # unit files. That is exactly the ordering that makes hypridle start before
    # WAYLAND_DISPLAY is imported and die in start-limit-hit (see below), so the
    # nixpkgs toggle is overridden and this module's unit stays authoritative.
    (lib.mkIf cfg.enable {
      services.hypridle.enable = lib.mkForce false;
    })

    (lib.mkIf (cfg.enable && idleCfg.enable) {
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
        # Bound to hyprland-session.target (like waybar/pyprland/wallpapers), NOT
        # graphical-session.target: the exec-once that starts hyprland-session.target
        # is also what imports WAYLAND_DISPLAY into the systemd user environment
        # (core/config.nix). Ordering off graphical-session.target let hypridle start
        # before that import, fail wl_display_connect, and burn its 6 retries into
        # start-limit-hit — dead for the rest of the session.
        partOf = [ "hyprland-session.target" ];
        after = [ "hyprland-session.target" ];
        wantedBy = [ "hyprland-session.target" ];
        path = [
          config.programs.hyprland.package
          config.programs.hyprlock.package
          # `lock_cmd` below execs this exact binary (swaylock by default), and the
          # unit's PATH is *only* this list — it does not include
          # /run/current-system/sw/bin, so an uninstalled-from-here lock command
          # failed with "swaylock: command not found" (seen 2026-11-13).
          cfg.lockscreen.package
          pkgs.procps
        ];

        # hypridle reads its listeners once at startup; without this a rebuild that
        # changes hypridle.conf leaves the daemon on the previous timers forever
        # (seen 2026-11-13: rebuilt at 17:52, daemon still on pre-rebuild rules).
        # The trigger is the content-addressed etc source, so it only fires when
        # the generated config actually changes.
        restartTriggers = [ config.environment.etc."hypr/hypridle.conf".source ];

        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.hypridle}/bin/hypridle";
          Restart = "on-failure";
        };
      };
    })
  ];
}
