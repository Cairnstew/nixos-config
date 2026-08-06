{ lib, ... }:

let
  # F11: mkEnableOption dropped — both enables now declared via mkOption with invariant-core defaults
  inherit (lib) mkOption types;
in
{
  options.my.services.suwayomi.sync.export = {
    enable = mkOption {
      type = types.bool;
      # F11: invariant core default — desktop/server duplicate this; hosts may override (recon F11)
      default = true;
      description = "Whether to enable Suwayomi library export to git repo";
    };

    interval = mkOption {
      type = types.str;
      default = "weekly";
      example = "daily";
      description = "systemd OnCalendar expression for export frequency";
    };

    repoPath = mkOption {
      type = types.path;
      # F11: invariant core default — desktop/server duplicate this; hosts may override (recon F11)
      default = "/home/seanc/nixos-config";
      description = "Path to the git repo where the filtered backup is committed";
      example = "/home/seanc/nixos-config";
    };

    destFile = mkOption {
      type = types.str;
      default = "suwayomi-backup.tachibk";
      example = "suwayomi/suwayomi-backup.tachibk";
      description = "Relative path inside repoPath for the canonical backup file";
    };

    autoPush = mkOption {
      type = types.bool;
      # F11: invariant core default — desktop/server duplicate this; hosts may override (recon F11)
      default = true;
      description = ''
        Whether to git push after committing.
        When false, the commit stays local and will be picked up by gitreposync
        on its next pull cycle (if the repo is tracked there).
      '';
    };

    secretPath = mkOption {
      type = types.nullOr types.path;
      # F11: invariant core default — desktop/server duplicate this; hosts may override (recon F11)
      default = "/run/agenix/github-token";
      example = "/run/agenix/github-token";
      description = ''
        Path to a file containing a GitHub token for HTTPS push authentication.
        Required when autoPush = true (the repo remote is HTTPS, so push cannot
        authenticate without it). The token is injected into the remote URL as
        https://oauth2:TOKEN@github.com/....
        When null and autoPush = false, commit stays local and push is not attempted.
        Follows the same pattern as gitreposync.agenix.secretPath.
      '';
    };
  };

  options.my.services.suwayomi.sync.import = {
    enable = mkOption {
      type = types.bool;
      # F11: invariant core default — desktop/server duplicate this; hosts may override (recon F11)
      default = true;
      description = "Whether to enable Suwayomi library import from git repo";
    };

    interval = mkOption {
      type = types.str;
      default = "hourly";
      example = "30m";
      description = "systemd OnCalendar expression for import frequency";
    };
  };
}
