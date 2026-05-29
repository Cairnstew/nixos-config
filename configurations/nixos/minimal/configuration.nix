{ config, lib, pkgs, ... }: {
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "minimal";
  networking.networkmanager.enable = true;
  i18n.defaultLocale = "en_US.UTF-8";
  services.xserver.xkb = { layout = "us"; variant = ""; };

  users.users.seanc = {
    isNormalUser = true;
    description = "Sean Cairns";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  services.openssh.enable = true;
  environment.systemPackages = with pkgs; [ micro git ];
  system.stateVersion = "25.11";
}
