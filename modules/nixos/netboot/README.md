# Netboot Module (`my.services.netboot`)

DHCP + TFTP + HTTP PXE netboot server for multi-stage provisioning (e.g. Windows
Installer → NixOS Installer → local boot).

## Usage

Enable the service and define your machines:

```nix
{
  my.services.netboot = {
    enable = true;
    interface = "eth0";
    serverAddress = "192.168.100.1";

    windows.enable = true;   # Serve Windows installer (requires windows-iso-sync)
    nixos.enable = true;      # Chainload NixOS netboot installer

    machines = {
      my-workstation = {
        macAddress = "00:11:22:33:44:55";
        stages = [ "windows" "nixos" "done" ];
      };
    };
  };
}
```

## Workflow: Provisioning a New Desktop from a Laptop

### 1. Connect & Configure

Connect the laptop's ethernet port to the desktop's ethernet port.
Run the netboot server on the laptop:

```bash
sudo nixos-rebuild switch      # activates PXE server, NAT sharing, HTTP/TFTP
```

### 2. Find the Target MAC

Connect the cable, then on the laptop scan for active MACs on the PXE network:

```bash
sudo netboot-advance scan
```

This reads dnsmasq's DHCP lease file and shows any unconfigured machines that
have received an IP.  If the desktop is powered on (even a regular boot), its
MAC appears here.  Copy the MAC into your host config's `macAddress` field.

Alternatively, check the desktop's BIOS/UEFI network boot screen — it usually
displays the MAC address.

### 3. Discover Stage — Select Disk & Hostname (Optional)

If `stages` includes `"discover"`, the first PXE boot boots an interactive
environment instead of the Windows installer.  The desktop prompts you to
select the target disk, Windows partition size, and hostname:

```
Available disks:
nvme0n1  931.5G  Samsung SSD 980 PRO
sda      240.1G  Kingston SSD

Target disk [/dev/nvme0n1]: /dev/nvme0n1
Windows partition size [150G]:
Hostname [desktop]: my-desktop

Sending config to PXE server... OK
Auto-advancing to next stage... done
Rebooting in 10 seconds...
```

The webhook automatically advances the stage from `discover` to `windows`
(no manual `netboot-advance` needed).  Just PXE boot again to continue.

### 4. Boot Windows Installer

Set the desktop's BIOS to **UEFI Network Boot** (or PXE boot).  On boot:

1. DHCP → laptop gives IP + PXE options
2. TFTP → downloads `ipxe.efi`
3. HTTP → fetches `stage-windows.ipxe` (wimboot + boot.wim)
4. If `windows.unattended.enable`, `autounattend.xml` is injected as a wimboot
   initrd, automating the entire Windows setup

Windows installs to its partition, creates a local admin account, and reboots.

### 5. Advance to NixOS Installer

After Windows reboots, the desktop may try to boot from the local disk
(Windows).  Interrupt the boot and select PXE boot again in the BIOS boot menu.
Before that second PXE boot, advance the stage on the laptop:

```bash
sudo netboot-advance advance 00:11:22:33:44:55
```

### 6. Boot NixOS Installer (Automated)

The desktop PXE boots again, now fetching `stage-nixos.ipxe`, which boots the
custom netboot kernel+initrd.  The installer image automatically:

1. Fetches the per-machine config bundle (`disko.nix` + `configuration.nix`)
2. Runs `disko` to partition remaining space for NixOS
3. Runs `nixos-install` to build and install the target system
4. Runs `grub-mkconfig` inside the new system to detect Windows
5. Reboots

### 7. Done

The desktop boots from local disk into GRUB, which shows both
**NixOS** and **Windows 11** entries.

---

## Stage Management

Each machine's current stage is stored as a **symlink** at
`/srv/pxe/<MAC>.ipxe → stages/<MAC>/stage-<name>.ipxe`.  Advance stages with:

```bash
sudo netboot-advance list                          # Show all machines
sudo netboot-advance scan                          # Find active but unconfigured MACs
sudo netboot-advance advance 00:11:22:33:44:55     # Next stage
sudo netboot-advance reset   00:11:22:33:44:55     # Back to first stage
sudo netboot-advance set     00:11:22:33:44:55 nixos  # Jump to specific stage
```

