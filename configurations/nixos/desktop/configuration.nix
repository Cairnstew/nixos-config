# Minimal host-specific config — profiles handle most settings.
# Bootloader, networking, locale, and user groups that differ from defaults.
{ config, pkgs, ... }:

{
  networking.networkmanager.enable = true;

  # F14: defaultLocale is current-location.nix:47 mkDefault "en_GB.UTF-8" — redundant (recon F14)
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

  # F14: xkb layout "us" is workstation.nix:25 mkDefault — redundant (recon F14)

  users.users.seanc = {
    # F8: isNormalUser is common.nix:156 mkDefault true (recon F8)
    description = "Sean Cairns";
    # extraGroups removed — matches common.nix default [networkmanager terraform wheel] (M4b)
    # Remove this line after first SSH login. (recon F9)
    initialPassword = "changeme";
  };
}
