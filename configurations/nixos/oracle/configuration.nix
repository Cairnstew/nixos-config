{ config, lib, pkgs, ... }: {
  boot.loader.systemd-boot.enable = true;
  # No canTouchEfiVariables: OCI instances don't expose efivarfs — NixOS
  # writes /boot directly during install (nixos-anywhere disko).

  networking.networkmanager.enable = true;
  i18n.defaultLocale = "en_US.UTF-8";

  # Headless cloud box — nothing here, services come from profiles/host config.
  services.xserver = lib.mkDefault { };

  environment.systemPackages = with pkgs; [ micro git ];
  system.stateVersion = "26.11";
}
