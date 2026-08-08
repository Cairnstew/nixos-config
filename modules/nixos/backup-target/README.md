# Backup Target

Server-side restic backup destination. Each configured source host gets its own
restic repository at `<targetDir>/<hostname>` on the server's data volume, and
sources push over SFTP through the existing SSH port 22 (chrooted to
`targetDir`). No new ports, no HTTP surface, no rest-server daemon.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.backup-target.enable` | `false` | Enable the target |
| `my.services.backup-target.targetDir` | `/mnt/data/backup` | Repository root (SFTP chroot) |
| `my.services.backup-target.user` | `backup` | SFTP system user |
| `my.services.backup-target.group` | `backup` | Primary group |
| `my.services.backup-target.sources.<name>.publicKey` | `null` | Source's SSH public key |
| `my.services.backup-target.monitoring.repository` | `null` | Restic exporter repo (default: first source) |
| `my.services.backup-target.diskGuard.threshold` | `85` | Alert when target fs is this % full |

## Usage

```nix
my.services.backup-target = {
  enable = true;
  sources = {
    desktop = { publicKey = "ssh-ed25519 AAAA…"; };
    laptop  = { publicKey = "ssh-ed25519 AAAA…"; };
  };
};
```

## Notes

- `targetDir` must live on a data volume, never the root filesystem.
- The `backup` user is SFTP-only (`internal-sftp` forced command), chrooted to
  `targetDir`; authorized keys are managed via `/etc/ssh/authorized_keys.d`.
- A daily disk-space guard emails via `send-alert` when `targetDir`'s
  filesystem crosses `diskGuard.threshold` (needs the email-alerts module).
- The restic Prometheus exporter (`services.prometheus.exporters.restic`) is
  wired only when the monitoring module is enabled on this host.
