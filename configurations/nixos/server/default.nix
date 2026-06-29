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

  # ── Networking / VPN (Dual-Mesh for Headless Reliability) ──────────────
  # Both Tailscale and ZeroTier run simultaneously so you always have a
  # fallback if one mesh goes down — critical for a completely headless box.

  my.services.tailscale = {
    enable = true;
    tags = [ "tag:nixos" "tag:server" ];
    acceptRoutes = true;
    ssh = {
      enable = true;
      user = "seanc";
      extraHostConfig = "ForwardAgent yes";
    };
  };

  my.services.zerotier = {
    enable = true;
    # ── FIXME: Replace with your ZeroTier network ID ──
    networks = [ ];
    openFirewall = true;
  };

  # ── SSH (LAN Password Fallback) ──────────────────────────────────────
  # Primary: SSH keys via Tailscale SSH + ZeroTier
  # Fallback: Password auth from LAN subnets (for physical access)
  # Tailscale uses 100.64.0.0/10 = not matched; ZeroTier may overlap with
  # private ranges so be specific about your actual LAN subnet.
  my.services.ssh.lanSubnets = [ "192.168.0.0/16" "172.16.0.0/12" ];

  # Boot resilience: Tailscale watchdog, emergency alerting, boot health tracking
  my.services.tailscaleWatchdog.enable = true;
  my.services.bootAlerting.enable = true;
  my.services.bootHealth.enable = true;

  # ── NVIDIA Configuration ───────────────────────────────────────────────
  my.services.ollama = {
    gpu.enable = true;
    gpu.type = "nvidia";
    dataDir = "/mnt/data/ollama";
  };

  # ── SSH Access ──────────────────────────────────────────────────────────
  my.services.ssh.authorizedKeys = [ flake.config.me.sshKey ];

  # ── Swap Configuration ──────────────────────────────────────────────────
  #swapDevices = [{
  #  device = "/mnt/data/storage/swapfile";
  #  size = 32 * 1024;
  #}];

  # ── Unfree Software ─────────────────────────────────────────────────────
  nixpkgs.config = {
    allowUnfree = true;
    cuda.acceptLicense = true;
  };

  # ── Disko / Hardware Config Resolution ──────────────────────────────────
  #fileSystems."/".device = lib.mkForce "/dev/disk/by-partlabel/disk-main-root";
  #fileSystems."/boot".device = lib.mkForce "/dev/disk/by-partlabel/disk-main-boot";
}
