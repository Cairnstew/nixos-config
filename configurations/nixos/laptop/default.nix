# Laptop Configuration
# See: ../../AGENT.md for configuration conventions
{ flake, ... }:
{
  imports = [
    # Import hardware config FIRST to set hostPlatform
    ./hardware-configuration.nix
    flake.inputs.self.nixosModules.common
  ];

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

    # Desktop — GNOME
    desktop.gnome.enable = true;

    # Hardware
    gpu.mesa.enable = true;
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

  # ── Backup Source ───────────────────────────────────────────────────────
  # Push /home/seanc to the server's restic repository over SFTP (tailnet
  # SSH port 22). Inert until the backup-repo-passphrase agenix secret exists.
  my.services.backup-source = {
    enable = true;
    jobs.home = {
      paths = [ "/home/seanc" ];
    };
  };

}
