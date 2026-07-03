{ config, lib, pkgs, ... }: {
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;
  i18n.defaultLocale = "en_US.UTF-8";
  services.xserver.xkb = { layout = "us"; variant = ""; };

  # services.openssh.enable removed — minimal profile already enables via my.services.ssh.enable (M3)
  environment.systemPackages = with pkgs; [ micro git ];
  system.stateVersion = "25.11";
}
