# Windows Installer

Automated Windows 11 installer on first boot. Downloads Windows ISO via UUP,
generates `autounattend.xml` for unattended installation, injects DSC config
from dscnix, and bootstraps DSC v3 apply on first logon.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.windowsInstaller.enable` | `false` | Enable installer |
| `my.services.windowsInstaller.windowsBuild` | `"windows-11"` | Build version |
| `my.services.windowsInstaller.windowsEdition` | `"pro"` | Windows edition |
| `my.services.windowsInstaller.windowsLang` | `"en-gb"` | Language/locale |
| `my.services.windowsInstaller.windowsDisk` | `"/dev/nvme0n1"` | Target disk |
| `my.services.windowsInstaller.windowsPartitionIndex` | `2` | Partition index |
| `my.services.windowsInstaller.localUsername` | `"user"` | Local account name |
| `my.services.windowsInstaller.localPassword` | `""` | Local account password |
| `my.services.windowsInstaller.computerName` | `"WINDOWS-PC"` | Windows computer name |
| `my.services.windowsInstaller.timeZone` | `"GMT Standard Time"` | Windows timezone |
| `my.services.windowsInstaller.isoOutputDir` | `"/var/lib/windows-installer"` | Working directory |
| `my.services.windowsInstaller.dscConfigPath` | `null` | Path to dsc-configuration.yaml |

## Usage

```nix
my.services.windowsInstaller = {
  enable = true;
  windowsDisk = "/dev/nvme0n1";
  localUsername = "seanc";
  computerName = "desktop";
  localPassword = builtins.readFile config.age.secrets.windows-password.path;
  dscConfigPath = "${config.my.services.dscnix.configFile}";
};
```

## Notes

- Requires `uup-builder` flake input
- **Idempotent**: checks if Windows is already installed (NTFS + bootmgfw.efi)
  before downloading anything
- `autounattend.xml` uses the `packages/autounattend-xml` derivation (build-time
  generated, no inline heredoc)
- DSC config + bootstrap script (`apply-dsc.ps1`) injected into
  `sources\$OEM$\$$\Setup\Scripts\`
- `apply-dsc.ps1` installs PowerShell 7 + DSC v3 on first logon and applies
  the injected `dsc-configuration.yaml`
- Password should be set via agenix secret, not committed in plaintext
- Recovery partition creation is disabled by default (cleaner disko layout)
- After Windows Setup, run `nixos-rebuild switch` to trigger
  `windows-post-install` (restores GRUB boot order) and `windows-dsc-sync`
  (pushes updated DSC config to Windows partition)
