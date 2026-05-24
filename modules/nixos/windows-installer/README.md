# Windows Installer

Automated Windows installer on first boot. Downloads Windows ISO via UUP, generates autounattend.xml for unattended installation, injects DSC configuration from dscnix.

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
| `my.services.windowsInstaller.timeZone` | `"GMT Standard Time"` | Windows timezone |
| `my.services.windowsInstaller.isoOutputDir` | `"/var/lib/windows-installer"` | Working directory |
| `my.services.windowsInstaller.dscConfigPath` | `null` | Path to dsc-configuration.yaml |

## Usage

```nix
my.services.windowsInstaller = {
  enable = true;
  windowsDisk = "/dev/nvme0n1";
  localUsername = "user";
  dscConfigPath = "${config.my.services.dscnix.configFile}";
};
```

## Notes

- Requires `uup-builder` flake input
- DSC config injected into `sources\$OEM$\$$\Setup\Scripts\dsc-configuration.yaml`
- Registry run synchronous command in specialize pass applies DSC on first boot
- Password should be set via agenix secret, not committed in plaintext
