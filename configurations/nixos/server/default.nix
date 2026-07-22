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
    ai.enable = false;
    gpu.nvidia-headless.enable = true;
    location.enable = true;
  };

  # ── VS Code Server ──────────────────────────────────────────────────────
  # Enables Remote-SSH on NixOS (patches dynamically linked Node binaries)
  my.programs.vscode.server.enable = true;

  # ── Home Profiles ────────────────────────────────────────────────────────
  my.homeProfiles = {
    common.enable = true;
    server.enable = true;
    development.enable = true;
  };

  # ── Home Manager Extra ───────────────────────────────────────────────────
  my.homeManager.extraConfig.my.programs.goals.enable = true;

  # ── Location ─────────────────────────────────────────────────────────────
  my.system.location = {
    # enable = true — redundant: profile already sets via mkIf cfg.location.enable (M3)
    timeZone = "America/Chicago";
    latitude = 30.2672;
    longitude = -97.7431;
  };

  # ── Networking ──────────────────────────────────────────────────────────
  networking.networkmanager.enable = true;

  # ── Reverse Proxy ─────────────────────────────────────────────────────
  # Unified proxy module: services auto-register with my.services.proxy.upstreams.
  # tailscale serve forwards :443 → nginx:8081 so each service is at
  # https://server.tail685690.ts.net/<service>/.
  # Dashboard at / shows all registered services.
  my.services.proxy = {
    enable = true;
    listenAddresses = [ "127.0.0.1" ];
    tailscaleServe.enable = true;
  };

  # ── Container Storage ──────────────────────────────────────────────────
  # Store container images and volumes on the large SATA data drive (1.8T)
  # to preserve NVMe space for the Nix store and OS.
  my.virtualisation.docker.dataRoot = "/mnt/data/docker-data";

  virtualisation.containers.storage.settings.storage = {
    graphroot = "/mnt/data/containers/storage";
  };

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
    mtu = 1200;
    tags = [ "tag:nixos" "tag:temp" ];
    acceptRoutes = true;
    manager.enable = true;
  };

  # ZeroTier is a tailscale fallback — the watchdog starts/stops it automatically.
  # The service is configured but won't auto-start at boot.
  my.services.zerotier = {
    enable = true;
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

  # ── Manga Reader (sync library to config repo) ───────────────────────────
  my.services.suwayomi = {
    enable = true;
    settings.server = {
      backupInterval = 0;
      extensionRepos = [
        "https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json"
      ];
    };
    openFirewall = true;
    sync.export = {
      enable = true;
      autoPush = true;
      repoPath = "/home/seanc/nixos-config";
      secretPath = "/run/agenix/github-token";
      interval = "daily";
    };
    sync.import.enable = true;
  };

  # ── Ollama (LLM Serving) ───────────────────────────────────────────────
  my.services.ollama = {
    enable = true;
    dataDir = "/mnt/data/ollama";
    gpu.enable = true;
  };

  # ── RisuAI (LLM Roleplay Frontend) ────────────────────────────────────
  my.services.risuai = {
    enable = true;
    dataDir = "/mnt/data/risuai";
    ollama.enable = true;
  };

  # Connect risuai container to ollama-net so it can resolve ollama:11434
  systemd.services."docker-risuai-ollama-net" = {
    description = "Connect risuai container to ollama-net";
    after = [ "docker-risuai.service" ];
    requires = [ "docker-risuai.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.docker}/bin/docker network connect ollama-net risuai 2>/dev/null || true
    '';
  };

  # ── SSH Access ──────────────────────────────────────────────────────────
  my.services.ssh.authorizedKeys = [
    flake.config.me.sshKey
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGEp55lp8743MYUsvmZ4XXnhvJ7c5GQDQzIg9GQzWPbg sean.cairnsst@gmail.com" # desktop
  ];

  # Temporary console password for initial recovery.
  # Remove this line after first SSH login.
  users.users.seanc.initialPassword = "changeme123";

  # ── Unfree Software (allowUnfree set globally in flake.nix) ────────────
  nixpkgs.config = {
    # allowUnfree removed — globally set in flake.nix perSystem (M4d)
    cuda.acceptLicense = true;
  };

}
