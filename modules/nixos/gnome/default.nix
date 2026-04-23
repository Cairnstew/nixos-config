{ flake, config, pkgs, lib, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
  homeModule = import ./home.nix;
in
{
  imports = [
    {
      home-manager.sharedModules = [ homeModule ];
    }
  ];

  options.systemModules.gnome.enable = lib.mkEnableOption "GNOME desktop environment";

  config = lib.mkIf config.systemModules.gnome.enable {
    home-manager.users.${flake.config.me.username}.my.desktop.gnome.enable = true;
    # ── Filesystems / removable media ─────────────────────────────────────────
    services.gvfs.enable   = true;
    services.devmon.enable = true;

    # ── Networking (connectivity indicator in top bar) ────────────────────────
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
        monospace  = [ "JetBrains Mono" ];
        emoji      = [ "Noto Color Emoji" ];
      };
    };

    # ── Excluded GNOME bloat ───────────────────────────────────────────────────
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

    # ── System packages ────────────────────────────────────────────────────────
    environment.systemPackages = with pkgs; [
      gnome-tweaks
      adwaita-icon-theme
      papirus-icon-theme
      kdePackages.breeze-gtk
      kdePackages.breeze-icons
      kdePackages.breeze
    ];

    # ── dconf (required for home-manager dconf settings to apply) ─────────────
    programs.dconf.enable = true;

    # ── XDG portal (needed by Flatpak, screen sharing, file pickers) ──────────
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    };

    # ── Display manager & desktop ─────────────────────────────────────────────
    services = {
      xserver.displayManager.gdm = {
        enable      = true;
        autoSuspend = false;
      };

      xserver.desktopManager.gnome.enable = true;

      gnome = {
        gnome-keyring.enable = true;

        core-apps.enable            = false;
        core-developer-tools.enable = false;
        games.enable                = false;

        localsearch.enable = false;
        tinysparql.enable  = false;
      };
    };

    security.pam.services.gdm.enableGnomeKeyring = true;
  };
}