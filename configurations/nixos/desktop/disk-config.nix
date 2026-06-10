# Existing partition layout — DO NOT REPARTITION.
# ESP:    vfat  512M  label "EFI"    — Windows + NixOS EFI, NEVER reformatted
# MSR:    —      16M                  — Microsoft Reserved, ignored
# Windows: ntfs ~80G  label "Windows" — C: drive, NEVER touched
# NixOS:  ext4  rest  label "nixos"  — NixOS root, formatted once on first deploy
#
# Uses /dev/disk/by-label/ paths which are stable across reboots (unlike
# sdX device names which can change when disks are discovered in different order).
#
# WARNING: Do NOT add disko.devices.disk here. That triggers sgdisk
# which wipes the partition table and destroys Windows.
#
# Deploy with:
#   nix run .#deploy-desktop -- nixos@<ip>              # auto-detected --disko-mode disko
#   nix run .#deploy-desktop -- nixos@<ip> --disko-mode format  # reformat sdb4 only
#   nix run .#deploy-desktop -- nixos@<ip> --disko-mode mount   # mount only, skip format
{ config, pkgs, lib, ... }: let
  inherit (pkgs) writeScript;
  diskoCfg = config.disko.devices;
in {
  # Override _scripts to generate build outputs from the nodev config directly,
  # bypassing disko's "no disks defined" guard (which requires at least one
  # disko.devices.disk entry). The nodev config already provides _create, _mount,
  # _disko, and _packages via the disko lib — we just wrap them into derivations
  # that nixos-anywhere expects.
  disko.devices._scripts = { pkgs, ... }: {
    diskoScript = (writeScript "disko" ''
      #!${pkgs.bash}/bin/bash
      export PATH=${lib.makeBinPath (diskoCfg._packages pkgs)}:$PATH
      ${diskoCfg._disko}
    '');
    formatScript = (writeScript "disko-format" ''
      #!${pkgs.bash}/bin/bash
      export PATH=${lib.makeBinPath (diskoCfg._packages pkgs)}:$PATH
      ${diskoCfg._create}
    '');
    mountScript = (writeScript "disko-mount" ''
      #!${pkgs.bash}/bin/bash
      export PATH=${lib.makeBinPath (diskoCfg._packages pkgs)}:$PATH
      ${diskoCfg._mount}
    '');
  };

  disko.devices.nodev = {
    "/" = {
      fsType = "ext4";
      device = "/dev/disk/by-label/nixos";
    };
    "/boot" = {
      fsType = "vfat";
      device = "/dev/disk/by-label/EFI";
      mountOptions = [ "umask=0077" ];
    };
  };
}
