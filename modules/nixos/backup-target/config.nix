{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.backup-target;
  inherit (lib) mkIf mkMerge;
  sourceHosts = builtins.attrNames cfg.sources;
  sourcePubKeys = lib.mapAttrsToList (_: s: s.publicKey) (lib.filterAttrs (_: s: s.publicKey != null) cfg.sources);
  monitoringEnabled = config.my.services.monitoring.enable or false;
  hasPassphrase = config.age.secrets ? "backup-repo-passphrase";

  diskGuard = pkgs.writeShellApplication {
    name = "backup-target-disk-guard";
    runtimeInputs = with pkgs; [ coreutils gawk systemd ];
    text = ''
      # send-alert is installed via environment.systemPackages (email-alerts
      # module), which is not on the minimal systemd service PATH.
      export PATH="/run/current-system/sw/bin:$PATH"
      TARGET_DIR="${cfg.targetDir}"
      THRESHOLD=${toString cfg.diskGuard.threshold}

      PCT=$(${pkgs.coreutils}/bin/df -P "$TARGET_DIR" 2>/dev/null | ${pkgs.gawk}/bin/awk 'NR==2 {print $5}' | ${pkgs.coreutils}/bin/tr -d '%')
      if ! [[ "$PCT" =~ ^[0-9]+$ ]]; then
        echo "backup-target-disk-guard: could not read usage of $TARGET_DIR" \
          | systemd-cat -t backup-target-disk-guard -p warning
        exit 0
      fi

      if [ "$PCT" -ge "$THRESHOLD" ]; then
        if command -v send-alert >/dev/null 2>&1; then
          send-alert -s "Backup target disk $PCT% full (threshold $THRESHOLD%)" \
            -b "The filesystem holding $TARGET_DIR is $PCT% full. Prune restic snapshots or expand storage before backups fail." \
            || true
        else
          echo "backup-target-disk-guard: $TARGET_DIR is $PCT% full (threshold $THRESHOLD%) but send-alert is not installed" \
            | systemd-cat -t backup-target-disk-guard -p warning
        fi
      fi
    '';
  };
in
{
  config = mkIf cfg.enable (mkMerge [
    {
      # Dedicated SFTP-only user. Authorized keys are managed by NixOS via
      # /etc/ssh/authorized_keys.d/<user> (read pre-chroot), so the user's home
      # can safely be the chroot root without createHome.
      users.users.${cfg.user} = {
        isSystemUser = true;
        inherit (cfg) group;
        home = cfg.targetDir;
        createHome = false;
        description = "restic backup target SFTP user (chrooted to targetDir)";
        openssh.authorizedKeys.keys = sourcePubKeys;
      };
      users.groups.${cfg.group} = { };

      # SFTP-chrooted access (Tier 0 §2.2/§3): sources push over SFTP on the
      # existing SSH port 22 — already allowed by the tailnet ACL (tcp:22 in
      # interNodePorts, modules/nixos/common.nix:339) and trustedInterfaces.
      # This deliberately avoids services.restic.server (rest-server HTTP
      # daemon), which would need a new TCP port added to interNodePorts and
      # opens a fresh HTTP surface. ChrootDirectory to targetDir keeps each
      # source inside the backup volume. Home = targetDir (the chroot root) so
      # the post-chroot chdir resolves; the Match block is appended after the
      # ssh module's lanSubnets Match so its settings win for this user.
      services.openssh.extraConfig = ''
        Match User ${cfg.user}
          PasswordAuthentication no
          KbdInteractiveAuthentication no
          AllowTcpForwarding no
          AllowAgentForwarding no
          PermitTTY no
          X11Forwarding no
          ForceCommand internal-sftp
          ChrootDirectory ${cfg.targetDir}
      '';

      # Create the chroot root (root-owned, non-writable — sshd ChrootDirectory
      # requirement) and one per-source subdirectory owned by the backup user.
      system.activationScripts.backupTargetDirs = {
        deps = [ "users" ];
        text = ''
          mkdir -p ${cfg.targetDir}
          chown root:root ${cfg.targetDir}
          chmod 0755 ${cfg.targetDir}
          ${lib.concatMapStrings (h: ''
            mkdir -p ${cfg.targetDir}/${h}
            chown ${cfg.user}:${cfg.group} ${cfg.targetDir}/${h}
            chmod 0750 ${cfg.targetDir}/${h}
          '') sourceHosts}
        '';
      };

      # Disk-space guard: daily df-threshold check against targetDir's
      # filesystem, emailing via send-alert when breached (Tier 0 §5.2).
      systemd.services.backup-target-disk-guard = {
        description = "Backup target disk space guard";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${diskGuard}/bin/backup-target-disk-guard";
        };
      };
      systemd.timers.backup-target-disk-guard = {
        description = "Daily backup target disk space guard";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "30min";
        };
      };
    }

    # restic Prometheus exporter: only when the monitoring module is enabled on
    # this host AND a repo passphrase exists. Single-instance exporter, so it
    # monitors the first configured source's repository by default (override
    # with my.services.backup-target.monitoring.repository). Runs as the backup
    # user so it can read/write the repositories; the passphrase reaches it via
    # systemd LoadCredential (no direct read needed). restic-exporter.py crashes
    # on a not-yet-initialized repository (no config file), so retry slowly and
    # without a start rate limit — it self-heals once the first source backup
    # runs restic init.
    (mkIf (monitoringEnabled && hasPassphrase && sourceHosts != [ ]) {
      services.prometheus.exporters.restic = {
        enable = true;
        repository =
          if cfg.monitoring.repository != null then
            cfg.monitoring.repository
          else
            "${cfg.targetDir}/${builtins.head sourceHosts}";
        passwordFile = config.age.secrets."backup-repo-passphrase".path;
        inherit (cfg) user group;
      };
      systemd.services.prometheus-restic-exporter.serviceConfig = {
        Restart = "on-failure";
        RestartSec = "10min";
        StartLimitIntervalSec = 0;
      };
    })
  ]);
}
