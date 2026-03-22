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
  systemModules.xserver.enable  = true;

  # ── Filesystems / removable media ─────────────────────────────────────────
  services.gvfs.enable   = true;
  services.devmon.enable = true;

  # ── Keyring & secrets ─────────────────────────────────────────────────────
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.gdm.enableGnomeKeyring = true;

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
      nerd-fonts.jetbrains-mono    # new per-font package
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
    kdePackages.breeze          # provides Breeze_Snow cursor
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
    displayManager.gdm = {
      enable      = true;
      autoSuspend = false;   # prevent GDM itself from suspending at login screen
    };

    desktopManager.gnome.enable = true;

    gnome = {
      core-apps.enable            = false;
      core-developer-tools.enable = false;
      games.enable                = false;

      # Tracker (file indexer) — disable if you don't use GNOME Search
      tracker-miners.enable = false;
      tracker.enable        = false;
    };
  };
}