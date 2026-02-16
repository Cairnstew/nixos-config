{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
  homeMod = self + /modules/home;
in
{

  imports = [
    self.nixosModules.udisks2
    self.nixosModules.graphics
    self.nixosModules.xserver

    {
      home-manager.sharedModules = [
        self.homeModules.gnome
      ];
      home-manager.users.${config.me.username}.my.desktop.gnome.enable = true;
    }

  ];
  
  systemModules.graphics.enable = true;
  systemModules.xserver.enable = true;

  services.gvfs.enable = true;
  services.devmon.enable = true;
  

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
