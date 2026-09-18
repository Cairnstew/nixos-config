# Laptop Configuration
# See: ../../AGENT.md for configuration conventions
{ flake, config, lib, pkgs, ... }:
{
  imports = [
    # Import hardware config FIRST to set hostPlatform
    ./hardware-configuration.nix
    flake.inputs.self.nixosModules.common
    flake.inputs.self.nixosModules.eduroam
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
    development.enable = true;

    # Desktop — Hyprland
    desktop.choice = "hyprland";

    # Hardware
    gpu.mesa.enable = true;
    location.enable = true;
    # Battery-aware power management (auto-cpufreq, thermald, logind lid
    # handling). Replaces power.laptop, which is GNOME-only and asserts
    # desktop.gnome.enable. For Hyprland, idle/lock/suspend is handled by
    # hypridle (my.desktop.hyprland.idle).
    battery.enable = true;

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

  # ── Eduroam (GCU WiFi) ─────────────────────────────────────────────────────
  # Declarative WPA2-Enterprise profile. Password stored in agenix secret.
  # On campus: eduroam auto-connects. Off campus: profile is inert.
  # To set the secret:  echo -n 'yourpassword' > /tmp/eduroam-pw
  #                     agenix-manager new eduroam-password --file /tmp/eduroam-pw
  my.networking.eduroam = {
    enable = true;
    identity = "SCAIRN303@gcu.ac.uk"; # ← replace with your GCU student/staff email
    interface = "wlp170s0";
    domain = "gcu.ac.uk";
  };

  # ── Laptop-specific services ─────────────────────────────────────────────
  services.fwupd.enable = true;

  # ── Reverse Proxy ────────────────────────────────────────────────────────
  # Unified proxy module: services auto-register with my.services.proxy.upstreams.
  # Caddy serves the service dashboard at / and proxies subpaths to each backend.
  # tailscale serve forwards :443 → Caddy:8081 so each service is at
  # https://laptop.tail685690.ts.net/<service>/.
  my.services.proxy = {
    listenAddresses = [ "100.108.181.64" "127.0.0.1" ];
    tailscaleServe.enable = true;
    dashboard.title = "${lib.toUpper (builtins.substring 0 1 config.networking.hostName)}${builtins.substring 1 (builtins.stringLength config.networking.hostName) config.networking.hostName} Dashboard";
  };

  # ── Service Configuration ────────────────────────────────────────────────
  my.services.natShare = {
    enable = true;
    wanInterface = "wlp170s0";
    lanInterface = "enp0s13f0u2";
  };

  # ── Jupyter Template Projects ───────────────────────────────────────────
  # Created on every rebuild so they're always available.
  # Runs as primary user since dataDir lives in ~/Documents.
  my.services.jupyter = {
    user = flake.config.me.username;
    group = "users";
    passwordFile = config.age.secrets.jupyter-password.path;
    templates = [
      { name = "project_template"; packages = [ "ipykernel" ]; description = "Starter template"; }
    ];
  };

  # ═══════════════════════════════════════════════════════════════════════════
  #  Additional Programs
  # ═══════════════════════════════════════════════════════════════════════════

  # ── Additional Programs ────────────────────────────────────────────────
  my.programs.ventoy.enable = true;

  # mosh client — pair with server's my.services.mosh for lag-free sessions
  # over flaky links (UDP, survives relay flaps).
  environment.systemPackages = with pkgs; [ mosh ];

  # ── Backup Source ───────────────────────────────────────────────────────
  # Push /home/seanc to the server's restic repository over SFTP (tailnet
  # SSH port 22). Inert until the backup-repo-passphrase agenix secret exists.
  my.services.backup-source = {
    enable = true;
    jobs.home = {
      paths = [ "/home/seanc" ];
    };
  };

  # ── OpenCode Zen provider ────────────────────────────────────────────────
  # The laptop uses a dedicated zen key (laptop-opencode-key) instead of the
  # shared OpenCode token used by default on all other hosts.
  my.homeManager.extraConfig.my.programs.opencode.opencode-zen.keyFile =
    config.age.secrets.laptop-opencode-key.path;
}
