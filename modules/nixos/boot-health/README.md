# Boot Health

Boot health tracking with success markers and optional automatic rollback on failure.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.services.bootHealth.enable` | bool | false | Enable boot health tracking |
| `my.services.bootHealth.autoRollback.enable` | bool | false | Enable automatic nix-env --rollback + reboot on emergency detection |
| `my.services.bootHealth.autoRollback.maxAttempts` | int | 1 | Maximum rollback attempts per boot cycle |
| `my.services.bootHealth.stateDir` | str | "/var/lib/boot-health" | State directory for boot health markers |
| `my.services.bootHealth.emailTo` | str | flake.config.me.email | Email address for rollback notifications |

## Usage

```nix
my.services.bootHealth = {
  enable = true;
  autoRollback.enable = true;
};
```

## Dependencies

- **NixOS modules**: `boot-alerting` (reads `/var/lib/boot-alerting/emergency-flag`)
- **Packages**: nix, systemd, coreutils

## Notes

- Runs 5 minutes after boot (ExecStartPre sleep 300).
- Auto-rollback does `nix-env --rollback` on the system profile and reboots.
- `maxAttempts = 1` prevents infinite rollback loops.
- If boot-alerting is not installed, auto-rollback still works but with less context.