## Unattended Windows Install

Enable `windows.unattended` per-machine to inject `autounattend.xml` into the
WinPE boot process. The XML is served as an additional wimboot initrd.

```nix
machines = {
  my-pc = {
    macAddress = "00:11:22:33:44:55";
    stages = [ "windows" "nixos" "done" ];
    windows.unattended = {
      enable = true;
      computerName = "TARGET-PC";
      localUser = "admin";
      password = "temporary-password"; # plaintext over HTTP — secure the VLAN
    };
  };
};
```

The password is in plaintext in `autounattend.xml` and served over unencrypted
HTTP. Use an isolated PXE VLAN or change the password post-install.

## Automated NixOS Install

Enable `nixos.autoInstall` for a fully automated NixOS installation via a custom
netboot image (one generic kernel+initrd shared by all machines):

```nix
machines = {
  my-pc = {
    macAddress = "00:11:22:33:44:55";
    stages = [ "windows" "nixos" "done" ];
    nixos.autoInstall = {
      enable = true;
      diskoConfig = {
        disk = {
          type = "disk";
          device = "/dev/nvme0n1";
          content = {
            type = "gpt";
            partitions = {
              esp = { size = "1G"; type = "EF00"; content.type = "filesystem"; format = "vfat"; mountpoint = "/boot"; };
              nixos = { size = "100%"; content.type = "filesystem"; format = "ext4"; mountpoint = "/"; };
            };
          };
        };
      };
      nixosConfig = { pkgs, lib, ... }: {
        system.stateVersion = "25.05";
        networking.hostName = "target-pc";
        boot.loader.grub = {
          enable = true;
          devices = [ "nodev" ];
          efiSupport = true;
          useOSProber = true;
        };
      };
    };
  };
};
```

The generic netboot image boots, fetches the per-machine config bundle from the
PXE server, runs `disko`, then `nixos-install`, then reboots.

## Integration with `windows-iso-sync`

This module serves Windows boot files from `windows.bootDir`
(default: `/srv/pxe/windows`), which matches the default `outputDir` of
`my.services.windowsIsoSync`.  Enable both modules:

```nix
{
  my.services.windowsIsoSync.enable = true;
  my.services.netboot.windows.enable = true;
}
```

The Windows ISO sync module downloads and extracts boot files; the netboot module
serves them over HTTP.

## Architecture

```
Target Machine (PXE boot)
  1. DHCP → gets IP, TFTP server address
  2. TFTP → downloads undionly.kpxe / ipxe.efi
  3. iPXE → HTTP /boot.ipxe
  4. HTTP → <MAC>.ipxe (symlink → current stage)
  5. Stage executes:
     - windows:    wimboot + boot.wim (+ autounattend.xml if enabled)
     - nixos:      custom netboot kernel+initrd, or upstream chainload
     - done:       exit (boot local disk)

Service   | Port         | Role
----------|--------------|--------------------
dnsmasq   | UDP 67/69    | DHCP + TFTP
nginx     | TCP 80       | HTTP (scripts, WIM, config bundles)
```

## File Layout

```
/srv/tftp/
├── undionly.kpxe        ← from pkgs.ipxe (BIOS PXE)
└── ipxe.efi             ← from pkgs.ipxe (UEFI PXE)

/srv/pxe/
├── boot.ipxe            ← main iPXE entrypoint
├── <MAC>.ipxe → ...     ← per-machine state symlink
├── stages/<MAC>/        ← per-machine stage scripts
├── machines/<MAC>/      ← per-machine artifacts
│   ├── autounattend.xml  ← unattended Windows answer file
│   ├── vmlinuz           ← custom NixOS netboot kernel (autoInstall)
│   ├── initrd            ← custom NixOS netboot initrd (autoInstall)
│   └── config.tar.gz     ← disko.nix + configuration.nix (autoInstall)
└── windows/              ← from windows-iso-sync
    ├── boot/{bcd,boot.sdi}
    └── sources/boot.wim
```
