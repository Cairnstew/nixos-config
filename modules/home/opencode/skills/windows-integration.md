# Windows Integration

> Skill for managing Windows dual-boot, PXE netboot, DSC configuration, and unattended installs

## Overview

This system supports Windows integration at multiple levels:
- **Dual-boot**: GRUB chainloads Windows Boot Manager on the desktop
- **PXE Netboot**: Network-boot Windows installer for headless machines
- **DSC (Desired State Configuration)**: Nix-to-Windows managed config
- **Ventoy**: Multi-boot USB with Windows ISOs

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
(`windows-post-install` in `configurations/nixos/desktop/default.nix`) restores
GRUB to the front after the first boot following a Windows install.

## PXE Netboot

The `my.services.netboot` module provides network booting (DHCP + TFTP + HTTP).

### Modes
- **CLI mode** (`serveMode = "cli"`): Interactive tool to start/stop PXE services
- **Daemon mode** (`serveMode = "daemon"`): Persistent systemd services

### Windows Netboot
```nix
my.services.netboot = {
  enable = true;
  serveMode = "cli";  # or "daemon"
  interface = "eth0";
  serverAddress = "192.168.100.1";
  windows.enable = true;
};
```

### Machine Definitions
```nix
my.services.netboot.machines."aa:bb:cc:dd:ee:ff" = {
  windows.unattended = {
    enable = true;
    edition = "Windows 11 Pro";
    localUser = "admin";
    password = "temporary-password";  # Change after install!
    timeZone = "GMT Standard Time";
    computerName = "DESKTOP-ABC";
  };
};
```

### NixOS Auto-Install via Netboot
```nix
my.services.netboot.machines."aa:bb:cc:dd:ee:ff" = {
  nixos.autoInstall = {
    enable = true;
    diskoConfig = { ... };  # disko layout attrset
    nixosConfig = ''...'';  # NixOS module expression as string
  };
};
```

## DSC (Desired State Configuration)

DSC v3 generates a YAML configuration from Nix options, applied by a PowerShell
script during Windows setup.

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
1. `autounattend.xml` is generated at build time by `packages/autounattend-xml`
2. Contains a `FirstLogonCommand` that downloads `apply-dsc.ps1` from the PXE HTTP server
3. The script installs PowerShell 7 + DSC v3 and applies the YAML config

## Unattended Windows Install (autounattend.xml)

The answer file drives Windows Setup without user interaction.

### Answer File Templates
Located at `packages/ventoy/answer-files/`:
- `dev.xml` — Developer workstation (auto-logon)
- `minimal.xml` — Minimal install (manual account)
- `domain.xml` — Corporate domain join
- `kiosk.xml` — Kiosk mode (999 auto-logons)
- `dual-boot.xml` — Dual-boot setup (wipes disk)

### Security Notes
- The admin password is in plaintext in `autounattend.xml` over HTTP
- Mitigation: Use isolated PXE VLAN, set temporary password
- Use `passwordFile` for eval-time file reads (not runtime paths like `/run/agenix/`)

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

### Netboot client gets DHCP but no PXE
Check dnsmasq config doesn't conflict with natShare. If both target the same
interface, netboot delegates PXE options to natShare via `extraDnsmasqSettings`.

### ISO repack fails with "same Joliet name"
Add `-joliet-long` to genisoimage flags (already fixed in `windows-installer/services.nix`).

### UEFI firmware can't boot repacked ISO
Verify both BIOS (`-b boot/etfsboot.com`) and UEFI (`-eltorito-alt-boot -e efi/microsoft/boot/efisys.bin`)
El Torito entries are present (already fixed in `windows-installer/services.nix`).
