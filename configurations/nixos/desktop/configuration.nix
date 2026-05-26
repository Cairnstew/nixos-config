# Minimal host-specific config — profiles handle most settings.
# Bootloader, networking, locale, and user groups that differ from defaults.
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # GRUB with os-prober for NixOS + Windows dual-boot (separate disk /dev/sda)
  boot.loader.grub.enable = true;
  boot.loader.grub.devices = [ "nodev" ];
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.useOSProber = true;
  boot.loader.grub.configurationLimit = 10;
  boot.loader.grub.extraEntries = ''
    menuentry "Windows 11 Setup" {
      insmod part_gpt
      insmod fat
      insmod chain
      search --no-floppy --set=root --file /EFI/Microsoft/Boot/cdboot.efi
      chainloader /EFI/Microsoft/Boot/cdboot.efi
    }
  '';
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  i18n.defaultLocale = "en_GB.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_POSITION = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  services.xserver = {
    layout = "us";
    xkbVariant = "";
  };

  users.users.seanc = {
    isNormalUser = true;
    description = "Sean Cairns";
    extraGroups = [ "networkmanager" "wheel" "docker" "terraform" ];
  };
}
