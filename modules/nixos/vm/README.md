# VM — Per-Host VM Configuration

Declares `my.vm.*` options that the flake-level VM builder
(`modules/flake-parts/vm/`) reads to generate per-host QEMU VM packages.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.vm.enable` | `false` | Enable VM build for this host |
| `my.vm.memory` | `2048` | RAM in MB |
| `my.vm.cores` | `2` | CPU cores |
| `my.vm.diskSize` | `4096` | Disk size in MB |
| `my.vm.extraConfig` | `{}` | NixOS module fragment merged only into the VM variant |

## Usage

```nix
my.vm = {
  enable = true;
  memory = 4096;
  extraConfig = {
    my.hardware.gpu.mesa.enable = false;
  };
};
```
