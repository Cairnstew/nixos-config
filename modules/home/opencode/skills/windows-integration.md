# Windows Integration

> Skill for managing Windows dual-boot, DSC configuration, and unattended installs via Ventoy

## Overview

This system supports Windows integration at multiple levels:
- **Dual-boot**: GRUB chainloads Windows Boot Manager on the desktop
- **DSC (Desired State Configuration)**: Nix-to-Windows managed config, rendered to YAML on the NixOS side
- **Ventoy**: Multi-boot USB with Windows ISOs and unattended answer files

> **Note (2026-08-03):** PXE netboot (`my.services.netboot`) was removed from the repo. Any
> reference to `modules/nixos/netboot/`, `packages/autounattend-xml`, or
> `modules/nixos/windows-installer/` is stale — those modules/packages no longer exist.

## Dual-Boot (Desktop)

The desktop has GRUB EFI as primary bootloader with Windows 11 as a menu entry.

### Partition Layout
```
sda1  EFI       vfat    512M   Shared Windows/NixOS ESP (label: EFI)
sda2  MSR       —        16M   Microsoft Reserved
sda3  Windows   ntfs    ~80G   Windows C: drive (label: Windows)
sda4  NixOS     ext4    Rest   NixOS root (label: nixos)
```

### GRUB Windows Entry
```nix
boot.loader.grub.extraEntries = ''
  menuentry "Windows 11" {
    insmod part_gpt
    insmod fat
    insmod chain
    search --no-floppy --label --set=root ESP
    chainloader /EFI/Microsoft/Boot/bootmgfw.efi
  }
'';
```

### Post-Install: Restore GRUB Boot Order
Windows Setup always sets itself as first EFI entry. A one-shot systemd service
(`windows-post-install`) restores GRUB to the front after the first boot following a
Windows install. It lives in two places:
- `systemd.services.windows-post-install` in `configurations/nixos/desktop/default.nix`
- The same service is also defined in `modules/nixos/disko/config.nix` (dual-boot flow)

## DSC (Desired State Configuration)

DSC v3 generates a YAML configuration from Nix options. The module is `my.services.dscnix`
(`modules/nixos/dscnix/`); the rendered YAML is exposed on the NixOS host, not injected
into a Windows installer (the old PXE-delivered `apply-dsc.ps1` bootstrap is gone).

```nix
my.services.dscnix = {
  enable = true;
  configurationName = "MyWindowsDSC";
  registry = {
    "DisableTelemetry" = {
      keyPath = "HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection";
      valueName = "AllowTelemetry";
      valueData = { DWord = 0; };
    };
  };
  optionalFeatures = {
    "Microsoft-Windows-Subsystem-Linux" = { state = "Installed"; };
    "VirtualMachinePlatform" = { state = "Installed"; };
  };
};
```

### How It Works
1. `my.services.dscnix` renders a DSC v3 YAML document at eval time
2. Output available at `config.my.services.dscnix.configFile` (a Nix derivation) and
   deployed to `/etc/dscnix/desktop.yaml` on the NixOS host
3. Auto-derived values (hostname, dark mode, timezone) come from the host config

## Unattended Windows Install via Ventoy

Windows unattended install is driven by answer-file XML templates on a Ventoy USB —
not by the removed netboot/autounattend-xml path.

### Answer File Templates
Located at `packages/ventoy/answer-files/`:
- `dev.xml` — Developer workstation (auto-logon)
- `minimal.xml` — Minimal install (manual account)
- `domain.xml` — Corporate domain join
- `kiosk.xml` — Kiosk mode (999 auto-logons)
- `dual-boot.xml` — Dual-boot setup (wipes disk)

Templates use `@VAR@` placeholders (`@productKey@`, `@computerName@`, `@username@`,
`@password@`, `@diskId@`, …) substituted at eval time by
`modules/flake-parts/ventoy/answer-files.nix`. Each profile is exported as a
`windows-answ-pro-<name>` package (e.g. `nix build .#windows-answ-pro-dual-boot`).
See `packages/ventoy/answer-files/README.md` for the full variable reference.

### Security Notes
- The admin password is in plaintext in the answer XML
- Mitigation: use a temporary password, change it after install
- Use `ventoy.answerFileSettings.password` (eval-time value), not a runtime path like
  `/run/agenix/` which doesn't exist at eval time

## Ventoy Windows ISO

```nix
my.ventoy.isos = {
  win11-23h2 = {
    source = flake.inputs.windows-iso-src.packages.x86_64-linux."windows-iso-22631.7079.23H2.PRO.X64.EN";
    target = "/iso/windows/22631.7079.23H2.PRO.X64.EN.iso";
  };
};
```

## Troubleshooting

### Windows Setup overwrites GRUB
Run the `windows-post-install` service or manually:
```bash
sudo efibootmgr -o 0000,0001  # Put GRUB first
```

### "Can't find ext4 filesystem" on dual-boot desktop
The disko nodev config references `/dev/disk/by-label/nixos` — if the partition
doesn't exist or has a different label, the mount fails. Verify with `lsblk -f`.

### Windows-post-install runs on every boot
The `windows-post-install` service is idempotent via a `/var/lib/windows-post-install/.done`
stamp — it exits immediately if the stamp exists, and touches it after reordering the EFI
boot entries. If it keeps re-running, check the stamp logic in
`configurations/nixos/desktop/default.nix` (or `modules/nixos/disko/config.nix`).
