{ flake, lib, config, pkgs, ... }:
{
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
    ./disk-config.nix
    flake.inputs.self.nixosModules.common
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # ── System Identity ──────────────────────────────────────────────────────
  networking.hostName = "server";
  nixos-unified.sshTarget = "seanc@server";

  # ── State Version ────────────────────────────────────────────────────────
  # Must match the nixpkgs version this was first installed with
  system.stateVersion = "24.05";

  # ── System Profiles ──────────────────────────────────────────────────────
  my.profiles = {
    server.enable = true;
    development.enable = true;
    gpu.nvidia-headless.enable = true;
    location.enable = true;
  };

  # ── Home Profiles ────────────────────────────────────────────────────────
  my.homeProfiles = {
    common.enable = true;
    server.enable = true;
    development.enable = true;
  };

  # ── Location ─────────────────────────────────────────────────────────────
  my.system.location = {
    timeZone = "America/Chicago";
    latitude = 30.2672;
    longitude = -97.7431;
  };

  # ── Networking ──────────────────────────────────────────────────────────
  networking.networkmanager.enable = true;

  # ── Nix Build Directory ─────────────────────────────────────────────────
  # Use the large SATA data disk (1.8T) for build temp files to preserve
  # NVMe space for the Nix store and OS.
  nix.settings.build-dir = "/mnt/data/nix-build";

  # Ensure the build directory exists before nix tries to use it
  systemd.tmpfiles.rules = [ "d /mnt/data/nix-build 0755 root root -" ];

  # ── Networking / VPN (Dual-Mesh for Headless Reliability) ──────────────
  # Both Tailscale and ZeroTier run simultaneously so you always have a
  # fallback if one mesh goes down — critical for a completely headless box.

  my.services.tailscale = {
    enable = true;
    tags = [ "tag:nixos" "tag:temp" ];
    acceptRoutes = true;
    ssh = {
      enable = true;
      user = "seanc";
      extraHostConfig = "ForwardAgent yes";
    };
  };

  # ZeroTier is a tailscale fallback — the watchdog starts/stops it automatically.
  # The service is configured but won't auto-start at boot.
  my.services.zerotier = {
    enable = true;
    openFirewall = true;
  };

  # Email alerts: provides send-alert command for system notifications
  my.services.emailAlerts.enable = true;

  # Tailscale watchdog: monitors connectivity, starts zerotier on failure, alerts via email
  my.services.tailscaleWatchdog.enable = true;

  # ── SSH (LAN Password Fallback) ──────────────────────────────────────
  # Primary: SSH keys via Tailscale SSH + ZeroTier
  # Fallback: Password auth from LAN subnets (for physical access)
  # Tailscale uses 100.64.0.0/10 = not matched; ZeroTier may overlap with
  # private ranges so be specific about your actual LAN subnet.
  my.services.ssh.lanSubnets = [ "192.168.0.0/16" "172.16.0.0/12" ];

  # Boot resilience: Emergency alerting, boot health tracking
  my.services.bootAlerting.enable = true;
  my.services.bootHealth = {
    enable = true;
    autoRollback.enable = true;
  };

  # ── NVIDIA Configuration ───────────────────────────────────────────────
  my.services.ollama = {
    gpu.enable = true;
    gpu.type = "nvidia";
    dataDir = "/mnt/data/ollama";
  };

  # ── SSH Access ──────────────────────────────────────────────────────────
  my.services.ssh.authorizedKeys = [
    flake.config.me.sshKey
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGEp55lp8743MYUsvmZ4XXnhvJ7c5GQDQzIg9GQzWPbg sean.cairnsst@gmail.com" # desktop
  ];

  # Temporary console password for initial recovery.
  # Remove this line after first SSH login.
  users.users.seanc.initialPassword = "changeme123";

  # ── Unfree Software ─────────────────────────────────────────────────────
  nixpkgs.config = {
    allowUnfree = true;
    cuda.acceptLicense = true;
  };

}
