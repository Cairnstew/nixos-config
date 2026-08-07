# Laptop Configuration
# See: ../../AGENT.md for configuration conventions
{ flake, config, lib, ... }:
{
  imports = [
    # Import hardware config FIRST to set hostPlatform
    ./hardware-configuration.nix
    flake.inputs.self.nixosModules.common
  ];

  # Explicitly set hostPlatform to ensure pkgs is available
  nixpkgs.hostPlatform = "x86_64-linux";

  # ── Bootloader (was in configuration.nix, now inlined) ─────────────────
  boot.loader.systemd-boot.enable = true;
  boot.kernelParams = [ "acpi_backlight=native" ];

  # ── System State ─────────────────────────────────────────────────────────
  system.stateVersion = "24.05";

  # ── System Identity ──────────────────────────────────────────────────────
  networking.hostName = "laptop";
  nixos-unified.sshTarget = "seanc@laptop";

  # ── System Profiles ──────────────────────────────────────────────────────
  my.profiles = {
    # Role
    workstation.enable = true;

    # Desktop — GNOME
    desktop.gnome.enable = true;

    # Hardware
    gpu.mesa.enable = true;
    # F6: redundant — power.laptop profile already mkDefaults battery.enable
    location.enable = true;
    power.laptop.enable = true;

    # Theming
    theming.stylix.enable = true;
  };

  # ── Home Profiles ──────────────────────────────────────────────────────
  my.homeProfiles = {
    common.enable = true;
    desktop.enable = true;
    development.enable = true;
  };

  # ── SSH Access
  # F12: authorizedKeys inherited from common.nix mkDefault (single source of truth)

  # ── Laptop-specific services ─────────────────────────────────────────────
  services.fwupd.enable = true;

  # ── Service Configuration ────────────────────────────────────────────────
  my.services.natShare = {
    enable = true;
    wanInterface = "wlp170s0";
    lanInterface = "enp0s13f0u2";
  };

  # ═══════════════════════════════════════════════════════════════════════════
  #  Additional Programs
  # ═══════════════════════════════════════════════════════════════════════════

  # ── Additional Programs ────────────────────────────────────────────────
  my.programs.ventoy.enable = true;

  # ── Home Manager Extra ───────────────────────────────────────────────────
  my.homeManager.extraConfig.my.programs = {
    # T2: discord/firefox/spotify/obsidian/thunderbird/vscode already mkDefault'd by
    # homeProfiles.desktop (profiles/home/config.nix:26-38) — only genuinely per-host
    # extras kept below.
    localsend.enable = true;
    "whatsapp-electron".enable = true;
    "youtube-music".enable = true;
  };

  my.homeManager.extraConfig.my.programs.direnv.secretFiles.spotify = {
    paths = {
      SPOTIFY_CRED = config.age.secrets."spotify-cred".path;
    };
  };
}
