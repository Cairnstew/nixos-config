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
  boot.loader.efi.canTouchEfiVariables = true;
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
    development.enable = true;

    # Desktop
    desktop.gnome.enable = true;

    # Hardware
    gpu.mesa.enable = true;
    battery.enable = true;
    location.enable = true;
  };

  # ── Home Profiles ──────────────────────────────────────────────────────
  my.homeProfiles = {
    common.enable = true;
    desktop.enable = true;
    development.enable = true;
  };

  # ── Location ────────────────────────────────────────────────────────────
  my.system.location = {
    enable = true;
    timeZone = "Europe/London";
    latitude = 55.8617;
    longitude = 4.2583;
  };

  # ── SSH Access
  my.services.ssh.authorizedKeys = [ flake.config.me.sshKey ];

  # ── Tailscale: expose pixrate web app to tag:nixos nodes ──────────────────
  my.services.tailscale.manager.policy.interNodePorts = [ "tcp:22" "tcp:8000" ];

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

  my.programs.spotify.enable = true;

  # ── Home Manager Extra ───────────────────────────────────────────────────
  my.homeManager.extraConfig.my.programs = {
    discord.enable = true;
    localsend.enable = true;
    firefox.enable = true;
    obsidian.enable = true;
    thunderbird.enable = true;
    vscode.enable = true;
    "whatsapp-electron".enable = true;
    "youtube-music".enable = true;
    thunderbird = {
      email = flake.config.me.email;
      username = flake.config.me.username;
    };
  };
}
