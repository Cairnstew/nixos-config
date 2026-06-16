{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.desktop.gnome;
  homeModule = import ./home.nix;
in
{
  imports = [
    { home-manager.sharedModules = [ homeModule ]; }
  ];

  config = lib.mkIf cfg.enable {
    home-manager.users.${flake.config.me.username}.my.desktop.gnome.enable = true;

    services.gvfs.enable = true;
    services.devmon.enable = true;
    networking.networkmanager.enable = true;

    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        inter
        jetbrains-mono
        noto-fonts
        noto-fonts-color-emoji
        nerd-fonts.jetbrains-mono
      ];
      fontconfig.defaultFonts = lib.mkIf (!(config.stylix.enable or false)) {
        sansSerif = [ "Inter" ];
        monospace = [ "JetBrains Mono" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };

    environment.gnome.excludePackages = with pkgs; [
      gnome-tour
      gnome-photos
      cheese
      gnome-music
      epiphany
      gnome-characters
      geary
      tali
      iagno
      hitori
      atomix
      yelp
      gnome-contacts
      gnome-initial-setup
    ];

    environment.systemPackages = with pkgs; [
      gnome-tweaks
      gnome-shell-extensions
      adwaita-icon-theme
      papirus-icon-theme
      kdePackages.breeze-gtk
      kdePackages.breeze-icons
      kdePackages.breeze
    ];

    programs.dconf.enable = true;

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    };

    services.xserver.enable = true;

    services.displayManager.gdm = {
      enable = true;
      autoSuspend = false;
    };

    services.desktopManager.gnome.enable = true;

    services.gnome = {
      gnome-keyring.enable = true;
      core-apps.enable = false;
      core-developer-tools.enable = false;
      games.enable = false;
      localsearch.enable = false;
      tinysparql.enable = false;
    };

    security.pam.services.gdm.enableGnomeKeyring = true;
  };
}
