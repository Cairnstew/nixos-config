{ lib, flake, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.bootHealth = {
    enable = mkEnableOption "Boot health tracking (success marker, failure detection)";

    autoRollback = {
      enable = mkEnableOption "Automatic nix-env --rollback + reboot on emergency detection";

      maxAttempts = mkOption {
        type = types.int;
        default = 1;
        description = "Maximum rollback attempts per boot cycle (prevents infinite rollback loop).";
      };
    };

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/boot-health";
      description = "State directory path for boot health markers.";
    };

    emailTo = mkOption {
      type = types.str;
      default = flake.config.me.email or "root@localhost";
      description = "Email address for rollback notifications.";
    };
  };
}
