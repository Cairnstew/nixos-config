{ config, lib, ... }:
let
  cfg = config.my.services.backup-source;
  hasPassphrase = config.age.secrets ? "backup-repo-passphrase";
in
{
  config = lib.mkIf cfg.enable {
    # Thin wrapper over services.restic.backups: namespaced defaults + secret
    # wiring only. Scheduling, retention and pruning are upstream's.
    # The repository path is chroot-relative on the target: /<hostname> maps to
    # <targetDir>/<hostname> (see backup-target, SFTP ChrootDirectory).
    # The SSH identity is passed via sftp.args, which restic appends between
    # `-l <user>` and `-s sftp` (restic buildSSHCommand) — single quotes keep
    # systemd from splitting the value; restic re-splits it shell-style.
    # The jobs are inert until the backup-repo-passphrase secret exists
    # (SECRETS.md ?-guard pattern), so CI/hosts without it still evaluate.
    services.restic.backups = lib.mkIf hasPassphrase (
      lib.mapAttrs'
        (name: job:
          lib.nameValuePair name {
            repository = "sftp:${cfg.user}@${cfg.targetHost}:/${config.networking.hostName}";
            passwordFile = config.age.secrets."backup-repo-passphrase".path;
            extraOptions = [
              "sftp.args='-i ${cfg.sshIdentity} -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=60 -o ServerAliveCountMax=240'"
            ];
            paths = job.paths;
            exclude = cfg.defaultExcludes ++ job.exclude;
            timerConfig = job.timerConfig;
            pruneOpts = job.pruneOpts;
            initialize = job.initialize;
            checkOpts = job.checkOpts;
            extraBackupArgs = job.extraBackupArgs;
            user = "root";
          })
        cfg.jobs
    );

    warnings = lib.optionals (!hasPassphrase) [
      "my.services.backup-source is enabled but the agenix secret 'backup-repo-passphrase' is not in the manifest yet — restic jobs are inert until it is added (SECRETS.md guard pattern)."
    ];
  };
}
