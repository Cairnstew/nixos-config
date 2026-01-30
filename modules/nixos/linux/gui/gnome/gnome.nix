{flake, lib, config, pkgs, ... }:
let
  inherit (flake.config.me) zerotier_network;
  inherit (flake.inputs) self;
in
{
  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };

  hardware.opengl.enable = true;

  environment = {
    gnome = {
      excludePackages = [
        pkgs.gnome-tour
        pkgs.gnome-photos
            pkgs.cheese
            pkgs.gnome-music
            pkgs.epiphany
            pkgs.gnome-characters
            pkgs.geary
            pkgs.tali
            pkgs.iagno
            pkgs.hitori
            pkgs.atomix
            pkgs.yelp
            pkgs.gnome-contacts
            pkgs.gnome-initial-setup
          ];
        };
        systemPackages = [
          pkgs.gnome-tweaks
        ];
      };
  programs = {
    dconf = {
      enable = true;
    };
  };
  services = {
    displayManager = {
    	gdm.enable = true;
    };
  
    desktopManager = {
      gnome = {
        enable = true;
      };
    };
    gnome = {
      core-apps = {
        enable = false;
      };
      core-developer-tools = {
        enable = false;
      };
      games = {
        enable = false;
      };
    };
  };
}
