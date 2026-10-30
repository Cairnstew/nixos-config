{ config, pkgs, ... }: {
  boot.loader.systemd-boot.enable = true;
  # No canTouchEfiVariables: OCI instances don't expose efivarfs — NixOS
  # writes /boot directly during install (nixos-anywhere disko).

  networking.networkmanager.enable = true;
  i18n.defaultLocale = "en_US.UTF-8";

  # services.xserver = lib.mkDefault { } removed (H11): it was a no-op —
  # xserver.enable resolves to false on this headless host. Services come from
  # profiles/host config.

  environment.systemPackages = with pkgs; [ micro git ];
  system.stateVersion = "26.11";
}
