# Backup Source

Client-side restic backup. Each configured job becomes a
`services.restic.backups.<name>` definition that pushes encrypted, deduplicated
snapshots to a backup-target host over SFTP (tailnet SSH port 22). Scheduling,
retention and pruning are delegated to the upstream nixpkgs restic module — this
module only provides namespaced defaults and agenix secret wiring.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.backup-source.enable` | `false` | Enable the source |
| `my.services.backup-source.targetHost` | `server.tail685690.ts.net` | Target host |
| `my.services.backup-source.user` | `backup` | SFTP user on the target |
| `my.services.backup-source.sshIdentity` | `/run/agenix/backup-ssh-key` | Private key for SFTP |
| `my.services.backup-source.defaultExcludes` | git-managed paths | Applied to every job |
| `my.services.backup-source.jobs.<name>.paths` | `[]` | Paths to back up |
| `my.services.backup-source.jobs.<name>.exclude` | `[]` | Job excludes (merged with defaults) |
| `my.services.backup-source.jobs.<name>.timerConfig` | daily, `Persistent = true` | Schedule |
| `my.services.backup-source.jobs.<name>.pruneOpts` | keep-daily/weekly/monthly | Retention |
| `my.services.backup-source.jobs.<name>.initialize` | `true` | Init repo if missing |
| `my.services.backup-source.jobs.<name>.checkOpts` | `[]` | `restic check` options |
| `my.services.backup-source.jobs.<name>.extraBackupArgs` | `[]` | Extra backup args |

## Usage

```nix
my.services.backup-source = {
  enable = true;
  jobs.home = {
    paths = [ "/home/seanc" ];
  };
};
```

## Notes

- Requires the agenix secrets `backup-repo-passphrase` (repo password) and
  `backup-ssh-key` (SFTP private key). Until they exist the jobs are inert and a
  warning is emitted.
- Repository URL is `sftp:backup@<targetHost>:/<hostname>` — the path is
  chroot-relative on the target (`/<hostname>` → `<targetDir>/<hostname>`).
- `timerConfig.Persistent = true` (default) makes laptops catch up on wake after
  missing a scheduled run.
- Default excludes skip data already backed up to GitHub via git (nixos-config
  clone + suwayomi export, git-backed Obsidian vault, `.git` dirs).
