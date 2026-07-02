# Disko (Dual Boot)

Declarative disk partitioning for dual-boot NixOS + Windows systems using disko.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.disko.dualBoot.enable` | bool | false | Enable dual-boot with NixOS and Windows |
| `my.disko.dualBoot.mode` | "fresh" or "useExisting" | "useExisting" | Partitioning mode |
| `my.disko.dualBoot.disk` | str | "/dev/nvme0n1" | Disk device for NixOS root |
| `my.disko.dualBoot.espSizeGB` | int | 1 | ESP size in GB (fresh mode) |
| `my.disko.dualBoot.msrSizeMB` | int | 16 | MSR partition size in MB (fresh mode) |
| `my.disko.dualBoot.windowsSizeGB` | int | 150 | Windows partition size in GB (fresh mode) |
| `my.disko.dualBoot.nixosSizeGB` | null or int | null | NixOS partition size; null = remaining space |
| `my.disko.dualBoot.reservedSizeGB` | int | 0 | Unpartitioned space at end of disk (GB) |
| `my.disko.dualBoot.nixosPartition` | null or str | null | Existing NixOS partition (useExisting mode) |
| `my.disko.dualBoot.espPartition` | null or str | null | Existing ESP partition (useExisting mode) |
| `my.disko.dualBoot.useOSProber` | bool | false | Enable os-prober for boot entry detection |
| `my.disko.dualBoot.detection.*` | various | null | Internal detection metadata (set by detect-dualboot) |

## Usage

```nix
my.disko.dualBoot = {
  enable = true;
  mode = "useExisting";
  disk = "/dev/nvme0n1";
  nixosPartition = "/dev/nvme0n1p5";
  espPartition = "/dev/disk/by-partlabel/disk-main-ESP";
};
```

## Dependencies

- **Flake inputs**: `disko` (numtide/disko)
- **NixOS modules**: `nixosModules.common` (for boot.loader.grub defaults)

## Notes

- "fresh" mode creates partitions: ESP → MSR → Windows → NixOS.
- "useExisting" declares all four partitions but only formats NixOS.
- A `windows-post-install` systemd service restores GRUB EFI boot order after Windows Setup resets it.
- `nixosSizeGB` is required when `reservedSizeGB > 0`.
