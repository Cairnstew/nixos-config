# Minimal host-specific config — profiles handle most settings.
# Bootloader, networking, locale, and user groups that differ from defaults.
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # GRUB is managed by my.disko.dualBoot (disko config.nix).
  # Hardcoded "Windows 11" entry points to the ESP label.
  # os-prober is disabled (explicit entry replaces it).

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
