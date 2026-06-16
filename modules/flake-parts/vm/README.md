# VM — Per-Host QEMU VM Runner

Generates graphical and headless QEMU VM packages for each NixOS host,
backed by the nixpkgs `qemu-vm` module.

## Usage

Enable in any host that should build VM packages:

```nix
my.vm = {
  enable = true;
  hosts = [ "laptop" "desktop" ];  # empty = all hosts
  memory = 4096;
  cores = 4;
};
```

Build and run a graphical VM:
```bash
nix build .#laptop-vm
./result/bin/run-laptop-vm
```

Headless (serial console only):
```bash
nix build .#laptop-vm-headless
./result/bin/run-laptop-vm-headless
```

## Port Forwarding

```nix
my.vm.portForward = {
  ssh = { host = 2222; guest = 22; };
  http = { host = 8080; guest = 80; };
};
```

This adds `hostfwd` rules so you can SSH into the VM at `localhost:2222`.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.vm.enable` | `false` | Enable VM builders |
| `my.vm.hosts` | `[]` | Hostnames to build VMs for (empty = all) |
| `my.vm.memory` | `2048` | RAM in MB |
| `my.vm.cores` | `2` | CPU cores |
| `my.vm.diskSize` | `4096` | Disk size in MB |
| `my.vm.portForward` | `{}` | Port forwarding rules |
