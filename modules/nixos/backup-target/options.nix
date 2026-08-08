{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.backup-target = {
    enable = mkEnableOption "server-side restic backup target (SFTP-chrooted repositories)";

    targetDir = mkOption {
      type = types.str;
      default = "/mnt/data/backup";
      description = ''
        Root directory for backup repositories. Each configured source gets
        <targetDir>/<hostname>. Must live on a data volume, never the root
        filesystem (the server's root NVMe has little free space — Tier 0 §1.3).
        This directory becomes the SFTP chroot for the backup user, so it is
        created root-owned (0755) with per-source subdirectories owned by the
        backup user.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "backup";
      description = "System user that owns the backup repositories and is the SFTP identity for sources.";
    };

    group = mkOption {
      type = types.str;
      default = "backup";
      description = "Primary group of the backup user.";
    };

    sources = mkOption {
      type = types.attrsOf (types.submodule {
        options.publicKey = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            OpenSSH public key of this source's backup identity. When set it is
            authorized for the backup user (SFTP only, chrooted to targetDir).
            The subdirectory <targetDir>/<attrname> is created for the source
            regardless, scoping where its key can write.
          '';
        };
      });
      default = { };
      example = {
        desktop = { publicKey = "ssh-ed25519 AAAA…"; };
      };
      description = "Expected backup source hostnames (attrset keys) and their SSH public keys.";
    };

    monitoring = {
      repository = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Repository the restic Prometheus exporter monitors. Defaults to the
          first configured source's repository (<targetDir>/<firstSource>).
          Only applies when the monitoring module is enabled on this host.
        '';
      };
    };

    diskGuard = {
      threshold = mkOption {
        type = types.ints.between 1 99;
        default = 85;
        description = "Alert (via send-alert) when targetDir's filesystem is at or above this percent full.";
      };
    };
  };
}
