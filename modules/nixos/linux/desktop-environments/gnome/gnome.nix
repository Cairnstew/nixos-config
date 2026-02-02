{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
  homeMod = self + /modules/home;
in
{
  home-manager.sharedModules = [
      "${homeMod}/all/desktop-environments/gnome.nix"
    ];
  
  
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
