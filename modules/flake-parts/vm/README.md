# VM — Per-Host QEMU VM Runner

Generates graphical and headless QEMU VM packages for each NixOS host,
backed by the nixpkgs `qemu-vm` module.

## Usage

Per-host settings are configured in the host's NixOS config:

```nix
my.vm = {
  enable = true;
  memory = 4096;
  extraConfig = { lib, ... }: {
    my.profiles.workstation.enable = lib.mkForce false;
  };
};
```

All hosts with `my.vm.enable = true` get VM packages built automatically.

Build and run a graphical VM:
```bash
nix build .#desktop-vm
./result/bin/run-desktop-vm
```

Headless (serial console only):
```bash
nix build .#desktop-vm-headless
./result/bin/run-desktop-vm-headless
```

## Per-Host Options (set in host NixOS config)

| Option | Default | Description |
|--------|---------|-------------|
| `my.vm.enable` | `false` | Enable VM build for this host |
| `my.vm.memory` | `2048` | RAM in MB |
| `my.vm.cores` | `2` | CPU cores |
| `my.vm.diskSize` | `4096` | Disk size in MB |
| `my.vm.extraConfig` | `{}` | NixOS module fragment merged into this host's VM build only |

## Flake-Level Options (set in any NixOS config)

| Option | Default | Description |
|--------|---------|-------------|
| `my.vm.hosts` | `[]` | Optional filter — only build VMs for these hosts (empty = all enabled hosts) |

## Override example

Strip GPU/battery/hardware config that doesn't work in QEMU and use a
lightweight Hyprland desktop instead of the real host's heavy setup:

```nix
my.vm = {
  enable = true;
  extraConfig = { lib, ... }: {
    my.profiles.workstation.enable = lib.mkForce false;
    my.profiles.gaming.enable = lib.mkForce false;
    my.profiles.gpu.mesa.enable = lib.mkForce false;
    my.system.battery.enable = lib.mkForce false;
    my.desktop.hyprland.enable = true;
  };
};
```
