# modules/nixos/gnome/default.nix
# GNOME Desktop Environment configuration
{ flake, config, pkgs, lib, ... }:
let
  cfg = config.my.desktop.gnome;
  homeModule = import ./home.nix;
in
{
  imports = [
    # Share the home module via home-manager
    { home-manager.sharedModules = [ homeModule ]; }
  ];

  # ── Options ────────────────────────────────────────────────────────────────
  options.my.desktop.gnome = {
    enable = lib.mkEnableOption "GNOME desktop environment with GDM display manager";
  };

  # ── Configuration ─────────────────────────────────────────────────────────
  config = lib.mkIf cfg.enable {
    # Enable home module for the user
    home-manager.users.${flake.config.me.username}.my.desktop.gnome.enable = true;

    # ── Filesystems / removable media ────────────────────────────────────────
    services.gvfs.enable = true;
    services.devmon.enable = true;

    # ── Networking ───────────────────────────────────────────────────────────
    networking.networkmanager.enable = true;

    # ── Fonts ─────────────────────────────────────────────────────────────────
    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        inter
        jetbrains-mono
        noto-fonts
        noto-fonts-color-emoji
        nerd-fonts.jetbrains-mono
      ];
      fontconfig.defaultFonts = {
        sansSerif = [ "Inter" ];
        monospace = [ "JetBrains Mono" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };

    # ── Excluded GNOME packages ──────────────────────────────────────────────
    environment.gnome.excludePackages = [
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

    # ── System packages ───────────────────────────────────────────────────────
    environment.systemPackages = with pkgs; [
      gnome-tweaks
      adwaita-icon-theme
      papirus-icon-theme
      kdePackages.breeze-gtk
      kdePackages.breeze-icons
      kdePackages.breeze
    ];

    # ── dconf (required for home-manager dconf settings) ──────────────────────
    programs.dconf.enable = true;

    # ── XDG portal ────────────────────────────────────────────────────────────
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    };

    # ── Display manager & desktop ────────────────────────────────────────────
    # Use new NixOS option names (24.05+)
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
