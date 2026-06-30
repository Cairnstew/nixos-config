# ── Legacy/Handcrafted Configuration ──────────────────────────────────────
# Settings migrated to flake modules as the codebase evolves.
# Keep only hardware-specific config that doesn't fit module options yet.

{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ── Bootloader: GRUB with EFI ──────────────────────────────────────────
  # UEFI-only system. Installed as removable so EFI vars aren't touched
  # (important for headless recovery — no monitor needed for boot mgmt).
  boot.loader.grub.enable = true;
  boot.loader.grub.devices = [ "nodev" ];
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true;
  boot.loader.grub.configurationLimit = 10;
  boot.loader.grub.memtest86.enable = true;

  boot.kernelParams = [ "panic=10" ];

  # ── Locale ─────────────────────────────────────────────────────────────
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # ── Docker Data Root ───────────────────────────────────────────────────
  # Store container images and volumes on the large data drive
  virtualisation.docker.daemon.settings = {
    "data-root" = "/mnt/data/docker-data";
  };

  # ── Data Drive ─────────────────────────────────────────────────────────
  # 1.8T SATA SSD mounted for bulk storage (Ollama models, Docker data,
  # nix build temp, etc.)
  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/aaf609bd-e320-4d13-a9a6-fc2cc5cd0f3a";
    fsType = "ext4";
    options = [ "nofail" ];
  };
}
