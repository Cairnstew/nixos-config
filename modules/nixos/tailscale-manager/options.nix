{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.tailscale-manager = {
    enable = mkEnableOption "Tailscale auth key management via Terraform";

    tailnet = mkOption {
      type = types.str;
      default = "-";
      description = ''
        Tailnet name, e.g. "example.com". Pass "-" to auto-resolve from the
        OAuth credential.
      '';
    };

    tags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "tag:ci" "tag:infra" ];
      description = "Tags to apply to the managed auth key.";
    };

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/tailscale-manager";
      description = "Directory for Terraform state and backups.";
    };

    backupCount = mkOption {
      type = types.int;
      default = 5;
      description = "Number of tfstate backups to retain.";
    };

    watchCredentials = mkOption {
      type = types.bool;
      default = true;
      description = "Create a systemd path unit that re-runs apply when the credentials file changes.";
    };
  };
}
