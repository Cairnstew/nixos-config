{ lib, flake, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.bootAlerting = {
    enable = mkEnableOption "Emergency mode alerting and previous-boot failure detection";

    emergencyHook = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Inject best-effort email sending into emergency.service ExecStartPost.
          Network must be explicitly started (not guaranteed in emergency mode).
        '';
      };

      networkTimeout = mkOption {
        type = types.int;
        default = 10;
        description = "Seconds to wait for network to come up in emergency mode before giving up.";
      };
    };

    detectPreviousBoot = mkOption {
      type = types.bool;
      default = true;
      description = ''
        On each clean boot, check if the previous boot activated emergency.target.
        If so, send a detailed failure report email.
      '';
    };

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/boot-alerting";
      description = "State directory path for the emergency flag file.";
    };

    emailTo = mkOption {
      type = types.str;
      default = flake.config.me.email or "root@localhost";
      description = "Email address to receive boot-failure alerts.";
    };
  };
}
