# Minimal host-specific config — profiles handle most settings.
# Bootloader, networking, locale, and user groups that differ from defaults.
{ config, pkgs, ... }:

{
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

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  users.users.seanc = {
    isNormalUser = true;
    description = "Sean Cairns";
    # extraGroups removed — matches common.nix default [networkmanager terraform wheel] (M4b)
    initialPassword = "changeme";
  };
}
