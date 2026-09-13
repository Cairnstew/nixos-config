{ flake, lib, ... }: {
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
    ./disk-config.nix
    flake.inputs.self.nixosModules.common
  ];

  networking.hostName = "oracle";
  nixos-unified.sshTarget = "seanc@oracle";
  nixpkgs.hostPlatform = "aarch64-linux"; # Oracle Always Free Ampere A1 (ARM64)

  # ── System Profiles ──────────────────────────────────────────────────────
  # server profile: headless baseline (SSH + Tailscale + irqbalance, no GUI).
  # location profile: timezone/geolocation (VM lives in Oracle uk-london-1).
  my.profiles = {
    server.enable = true;
    location.enable = true;
  };

  # ── Home Profiles ────────────────────────────────────────────────────────
  # minimal: bash only — keep the tiny VM lean, no GUI tooling.
  my.homeProfiles.minimal.enable = true;

  # ── Location (uk-london-1) ───────────────────────────────────────────────
  my.system.location = {
    # enable = true — redundant: profile already sets via mkIf cfg.location.enable
    timeZone = "Europe/London";
    latitude = 51.5074;
    longitude = -0.1278;
  };

  # ── Tailscale ────────────────────────────────────────────────────────────
  # Enabled by the server profile; tag as cloud so the tailnet ACLs can group
  # cloud hosts separately from home hosts.
  my.services.tailscale = {
    tags = [ "tag:nixos" "tag:cloud" ];
  };

  # ── Monitoring ───────────────────────────────────────────────────────────
  # Node exporter so the home server's Prometheus (my.services.monitoring on
  # `server`) can scrape this box on the tailnet. Follow-up: add the oracle
  # tailscale IP to server's my.services.monitoring.prometheus.scrapeTargets.
  services.prometheus.exporters.node.enable = true;
}