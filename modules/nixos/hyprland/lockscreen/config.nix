{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  lockCfg = cfg.lockscreen;

  lockPkg = if lockCfg.useHyprlock then pkgs.hyprlock else lockCfg.package;

  swaylockConf = ''
    color=1e1e2e
    ring-color=89b4fa
    inside-color=313244
    text-color=cdd6f4
    line-color=89b4fa
    key-hl-color=cba6f7
    bs-hl-color=f38ba8
    font=JetBrainsMono Nerd Font
    font-size=14
    indicator-radius=80
  '';

  hyprlockConf = ''
    background {
        monitor =
        color = rgba(30, 30, 46, 1.0)
    }

    input-field {
        monitor =
        size = 300, 50
        outline_thickness = 2
        dots_size = 0.33
        dots_spacing = 0.15
        dots_center = true
        outer_color = rgba(137, 180, 250, 0.8)
        inner_color = rgba(49, 50, 68, 1.0)
        font_color = rgba(205, 214, 244, 1.0)
        fade_on_empty = true
        placeholder_text = <i>Password...</i>
        hide_input = false
        position = 0, -80
        halign = center
        valign = center
    }
  '';
in
{
  config = lib.mkIf (cfg.enable && lockCfg.enable) {
    environment.systemPackages = [ lockPkg ];

    environment.etc = lib.optionalAttrs (!lockCfg.useHyprlock) {
      "xdg/swaylock/config".text = swaylockConf;
    } // lib.optionalAttrs lockCfg.useHyprlock {
      "xdg/hypr/hyprlock.conf".text = hyprlockConf;
    };

    programs.hyprlock = lib.mkIf lockCfg.useHyprlock {
      enable = true;
      package = pkgs.hyprlock;
    };
  };
}
