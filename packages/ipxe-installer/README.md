# ipxe-installer

PXE netboot server for unattended Windows and NixOS installation.

## Quick Start

```bash
# Sync Windows ISO boot files (one-time)
ipxe-installer sync-iso

# Start PXE server for a machine
sudo ipxe-installer serve -i enp0s13f0u2 -a 192.168.99.1 \
  -p dual-boot -m a8:a1:59:8d:28:ec
```

## Commands

| Command | Description |
|---------|-------------|
| `serve` | Start PXE server (DHCP + TFTP + HTTP) |
| `advance` | Advance machine to next stage |
| `list` | List profiles and machines |
| `sync-iso` | Download/extract Windows ISO boot files |
| `gen-unattend` | Generate autounattend.xml |
| `gen-dsc` | Generate apply-dsc.ps1 |

## Stages

The install flow runs through ordered stages:

1. **nixos** — Netboot installer partitions disk with disko, runs nixos-install
2. **windows** — wimboot loads Windows PE, unattended install to pre-existing partition
3. **done** — Exit iPXE, boot from local disk

Use `advance <mac>` to move between stages.

## NixOS Module

```nix
{
  imports = [ flake.inputs.self.nixosModules.ipxe-installer ];
  my.services.ipxeInstaller = {
    enable = true;
    interface = "enp0s13f0u2";
    serverAddress = "192.168.99.1";
    windows.enable = true;
    profiles.dual-boot = {
      description = "NixOS + Windows 11";
      stages = [ "nixos" "windows" "done" ];
      windows.unattended = {
        enable = true;
        computerName = "DESKTOP";
      };
      nixos.autoInstall = {
        enable = true;
        diskoConfig = { ... };
      };
    };
    machines.desktop = {
      macAddress = "a8:a1:59:8d:28:ec";
    };
  };
}
```

## Development

```bash
cd packages/ipxe-installer
nix develop          # dev shell with editable install
uv add <pkg>         # add dependency
pytest               # run tests
nix build            # production build
nix run . -- --help  # run via Nix
```
