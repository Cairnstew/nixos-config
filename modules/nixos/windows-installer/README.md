# Windows Installer

Automated Windows installer on first boot. Downloads a pre-built ISO from a
GitHub release (e.g. `marcinmajsc/uup-dump-build-and-get-windows-iso`), injects
`autounattend.xml` for unattended installation, embeds DSC config from dscnix,
and bootstraps DSC v3 apply on first logon.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.windowsInstaller.enable` | `false` | Enable installer |
| `my.services.windowsInstaller.windowsReleaseTag` | *(required)* | GitHub release tag (e.g. `"26200.8521.25H2.MULTI.X64.PL.E.D.N"`) |
| `my.services.windowsInstaller.windowsRepo` | from `windows-iso-repo` flake input | GitHub repo (`"owner/repo"`) |
| `my.services.windowsInstaller.windowsImageIndex` | `2` | Image index for MULTI ISOs (1=Home, 2=Pro) |
| `my.services.windowsInstaller.isoChecksum` | `null` | Optional SHA-256 checksum for verification |
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
  windowsReleaseTag = "26200.8521.25H2.MULTI.X64.PL.E.D.N";
  windowsImageIndex = 2;
  windowsDisk = "/dev/nvme0n1";
  localUsername = "seanc";
  computerName = "desktop";
  localPasswordFile = config.age.secrets.windows-password.path;
  dscConfigPath = "${config.my.services.dscnix.configFile}";
};
```

## Notes

- **Idempotent**: checks if Windows is already installed (NTFS + bootmgfw.efi)
  before downloading anything
- The ISO is downloaded from a GitHub release as split zip parts, then
  reassembled with 7z at runtime
- Optional SHA-256 checksum verification protects against corrupted downloads
- DSC config + bootstrap script (`apply-dsc.ps1`) injected into
  `sources\$OEM$\$$\Setup\Scripts\`
- `apply-dsc.ps1` installs PowerShell 7 + DSC v3 on first logon and applies
  the injected `dsc-configuration.yaml`
- Password should be set via agenix secret, not committed in plaintext
- Recovery partition creation is disabled by default (cleaner disko layout)
- After Windows Setup, run `nixos-rebuild switch` to trigger
  `windows-post-install` (restores GRUB boot order) and `windows-dsc-sync`
  (pushes updated DSC config to Windows partition)
