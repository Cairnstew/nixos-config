{ flake, lib, config, pkgs, ... }:
{
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
    ./disk-config.nix
    flake.inputs.self.nixosModules.common
  ];

  # ── System Identity ──────────────────────────────────────────────────────
  networking.hostName = "server";
  nixos-unified.sshTarget = "seanc@server";

  # ── State Version ────────────────────────────────────────────────────────
  # Must match the nixpkgs version this was first installed with
  system.stateVersion = "24.05";

  # ── System Profiles ──────────────────────────────────────────────────────
  my.profiles = {
    server.enable = true;
    ai.enable = true;
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
  # Terminal opencode must not run while the browser (web) session is live —
  # both share ~/.config/opencode and the ensemble DB. Gate both directions.
  my.homeManager.extraConfig.my.programs.opencode.sessionGate.enable = true;

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
  # tailscale serve forwards :443 → caddy:8081 so each service is at
  # https://server.tail685690.ts.net/<service>/.
  # Dashboard at / shows all registered services.
  my.services.proxy = {
    # F4: proxy.enable is common.nix mkDefault true — redundant here (recon F4)
    # F5: listenAddresses [ "127.0.0.1" ] is the proxy/options.nix default — redundant here (recon F5)
    tailscaleServe.enable = true;
  };

  # ── Monitoring ─────────────────────────────────────────────────────────
  # Prometheus collects node-exporter metrics from this host and the
  # desktop (100.121.125.58); Grafana is served at /grafana behind Caddy.
  # Grafana binds 3001 (3000 is used by open-webui via the ai profile).
  my.services.monitoring = {
    enable = true;
    prometheus = {
      enable = true;
      scrapeTargets = [ "100.121.125.58:9100" ]; # desktop node-exporter
    };
    grafana = {
      enable = true;
      rootUrl = "https://server.tail685690.ts.net/grafana/";
    };
  };

  # ── Backup Target ──────────────────────────────────────────────────────
  # Hosts restic repositories for desktop/laptop under /mnt/data/backup
  # (SFTP-chrooted over tailnet SSH port 22 — no new ports). Each source's
  # subdirectory is pre-provisioned here; public keys are filled in once the
  # shared backup-ssh-key is generated (Tier 1 secrets step).
  my.services.backup-target = {
    enable = true;
    sources = {
      desktop = {
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBeutWkI0m3IvLKyb67OoKQ/q6CKAgeEtd43+kAi6X2C backup@nixos";
      };
      laptop = {
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBeutWkI0m3IvLKyb67OoKQ/q6CKAgeEtd43+kAi6X2C backup@nixos";
      };
    };
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
  my.services.tailscaleWatchdog = {
    enable = true;
    canaryPeers = [ "100.121.125.58" "100.70.43.44" ]; # desktop, pikvm
  };

  # ── SSH Resilience Stack ─────────────────────────────────────────────────
  # MSS clamping: root-cause fix for the MTU blackhole (tailscaled resets
  # tailscale0 to 1280 on restart; this clamps TCP MSS on the tunnel so large
  # packets survive instead of being silently dropped while ping still works).
  # MSS auto-derived: tailscale mtu 1200 → 1140.
  my.services.mssClamp.enable = true;

  # mosh + tmux: sessions survive mesh/VPN restarts (mosh rides UDP and
  # reconnects when the mesh comes back). openFirewall lets it work over the
  # ZeroTier/LAN fallback too, not just the (trusted) tailnet.
  my.services.mosh = {
    enable = true;
    openFirewall = true;
  };

  # Tor onion-service SSH: zero-inbound-port last resort. Works when both
  # meshes AND all inbound connectivity fail. Address: cat /var/lib/tor/onion/ssh/hostname
  my.services.torSsh.enable = true;

  # ttyd web console: browser-based emergency shell. Bound to the ZeroTier IP
  # so it's reachable even when Tailscale is down (basic auth protects it).
  my.services.ttyd = {
    enable = true;
    address = "192.168.191.54"; # ZeroTier IP (zt2lr37ya6) — Tailscale-independent path
    username = "seanc";
    passwordFile = config.age.secrets."ttyd-password".path;
    openFirewall = true; # listener binds only to the ZT IP, so this is ZT-scoped
  };
  my.services.proxy.upstreams.ttyd.host = "192.168.191.54"; # Caddy → ttyd on ZT IP

  # autossh phone-home reverse tunnel: reach this box via plain internet SSH
  # even when every mesh is down. Requires a bastion host you own — uncomment
  # and set `bastion` once you have one:
  # my.services.autosshReverse = {
  #   enable = true;
  #   bastion = "seanc@bastion.example.com";
  # };

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

  # ── ComfyUI (AI Image Generation) ───────────────────────────────────────
  my.services.comfyui = {
    # F7: comfyui.enable is mkDefault true via profiles/system/ai.nix — redundant here (recon F7)
    dataDir = "/mnt/data/comfyui";
  };

  # ── Manga Reader (sync library to config repo) ───────────────────────────
  my.services.suwayomi = {
    enable = true;
    autoBindTailscaleIp = true;
    settings.server = {
      # backupInterval is a FREEFORM HOCON field (options.nix freeformType) — cannot carry a
      # module default, so it stays explicit here (recon F11)
      backupInterval = 0;
    };
    openFirewall = true;
    # F11: extensionRepos, sync.export.{enable,autoPush,repoPath,secretPath}, sync.import.enable
    # now module defaults (suwayomi/sync-options.nix) — invariant core duplicated desktop/server removed
    sync.export.interval = "daily"; # F11: divergent — desktop hourly vs server daily (recon F11)
  };

  # Caddy upstream must point to the Tailscale IP when autoBindTailscaleIp is on
  my.services.proxy.upstreams.suwayomi.host = "100.78.102.28";

  # ── Minecraft Server (Dragon Technology modpack) ─────────────────────────
  # Prism Launcher is a client launcher and cannot run a server. This wraps the
  # exported modpack (NeoForge 1.21.1) into a declarative nix-minecraft server.
  my.services.minecraftServer = {
    enable = true;
    eula = true; # Mojang EULA — required
    dataDir = "/mnt/data/minecraft";

    servers.dragon-technology = {
      package = pkgs.neoforgeServers.neoforge-1_21_1-21_1_238;
      jvmOpts = "-Xms4G -Xmx8G";
      # pack: server-safe modpack content dir (mods/config/kubejs/scripts/datapacks/
      # defaultconfigs are symlinked in). Create it on the server by extracting the
      # Prism export's minecraft/ dir and stripping client-only junk (saves,
      # shaderpacks, screenshots, .mixin.out, .sable). The Dragon Technology pack
      # is 834 MB, so it is NOT committed to this repo:
      #   ssh server "mkdir -p /mnt/data/minecraft/packs && rsync -a minecraft/ ..."
      # For a small published pack you can instead use:
      #   pack = pkgs.fetchModrinthModpack { url = "..."; packHash = "sha256-..."; side = "server"; };
      pack = "/mnt/data/minecraft/packs/dragon-technology";

      serverProperties = {
        server-port = 25565;
        max-players = 12;
        motd = "Dragon Technology";
        white-list = true;
        enable-query = true;
      };
      whitelist = { };
      operators = { };
      openFirewall = true;
    };
  };

  # Memory cap for the Minecraft server (nix-minecraft hardens the rest).
  systemd.services.minecraft-server-dragon-technology.serviceConfig.MemoryMax = "12G";

  # ── Ollama (LLM Serving) ───────────────────────────────────────────────
  my.services.ollama = {
    enable = true;
    dataDir = "/mnt/data/ollama";
    gpu.enable = true;
    models = {
      "hf.co/Lewdiculous/DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small-GGUF-IQ-Imatrix:Q4_K_M-imat" = {
        name = "ArliAI DS-R1-Qwen3-8B RpR v4";
        numCtx = 16000;
        temperature = 0.6;
        topP = 0.95;
        topK = 40;
        repeatPenalty = 1.1;
      };
    };
  };

  # ── RisuAI (LLM Roleplay Frontend) ────────────────────────────────────
  my.services.risuai = {
    # F7: risuai.enable is mkDefault true via profiles/system/ai.nix — redundant here (recon F7)
    dataDir = "/mnt/data/risuai";
    ollama.enable = true;
    # H12: attach risuai to ollama-net (so it resolves ollama:11434) via the module's
    # network.name option — replaces the hand-rolled docker-risuai-ollama-net unit removed below.
    network.name = "ollama-net";
    # Default user settings enforced into the RisuAI save DB on container start:
    # parse thinking out of replies (was 'auto', which leaked <think> blocks) and
    # disable strict JSON schema so prose stays conversational.
    settings = {
      ollamaThinkingMode = "on";
      strictJsonSchema = false;
    };
  };

  # ── Neko (Remote Browser) — disabled 2026-07-30 ─────────────────────────
  my.services.neko.enable = false;

  # ── Squid Forward Proxy (Browser Egress) ────────────────────────────────
  my.services.squidProxy.enable = true;

  # H12: hand-rolled docker-risuai-ollama-net oneshot removed — the risuai module's
  # network.name option (set above to "ollama-net") now attaches the container at creation,
  # and the module + ollama both inspect-guard network creation, so no duplicate unit is needed.

  # ── SSH Access ──────────────────────────────────────────────────────────
  # F12: extra key only — me.sshKey is inherited from common.nix mkDefault.
  # Must stay lib.mkDefault: a plain assignment would override common's
  # mkDefault and LOSE me.sshKey; same-priority mkDefaults merge via
  # types.listOf concatenation → [ me.sshKey "desktop-key" ].
  my.services.ssh.authorizedKeys = lib.mkDefault [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGEp55lp8743MYUsvmZ4XXnhvJ7c5GQDQzIg9GQzWPbg sean.cairnsst@gmail.com" ]; # desktop

  # ── Unfree Software (allowUnfree set globally in flake.nix) ────────────
  nixpkgs.config = {
    # allowUnfree removed — globally set in flake.nix perSystem (M4d)
    cuda.acceptLicense = true;
  };

}
