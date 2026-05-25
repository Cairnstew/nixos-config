# Windows Post-Install — EFI Boot Order Recovery

Restores GRUB as the default EFI boot entry after Windows Setup completes.
Runs once (gated by `/var/lib/windows-post-install/.done`).

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.windowsPostInstall.enable` | `false` | Enable boot order recovery |
| `my.services.windowsPostInstall.autoFixBootOrder` | `true` | Auto-restore GRUB as default EFI entry |

## Behavior

1. Checks if `bootmgfw.efi` exists on ESP (Windows installed)
2. If yes and GRUB is not first in boot order, moves GRUB to the front
3. Removes stale "Windows 11 Setup" EFI boot entries
4. Marks done via state file
