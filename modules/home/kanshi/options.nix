{ config, lib, pkgs, ... }:
let
  types = lib.types;
in
{
  options.my.services.kanshi = {
    enable = lib.mkEnableOption "kanshi Wayland output management daemon";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.kanshi;
      defaultText = lib.literalExpression "pkgs.kanshi";
      description = "The kanshi package to use.";
    };

    settings = lib.mkOption {
      type = types.anything;
      default = [ ];
      example = [
        {
          profile = {
            name = "undocked";
            outputs = [
              {
                criteria = "eDP-1";
                status = "enable";
                position = "0,0";
                mode = "1920x1080@60Hz";
                scale = 1.0;
              }
            ];
          };
        }
        {
          profile = {
            name = "docked";
            outputs = [
              {
                criteria = "eDP-1";
                status = "disable";
              }
              {
                criteria = "DP-1";
                status = "enable";
                position = "0,0";
                mode = "3840x2160@60Hz";
                scale = 1.5;
                transform = "90";
              }
            ];
          };
        }
      ];
      description = ''
        Ordered list of kanshi directives (profiles, outputs, or includes).
        See kanshi(5) for available options.

        Each element is an attrset with exactly one key:
        `profile`, `output`, or `include`.

        If you specify an output at the top level (outside a profile),
        it acts as a global output alias.
      '';
    };

    systemdTarget = lib.mkOption {
      type = types.str;
      default = config.wayland.systemd.target or "graphical-session.target";
      defaultText = lib.literalExpression ''
        config.wayland.systemd.target or "graphical-session.target"'';
      description = "The systemd target to bind the kanshi service to.";
    };
  };
}
