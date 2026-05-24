# Windows Installer

Automated Windows installer on first boot. Downloads Windows ISO via UUP, generates autounattend.xml for unattended installation.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.windowsInstaller.enable` | `false` | Enable installer |
| `my.services.windowsInstaller.windowsDisk` | `"/dev/nvme0n1"` | Target disk |
| `my.services.windowsInstaller.windowsBuild` | `"windows-11"` | Build version |

## Usage

```nix
my.services.windowsInstaller = {
  enable = true;
  windowsDisk = "/dev/nvme0n1";
};
```
