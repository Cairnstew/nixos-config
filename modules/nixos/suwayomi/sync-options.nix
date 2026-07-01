{ lib, ... }:

let
  inherit (lib) mkOption mkEnableOption types;
in
{
  options.my.services.suwayomi.sync.export = {
    enable = mkEnableOption "Suwayomi library export to git repo";

    interval = mkOption {
      type = types.str;
      default = "weekly";
      example = "daily";
      description = "systemd OnCalendar expression for export frequency";
    };

    repoPath = mkOption {
      type = types.path;
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
      default = false;
      description = ''
        Whether to git push after committing.
        When false, the commit stays local and will be picked up by gitreposync
        on its next pull cycle (if the repo is tracked there).
      '';
    };

    secretPath = mkOption {
      type = types.nullOr types.path;
      default = null;
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
    enable = mkEnableOption "Suwayomi library import from git repo";

    interval = mkOption {
      type = types.str;
      default = "hourly";
      example = "30m";
      description = "systemd OnCalendar expression for import frequency";
    };
  };
}
