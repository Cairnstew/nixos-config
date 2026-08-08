{ lib, utils, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  unitOption = utils.systemdUtils.unitOptions.unitOption;
in
{
  options.my.services.backup-source = {
    enable = mkEnableOption "client-side restic backup source (push to a backup target over SFTP)";

    targetHost = mkOption {
      type = types.str;
      default = "server.tail685690.ts.net";
      description = "Tailnet hostname/IP of the backup-target host (Tier 0 §2.1: server = 100.78.102.28 / server.tail685690.ts.net).";
    };

    user = mkOption {
      type = types.str;
      default = "backup";
      description = "SFTP username on the target (must match my.services.backup-target.user).";
    };

    sshIdentity = mkOption {
      type = types.str;
      default = "/run/agenix/backup-ssh-key";
      description = "Path to the private SSH key used for the SFTP connection (agenix-decrypted).";
    };

    defaultExcludes = mkOption {
      type = types.listOf types.str;
      default = [
        "**/.git"
        "/home/*/nixos-config"
        "/home/*/Documents/Obsidian_Vault"
      ];
      description = ''
        Exclude patterns applied to every job. Defaults cover git-managed data
        already backed up elsewhere (Tier 0 §5.4): the nixos-config clone and
        suwayomi DB export (gitreposync → GitHub), and the git-backed Obsidian
        vault. Jobs append their own excludes.
      '';
    };

    jobs = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          paths = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Paths to back up.";
          };

          exclude = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Additional exclude patterns merged with defaultExcludes.";
          };

          timerConfig = mkOption {
            type = types.nullOr (types.attrsOf unitOption);
            default = {
              OnCalendar = "daily";
              Persistent = true;
            };
            description = ''
              systemd.timer(5) schedule. Default daily with Persistent = true so
              laptops catch up on wake after missing a scheduled run (Tier 0 §5.7).
              Set null for no timer (manual only).
            '';
          };

          pruneOpts = mkOption {
            type = types.listOf types.str;
            default = [ "--keep-daily 7" "--keep-weekly 4" "--keep-monthly 6" ];
            description = "restic forget --prune options for snapshot retention.";
          };

          initialize = mkOption {
            type = types.bool;
            default = true;
            description = "Create the restic repository if it does not exist.";
          };

          checkOpts = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Options for restic check (empty = no check runs).";
          };

          extraBackupArgs = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Extra arguments passed to restic backup.";
          };
        };
      });
      default = { };
      example = {
        home = {
          paths = [ "/home/seanc" ];
          timerConfig = { OnCalendar = "daily"; Persistent = true; };
        };
      };
      description = "Named restic backup jobs; each delegates to services.restic.backups.<name>.";
    };
  };
}
