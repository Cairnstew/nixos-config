{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  dmCfg = cfg.displayManager;
in
{
  config = lib.mkIf (cfg.enable && dmCfg.enable) (lib.mkMerge [

    # ── SDDM (graphical login with backgrounds) ────────────────────────────
    (lib.mkIf (dmCfg.greeter == "sddm") {
      services.xserver.enable = true;
      services.displayManager.sddm.wayland.enable = true;
      services.displayManager.defaultSession = "hyprland";

      services.displayManager.sddm = {
        enable = true;
        enableHidpi = dmCfg.sddm.enableHidpi;
        theme = "${dmCfg.sddm.theme}/share/sddm/themes/${dmCfg.sddm.themeName}";
        extraPackages = [ dmCfg.sddm.theme ];
        settings = {
          Autologin.Session = "";
          General.HaltCommand = "${pkgs.systemd}/bin/systemctl poweroff";
          General.RebootCommand = "${pkgs.systemd}/bin/systemctl reboot";
          Theme.CursorTheme = "Adwaita";
        }
        // lib.optionalAttrs dmCfg.sddm.numlock {
          General.Numlock = "on";
        }
        // lib.optionalAttrs (dmCfg.sddm.background != null) {
          Theme.Background = "${dmCfg.sddm.background}";
        };
      };

      services.greetd = {
        enable = lib.mkForce false;
        settings = { };
      };
    })

    # ── greetd (TTY-based greeter) ─────────────────────────────────────────
    (lib.mkIf (dmCfg.greeter == "greetd") {
      services.greetd = {
        enable = true;
        settings.default_session = {
          command = "${dmCfg.greeterPackage}/bin/tuigreet ${lib.escapeShellArgs dmCfg.extraGreetdArgs} --cmd ${dmCfg.sessionCommand}";
          user = "greeter";
        };
      };

      systemd.services.greetd.serviceConfig = {
        Type = "idle";
        StandardInput = "tty";
        StandardOutput = "tty";
        StandardError = "journal";
        TTYReset = true;
        TTYVHangup = true;
        TTYVTDisallocate = true;
      };
    })
  ]);
}
